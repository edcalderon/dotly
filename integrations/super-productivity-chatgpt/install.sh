#!/usr/bin/env bash
set -euo pipefail
bridge_source="$(cd -- "$(dirname -- "${BASH_SOURCE[0]}")" && pwd)"
bridge_node="${SP_BRIDGE_NODE:-$HOME/.nvm/versions/node/v24.14.1/bin/node}"
if [ ! -x "$bridge_node" ]; then bridge_node="$(command -v node)"; fi
if [ "$("$bridge_node" -p 'Number(process.versions.node.split(".")[0])')" -lt 24 ]; then
  echo 'Node 24 or newer is required.' >&2; exit 1
fi
export PATH="$(dirname -- "$bridge_node"):$PATH"
cd "$bridge_source"
npm ci --ignore-scripts
npm test
bridge_install="$HOME/.local/lib/super-productivity-chatgpt"
mkdir -p "$bridge_install" "$HOME/.local/bin" "$HOME/.config/systemd/user"
cp package.json package-lock.json "$bridge_install/"
cp -R src "$bridge_install/"
cp connect-tunnel.py CHATGPT_PROJECT_INSTRUCTIONS.md WEEKLY_REVIEW_PROMPT.md "$bridge_install/"
(cd "$bridge_install" && npm ci --omit=dev --ignore-scripts)
# Python quotes paths for the generated launcher and systemd units.
"$bridge_node" --version
python3 - "$bridge_node" "$bridge_install" <<'PY'
from pathlib import Path
import sys,shlex
node,root=sys.argv[1:];h=Path.home();launcher=h/'.local/bin/super-productivity-chatgpt'
launcher.write_text('#!/bin/sh\nexec '+shlex.quote(node)+' '+shlex.quote(root+'/src/server.js')+'\n');launcher.chmod(0o700)
units=h/'.config/systemd/user'
def systemd_quote(s):return '"'+s.replace('\\','\\\\').replace('"','\\"').replace('%','%%')+'"'
(units/'super-productivity-briefs.service').write_text('[Unit]\nDescription=Refresh Super Productivity project summaries\n[Service]\nType=oneshot\nUMask=0077\nExecStart='+systemd_quote(node)+' '+systemd_quote(root+'/src/snapshot.js')+'\nNoNewPrivileges=true\nPrivateTmp=true\n')
(units/'super-productivity-briefs.timer').write_text('[Unit]\nDescription=Refresh project summaries every five minutes\n[Timer]\nOnStartupSec=2min\nOnUnitActiveSec=5min\n[Install]\nWantedBy=timers.target\n')
print('Installed MCP launcher:',launcher)
desktop=h/'.local/share/applications/superproductivity.desktop'
autostart=h/'.config/autostart/superproductivity.desktop'
if desktop.exists() and not autostart.exists():
    autostart.parent.mkdir(parents=True,exist_ok=True)
    autostart.write_text(desktop.read_text()+'\nX-GNOME-Autostart-enabled=true\n')
    print('Enabled Super Productivity at desktop login.')
PY
systemctl --user daemon-reload
systemctl --user enable --now super-productivity-briefs.timer
"$bridge_node" "$bridge_install/src/doctor.js"
"$bridge_node" "$bridge_install/src/snapshot.js"
echo "Next: python3 $bridge_install/connect-tunnel.py"
