# Stack Reproducible: OmniRoute + Claude Code + OpenCode (Zen/Go) + Super Productivity

> Documentación para reproducir el stack de IA local en cualquier PC Linux Mint / Ubuntu en < 15 min via dotly.

## Resumen del Stack Actual (2026-09-28 — verificado en vivo en `ed`)

| Componente | Versión | Instalación | Puerto / Path | Estado |
|---|---|---|---|---|
| **OmniRoute Gateway** | 3.8.50 (npm, Node 24.14.1 via nvm) | `npm -g omniroute@latest` → systemd user | `http://localhost:20128` (`/v1` OpenAI-compat) | ✅ `systemctl --user status omniroute` |
| **Claude Code** | CLI `2.1.246` | native installer (`~/.local/share/claude/versions/…`) | `~/.claude/settings.json` → `ANTHROPIC_BASE_URL=http://localhost:20128` | ✅ Gateway discovery ON, model `claude-with-free-fallback` |
| **Claude Code "profiles"** | — | `~/.claude/profiles/<name>/settings.json` | run with `claude --settings ~/.claude/profiles/<name>/settings.json` | ✅ 11 profiles (fallback chains + raw models) |
| **OpenCode CLI** | 1.18.32 | `curl -fsSL https://opencode.ai/install \| bash` | `~/.config/opencode/opencode.json` | ✅ |
| **@omniroute/opencode-plugin** | 0.2.1 (built from source, not on npm) | cloned+built from `diegosouzapw/OmniRoute` → `~/.config/opencode/plugins/omniroute` | registers `omniroute` as an OpenCode provider (`opencode-omniroute/...`) | ✅ |
| **opencode-antigravity-auth** | 1.6.0 | npm plugin, auto-installed by OpenCode from `opencode.json` `plugin[]` | auth flow for the `antigravity` combo provider | ✅ |
| **OpenCode Zen** | — | hosted model marketplace by the OpenCode team | connected as an upstream provider inside OmniRoute + directly in OpenCode auth (`opencode-zen/qwen3.6-plus`, etc.) | ✅ auth in `~/.local/share/opencode/auth.json` |
| **OpenCode Go** | — | hosted model plan by the OpenCode team | connected as an upstream provider/combo (`go-with-claude-fallback`, …) | ✅ auth key `opencode-go` |
| **Super Productivity** | 18.21.2 | Flatpak `com.superproductivity.SuperProductivity` (Flathub) | `~/.var/app/.../data` | ⚠️ File-bridge requiere symlink (ver abajo) — **recomendado migrar a .deb nativo** |
| **SP-MCP Bridge** | organicmoron/SP-MCP | `~/.local/share/super-productivity-mcp/mcp_server.py` + plugin ZIP | `plugin_commands/` ↔ `plugin_responses/` | ✅ 10 tools, via `mcp==1.12.4` |

### Otros MCP servers activos (no gestionados por dotly, dependencias externas)

| MCP | Origen | Notas |
|---|---|---|
| `codebase-memory-mcp` | binario propio en `~/.local/bin/codebase-memory-mcp` | fuera de este repo; si no existe, se omite en `opencode.json`/`.mcp.json` |
| `headroom` | `~/.headroom/venv` (compresión/cache de contexto) | fuera de este repo |
| `pencil` | app de escritorio (AppImage montado en `/tmp/.mount_Pen-*`) | **no reproducible por script** — requiere reinstalar la app y que esté abierta; si el mount no existe, el MCP simplemente falla al conectar (no rompe nada más) |
| `hostinger` | remoto (`https://mcp.hostinger.com`) | necesita `HOSTINGER_API_TOKEN` en el entorno |

### Prueba end-to-end verificada

```bash
curl http://localhost:20128/v1/chat/completions -d '{"model":"auto/best-fast",
  "messages":[{"role":"user","content":"Create task Buy milk"}],
  "tools":[{"type":"function","function":{"name":"create_task","parameters":{"type":"object","properties":{"title":{"type":"string"}}}}}]}'
# → glm-5.2 genera tool_calls: create_task ✓
timeout 3 python3 -c "from mcp import ClientSession..." # list_tools → 10 tools ✓
claude --settings ~/.claude/profiles/go-with-claude-fallback/settings.json -p "ping"
opencode auth list   # google, openai, zai, anthropic, opencode-go, opencode-omniroute
```

---

## 1. Arquitectura del stack de IA

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

- **OmniRoute** is the single local gateway both CLIs talk to. It owns the upstream
  provider credentials and defines "combo" models (ordered fallback chains, e.g. try
  Claude first, fall back to a free/cheap model on rate-limit).
- **OpenCode Zen** and **OpenCode Go** are hosted model offerings from the OpenCode team
  (not part of this repo) — Zen is a pay-as-you-go model marketplace, Go is a bundled
  plan. Both are added as upstream providers so OmniRoute (and OpenCode directly) can
  route to them, including inside fallback combos like `go-with-claude-fallback`.
- **Claude Code** talks OpenAI/Anthropic wire format straight to OmniRoute via
  `ANTHROPIC_BASE_URL`; `CLAUDE_CODE_ENABLE_GATEWAY_MODEL_DISCOVERY=1` lets it list
  OmniRoute's dynamic model catalog.
- **OpenCode** talks to OmniRoute through `@omniroute/opencode-plugin`, a local plugin
  (not published to npm as of `0.2.1`) that registers `omniroute` as a provider and
  handles the `/connect` auth flow + multi-instance support.

---

## 2. Instalación Reproducible (dotly)

### 2.1 One-liner dotly (PC nuevo, Linux Mint)

```bash
sudo apt update && sudo apt install -y git
git clone https://github.com/edcalderon/dotly "$HOME/.dotfiles"
cd "$HOME/.dotfiles"
git submodule update --init --recursive modules/dotly
DOTFILES_PATH="$HOME/.dotfiles" DOTLY_PATH="$DOTFILES_PATH/modules/dotly" "$DOTLY_PATH/bin/dot" self install

# Restaura entorno base (zsh, Node, Docker, VSCodium, Yakuake, teclado, navegadores...)
DOTFILES_PATH="$PWD/dotfiles_template" bash dotfiles_template/restoration_scripts/01-default_linux_restoration.sh
# OmniRoute gateway + Super Productivity + SP-MCP
DOTFILES_PATH="$PWD/dotfiles_template" bash dotfiles_template/restoration_scripts/02-omniroute-superproductivity.sh
# OpenCode CLI + plugin de OmniRoute + wiring de Claude Code (gateway + profiles)
DOTFILES_PATH="$PWD/dotfiles_template" bash dotfiles_template/restoration_scripts/03-opencode-claude-ai-stack.sh

# Relogin y verifica
systemctl --user status omniroute --no-pager
claude mcp list
opencode auth list
```

### 2.2 Script `02-omniroute-superproductivity.sh`

Ver `dotfiles_template/restoration_scripts/02-omniroute-superproductivity.sh` — idempotente, re-ejecutable. Hace:

1. **OmniRoute**
   - Instala `nvm` Node `24.14.1` (o `22.22.2+`) si no está
   - `npm install -g omniroute@latest`
   - Crea `~/.omniroute/.env` con `PORT=20128`, `REQUIRE_API_KEY=false`, `DATA_DIR`, y genera `JWT_SECRET`/`API_KEY_SECRET`/`STORAGE_ENCRYPTION_KEY` si no existen (**nunca los regenera** si ya existen — rompería `storage.sqlite`)
   - Instala `~/.config/systemd/user/omniroute.service` y `systemctl --user enable --now omniroute`
   - Espera `http://localhost:20128/v1/models` y parchea `ANTHROPIC_BASE_URL` en `~/.claude/settings.json`

2. **Super Productivity (estable)**
   - Prefiere `.deb` nativo (`johannesjo/super-productivity` releases), fallback a Flatpak

3. **SP-MCP**
   - `pip install "mcp==1.12.4"` (pin, 2.x rompe `list_tools`)
   - Clona `organicmoron/SP-MCP` → `~/.local/share/super-productivity-mcp/`
   - Configura `~/.claude/.mcp.json` y `~/.config/opencode/opencode.json` (merge, no overwrite)

### 2.3 Script `03-opencode-claude-ai-stack.sh` (nuevo, 2026-09-28)

Ver `dotfiles_template/restoration_scripts/03-opencode-claude-ai-stack.sh`. Hace:

1. **OpenCode CLI**: instala si falta (`curl -fsSL https://opencode.ai/install | bash`)
2. **`@omniroute/opencode-plugin`**: clona `github.com/diegosouzapw/OmniRoute`, hace
   `npm install && npm run build` sobre `@omniroute/opencode-plugin`, y copia
   `dist/` + `package.json` a `~/.config/opencode/plugins/omniroute` (no está publicado
   en npm, por eso se compila desde fuente en vez de instalarlo como dependencia)
3. **`opencode.json`**: agrega (merge idempotente, sin pisar lo existente)
   - plugins: `opencode-antigravity-auth@1.6.0` + el plugin local de OmniRoute
     (`providerId: "omniroute"`, `baseURL: http://localhost:20128`)
   - `model` por defecto: `opencode-omniroute/cc/claude-sonnet-5`
   - `mcp.codebase-memory-mcp` / `mcp.super-productivity` **solo si el binario ya existe**
     (son dependencias externas, no las instala este script)
4. **`~/.claude/settings.json`**: agrega `ANTHROPIC_BASE_URL`,
   `CLAUDE_CODE_ENABLE_GATEWAY_MODEL_DISCOVERY=1`, `ENABLE_TOOL_SEARCH=true`
   (nunca toca `OMNIROUTE_API_KEY` si ya existe)
5. **`~/.claude/profiles/<name>/settings.json`**: escribe 3 perfiles de ejemplo
   (`claude-with-free-fallback`, `go-with-claude-fallback`, `opencode-zen-qwen3-6-plus`)
   que se usan así:
   ```bash
   claude --settings ~/.claude/profiles/go-with-claude-fallback/settings.json
   ```
6. Imprime los **pasos manuales** que siguen (sección 3) — no se pueden scriptear porque
   OmniRoute guarda providers/combos cifrados en `~/.omniroute/storage.sqlite`.

### 2.4 Pasos manuales (obligatorios, una sola vez por máquina)

1. Abre el dashboard de OmniRoute: `http://localhost:20128`
   - Primer login: usuario/`INITIAL_PASSWORD` de `~/.omniroute/.env`, cámbiala.
2. **Settings → Providers**: conecta las credenciales que quieras usar en combos:
   - Anthropic (API key)
   - OpenAI (API key)
   - Google (API key)
   - Z.AI (API key)
   - **OpenCode Zen** (API key desde `opencode.ai` / cuenta OpenCode)
   - **OpenCode Go** (login desde la cuenta OpenCode con el plan Go activo)
3. **Settings → Models**: crea los modelos "combo" (cadenas de fallback) referenciados
   por los perfiles de Claude Code, p. ej.:
   - `claude-with-free-fallback` → Claude Sonnet, fallback a un modelo gratis/barato
   - `go-with-claude-fallback` → OpenCode Go primero, fallback a Claude
   - (`opencode-zen/qwen3.6-plus` no necesita combo — es un modelo nativo de Zen)
4. Cierra el handshake de OpenCode ↔ OmniRoute:
   ```bash
   opencode auth login   # elige "omniroute", sigue el flujo /connect
   ```
5. Verifica:
   ```bash
   claude mcp list
   opencode auth list                 # debe listar: omniroute, opencode-go, opencode-zen (si lo conectaste), etc.
   claude --settings ~/.claude/profiles/go-with-claude-fallback/settings.json -p "ping"
   ```

### 2.5 Variables sensibles

| Archivo | Clave | Origen |
|---|---|---|
| `~/.omniroute/.env` | `JWT_SECRET`, `API_KEY_SECRET`, `STORAGE_ENCRYPTION_KEY` | Generado en primera instalación, **no regenerar** (rompe credenciales en `storage.sqlite`) |
| `~/.omniroute/storage.sqlite` | credenciales de todos los providers (Anthropic/OpenAI/Google/Z.AI/OpenCode Zen/Go) | Cifrado con `STORAGE_ENCRYPTION_KEY`; se configura solo desde el dashboard, no hay archivo plano que templetear |
| `~/.claude/settings.json` | `OMNIROUTE_API_KEY` | Dashboard de OmniRoute → Settings → API Keys (solo si `REQUIRE_API_KEY=true`) |
| `~/.local/share/opencode/auth.json` | `google`, `openai`, `zai`, `anthropic`, `opencode-go`, `opencode-omniroute` | `opencode auth login <provider>` por cada uno |

Backup: `~/.omniroute/storage.sqlite` + `.env` → Dropbox/dotfiles (encriptado, nunca en claro en este repo).

---

## 3. Configuración Manual (si no usas dotly)

### OmniRoute
```bash
nvm install 24.14.1 && nvm use 24.14.1
npm install -g omniroute@latest
mkdir -p ~/.omniroute
cat > ~/.omniroute/.env <<'EOF'
PORT=20128
DATA_DIR=/home/$USER/.omniroute
REQUIRE_API_KEY=false
OMNIROUTE_SERVER_HOST=127.0.0.1
JWT_SECRET=$(openssl rand -base64 32)
API_KEY_SECRET=$(openssl rand -hex 16)
STORAGE_ENCRYPTION_KEY=$(openssl rand -hex 32)
EOF
mkdir -p ~/.config/systemd/user
cat > ~/.config/systemd/user/omniroute.service <<EOF
[Unit]
Description=OmniRoute AI gateway
After=network-online.target
[Service]
Type=simple
Environment=NODE_ENV=production
Environment=DATA_DIR=%h/.omniroute
Environment=PATH=%h/.nvm/versions/node/v24.14.1/bin:/usr/local/bin:/usr/bin:/bin
EnvironmentFile=%h/.omniroute/.env
ExecStart=%h/.nvm/versions/node/v24.14.1/bin/node %h/.nvm/versions/node/v24.14.1/lib/node_modules/omniroute/bin/omniroute.mjs serve --no-open --no-tray
Restart=on-failure
[Install]
WantedBy=default.target
EOF
systemctl --user daemon-reload && systemctl --user enable --now omniroute
curl http://localhost:20128/v1/models | jq .
```

### OpenCode CLI + OmniRoute plugin
```bash
curl -fsSL https://opencode.ai/install | bash

git clone --depth 1 https://github.com/diegosouzapw/OmniRoute /tmp/OmniRoute
cd /tmp/OmniRoute/@omniroute/opencode-plugin && npm install && npm run build
mkdir -p ~/.config/opencode/plugins/omniroute
cp -r dist package.json ~/.config/opencode/plugins/omniroute/

# Merge into ~/.config/opencode/opencode.json:
#   "plugin": ["opencode-antigravity-auth@1.6.0",
#              ["./plugins/omniroute/dist/index.js",
#               {"providerId":"omniroute","baseURL":"http://localhost:20128","features":{"usableOnly":false}}]]
opencode auth login   # -> omniroute
```

### Claude Code → OmniRoute gateway
```bash
python3 <<'PY'
import json, pathlib
p = pathlib.Path.home() / ".claude/settings.json"
d = json.loads(p.read_text()) if p.exists() else {}
d.setdefault("env", {}).update({
    "ANTHROPIC_BASE_URL": "http://localhost:20128",
    "CLAUDE_CODE_ENABLE_GATEWAY_MODEL_DISCOVERY": "1",
})
p.write_text(json.dumps(d, indent=2))
PY
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
| Plugin no aparece en `claude mcp list` | `.mcp.json` mal formado | `cat ~/.claude/.mcp.json \| jq .` y `claude mcp list` |
| `opencode auth list` no muestra `omniroute` | Falta el `/connect` handshake | `opencode auth login` → elegir `omniroute` |
| OpenCode no encuentra el plugin de OmniRoute | `~/.config/opencode/plugins/omniroute/dist/index.js` no existe o build falló | Re-correr `03-opencode-claude-ai-stack.sh` con `FORCE_REBUILD_OMNIROUTE_PLUGIN=1` |
| Modelo de un perfil de Claude (`go-with-claude-fallback`, etc.) da 404/"model not found" | El combo no existe todavía en el dashboard de OmniRoute en esta máquina | Crear el combo en Settings → Models con el mismo nombre exacto |
| `pencil` MCP no conecta | Es una app de escritorio (AppImage montado en `/tmp/.mount_Pen-*`), no algo que dotly instale | Abrir la app de escritorio Pencil; si no la usas en esta máquina, quítalo de `~/.claude/settings.json` / `opencode.json` |

## 5. Próximos pasos

- [ ] Publicar `@omniroute/opencode-plugin` en npm para no tener que compilarlo desde fuente en cada máquina
- [ ] Documentar cómo exportar/importar los "combos" de OmniRoute (actualmente 100% manual vía dashboard)
- [ ] Backup cifrado de `~/.omniroute/.env` + `storage.sqlite` en dotfiles privado
- [ ] Evaluar mover `codebase-memory-mcp` / `headroom` a scripts propios de dotly si se vuelven parte fija del setup

---
*Actualizado 2026-09-28 — stack verificado en vivo en PC `ed`: OmniRoute 3.8.50, Node 24.14.1 (omniroute) / 22.22.2 (default), Claude Code 2.1.246, OpenCode 1.18.32, @omniroute/opencode-plugin 0.2.1, opencode-antigravity-auth 1.6.0, SP 18.21.2.*
