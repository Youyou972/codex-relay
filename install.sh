#!/bin/bash
set -e

REPO="Youyou972/codex-relay"
BRANCH="master"
RAW="https://raw.githubusercontent.com/$REPO/$BRANCH"

echo "Installing codex-relay..."
echo ""

# 1. Check prerequisites
if ! command -v codex &>/dev/null; then
  echo "ERROR: Codex CLI not found. Install it first:"
  echo "  npm install -g @openai/codex && codex login"
  exit 1
fi

if ! command -v claude &>/dev/null; then
  echo "ERROR: Claude Code CLI not found."
  exit 1
fi

# 2. Add marketplace + install plugin via CLI
echo "Adding marketplace..."
claude plugin marketplace add "$REPO" 2>/dev/null || true

echo "Installing plugin..."
claude plugin install codex-relay@codex-relay 2>/dev/null || true

# 3. Ensure codex plugin is installed too
claude plugin marketplace add openai/codex-plugin-cc 2>/dev/null || true
claude plugin install codex@openai-codex 2>/dev/null || true

# 4. Download agent definition (for Agent Teams support)
mkdir -p "$HOME/.claude/agents"
curl -fsSL "$RAW/plugins/codex-relay/agents/codex.md" \
  > "$HOME/.claude/agents/codex-teammate.md"
echo "Installed agent definition"

# 5. Download session hook (thread reset per session)
mkdir -p "$HOME/.claude/hooks"
curl -fsSL "$RAW/plugins/codex-relay/hooks/codex-relay-reset.sh" \
  > "$HOME/.claude/hooks/codex-relay-reset.sh"
chmod +x "$HOME/.claude/hooks/codex-relay-reset.sh"
echo "Installed session hook"

# 6. Add session hook to settings if not present
SETTINGS="$HOME/.claude/settings.json"
if [ -f "$SETTINGS" ] && command -v python3 &>/dev/null; then
  python3 << 'PYEOF'
import json, os

settings_path = os.path.expanduser("~/.claude/settings.json")
with open(settings_path) as f:
    s = json.load(f)

hooks = s.setdefault("hooks", {})
session_hooks = hooks.setdefault("SessionStart", [{"hooks": []}])
hook_list = session_hooks[0].setdefault("hooks", [])
hook_cmd = "~/.claude/hooks/codex-relay-reset.sh"
if not any(h.get("command") == hook_cmd for h in hook_list):
    hook_list.append({"type": "command", "command": hook_cmd})
    with open(settings_path, "w") as f:
        json.dump(s, f, indent=2)
        f.write("\n")
    print("Added session hook to settings.json")
else:
    print("Session hook already configured")
PYEOF
fi

echo ""
echo "Done! Restart Claude Code to activate."
echo ""
echo "Usage:"
echo "  /codex-chat <message>          — chat with Codex"
echo "  /codex-chat --new <message>    — fresh thread"
echo "  /codex-chat --write <message>  — let Codex edit files"
