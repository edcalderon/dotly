import { DatabaseSync } from 'node:sqlite';
import { mkdirSync, chmodSync } from 'node:fs';
import { join } from 'node:path';
import { createHash } from 'node:crypto';
import { setTimeout as sleep } from 'node:timers/promises';

export function canonical(value) {
  if (Array.isArray(value)) return value.map(canonical);
  if (value && typeof value === 'object') return Object.fromEntries(Object.keys(value).sort().map(k => [k, canonical(value[k])]));
  return value;
}
export const revision = value => createHash('sha256').update(JSON.stringify(canonical(value))).digest('hex');

export class Store {
  constructor(directory) {
    mkdirSync(directory, { recursive: true, mode: 0o700 });
    chmodSync(directory, 0o700);
    this.db = new DatabaseSync(join(directory, 'bridge.sqlite'));
    chmodSync(join(directory, 'bridge.sqlite'), 0o600);
    this.db.exec(`PRAGMA journal_mode=WAL; PRAGMA busy_timeout=5000;
      CREATE TABLE IF NOT EXISTS operations (
        key TEXT PRIMARY KEY, fingerprint TEXT NOT NULL, status TEXT NOT NULL,
        result TEXT, before_data TEXT, error TEXT, created_at TEXT NOT NULL
      );
      CREATE TABLE IF NOT EXISTS briefs (project_id TEXT PRIMARY KEY, text TEXT NOT NULL, revision TEXT NOT NULL);
      CREATE TABLE IF NOT EXISTS write_lock (id INTEGER PRIMARY KEY CHECK(id=1), owner TEXT NOT NULL, expires INTEGER NOT NULL);
      CREATE TABLE IF NOT EXISTS audit (id INTEGER PRIMARY KEY, at TEXT NOT NULL, action TEXT NOT NULL, detail TEXT NOT NULL);`);
  }
  audit(action, detail) {
    this.db.prepare('INSERT INTO audit(at, action, detail) VALUES(?,?,?)').run(new Date().toISOString(), action, JSON.stringify(detail));
  }
  async mutate(key, payload, work) {
    const fingerprint = revision(payload);
    this.db.exec('BEGIN IMMEDIATE');
    try {
      const prior = this.db.prepare('SELECT * FROM operations WHERE key=?').get(key);
      if (prior) {
        if (prior.fingerprint !== fingerprint) throw new Error('IDEMPOTENCY_CONFLICT: this requestId was used with different arguments.');
        if (prior.status === 'done') { this.db.exec('COMMIT'); return JSON.parse(prior.result); }
        throw new Error(`REQUEST_${prior.status.toUpperCase()}: do not retry with a new requestId. Inspect the task and local operation log first.`);
      }
      this.db.prepare('INSERT INTO operations(key,fingerprint,status,created_at) VALUES(?,?,?,?)').run(key, fingerprint, 'pending', new Date().toISOString());
      this.db.exec('COMMIT');
    } catch (error) { if (this.db.isTransaction) this.db.exec('ROLLBACK'); throw error; }
    let upstreamReturned = false;
    try {
      // Serialize task writes across MCP sessions/processes. The upstream API has no CAS.
      const deadline = Date.now() + 20000;
      while (true) {
        const now = Date.now();
        const acquired = this.db.prepare(`INSERT INTO write_lock VALUES(1,?,?)
          ON CONFLICT(id) DO UPDATE SET owner=excluded.owner,expires=excluded.expires
          WHERE write_lock.expires < ?`).run(key, now + 120000, now);
        if (acquired.changes) break;
        if (now > deadline) throw new Error('WRITE_BUSY: another bridge write is in progress.');
        await sleep(100);
      }
      const result = await work(before => this.db.prepare('UPDATE operations SET before_data=? WHERE key=?').run(JSON.stringify(before), key));
      upstreamReturned = true;
      this.db.prepare('UPDATE operations SET status=?,result=? WHERE key=?').run('done', JSON.stringify(result), key);
      this.audit(payload.action, { requestId: key, taskId: result.task?.id, projectId: result.projectId, result: 'done' });
      return result;
    } catch (error) {
      const uncertain = error.uncertain || upstreamReturned;
      this.db.prepare('UPDATE operations SET status=?,error=? WHERE key=?').run(uncertain ? 'uncertain' : 'failed', error.message, key);
      this.audit(payload.action, { requestId: key, result: uncertain ? 'uncertain' : 'failed' });
      throw error;
    } finally { this.db.prepare('DELETE FROM write_lock WHERE owner=?').run(key); }
  }
  brief(projectId) { return this.db.prepare('SELECT text,revision FROM briefs WHERE project_id=?').get(projectId) || { text: '', revision: revision('') }; }
  saveBrief(projectId, text, expectedRevision) {
    this.db.exec('BEGIN IMMEDIATE');
    try {
      const old = this.brief(projectId);
      if (old.revision !== expectedRevision) throw new Error('CONFLICT: project brief changed. Read it again before saving.');
      const next = revision(text);
      this.db.prepare('INSERT INTO briefs VALUES(?,?,?) ON CONFLICT(project_id) DO UPDATE SET text=excluded.text,revision=excluded.revision').run(projectId, text, next);
      this.audit('save_project_brief', { projectId, before: old, afterRevision: next });
      this.db.exec('COMMIT'); return { projectId, text, revision: next };
    } catch (error) { this.db.exec('ROLLBACK'); throw error; }
  }
  close() { this.db.close(); }
}
