#!/usr/bin/env bash
# Pinned user-local desktop prerequisites. Existing installations are preserved.
set -euo pipefail
[ "$(uname -m)" = x86_64 ] || { echo 'This installer requires x86_64 Linux.' >&2; exit 1; }
for dependency in curl python3 unzip dpkg-deb sha256sum; do command -v "$dependency" >/dev/null; done
install_work="$(mktemp -d)"
trap 'rm -rf -- "$install_work"' EXIT
mkdir -p "$HOME/.local/opt" "$HOME/.local/bin" "$HOME/.local/share/applications"
if [ ! -e "$HOME/.local/opt/superproductivity" ]; then
  curl -fL --retry 3 -o "$install_work/sp.deb" https://github.com/super-productivity/super-productivity/releases/download/v18.21.2/superProductivity-amd64.deb
  dpkg-deb -x "$install_work/sp.deb" "$install_work/sp"
  test -x "$install_work/sp/opt/Super Productivity/superproductivity"
  mv "$install_work/sp" "$HOME/.local/opt/superproductivity"
else
  echo 'Preserving existing local Super Productivity installation.'
fi
if [ ! -e "$HOME/.local/opt/tunnel-client-0.0.14" ]; then
  tunnel_release='https://github.com/openai/tunnel-client/releases/download/v0.0.14'
  tunnel_archive='tunnel-client-v0.0.14-linux-amd64.zip'
  curl -fL --retry 3 -o "$install_work/$tunnel_archive" "$tunnel_release/$tunnel_archive"
  curl -fsSL -o "$install_work/SHA256SUMS.txt" "$tunnel_release/SHA256SUMS.txt"
  python3 - "$install_work" "$tunnel_archive" <<'PY'
import hashlib, pathlib, sys
root=pathlib.Path(sys.argv[1]); name=sys.argv[2]
entries=[line.split() for line in (root/'SHA256SUMS.txt').read_text().splitlines()]
expected=[parts[0] for parts in entries if len(parts)==2 and parts[1].lstrip('*')==name]
if len(expected)!=1 or hashlib.sha256((root/name).read_bytes()).hexdigest()!=expected[0]:
    raise SystemExit('Tunnel checksum verification failed')
PY
  unzip -q "$install_work/$tunnel_archive" -d "$install_work/tunnel"
  test -f "$install_work/tunnel/tunnel-client"
  chmod 755 "$install_work/tunnel/tunnel-client"
  mv "$install_work/tunnel" "$HOME/.local/opt/tunnel-client-0.0.14"
fi
ln -sfn "$HOME/.local/opt/tunnel-client-0.0.14/tunnel-client" "$HOME/.local/bin/tunnel-client"
python3 - <<'PY'
from pathlib import Path
import shlex, shutil
h=Path.home(); root=h/'.local/opt/superproductivity'
launcher=h/'.local/bin/superproductivity'
if launcher.is_symlink(): launcher.unlink()
launcher.write_text('#!/bin/sh\nunset ELECTRON_RUN_AS_NODE\nexec '+shlex.quote(str(root/'opt/Super Productivity/superproductivity'))+' "$@"\n')
launcher.chmod(0o755)
source=root/'usr/share/applications/superproductivity.desktop'
text=source.read_text()
def desktop_quote(s): return '"'+s.replace('\\','\\\\').replace('"','\\"').replace('`','\\`').replace('$','\\$')+'"'
text='\n'.join('Exec='+desktop_quote(str(launcher))+' %U' if line.startswith('Exec=') else line for line in text.splitlines())+'\n'
(h/'.local/share/applications/superproductivity.desktop').write_text(text)
icons=root/'usr/share/icons'
if icons.exists(): shutil.copytree(icons,h/'.local/share/icons',dirs_exist_ok=True)
PY
echo 'Desktop prerequisites installed. Launch the app, restore/verify Dropbox data, and enable its local REST API before running install.sh.'
