# Stack Reproducible: OmniRoute + Super Productivity + MCP

> Documentación para reproducir el stack local en cualquier PC Linux Mint / Ubuntu en < 15 min via dotly.

## Resumen del Stack Actual (2026-09-06)

| Componente | Versión | Instalación | Puerto / Path | Estado |
|---|---|---|---|---|
| **OmniRoute Gateway** | 3.8.49 (npm) | `npm -g omniroute@3.8.51` → systemd user | `http://localhost:20128` (`/v1` OpenAI-compat) | ✅ `systemctl --user status omniroute` |
| **Super Productivity** | 18.21.2 | Flatpak `com.superproductivity.SuperProductivity` (Flathub) | `~/.var/app/.../data` | ⚠️ File-bridge requiere symlink (ver abajo) — **recomendado migrar a .deb nativo** |
| **SP-MCP Bridge** | organicmoron/SP-MCP | `~/.local/share/super-productivity-mcp/mcp_server.py` + plugin ZIP | `plugin_commands/` ↔ `plugin_responses/` | ✅ 10 tools, via `mcp==1.12.4` |
| **Claude Code** | - | `~/.claude/.mcp.json` + `~/.claude/settings.json` | `ANTHROPIC_BASE_URL=http://localhost:20128` | ✅ Gateway discovery ON |
| **Opencode** | - | `~/.config/opencode/opencode.json` | `provider.omniroute.baseURL=http://localhost:20128/v1` | ✅ `auto/best-*` |

### Prueba end-to-end verificada
```bash
curl http://localhost:20128/v1/chat/completions -d '{"model":"auto/best-fast",
  "messages":[{"role":"user","content":"Create task Buy milk"}],
  "tools":[{"type":"function","function":{"name":"create_task","parameters":{"type":"object","properties":{"title":{"type":"string"}}}}}]}'
# → glm-5.2 genera tool_calls: create_task ✓
timeout 3 python3 -c "from mcp import ClientSession..." # list_tools → 10 tools ✓
```

---

## 1. Decisión: ¿Cuál integración es más estable?

### Opciones evaluadas

| Opción | Mecanismo | Pros | Contras | Estabilidad |
|---|---|---|---|---|
| **SP-MCP (organicmoron) + .deb nativo** | File-bridge `~/.local/share/super-productivity-mcp/` + plugin Node | 10 tools completas, mantenido, diseñado para native (`~/.local/share`), sin sandbox | Requiere `.deb` (no flatpak) para evitar XDG mismatch | **★★★★★ Recomendado** |
| **SP-MCP + Flatpak (actual)** | Mismo file-bridge + symlink `XDG_DATA_HOME` → host | Funciona con workaround `ln -sfn ~/.local/share/... ~/.var/app/.../data/...` + `flatpak override` | Flatpak sandbox rompe `XDG_DATA_HOME`, requiere symlink + restart, polling 2s frágil, Timeout 30s visto | ★★★☆☆ Funciona pero frágil |
| **Super Productivity Sync Server / WebDAV** | HTTP sync | Nativo, sin plugin | Solo sync, no expone tasks/projects como tools MCP | ★★☆☆☆ No es MCP |
| **MCP HTTP alternativo (no existe estable)** | WebSocket/HTTP bridge | Evitaría file polling | No hay implementación mantenida, habría que forkar SP-MCP | ★☆☆☆☆ No recomendado |

**Recomendación final:** **Migrar Super Productivity de Flatpak a .deb nativo + SP-MCP**. Es la misma base de código pero sin el bug de `XDG_DATA_HOME=/home/ed/.var/app/.../data` que obliga al symlink. La instalación .deb pone `~/.local/share/super-productivity-mcp` directamente accesible para plugin y MCP server sin overrides.

> Si debes quedarte en Flatpak, el symlink documentado abajo es obligatorio y debes reinstalar el plugin tras cada update.

---

## 2. Instalación Reproducible (dotly)

### 2.1 One-liner dotly (PC nuevo, Linux Mint)

```bash
sudo apt update && sudo apt install -y git
git clone https://github.com/edcalderon/dotly "$HOME/.dotfiles"
cd "$HOME/.dotfiles"
git submodule update --init --recursive modules/dotly
DOTFILES_PATH="$HOME/.dotfiles" DOTLY_PATH="$DOTFILES_PATH/modules/dotly" "$DOTLY_PATH/bin/dot" self install
# Restaura entorno base + stack IA
DOTFILES_PATH="$PWD/dotfiles_template" bash dotfiles_template/restoration_scripts/01-default_linux_restoration.sh
DOTFILES_PATH="$PWD/dotfiles_template" bash dotfiles_template/restoration_scripts/02-omniroute-superproductivity.sh
# Relogin y verifica
systemctl --user status omniroute --no-pager
flatpak list | grep super # o dpkg -l | grep super-productivity
claude mcp list
```

### 2.2 Script `02-omniroute-superproductivity.sh` (nuevo)

Ver `dotfiles_template/restoration_scripts/02-omniroute-superproductivity.sh` — idempotente, re-ejecutable. Hace:

1. **OmniRoute**
   - Instala `nvm` Node `24.14.1` (o `22.22.2+`) si no está
   - `npm install -g omniroute@3.8.51`
   - Crea `~/.omniroute/.env` con `PORT=20128`, `REQUIRE_API_KEY=false`, `DATA_DIR`, y genera `JWT_SECRET` si no existe
   - Instala `~/.config/systemd/user/omniroute.service` y `systemctl --user enable --now omniroute`
   - Espera `http://localhost:20128/health` y hace `omniroute login` si es primera vez (abre Dashboard)

2. **Super Productivity (estable)**
   - Desinstala Flatpak si existe (opcional, con prompt)
   - Descarga último `.deb` de `johannesjo/super-productivity` releases y `sudo dpkg -i`
   - Fallback a Flatpak si .deb falla

3. **SP-MCP**
   - `pip install "mcp==1.12.4"` (pin, 2.x rompe `list_tools`)
   - `git clone https://github.com/organicmoron/SP-MCP /tmp/SP-MCP` → `~/.local/share/super-productivity-mcp/`
   - Configura `~/.claude/.mcp.json` y `~/.config/opencode/opencode.json` (merge, no overwrite)
   - Si Flatpak: crea symlink + `flatpak override --filesystem`
   - Instrucciones para subir `plugin.zip` en Super Productivity → Settings → Plugins → Upload

### 2.3 Variables sensibles

| Archivo | Clave | Origen |
|---|---|---|
| `~/.omniroute/.env` | `JWT_SECRET`, `API_KEY_SECRET`, `STORAGE_ENCRYPTION_KEY` | Generado en primera instalación, **no regenerar** (rompe credenciales en `storage.sqlite`) |
| `~/.config/opencode/opencode.json` | `OMNIROUTE_API_KEY` env | Copiado de `~/.omniroute/.env` o Dashboard |
| `~/.claude/settings.json` | `ANTHROPIC_BASE_URL`, `OMNIROUTE_API_KEY` | Apunta a `http://localhost:20128` |

Backup: `~/.omniroute/storage.sqlite` + `.env` → Dropbox/dotfiles (encriptado).

---

## 3. Configuración Manual (si no usas dotly)

### OmniRoute
```bash
nvm install 24.14.1 && nvm use 24.14.1
npm install -g omniroute@3.8.51
mkdir -p ~/.omniroute
cat > ~/.omniroute/.env <<'EOF'
PORT=20128
DATA_DIR=/home/$USER/.omniroute
REQUIRE_API_KEY=false
OMNIROUTE_SERVER_HOST=127.0.0.1
# Genera con: openssl rand -base64 32
JWT_SECRET=$(openssl rand -base64 32)
API_KEY_SECRET=$(openssl rand -hex 16)
STORAGE_ENCRYPTION_KEY=$(openssl rand -hex 32)
EOF
# Systemd
mkdir -p ~/.config/systemd/user
cat > ~/.config/systemd/user/omniroute.service <<'EOF'
[Unit]
Description=OmniRoute AI gateway
After=network-online.target
[Service]
Type=simple
Environment=NODE_ENV=production
Environment=DATA_DIR=%h/.omniroute
Environment=PATH=%h/.nvm/versions/node/v22.22.0/bin:/usr/local/bin:/usr/bin:/bin
EnvironmentFile=%h/.omniroute/.env
ExecStart=%h/.nvm/versions/node/v22.22.0/bin/node %h/.nvm/versions/node/v22.22.0/lib/node_modules/omniroute/bin/omniroute.mjs serve --no-open --no-tray
Restart=on-failure
[Install]
WantedBy=default.target
EOF
systemctl --user daemon-reload && systemctl --user enable --now omniroute
curl http://localhost:20128/v1/models | jq .
```

### Super Productivity .deb (recomendado)
```bash
flatpak uninstall -y com.superproductivity.SuperProductivity 2>/dev/null || true
latest=$(curl -s https://api.github.com/repos/johannesjo/super-productivity/releases/latest | jq -r '.assets[] | select(.name | endswith("_amd64.deb")) | .browser_download_url' | head -n1)
wget -O /tmp/super-productivity.deb "$latest" && sudo dpkg -i /tmp/super-productivity.deb || sudo apt -f install -y
```

### SP-MCP
```bash
pip3 install "mcp==1.12.4" --break-system-packages
git clone https://github.com/organicmoron/SP-MCP /tmp/SP-MCP
MCP_DIR="$HOME/.local/share/super-productivity-mcp"
mkdir -p "$MCP_DIR/plugin_commands" "$MCP_DIR/plugin_responses"
cp /tmp/SP-MCP/mcp_server.py /tmp/SP-MCP/merge_config.py "$MCP_DIR/"
# Claude Code
python3 <<'PY'
import json, pathlib
p=pathlib.Path.home()/".claude/.mcp.json"
d=json.loads(p.read_text()) if p.exists() else {"mcpServers":{}}
d.setdefault("mcpServers",{})["super-productivity"]={"command":"python3","args":[str(pathlib.Path.home()/".local/share/super-productivity-mcp/mcp_server.py")]}
p.write_text(json.dumps(d, indent=2))
PY
# Opencode
python3 <<'PY'
import json, pathlib
p=pathlib.Path.home()/".config/opencode/opencode.json"
d=json.loads(p.read_text())
d.setdefault("mcp",{})["super-productivity"]={"enabled":True,"type":"local","command":["python3",str(pathlib.Path.home()/".local/share/super-productivity-mcp/mcp_server.py")]}
p.write_text(json.dumps(d, indent=2))
PY
# Si aún en Flatpak, aplica workaround:
# ln -sfn ~/.local/share/super-productivity-mcp ~/.var/app/com.superproductivity.SuperProductivity/data/super-productivity-mcp
# flatpak override --user --filesystem=$HOME/.local/share/super-productivity-mcp:rw com.superproductivity.SuperProductivity
# Luego en Super Productivity: Settings → Plugins → Upload plugin.zip
```

---

## 4. Troubleshooting

| Síntoma | Causa | Fix |
|---|---|---|
| `AttributeError: 'Server' has no attribute 'list_tools'` | `mcp` 2.x instalado | `pip install "mcp==1.12.4"` |
| `Timeout waiting for response to addTask` (30s) | Flatpak `XDG_DATA_HOME` mismatch | Migrar a .deb o aplicar symlink + override + re-upload plugin |
| `curl 20128` connection refused | `omniroute.service` no corre | `systemctl --user restart omniroute; journalctl --user -u omniroute -n 50` |
| `ANTHROPIC_BASE_URL` ignora gateway | `CLAUDE_CODE_ENABLE_GATEWAY_MODEL_DISCOVERY=0` | Pon `1` en `~/.claude/settings.json` |
| Plugin no aparece en `claude mcp list` | `.mcp.json` mal formado | `cat ~/.claude/.mcp.json | jq .` y `claude mcp list` |

## 5. Próximos pasos

- [ ] Migrar este PC de Flatpak → .deb y validar `create_task` sin timeout (quitar symlink)
- [ ] Añadir `02-omniroute-superproductivity.sh` a dotly y probar en VM limpia Linux Mint
- [ ] Backup `~/.omniroute/.env` + `storage.sqlite` en dotfiles privado

---
*Generado 2026-09-06 — stack verificado en PC ed / Mint, Node 22.22.0, OmniRoute 3.8.49, SP 18.21.2, SP-MCP file-bridge.*
