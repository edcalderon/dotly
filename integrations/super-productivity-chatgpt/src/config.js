import { homedir } from 'node:os';
import { join } from 'node:path';

export function config(env = process.env) {
  return {
    tokenFile: env.SP_TOKEN_FILE || join(homedir(), '.config/superProductivity/local-rest-api-token'),
    dataDir: env.SP_BRIDGE_DATA_DIR || join(homedir(), '.local/share/super-productivity-chatgpt'),
    // An empty list means all projects, explicitly authorized for this installation.
    projectIds: (env.SP_PROJECT_IDS || '').split(',').map(s => s.trim()).filter(Boolean),
  };
}
