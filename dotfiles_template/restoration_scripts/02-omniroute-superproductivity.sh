#!/usr/bin/env bash
set -euo pipefail

# 02-omniroute-superproductivity.sh — Reproducible OmniRoute + Super Productivity + MCP
# Idempotent, safe to re-run. Part of dotly: Documents/dotly
# Usage: DOTFILES_PATH="$PWD/dotfiles_template" bash dotfiles_template/restoration_scripts/02-omniroute-superproductivity.sh

if [ -n "${DOTFILES_PATH:-}" ] && [ -f "$DOTFILES_PATH/os/linux/.dotly" ]; then
  # shellcheck source=/dev/null
  . "$DOTFILES_PATH/os/linux/.dotly"
fi

OMNI_PORT="${OMNI_PORT:-20128}"
MCP_DIR="${HOME}/.local/share/super-productivity-mcp"
OMNI_DATA_DIR="${HOME}/.omniroute"

ensure_node() {
  local nvm_dir="${NVM_DIR:-$HOME/.nvm}"
  if [ ! -d "$nvm_dir" ]; then
    echo "[node] Installing NVM..."
    curl -fsSL https://raw.githubusercontent.com/nvm-sh/nvm/v0.40.0/install.sh | bash
  fi
  # shellcheck source=/dev/null
  [ -s "$nvm_dir/nvm.sh" ] && . "$nvm_dir/nvm.sh"
  # Prefer 24.14.1 (patched), fallback to 22.22.2+ for OmniRoute 3.8.49
  local want="24.14.1"
  if ! nvm ls "$want" >/dev/null 2>&1; then
    echo "[node] Installing Node $want..."
    nvm install "$want" || nvm install 22.22.2
  fi
  nvm alias default "$want" 2>/dev/null || true
  nvm use "$want" >/dev/null 2>&1 || nvm use 22 >/dev/null 2>&1 || true
  echo "[node] $(node --version) via $(which node)"
}

install_omniroute() {
  ensure_node
  if ! command -v omniroute >/dev/null 2>&1; then
    echo "[omniroute] Installing npm -g omniroute..."
    npm install -g omniroute@latest || npm install -g omniroute@3.8.49
  else
    echo "[omniroute] Already installed: $(omniroute --version 2>&1 | head -n1) — ensuring latest"
    npm install -g omniroute@latest 2>/dev/null || true
  fi

  mkdir -p "$OMNI_DATA_DIR" "$OMNI_DATA_DIR/logs" "$HOME/.config/systemd/user"

  # .env idempotente — no regenerar si existe (rompe STORAGE_ENCRYPTION_KEY)
  if [ ! -f "$OMNI_DATA_DIR/.env" ]; then
    echo "[omniroute] Creating $OMNI_DATA_DIR/.env..."
    cat > "$OMNI_DATA_DIR/.env" <<EOF
# OmniRoute local — generated $(date -Is)
PORT=$OMNI_PORT
DATA_DIR=$OMNI_DATA_DIR
REQUIRE_API_KEY=false
OMNIROUTE_SERVER_HOST=127.0.0.1
JWT_SECRET=$(openssl rand -base64 32 | tr -d '\n')
API_KEY_SECRET=$(openssl rand -hex 16)
STORAGE_ENCRYPTION_KEY=$(openssl rand -hex 32)
STORAGE_ENCRYPTION_KEY_VERSION=v1
EOF
    chmod 600 "$OMNI_DATA_DIR/.env"
  else
    echo "[omniroute] $OMNI_DATA_DIR/.env exists, keeping (skip regenerate)"
    # Asegurar PORT/DATA_DIR si faltan
    grep -q "^PORT=" "$OMNI_DATA_DIR/.env" || echo "PORT=$OMNI_PORT" >> "$OMNI_DATA_DIR/.env"
    grep -q "^DATA_DIR=" "$OMNI_DATA_DIR/.env" || echo "DATA_DIR=$OMNI_DATA_DIR" >> "$OMNI_DATA_DIR/.env"
  fi

  local nvm_node
  nvm_node="$(command -v node)"
  local omni_bin
  omni_bin="$(command -v omniroute || echo "$HOME/.nvm/versions/node/$(node --version | tr -d 'v')/lib/node_modules/omniroute/bin/omniroute.mjs")"
  # Resolver omniroute.mjs real si es shim
  if [ -f "$HOME/.nvm/versions/node/$(node --version | tr -d 'v')/lib/node_modules/omniroute/bin/omniroute.mjs" ]; then
    omni_bin="$HOME/.nvm/versions/node/$(node --version | tr -d 'v')/lib/node_modules/omniroute/bin/omniroute.mjs"
    nvm_node="$HOME/.nvm/versions/node/$(node --version | tr -d 'v')/bin/node"
  fi

  cat > "$HOME/.config/systemd/user/omniroute.service" <<EOF
[Unit]
Description=OmniRoute AI gateway (v3.8.51)
Documentation=https://omniroute.online
After=network-online.target
[Service]
Type=simple
Environment=NODE_ENV=production
Environment=DATA_DIR=$OMNI_DATA_DIR
Environment=PATH=$HOME/.nvm/versions/node/$(node --version | tr -d 'v')/bin:/usr/local/bin:/usr/bin:/bin
EnvironmentFile=$OMNI_DATA_DIR/.env
WorkingDirectory=$OMNI_DATA_DIR
ExecStart=$nvm_node $omni_bin serve --no-open --no-tray
Restart=on-failure
RestartSec=5
KillSignal=SIGTERM
TimeoutStopSec=30
StandardOutput=append:$OMNI_DATA_DIR/logs/omniroute.service.log
StandardError=append:$OMNI_DATA_DIR/logs/omniroute.service.log
[Install]
WantedBy=default.target
EOF

  systemctl --user daemon-reload
  systemctl --user enable omniroute 2>/dev/null || true
  systemctl --user restart omniroute || systemctl --user start omniroute

  echo "[omniroute] Waiting for http://localhost:$OMNI_PORT/v1/models..."
  for i in $(seq 1 20); do
    if curl -sf "http://localhost:$OMNI_PORT/v1/models" >/dev/null 2>&1; then
      echo "[omniroute] UP on $OMNI_PORT"
      break
    fi
    sleep 1
    if [ "$i" -eq 20 ]; then
      echo "[omniroute] WARNING: not responding after 20s, check journalctl --user -u omniroute -n 50" >&2
    fi
  done

  # Configurar Claude Code y Opencode para usar gateway si no están
  if [ -f "$HOME/.claude/settings.json" ]; then
    python3 <<'PY'
import json, pathlib
p=pathlib.Path.home()/".claude/settings.json"
d=json.loads(p.read_text())
d.setdefault("env",{})["ANTHROPIC_BASE_URL"]="http://localhost:20128"
d["env"]["CLAUDE_CODE_ENABLE_GATEWAY_MODEL_DISCOVERY"]="1"
# Preservar OMNIROUTE_API_KEY si existe
p.write_text(json.dumps(d, indent=2))
print("[omniroute] Patched ~/.claude/settings.json ANTHROPIC_BASE_URL")
PY
  fi
}

install_superproductivity_native() {
  if command -v superproductivity >/dev/null 2>&1 && dpkg -l | grep -q super-productivity 2>/dev/null; then
    echo "[superproductivity] Native .deb already installed"
    return 0
  fi
  # Prefer .deb nativo para MCP estable; fallback a Flatpak
  local pm
  pm=$(detect_package_manager 2>/dev/null || echo apt)
  local deb_url
  deb_url=$(curl -sf https://api.github.com/repos/johannesjo/super-productivity/releases/latest 2>/dev/null | python3 -c "import json,sys; d=json.load(sys.stdin); urls=[a['browser_download_url'] for a in d.get('assets',[]) if a['name'].endswith('_amd64.deb')]; print(urls[0] if urls else '')" 2>/dev/null || echo "")
  if [ -n "$deb_url" ] && [ "$pm" = "apt" ]; then
    echo "[superproductivity] Installing native .deb from $deb_url"
    wget -O /tmp/super-productivity.deb "$deb_url"
    sudo dpkg -i /tmp/super-productivity.deb || sudo apt -f install -y
    echo "[superproductivity] Native install done"
  elif command -v flatpak >/dev/null 2>&1; then
    echo "[superproductivity] .deb not available, installing Flatpak fallback"
    flatpak remote-add --if-not-exists flathub https://flathub.org/repo/flathub.flatpakrepo 2>/dev/null || true
    flatpak install -y flathub com.superproductivity.SuperProductivity || true
  else
    echo "[superproductivity] Manual install required" >&2
  fi
}

install_sp_mcp() {
  echo "[sp-mcp] Installing..."
  pip3 install "mcp==1.12.4" --break-system-packages 2>/dev/null || pip3 install "mcp==1.12.4"
  rm -rf /tmp/SP-MCP
  git clone https://github.com/organicmoron/SP-MCP /tmp/SP-MCP
  mkdir -p "$MCP_DIR/plugin_commands" "$MCP_DIR/plugin_responses"
  cp /tmp/SP-MCP/mcp_server.py /tmp/SP-MCP/merge_config.py "$MCP_DIR/"
  chmod +x "$MCP_DIR/mcp_server.py"

  # Claude Code
  python3 <<'PY'
import json, pathlib
p=pathlib.Path.home()/".claude/.mcp.json"
d=json.loads(p.read_text()) if p.exists() else {"mcpServers":{}}
d.setdefault("mcpServers",{})["super-productivity"]={"command":"python3","args":[str(pathlib.Path.home()/".local/share/super-productivity-mcp/mcp_server.py")]}
p.parent.mkdir(parents=True, exist_ok=True)
p.write_text(json.dumps(d, indent=2))
print("[sp-mcp] Patched ~/.claude/.mcp.json")
PY

  # Opencode
  python3 <<'PY'
import json, pathlib
p=pathlib.Path.home()/".config/opencode/opencode.json"
if p.exists():
    d=json.loads(p.read_text())
    d.setdefault("mcp",{})["super-productivity"]={"enabled":True,"type":"local","command":["python3",str(pathlib.Path.home()/".local/share/super-productivity-mcp/mcp_server.py")]}
    p.write_text(json.dumps(d, indent=2))
    print("[sp-mcp] Patched ~/.config/opencode/opencode.json")
else:
    print("[sp-mcp] Opencode config not found, skip")
PY

  # Flatpak workaround si aplica
  if flatpak list 2>/dev/null | grep -q com.superproductivity.SuperProductivity; then
    echo "[sp-mcp] Flatpak detected — applying symlink workaround"
    mkdir -p "$HOME/.var/app/com.superproductivity.SuperProductivity/data"
    rm -f "$HOME/.var/app/com.superproductivity.SuperProductivity/data/super-productivity-mcp"
    ln -sfn "$MCP_DIR" "$HOME/.var/app/com.superproductivity.SuperProductivity/data/super-productivity-mcp"
    flatpak override --user --filesystem="$MCP_DIR:rw" com.superproductivity.SuperProductivity 2>/dev/null || true
    echo "[sp-mcp] Symlink + override done"
  fi

  echo "[sp-mcp] Done. Now in Super Productivity: Settings → Plugins → Upload $MCP_DIR/plugin.zip (or /tmp/SP-MCP/plugin.zip)"
  cp /tmp/SP-MCP/plugin.zip "$MCP_DIR/plugin.zip" 2>/dev/null || true
  cp /tmp/SP-MCP/plugin.zip "$HOME/Desktop/SP-MCP-plugin.zip" 2>/dev/null || true
}

main() {
  echo "[02] OmniRoute + Super Productivity + MCP — start"
  install_omniroute
  install_superproductivity_native
  install_sp_mcp
  echo "[02] Done. Verify:"
  echo "  systemctl --user status omniroute --no-pager"
  echo "  curl http://localhost:$OMNI_PORT/v1/models | jq .data[0].id"
  echo "  claude mcp list"
  echo "  cat ~/.local/share/super-productivity-mcp/mcp_server.log"
}

main "$@"
