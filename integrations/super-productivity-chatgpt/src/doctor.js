import { config } from './config.js';
import { SpApi } from './api.js';

const cfg = config();
const api = new SpApi(cfg.tokenFile);
try {
  const projects = await api.projects();
  const tasks = await api.tasks({ includeDone: true });
  console.log(JSON.stringify({ healthy: true, projects: projects.length, activeTasks: tasks.length, access: cfg.projectIds.length ? cfg.projectIds : 'all projects' }));
} catch (error) { console.error(error.message); process.exitCode = 1; }
