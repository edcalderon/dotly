// Read-only by default. --write creates, updates and removes ONE labelled test task.
import assert from 'node:assert/strict';
import { randomUUID } from 'node:crypto';
import { fileURLToPath } from 'node:url';
import { Client } from '@modelcontextprotocol/sdk/client/index.js';
import { StdioClientTransport } from '@modelcontextprotocol/sdk/client/stdio.js';
import { config } from './config.js';
import { SpApi } from './api.js';

const api = new SpApi(config().tokenFile);
const client = new Client({ name: 'dotly-live-verification', version: '1.0' });
const transport = new StdioClientTransport({ command: process.execPath, args: [fileURLToPath(new URL('./server.js', import.meta.url))], env: { ...process.env }, stderr: 'pipe' });
let createdId;
try {
  await client.connect(transport);
  const call = async (name, args) => {
    const result = await client.callTool({ name, arguments: args });
    if (result.isError) throw new Error(result.content[0].text);
    return result.structuredContent;
  };
  const { projects } = await call('list_projects', {});
  const before = await api.tasks({ includeDone: true });
  const found = await call('search_tasks', { includeDone: true, limit: 100 });
  assert.equal(found.total, before.length);
  console.log(`Verified MCP reads: ${projects.length} projects, ${found.total} tasks.`);
  if (process.argv.includes('--write')) {
    const project = projects.find(p => p.id === 'INBOX_PROJECT') || projects.find(p => !p.isArchived);
    const args = { requestId: randomUUID(), projectId: project.id, title: '[Temporary] ChatGPT bridge connection test' };
    const created = await call('create_task', args); createdId = created.task.id;
    const duplicate = await call('create_task', args);
    assert.equal(duplicate.task.id, createdId);
    const fresh = await call('get_task', { taskId: createdId });
    const updated = await call('update_task', { requestId: randomUUID(), taskId: createdId, expectedRevision: fresh.revision, changes: { isDone: true } });
    assert.equal(updated.task.isDone, true);
    assert.equal((await api.task(createdId)).isDone, true);
    console.log('Verified live create, duplicate retry and completion.');
    await api.request('DELETE', `/tasks/${encodeURIComponent(createdId)}`); createdId = undefined;
    const after = await api.tasks({ includeDone: true });
    assert.deepEqual(after.map(t => t.id).sort(), before.map(t => t.id).sort());
    console.log('Temporary task removed; original task IDs preserved.');
  }
} finally {
  if (createdId) await api.request('DELETE', `/tasks/${encodeURIComponent(createdId)}`);
  await client.close();
}
