#!/bin/bash
set -e

REPO="Youyou972/codex-relay"
BRANCH="master"
RAW="https://raw.githubusercontent.com/$REPO/$BRANCH"
SETTINGS="$HOME/.claude/settings.json"

echo "Installing codex-relay..."

# 1. Download agent definition
mkdir -p "$HOME/.claude/agents"
curl -fsSL "$RAW/plugins/codex-relay/agents/codex.md" \
  > "$HOME/.claude/agents/codex-teammate.md"

# 2. Download session hook
mkdir -p "$HOME/.claude/hooks"
curl -fsSL "$RAW/plugins/codex-relay/hooks/codex-relay-reset.sh" \
  > "$HOME/.claude/hooks/codex-relay-reset.sh"
chmod +x "$HOME/.claude/hooks/codex-relay-reset.sh"

# 3. Patch settings.json
if [ ! -f "$SETTINGS" ]; then
  echo '{}' > "$SETTINGS"
fi

python3 << PYEOF
import json

with open("$SETTINGS") as f:
    s = json.load(f)

mkts = s.setdefault("extraKnownMarketplaces", {})
if "codex-relay" not in mkts:
    mkts["codex-relay"] = {"source": {"source": "github", "repo": "$REPO"}}

plugins = s.setdefault("enabledPlugins", {})
plugins["codex-relay@codex-relay"] = True

hooks = s.setdefault("hooks", {})
session_hooks = hooks.setdefault("SessionStart", [{"hooks": []}])
hook_list = session_hooks[0].setdefault("hooks", [])
hook_cmd = "~/.claude/hooks/codex-relay-reset.sh"
if not any(h.get("command") == hook_cmd for h in hook_list):
    hook_list.append({"type": "command", "command": hook_cmd})

with open("$SETTINGS", "w") as f:
    json.dump(s, f, indent=2)
    f.write("\n")

PYEOF

echo "Done! Restart Claude Code."
echo ""
echo "Prerequisites (if not already installed):"
echo "  npm install -g @openai/codex && codex login"
