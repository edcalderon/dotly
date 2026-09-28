# Reproduce the current desktop and ChatGPT setup

Validated on Linux Mint, 2026-09-06. These are pinned, tested versions, not a claim that they are the newest upstream releases.

| Component | Version / location |
| --- | --- |
| Node (nvm) | 24.14.1 |
| OmniRoute | 3.8.50, user service `omniroute.service`, localhost:20128 |
| Super Productivity | 18.21.2, native Debian package extracted under `~/.local/opt/superproductivity` |
| Task sync | Super Productivity's own Dropbox connection |
| ChatGPT bridge | [Source and instructions](integrations/super-productivity-chatgpt/README.md), authenticated local REST API on 127.0.0.1:3876 |
| OpenAI tunnel client | 0.0.14, private managed stdio runtime named `super-productivity` |
| Local summaries | User timer `super-productivity-briefs.timer`, every five minutes |

The former Flatpak installation was removed after preserving its profile. The old SP-MCP file plugin is not required for this connection. OmniRoute is independent of the ChatGPT bridge. No model provider configuration is implied by installing OmniRoute.

## New Linux machine

Requires x86_64 Linux, a desktop session, user systemd, Python 3, curl, unzip, dpkg-deb and Node 24+. Install Node 24.14.1 through your existing nvm installation (`nvm install 24.14.1; nvm alias default 24.14.1`). If nvm is absent, follow its [official installation instructions](https://github.com/nvm-sh/nvm#installing-and-updating).

```bash
git clone https://github.com/edcalderon/dotly.git
cd dotly
bash integrations/super-productivity-chatgpt/install-desktop.sh
```

This installs the pinned native app and checksum-verifies the pinned tunnel client. It does not remove another installation, import data, or launch sync. Launch Super Productivity from the application menu, then complete the following **before installing the bridge**:

1. On the original machine, sync and export a complete Super Productivity backup. Check that expected projects and tasks exist. Keep this export privately outside Git.
2. On the new machine, connect Dropbox inside Super Productivity. A linked Dropbox desktop client is neither required nor sufficient. Use the existing remote data; do not choose to overwrite it with an empty/new local database. If the UI cannot clearly restore remote data, stop and import the verified full export first, then resolve sync using that known complete copy.
3. Confirm project names, task counts, completed tasks and archives, then restart the app and confirm Dropbox remains selected. A green connection indicator alone does not prove the remote contents are correct.
4. Enable the local REST API under Settings → Misc. Keep the desktop app open. Its bearer token is generated locally; do not commit or paste it.

```bash
bash integrations/super-productivity-chatgpt/install.sh
python3 ~/.local/lib/super-productivity-chatgpt/connect-tunnel.py
```

The wizard needs an account-owned tunnel ID and runtime key. See the [browser connection steps](integrations/super-productivity-chatgpt/README.md#connect-chatgpt-in-the-browser). No domain is needed. Account sign-in and attaching the connection in ChatGPT remain manual.

## OmniRoute (optional, separate)

With Node 24.14.1 active, `npm install -g omniroute@3.8.50` reproduces the installed package. For service and private environment-file provisioning using the repository helper:

```bash
bash dotfiles_template/restoration_scripts/02-omniroute-superproductivity.sh --omniroute-only
```

This preserves an existing `~/.omniroute/.env`; it must never regenerate an existing storage encryption key. The helper also updates existing Claude gateway settings. Configure providers in http://localhost:20128 separately. An authenticated API returning 401 is not proof that the service is down. Preserve the complete private `~/.omniroute` directory when migrating existing provider state and keys; never publish it.

## Current project organization

Active user projects: **HACKATHONS, TESIS, LSTS, HASHPASS, JACK-K**, plus Inbox. Hackthon tasks were moved into HACKATHONS; MAESTRIA mapped to TESIS and had no active tasks. Nineteen older projects were archived without marking their unfinished tasks complete. The verified post-migration Dropbox snapshot contained 55 task records, 25 total projects and 22 separately archived tasks. These counts are a migration baseline, not an invariant for future use.

Project IDs and task IDs are the bindings; names alone are not durable identifiers. Resolve them with `list_projects` and keep each mapping in its shared brief. Actual IDs, task contents, account details and credentials are deliberately local. The existing private `project-bindings.json` records the initial mapping. This bridge cannot create/archive projects or discover new private ChatGPT Projects automatically.

## Migration, backups and multiple machines

Use one machine as the bridge host. Other Super Productivity clients can use normal Dropbox sync. Do not point competing bridge hosts with independent operation journals at the same task database: retry history and brief revisions are local. A new host needs its own REST token and a configured tunnel runtime; stop the old runtime before switching the ChatGPT connection.

Back up Super Productivity with its full export. Preserve the old native/Flatpak profile until the new app and remote data are verified. In this migration, an earlier client had overwritten Dropbox with starter tasks; an older Dropbox revision recovered the full dataset. Retain useful Dropbox revision history and local exports before resolving conflicts.

Shared briefs are **not** in Super Productivity's Dropbox snapshot. Back up the bridge database consistently with SQLite's backup API (ordinary copying of a live WAL database can omit recent changes):

```bash
python3 - <<'PY'
from pathlib import Path
import sqlite3, datetime
root = Path.home()/'.local/share/super-productivity-chatgpt'
out = Path.home()/'.local/state/dotly-backups'/datetime.datetime.now().strftime('%Y%m%d-%H%M%S')
out.mkdir(parents=True, mode=0o700)
src = sqlite3.connect(f'file:{root}/bridge.sqlite?mode=ro', uri=True)
dst = sqlite3.connect(out/'bridge.sqlite')
with dst: src.backup(dst)
src.close(); dst.close()
(out/'bridge.sqlite').chmod(0o600)
print(out)
PY
```

Copy that backup and optional private `project-bindings.json` securely to the new host. Stop its bridge runtime and summary timer before restoring `bridge.sqlite`; restore into a private directory with mode 0700 and the database with 0600, then restart. Never overwrite a live database. Summary JSON is derived and can be regenerated. Do not put runtime keys, OAuth tokens, app profiles, database files or task exports in this repository.

## Startup and verification

The installer enables the native app at desktop login and the five-minute summary timer. The tunnel uses OpenAI's managed runtime supervision; **reboot/login persistence has not been verified**. After login check readiness and reconnect with the wizard if necessary (an empty key input retains the existing private key):

```bash
systemctl --user status super-productivity-briefs.timer
~/.nvm/versions/node/v24.14.1/bin/node ~/.local/lib/super-productivity-chatgpt/src/doctor.js
~/.local/bin/tunnel-client runtimes status super-productivity --json
```

Require `healthy` and `ready`, then test `list_projects` from the actual ChatGPT browser conversation. **Browser verification passed on 2026-09-06:** the installed `super-productivity` connection invoked the tool and returned Inbox, HASHPASS, HACKATHONS, TESIS, LSTS and JACK-K with their exact IDs. No data was changed during that browser test. Local MCP tests and tunnel readiness also passed. Repeat the browser check in each destination account. The computer, app and tunnel must be running at scheduled review time.

## Weekly ChatGPT review

Status: live reads from the ChatGPT browser are verified. Creation of the weekly schedule and a successful unattended run have not yet been evidenced; do not infer scheduling success from the connection test.

Paste [WEEKLY_REVIEW_PROMPT.md](integrations/super-productivity-chatgpt/WEEKLY_REVIEW_PROMPT.md) into a ChatGPT conversation with the tunnel connection attached. Suggested schedule: Monday 09:00 America/Bogota. The local summary timer is not a ChatGPT scheduled task. Scheduling is complete only when ChatGPT confirms it and the task is visible in its scheduled-task settings.

The integration supports live task reads and authorized task writes in both directions through one Super Productivity database. It does not replicate ChatGPT chat histories, uploaded files, or private Project membership. New ChatGPT projects must be supplied and mapped explicitly.

---

# OmniRoute for Claude Code and OpenCode (AI coding agents)

Separate from the ChatGPT bridge above — this section reproduces the OmniRoute gateway
being used to route the **Claude Code** and **OpenCode** CLIs through pinned upstream
providers, including the hosted **OpenCode Zen** and **OpenCode Go** model offerings.
Same OmniRoute install as above; this is an independent set of consumers on top of it.

Live on this machine as of 2026-09-28, checked against the running config, not a claim
that it is the newest upstream state:

| Component | Version / location | Notes |
| --- | --- | --- |
| OmniRoute Gateway | 3.8.50, `systemctl --user status omniroute` on `localhost:20128` | same service as the ChatGPT bridge section; `/v1` is OpenAI-compatible |
| Claude Code | CLI `2.1.246` | `~/.claude/settings.json` → `ANTHROPIC_BASE_URL=http://localhost:20128`, `CLAUDE_CODE_ENABLE_GATEWAY_MODEL_DISCOVERY=1` |
| Claude Code "profiles" | `~/.claude/profiles/<name>/settings.json` | run with `claude --settings ~/.claude/profiles/<name>/settings.json`; each just overrides the model, still routes through OmniRoute |
| OpenCode CLI | 1.18.32 | `~/.config/opencode/opencode.json` |
| `@omniroute/opencode-plugin` | 0.2.1, built from source (not published to npm) | source: `github.com/diegosouzapw/OmniRoute`, subdir `@omniroute/opencode-plugin`; built copy lives at `~/.config/opencode/plugins/omniroute` |
| `opencode-antigravity-auth` | 1.6.0 | npm plugin, auto-installed by OpenCode from the `plugin[]` array in `opencode.json` |
| OpenCode Zen | hosted model marketplace, OpenCode team | connected as an upstream provider; used directly as `opencode-zen/qwen3.6-plus` and inside OmniRoute combos |
| OpenCode Go | hosted plan, OpenCode team | connected as an upstream provider; feeds the `go-with-claude-fallback` combo |

External MCP servers also present on this machine but **not installed or managed by
dotly** (listed so a fresh machine doesn't chase phantom config): `codebase-memory-mcp`
(private binary at `~/.local/bin/codebase-memory-mcp`), `headroom`
(`~/.headroom/venv`), `pencil` (a desktop app's AppImage mount — its MCP entry simply
fails to connect if the app isn't running, harmlessly), `hostinger` (remote MCP, needs
`HOSTINGER_API_TOKEN`). Skip these on a new machine unless you specifically use them.

## Architecture

```
                     ┌─────────────────────────┐
                     │   OmniRoute Gateway      │  systemd --user, :20128
                     │   (OpenAI-compatible)    │  storage.sqlite (encrypted)
                     │  combos / fallback chains│
                     └───────────┬──────────────┘
                                 │ upstream providers (connected via dashboard)
              ┌────────┬─────────┼─────────┬────────────┬────────────┐
              ▼        ▼         ▼         ▼            ▼            ▼
          Anthropic  OpenAI   Google     Z.AI      OpenCode Zen   OpenCode Go
                                 │
        ┌────────────────────────┴───────────────────────────┐
        │ ANTHROPIC_BASE_URL=http://localhost:20128           │
        ▼                                                      ▼
   Claude Code CLI                                        OpenCode CLI
   (~/.claude/settings.json                          (~/.config/opencode/opencode.json
    + ~/.claude/profiles/*)                            + plugins/omniroute (local, built)
                                                         + opencode-antigravity-auth)
```

OmniRoute owns the upstream provider credentials (encrypted in `storage.sqlite`) and
defines "combo" models — ordered fallback chains, e.g. try Claude first, fall back to a
free/cheap model on rate-limit. OpenCode Zen and OpenCode Go are not part of this repo;
they're hosted offerings from the OpenCode team, added here as two more upstream
providers OmniRoute (and OpenCode directly) can route to.

## New machine setup

```bash
# 1. Base OmniRoute service (see "OmniRoute (optional, separate)" above)
bash dotfiles_template/restoration_scripts/02-omniroute-superproductivity.sh --omniroute-only

# 2. OpenCode CLI + the OmniRoute plugin (built from source) + Claude Code gateway wiring
DOTFILES_PATH="$PWD/dotfiles_template" \
  bash dotfiles_template/restoration_scripts/03-opencode-claude-ai-stack.sh
```

`03-opencode-claude-ai-stack.sh` is idempotent and:

1. Installs the OpenCode CLI if missing (`curl -fsSL https://opencode.ai/install | bash`).
2. Clones `github.com/diegosouzapw/OmniRoute`, runs `npm install && npm run build` on
   `@omniroute/opencode-plugin`, and copies `dist/` + `package.json` into
   `~/.config/opencode/plugins/omniroute` (there's no published npm package to install
   directly, so it's built from source; re-run with `FORCE_REBUILD_OMNIROUTE_PLUGIN=1`
   to rebuild).
3. Merges (never overwrites) `~/.config/opencode/opencode.json`: adds
   `opencode-antigravity-auth@1.6.0` and the local OmniRoute plugin
   (`providerId: "omniroute"`, `baseURL: http://localhost:20128`) to `plugin[]`, and a
   default model. Only adds `mcp.codebase-memory-mcp` / `mcp.super-productivity` entries
   if those binaries already exist on the machine.
4. Merges `~/.claude/settings.json`: `ANTHROPIC_BASE_URL`,
   `CLAUDE_CODE_ENABLE_GATEWAY_MODEL_DISCOVERY=1`, `ENABLE_TOOL_SEARCH=true`. Never
   touches `OMNIROUTE_API_KEY` if one is already set.
5. Writes example profiles to `~/.claude/profiles/<name>/settings.json`
   (`claude-with-free-fallback`, `go-with-claude-fallback`, `opencode-zen-qwen3-6-plus`)
   if they don't already exist.
6. Prints the manual steps below — these can't be scripted because OmniRoute keeps
   provider credentials and combo definitions encrypted in `~/.omniroute/storage.sqlite`,
   not in a plain file.

## Manual steps (once per machine, not scriptable)

1. Open the OmniRoute dashboard at `http://localhost:20128`. First run: log in with
   `INITIAL_PASSWORD` from `~/.omniroute/.env`, then change it.
2. **Settings → Providers**: connect whichever upstream credentials you want available
   to combos — Anthropic, OpenAI, Google, Z.AI, **OpenCode Zen** (API key from an
   OpenCode account), **OpenCode Go** (log in with the account that holds the Go plan).
3. **Settings → Models**: create the "combo" (fallback chain) models referenced by the
   profiles step 5 above wrote, for example:
   - `claude-with-free-fallback` → Claude Sonnet, falling back to a free/cheap model
   - `go-with-claude-fallback` → OpenCode Go first, falling back to Claude
   - `opencode-zen/qwen3.6-plus` needs no combo — it's a native Zen model
   Or just edit `~/.claude/profiles/*/settings.json` to point at whatever combo names
   you actually create.
4. Complete the OpenCode ↔ OmniRoute auth handshake:
   ```bash
   opencode auth login   # choose "omniroute", follow the /connect flow
   ```
5. Verify:
   ```bash
   claude mcp list
   opencode auth list                 # expect: omniroute, opencode-go, opencode-zen (if connected), ...
   claude --settings ~/.claude/profiles/go-with-claude-fallback/settings.json -p "ping"
   ```

## Sensitive files

| File | Holds | Source |
| --- | --- | --- |
| `~/.omniroute/.env` | `JWT_SECRET`, `API_KEY_SECRET`, `STORAGE_ENCRYPTION_KEY` | generated on first install, **never regenerate** — invalidates `storage.sqlite` |
| `~/.omniroute/storage.sqlite` | every provider credential (Anthropic/OpenAI/Google/Z.AI/OpenCode Zen/Go) | encrypted with `STORAGE_ENCRYPTION_KEY`; set only from the dashboard, no plain file to template |
| `~/.claude/settings.json` | `OMNIROUTE_API_KEY` | OmniRoute dashboard → Settings → API Keys, only needed if `REQUIRE_API_KEY=true` |
| `~/.local/share/opencode/auth.json` | `google`, `openai`, `zai`, `anthropic`, `opencode-go`, `opencode-omniroute` | `opencode auth login <provider>`, one at a time |

Back up `~/.omniroute/storage.sqlite` + `.env` the same way as the rest of this repo's
secrets: encrypted, never committed in the clear.

## Troubleshooting

| Symptom | Cause | Fix |
| --- | --- | --- |
| `curl :20128` connection refused | `omniroute.service` isn't running | `systemctl --user restart omniroute; journalctl --user -u omniroute -n 50` |
| `ANTHROPIC_BASE_URL` ignored by Claude Code | `CLAUDE_CODE_ENABLE_GATEWAY_MODEL_DISCOVERY` unset or `0` | set it to `1` in `~/.claude/settings.json` |
| `opencode auth list` doesn't show `omniroute` | `/connect` handshake never completed | `opencode auth login` → pick `omniroute` |
| OpenCode can't find the OmniRoute plugin | `~/.config/opencode/plugins/omniroute/dist/index.js` missing or build failed | re-run `03-opencode-claude-ai-stack.sh FORCE_REBUILD_OMNIROUTE_PLUGIN=1` |
| A Claude Code profile's model (e.g. `go-with-claude-fallback`) 404s / "model not found" | that combo doesn't exist yet in this machine's OmniRoute dashboard | create it under Settings → Models with the exact same name, or edit the profile |
| `pencil` MCP fails to connect | it's a desktop app's AppImage mount, not something dotly installs | open the Pencil desktop app, or drop it from `~/.claude/settings.json` / `opencode.json` if unused here |

## Open items

- [ ] Publish `@omniroute/opencode-plugin` to npm so machines don't need to build it from source
- [ ] Document exporting/importing OmniRoute's "combos" (currently 100% manual, dashboard-only)
- [ ] Encrypted backup of `~/.omniroute/.env` + `storage.sqlite` in the private dotfiles store
- [ ] Decide whether `codebase-memory-mcp` / `headroom` become first-class dotly scripts if they stay part of the standard setup
