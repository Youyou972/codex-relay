#!/bin/bash
set -e

SCRIPT_DIR="$(cd "$(dirname "$0")" && pwd)"
SETTINGS="$HOME/.claude/settings.json"

echo "Installing codex-relay..."

# 1. Marketplace manifest
mkdir -p "$HOME/.claude/plugins/local/.claude-plugin"
cat > "$HOME/.claude/plugins/local/.claude-plugin/marketplace.json" << 'EOF'
{
  "name": "local-dev",
  "owner": { "name": "Team" },
  "plugins": [{ "name": "codex-relay", "source": "./codex-relay" }]
}
EOF

# 2. Agent definition
mkdir -p "$HOME/.claude/agents"
cp "$SCRIPT_DIR/agents/codex.md" "$HOME/.claude/agents/codex-teammate.md"

# 3. Session hook
mkdir -p "$HOME/.claude/hooks"
cp "$SCRIPT_DIR/hooks/codex-relay-reset.sh" "$HOME/.claude/hooks/"
chmod +x "$HOME/.claude/hooks/codex-relay-reset.sh"

# 4. Patch settings.json
if [ ! -f "$SETTINGS" ]; then
  echo '{}' > "$SETTINGS"
fi

python3 << PYEOF
import json, sys

with open("$SETTINGS") as f:
    s = json.load(f)

changed = False

# Add local-dev marketplace
mkts = s.setdefault("extraKnownMarketplaces", {})
if "local-dev" not in mkts:
    mkts["local-dev"] = {"source": {"source": "directory", "path": "$HOME/.claude/plugins/local"}}
    changed = True

# Enable plugin
plugins = s.setdefault("enabledPlugins", {})
if "codex-relay@local-dev" not in plugins:
    plugins["codex-relay@local-dev"] = True
    changed = True

# Add session hook
hooks = s.setdefault("hooks", {})
session_hooks = hooks.setdefault("SessionStart", [{"hooks": []}])
hook_list = session_hooks[0].setdefault("hooks", [])
hook_cmd = "~/.claude/hooks/codex-relay-reset.sh"
if not any(h.get("command") == hook_cmd for h in hook_list):
    hook_list.append({"type": "command", "command": hook_cmd})
    changed = True

if changed:
    with open("$SETTINGS", "w") as f:
        json.dump(s, f, indent=2)
        f.write("\n")

PYEOF

echo "Done! Restart Claude Code."
echo ""
echo "Prerequisites (if not already installed):"
echo "  npm install -g @openai/codex && codex login"
