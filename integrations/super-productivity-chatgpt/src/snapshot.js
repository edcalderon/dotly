import { mkdir, writeFile, rename } from 'node:fs/promises';
import { join } from 'node:path';
import { config } from './config.js';
import { SpApi } from './api.js';
import { Store } from './store.js';
import { Bridge } from './bridge.js';

process.umask(0o077);
const cfg = config();
const store = new Store(cfg.dataDir);
try {
  const bridge = new Bridge(new SpApi(cfg.tokenFile), store, cfg.projectIds);
  const projects = (await bridge.projects()).filter(p => !p.isArchived);
  const summaries = [];
  for (const project of projects) summaries.push(await bridge.projectBrief(project.id));
  const directory = join(cfg.dataDir, 'summaries');
  await mkdir(directory, { recursive: true, mode: 0o700 });
  const text = JSON.stringify({ generatedAt: new Date().toISOString(), projects: summaries }, null, 2);
  const temporary = join(directory, `latest.${process.pid}.tmp`);
  await writeFile(temporary, text, { mode: 0o600 });
  await rename(temporary, join(directory, 'latest.json'));
  console.log(`Refreshed ${summaries.length} project summaries.`);
} finally { store.close(); }
