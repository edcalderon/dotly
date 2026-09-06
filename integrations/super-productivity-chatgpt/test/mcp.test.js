import test from 'node:test';
import assert from 'node:assert/strict';
import { mkdtempSync, rmSync } from 'node:fs';
import { tmpdir } from 'node:os';
import { join } from 'node:path';
import { fileURLToPath } from 'node:url';
import { Client } from '@modelcontextprotocol/sdk/client/index.js';
import { StdioClientTransport } from '@modelcontextprotocol/sdk/client/stdio.js';

test('stdio MCP handshake, safe tool metadata and input validation', async () => {
  const dir = mkdtempSync(join(tmpdir(), 'sp-mcp-test-'));
  const client = new Client({ name: 'bridge-test', version: '1.0' });
  const transport = new StdioClientTransport({ command: process.execPath, args: [fileURLToPath(new URL('../src/server.js', import.meta.url))], env: { ...process.env, SP_BRIDGE_DATA_DIR: dir }, stderr: 'pipe' });
  try {
    await client.connect(transport);
    const { tools } = await client.listTools();
    assert.equal(tools.length, 8);
    assert.equal(tools.find(t => t.name === 'update_task').annotations.readOnlyHint, false);
    assert.equal(tools.find(t => t.name === 'get_task').annotations.readOnlyHint, true);
    assert.equal(tools.some(t => /delete|overwrite|shell/.test(t.name)), false);
    const response = await client.callTool({ name: 'update_task', arguments: { taskId: 'x', changes: { title: 'x' } } });
    assert.equal(response.isError, true);
  } finally { await client.close(); rmSync(dir, { recursive: true, force: true }); }
});
