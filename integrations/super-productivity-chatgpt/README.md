# ChatGPT ↔ Super Productivity

This bridge gives ChatGPT live access to Super Productivity projects and tasks through eight MCP tools. Super Productivity remains the task database and owns its normal Dropbox sync. Goals and decisions can be kept in a separate shared project brief. The bridge never rewrites Dropbox snapshots or private ChatGPT conversations.

## Architecture

ChatGPT browser → OpenAI Secure MCP Tunnel → local stdio MCP bridge → authenticated Super Productivity REST API at `127.0.0.1:3876`.

There is no public listener or domain to maintain. Tunnel access is controlled by the OpenAI organization/workspace association and the tunnel runtime key. The Super Productivity token stays on this computer. This is a personal developer-mode connection, not a publicly distributed plugin.

The desktop app, computer and tunnel runtime must be running. A five-minute user timer refreshes local project summaries; it does not initiate ChatGPT conversations or update uploaded Project files. MCP reads always fetch live task data.

## Install

For a new machine, migration, private backups and the actual validated stack, start with [REPRODUCIBLE_SETUP.md](../../REPRODUCIBLE_SETUP.md). Use [the weekly prompt](WEEKLY_REVIEW_PROMPT.md) in ChatGPT after verifying the connection. Scheduling is a separate browser action; no ChatGPT schedule is created by these installers.

Requirements: Linux with user systemd, Node 24+, Python 3, Super Productivity desktop 18.21.2, and its local REST API enabled in Settings → Misc. The application generates a device-local `local-rest-api-token` automatically. No OpenAI model API is called by this bridge.

```bash
bash integrations/super-productivity-chatgpt/install.sh
```

The installer pins dependencies with `package-lock.json`, runs the automated tests, installs a launcher under `~/.local/bin`, verifies the local API, and enables `super-productivity-briefs.timer`. If the native app has a local desktop launcher and no existing autostart entry, it also enables Super Productivity at desktop login.

For a different Node installation, set `SP_BRIDGE_NODE` to an absolute Node 24+ executable path.

## Connect ChatGPT in the browser

1. Install the official `tunnel-client` Linux binary from [OpenAI releases](https://github.com/openai/tunnel-client/releases/latest) into `~/.local/bin/tunnel-client`, verifying the release's SHA256SUMS. This machine has v0.0.14 installed and checksum-verified.
2. Create a tunnel in [Platform tunnel settings](https://platform.openai.com/settings/organization/tunnels). Associate it with your personal Platform organization **and the ChatGPT workspace you use**.
3. Create a runtime API key with Tunnels Read + Use. Tunnel creation requires Read + Manage. Do not use an admin key as the runtime key. Do not paste keys into ChatGPT or commit them.
4. Run the local setup wizard:

   ```bash
   python3 ~/.local/lib/super-productivity-chatgpt/connect-tunnel.py
   ```

   Enter the tunnel ID and key at the prompts. The key is saved in a private local file. The wizard uses `tunnel-client runtimes connect` for managed supervision, then prints runtime status. A running process alone is not sufficient: check `healthy` and `ready`.
5. In ChatGPT, enable Developer mode (currently Settings → Security and login; availability depends on your account/workspace). Open plugin/connection settings, add a connection, choose **Tunnel**, and select the tunnel ID. Review the eight discovered tools.
6. Attach the connection to a chat inside your ChatGPT Project. Add the contents of [CHATGPT_PROJECT_INSTRUCTIONS.md](CHATGPT_PROJECT_INSTRUCTIONS.md) to its instructions.
7. Ask: “List my Super Productivity projects, then show the current brief for HASHPASS.” Next, request one clearly identified task update and confirm its result in the desktop app.

The local bridge can be fully tested before step 2. A tunnel ID, runtime key, and the final ChatGPT connection are account-owned steps; local installation alone does not connect a ChatGPT account.

## Tools

| Tool | Purpose |
| --- | --- |
| `list_projects` | Resolve exact project IDs |
| `list_tags` | Resolve existing tag IDs |
| `search_tasks` | Paginated live task search, including optional archives |
| `get_task` | Read one task and obtain its revision |
| `get_project_brief` | Shared context plus live task counts and tasks |
| `save_project_brief` | Save project goals, decisions and references with revision checking |
| `create_task` | Create one task with a durable retry ID |
| `update_task` | Patch one task with revision and retry IDs |

All projects are authorized for this installation. `SP_PROJECT_IDS` may optionally restrict a future deployment to comma-separated IDs. `SP_TOKEN_FILE` and `SP_BRIDGE_DATA_DIR` override the default token/data locations.

## Reliability and recovery

- Updates check the task revision immediately before the write. Bridge writes are serialized across processes. The upstream REST API has no conditional-write primitive, so a desktop edit made between that check and PATCH can still race; this is not a transactional two-system sync guarantee.
- Every task write has a persisted request ID. Replaying the same request returns the prior result. A different payload with that ID is rejected.
- Timeouts or interrupted requests remain uncertain/pending and are not blindly retried. Inspect the target task and operation log before taking further action. Retrying with a fresh ID can create duplicates.
- Before-images for updates, operation outcomes, and brief revisions are saved in the local SQLite database. No delete, restore, arbitrary HTTP request, or shell tool is exposed to ChatGPT.
- Only individual task changes enter Super Productivity's normal operation/sync flow. The bridge does not verify Dropbox upload completion for each tool call.
- Shared briefs and local summaries are outside Super Productivity and are **not** Dropbox-synced automatically. Back up the bridge data directory separately. Existing ChatGPT Project material must be supplied explicitly for the initial brief.

Private state: `~/.local/share/super-productivity-chatgpt/bridge.sqlite` (including WAL files while running). Summaries: `~/.local/share/super-productivity-chatgpt/summaries/latest.json`. They contain personal project information and are mode 0600 in a mode 0700 directory.

## Verification and operation

```bash
cd integrations/super-productivity-chatgpt
npm test
npm run doctor
node src/verify-live.js
# Optional: creates/completes/removes exactly one labelled temporary test task:
node src/verify-live.js --write

systemctl --user status super-productivity-briefs.timer
journalctl --user -u super-productivity-briefs.service -n 20
tunnel-client runtimes status super-productivity --json
```

If the app is closed, API calls fail explicitly, and the summary timer preserves the last snapshot with its old `generatedAt` timestamp. It retries at its next interval. It never presents cached task state as a successful live read.

## Sources

- [Super Productivity 18.21.2 API](https://github.com/super-productivity/super-productivity/blob/v18.21.2/docs/wiki/3.01-API.md)
- [OpenAI Secure MCP Tunnel](https://developers.openai.com/api/docs/guides/secure-mcp-tunnels)
- [Connect an MCP server to ChatGPT](https://developers.openai.com/plugins/deploy/connect-chatgpt)

OAuth/public HTTPS deployment is not required for the private stdio tunnel route. If you later want a public plugin, it requires a separate authenticated HTTPS deployment and review.
