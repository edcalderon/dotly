import test from 'node:test';
import assert from 'node:assert/strict';
import { mkdtempSync, rmSync } from 'node:fs';
import { tmpdir } from 'node:os';
import { join } from 'node:path';
import { Store } from '../src/store.js';
import { Bridge } from '../src/bridge.js';
import { ApiError } from '../src/api.js';

function fixture(t) {
  const dir = mkdtempSync(join(tmpdir(), 'sp-bridge-test-'));
  const store = new Store(dir);
  const tasks = new Map([['task-1', { id: 'task-1', title: 'Original', projectId: 'project-1', isDone: false }]]);
  let creates = 0;
  const api = {
    projects: async () => [{ id: 'project-1', title: 'Project' }, { id: 'project-2', title: 'Other' }],
    tasks: async () => [...tasks.values()],
    task: async id => structuredClone(tasks.get(id)),
    create: async fields => { creates++; const task = { id: 'new-task', ...fields }; tasks.set(task.id, task); return task; },
    update: async (id, fields) => { const task = { ...tasks.get(id), ...fields }; tasks.set(id, task); return task; },
  };
  t.after(() => { store.close(); rmSync(dir, { recursive: true, force: true }); });
  return { dir, store, api, tasks, bridge: new Bridge(api, store), creates: () => creates };
}
test('repeated create returns same task even with another database connection', async t => {
  const f = fixture(t), args = { requestId: 'request-0001', projectId: 'project-1', title: 'New' };
  const first = await f.bridge.create(args);
  const otherStore = new Store(f.dir);
  try {
    const second = await new Bridge(f.api, otherStore).create(args);
    assert.deepEqual(first, second); assert.equal(f.creates(), 1);
  } finally { otherStore.close(); }
  await assert.rejects(f.bridge.create({ ...args, title: 'Different' }), /IDEMPOTENCY_CONFLICT/);
});
test('concurrent calls cannot duplicate the same operation', async t => {
  const f = fixture(t), args = { requestId: 'request-0002', projectId: 'project-1', title: 'New' };
  const results = await Promise.allSettled([f.bridge.create(args), f.bridge.create(args)]);
  assert.equal(results.filter(r => r.status === 'fulfilled').length, 1);
  assert.equal(f.creates(), 1);
});
test('stale edits reject rather than overwrite a desktop edit', async t => {
  const f = fixture(t), read = await f.bridge.getTask('task-1');
  f.tasks.get('task-1').title = 'Changed in desktop';
  await assert.rejects(f.bridge.update({ requestId: 'request-0003', taskId: 'task-1', expectedRevision: read.revision, changes: { title: 'From ChatGPT' } }), /CONFLICT/);
  assert.equal(f.tasks.get('task-1').title, 'Changed in desktop');
});
test('updates log the original task and preserve unspecified fields', async t => {
  const f = fixture(t), read = await f.bridge.getTask('task-1');
  const result = await f.bridge.update({ requestId: 'request-0004', taskId: 'task-1', expectedRevision: read.revision, changes: { isDone: true } });
  assert.equal(result.task.title, 'Original'); assert.equal(result.task.isDone, true);
  const before = f.store.db.prepare('SELECT before_data FROM operations WHERE key=?').get('request-0004');
  assert.equal(JSON.parse(before.before_data).isDone, false);
});
test('ambiguous upstream timeout blocks replay', async t => {
  const f = fixture(t); let attempts = 0;
  f.api.create = async () => { attempts++; throw new ApiError('timeout', { uncertain: true }); };
  const args = { requestId: 'request-0005', projectId: 'project-1', title: 'New' };
  await assert.rejects(f.bridge.create(args), /timeout/);
  await assert.rejects(f.bridge.create(args), /REQUEST_UNCERTAIN/);
  assert.equal(attempts, 1);
});
test('project restrictions apply to reads, creates and moves', async t => {
  const f = fixture(t), b = new Bridge(f.api, f.store, ['project-1']);
  assert.equal((await b.projects()).length, 1);
  await assert.rejects(b.create({ requestId: 'request-0006', projectId: 'project-2', title: 'No' }), /PROJECT_NOT_ALLOWED/);
  const read = await b.getTask('task-1');
  await assert.rejects(b.update({ requestId: 'request-0007', taskId: 'task-1', expectedRevision: read.revision, changes: { projectId: 'project-2' } }), /PROJECT_NOT_ALLOWED/);
  f.tasks.set('private', { id: 'private', projectId: 'project-2' });
  await assert.rejects(b.getTask('private'), /PROJECT_NOT_ALLOWED/);
});
test('shared brief revision prevents overwriting another editor', async t => {
  const f = fixture(t), initial = f.store.brief('project-1');
  await f.bridge.saveBrief({ projectId: 'project-1', text: 'Goals', expectedRevision: initial.revision });
  await assert.rejects(f.bridge.saveBrief({ projectId: 'project-1', text: 'Stale', expectedRevision: initial.revision }), /CONFLICT/);
  assert.equal(f.store.brief('project-1').text, 'Goals');
});
