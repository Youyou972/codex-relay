#!/bin/bash
set -e

REPO="Youyou972/codex-relay"
RAW="https://raw.githubusercontent.com/$REPO/HEAD"

echo "Installing codex-relay..."
echo ""

# Prerequisites
if ! command -v codex &>/dev/null; then
  echo "ERROR: Codex CLI not found."
  echo "  npm install -g @openai/codex && codex login"
  exit 1
fi

if ! command -v claude &>/dev/null; then
  echo "ERROR: Claude Code CLI not found."
  exit 1
fi

if ! command -v node &>/dev/null; then
  echo "ERROR: Node.js not found."
  exit 1
fi

# Install plugins via CLI
echo "Adding codex-relay marketplace..."
if ! claude plugin marketplace add "$REPO"; then
  echo "ERROR: Failed to add marketplace. Check network and repo access."
  exit 1
fi

echo "Installing codex-relay plugin..."
if ! claude plugin install codex-relay@codex-relay; then
  echo "ERROR: Failed to install codex-relay plugin."
  exit 1
fi

echo "Ensuring codex plugin is installed..."
claude plugin marketplace add openai/codex-plugin-cc 2>/dev/null || true
claude plugin install codex@openai-codex 2>/dev/null || true

# Download agent definition
mkdir -p "$HOME/.claude/agents"
if ! curl -fsSL "$RAW/plugins/codex-relay/agents/codex.md" > "$HOME/.claude/agents/codex-teammate.md"; then
  echo "ERROR: Failed to download agent definition."
  exit 1
fi
echo "Installed agent definition"

# Download session hook
mkdir -p "$HOME/.claude/hooks"
if ! curl -fsSL "$RAW/plugins/codex-relay/hooks/codex-relay-reset.sh" > "$HOME/.claude/hooks/codex-relay-reset.sh"; then
  echo "ERROR: Failed to download session hook."
  exit 1
fi
chmod +x "$HOME/.claude/hooks/codex-relay-reset.sh"
echo "Installed session hook"

# Add session hook to settings.json using Node (no python3 dependency)
SETTINGS="$HOME/.claude/settings.json"
if [ ! -f "$SETTINGS" ]; then
  echo '{}' > "$SETTINGS"
fi

node -e "
const fs = require('fs');
const p = '$SETTINGS';
const s = JSON.parse(fs.readFileSync(p, 'utf8'));
const hooks = s.hooks = s.hooks || {};
const ss = hooks.SessionStart = hooks.SessionStart || [{ hooks: [] }];
const list = ss[0].hooks = ss[0].hooks || [];
const cmd = '~/.claude/hooks/codex-relay-reset.sh';
if (!list.some(h => h.command === cmd)) {
  list.push({ type: 'command', command: cmd });
  fs.writeFileSync(p, JSON.stringify(s, null, 2) + '\n');
  console.log('Added session hook to settings.json');
} else {
  console.log('Session hook already configured');
}
"

echo ""
echo "Done! Restart Claude Code to activate."
echo ""
echo "Usage:"
echo "  /codex-chat <message>          — chat with Codex"
echo "  /codex-chat --new <message>    — fresh thread"
echo "  /codex-chat --write <message>  — let Codex edit files"
