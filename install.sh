#!/bin/bash
set -e

SCRIPT_DIR="$(cd "$(dirname "$0")" && pwd)"
PLUGIN_DIR="$SCRIPT_DIR/plugins/codex-relay"
SETTINGS="$HOME/.claude/settings.json"

echo "Installing codex-relay..."

# 1. Agent definition (resolve CLAUDE_PLUGIN_ROOT to actual path)
mkdir -p "$HOME/.claude/agents"
sed "s|\${CLAUDE_PLUGIN_ROOT}|$PLUGIN_DIR|g" "$PLUGIN_DIR/agents/codex.md" > "$HOME/.claude/agents/codex-teammate.md"

# 2. Session hook
mkdir -p "$HOME/.claude/hooks"
cp "$PLUGIN_DIR/hooks/codex-relay-reset.sh" "$HOME/.claude/hooks/"
chmod +x "$HOME/.claude/hooks/codex-relay-reset.sh"

# 3. Patch settings.json
if [ ! -f "$SETTINGS" ]; then
  echo '{}' > "$SETTINGS"
fi

python3 << PYEOF
import json

with open("$SETTINGS") as f:
    s = json.load(f)

changed = False

# Add GitHub marketplace
mkts = s.setdefault("extraKnownMarketplaces", {})
if "codex-relay" not in mkts:
    mkts["codex-relay"] = {"source": {"source": "github", "repo": "Youyou972/codex-relay"}}
    changed = True

# Enable plugin
plugins = s.setdefault("enabledPlugins", {})
if "codex-relay@codex-relay" not in plugins:
    plugins["codex-relay@codex-relay"] = True
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
