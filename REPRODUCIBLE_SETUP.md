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
