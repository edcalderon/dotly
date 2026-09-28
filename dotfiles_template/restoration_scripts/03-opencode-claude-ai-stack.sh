#!/usr/bin/env bash
set -euo pipefail

# 03-opencode-claude-ai-stack.sh — OpenCode <-> OmniRoute plugin + Claude Code gateway wiring
# Idempotent, safe to re-run. Part of dotly: Documents/dotly
#
# Assumes 02-omniroute-superproductivity.sh already ran (OmniRoute service up on $OMNI_PORT).
# This script wires the CLIENT side of the AI stack:
#   - OpenCode CLI: @omniroute/opencode-plugin (built from source) + opencode-antigravity-auth
#   - Claude Code:  gateway env vars + example multi-model "profiles"
#
# What it CANNOT automate (OmniRoute stores this encrypted in ~/.omniroute/storage.sqlite,
# not in a plain file dotly can template): connecting upstream providers (Anthropic, OpenAI,
# Google, Z.AI, OpenCode Zen, OpenCode Go) and defining the fallback "combo" models
# (claude-with-free-fallback, go-with-claude-fallback, etc.) in the OmniRoute dashboard.
# See the printed manual steps at the end, and REPRODUCIBLE_SETUP.md.
#
# Usage: DOTFILES_PATH="$PWD/dotfiles_template" bash dotfiles_template/restoration_scripts/03-opencode-claude-ai-stack.sh

if [ -n "${DOTFILES_PATH:-}" ] && [ -f "$DOTFILES_PATH/os/linux/.dotly" ]; then
  # shellcheck source=/dev/null
  . "$DOTFILES_PATH/os/linux/.dotly"
fi

OMNI_PORT="${OMNI_PORT:-20128}"
OMNI_BASE_URL="http://localhost:${OMNI_PORT}"
OPENCODE_CONFIG_DIR="${HOME}/.config/opencode"
OPENCODE_CONFIG="${OPENCODE_CONFIG_DIR}/opencode.json"
PLUGIN_DIR="${OPENCODE_CONFIG_DIR}/plugins/omniroute"
ANTIGRAVITY_AUTH_VERSION="${ANTIGRAVITY_AUTH_VERSION:-1.6.0}"
DEFAULT_MODEL="${OPENCODE_DEFAULT_MODEL:-opencode-omniroute/cc/claude-sonnet-5}"

ensure_opencode() {
  if command -v opencode >/dev/null 2>&1; then
    echo "[opencode] Already installed: $(opencode --version 2>&1 | head -n1)"
    return 0
  fi
  echo "[opencode] Installing OpenCode (https://opencode.ai)..."
  curl -fsSL https://opencode.ai/install | bash -s -- --no-modify-path
  export PATH="$HOME/.opencode/bin:$PATH"
}

# Builds @omniroute/opencode-plugin from source (not published to npm as of 0.2.1)
# and drops it into ~/.config/opencode/plugins/omniroute, matching the live layout.
install_omniroute_opencode_plugin() {
  if [ -f "$PLUGIN_DIR/dist/index.js" ] && [ "${FORCE_REBUILD_OMNIROUTE_PLUGIN:-0}" != "1" ]; then
    echo "[omniroute-plugin] Already built at $PLUGIN_DIR (set FORCE_REBUILD_OMNIROUTE_PLUGIN=1 to rebuild)"
    return 0
  fi
  if ! command -v npm >/dev/null 2>&1; then
    echo "[omniroute-plugin] npm not found (need Node from 01/02 scripts), skipping" >&2
    return 1
  fi

  echo "[omniroute-plugin] Building @omniroute/opencode-plugin from source..."
  local src_dir
  src_dir="$(mktemp -d)"
  git clone --depth 1 https://github.com/diegosouzapw/OmniRoute "$src_dir/OmniRoute"
  (
    cd "$src_dir/OmniRoute/@omniroute/opencode-plugin"
    npm install
    npm run build
  )

  mkdir -p "$PLUGIN_DIR"
  cp -r "$src_dir/OmniRoute/@omniroute/opencode-plugin/dist" "$PLUGIN_DIR/"
  cp "$src_dir/OmniRoute/@omniroute/opencode-plugin/package.json" "$PLUGIN_DIR/"
  [ -f "$src_dir/OmniRoute/@omniroute/opencode-plugin/README.md" ] && cp "$src_dir/OmniRoute/@omniroute/opencode-plugin/README.md" "$PLUGIN_DIR/"
  rm -rf "$src_dir"
  echo "[omniroute-plugin] Built -> $PLUGIN_DIR/dist/index.js"
}

configure_opencode_json() {
  mkdir -p "$OPENCODE_CONFIG_DIR"
  OMNI_BASE_URL="$OMNI_BASE_URL" DEFAULT_MODEL="$DEFAULT_MODEL" ANTIGRAVITY_AUTH_VERSION="$ANTIGRAVITY_AUTH_VERSION" python3 <<'PY'
import json, os, pathlib

p = pathlib.Path.home() / ".config/opencode/opencode.json"
d = json.loads(p.read_text()) if p.exists() else {}

d.setdefault("$schema", "https://opencode.ai/config.json")
d.setdefault("model", os.environ["DEFAULT_MODEL"])
d.setdefault("default_agent", "build")
d.setdefault("compaction", {"auto": True, "prune": True})

plugins = d.setdefault("plugin", [])

antigravity_pkg = f'opencode-antigravity-auth@{os.environ["ANTIGRAVITY_AUTH_VERSION"]}'
if not any(isinstance(x, str) and x.startswith("opencode-antigravity-auth@") for x in plugins):
    plugins.append(antigravity_pkg)

if not any(isinstance(x, list) and x and x[0] == "./plugins/omniroute/dist/index.js" for x in plugins):
    plugins.append([
        "./plugins/omniroute/dist/index.js",
        {
            "providerId": "omniroute",
            "baseURL": os.environ["OMNI_BASE_URL"],
            "features": {"usableOnly": False},
        },
    ])

mcp = d.setdefault("mcp", {})
cbm_bin = pathlib.Path.home() / ".local/bin/codebase-memory-mcp"
if cbm_bin.exists() and "codebase-memory-mcp" not in mcp:
    mcp["codebase-memory-mcp"] = {"enabled": True, "type": "local", "command": [str(cbm_bin)]}

sp_mcp = pathlib.Path.home() / ".local/share/super-productivity-mcp/mcp_server.py"
if sp_mcp.exists() and "super-productivity" not in mcp:
    mcp["super-productivity"] = {"enabled": True, "type": "local", "command": ["python3", str(sp_mcp)]}

p.write_text(json.dumps(d, indent=2) + "\n")
print(f"[opencode] Patched {p}")
PY
}

configure_claude_gateway() {
  mkdir -p "$HOME/.claude"
  if [ ! -f "$HOME/.claude/settings.json" ]; then
    echo '{}' > "$HOME/.claude/settings.json"
  fi
  OMNI_BASE_URL="$OMNI_BASE_URL" python3 <<'PY'
import json, os, pathlib

p = pathlib.Path.home() / ".claude/settings.json"
d = json.loads(p.read_text())
env = d.setdefault("env", {})
env["ANTHROPIC_BASE_URL"] = os.environ["OMNI_BASE_URL"]
env.setdefault("CLAUDE_CODE_ENABLE_GATEWAY_MODEL_DISCOVERY", "1")
env.setdefault("ENABLE_TOOL_SEARCH", "true")
# OMNIROUTE_API_KEY is intentionally left untouched here — set it by hand from the
# OmniRoute dashboard (Settings -> API Keys) if REQUIRE_API_KEY=true in ~/.omniroute/.env.
p.write_text(json.dumps(d, indent=2) + "\n")
print(f"[claude] Patched {p} (ANTHROPIC_BASE_URL, gateway discovery, tool search)")
PY
}

# Example multi-model "profiles": run any of them with
#   claude --settings ~/.claude/profiles/<name>/settings.json
# Each one just overrides `model`/`ANTHROPIC_MODEL`; all still route through OmniRoute.
# The model names below must exist as "combo" models in the OmniRoute dashboard first.
write_claude_profiles() {
  local profiles_dir="$HOME/.claude/profiles"
  mkdir -p "$profiles_dir"

  local -A profiles=(
    [claude-with-free-fallback]="claude-with-free-fallback"
    [go-with-claude-fallback]="go-with-claude-fallback"
    [opencode-zen-qwen3-6-plus]="opencode-zen/qwen3.6-plus"
  )

  for name in "${!profiles[@]}"; do
    local model="${profiles[$name]}"
    local dir="$profiles_dir/$name"
    if [ -f "$dir/settings.json" ]; then
      continue
    fi
    mkdir -p "$dir"
    cat > "$dir/settings.json" <<EOF
{
  "\$schema": "https://json.schemastore.org/claude-code-settings.json",
  "model": "$model",
  "env": {
    "ANTHROPIC_BASE_URL": "$OMNI_BASE_URL",
    "ANTHROPIC_MODEL": "$model",
    "CLAUDE_CODE_ENABLE_GATEWAY_MODEL_DISCOVERY": "1",
    "CLAUDE_CODE_AUTO_COMPACT_WINDOW": "190000"
  }
}
EOF
    echo "[claude] Wrote profile $dir/settings.json"
  done
}

main() {
  echo "[03] OpenCode + Claude Code AI-stack wiring — start"
  ensure_opencode
  install_omniroute_opencode_plugin
  configure_opencode_json
  configure_claude_gateway
  write_claude_profiles

  cat <<EOF

[03] Done. Manual steps still required (OmniRoute keeps these encrypted in
~/.omniroute/storage.sqlite, so they can't be templated by dotly):

  1. Open the OmniRoute dashboard: $OMNI_BASE_URL
     First run: log in with INITIAL_PASSWORD from ~/.omniroute/.env, then change it.
  2. Settings -> Providers: connect Anthropic, OpenAI, Google, Z.AI, OpenCode Zen and
     OpenCode Go (each needs its own API key / OAuth login).
  3. Settings -> Models: create the "combo" (fallback chain) models referenced by the
     profiles this script just wrote:
       - claude-with-free-fallback
       - go-with-claude-fallback
       - opencode-zen/qwen3.6-plus (native OpenCode Zen model, no combo needed)
     Or edit ~/.claude/profiles/*/settings.json to point at whatever combo names you use.
  4. Complete the OpenCode <-> OmniRoute auth handshake:
       opencode auth login   # choose "omniroute", follow the /connect flow
  5. Verify:
       claude mcp list
       claude --settings ~/.claude/profiles/go-with-claude-fallback/settings.json
       opencode --version && opencode auth list
EOF
}

main "$@"
