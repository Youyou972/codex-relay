#!/bin/bash
set -e

PLUGIN_DIR="$HOME/.claude/plugins/local/codex-relay"
SCRIPT_DIR="$(cd "$(dirname "$0")" && pwd)"

echo "Installing codex-relay plugin..."

# 1. Create marketplace manifest (if not exists)
MARKETPLACE_DIR="$HOME/.claude/plugins/local/.claude-plugin"
mkdir -p "$MARKETPLACE_DIR"
if [ ! -f "$MARKETPLACE_DIR/marketplace.json" ]; then
  cat > "$MARKETPLACE_DIR/marketplace.json" << 'EOF'
{
  "name": "local-dev",
  "owner": { "name": "Team" },
  "plugins": [
    { "name": "codex-relay", "source": "./codex-relay" }
  ]
}
EOF
  echo "  Created marketplace manifest"
else
  echo "  Marketplace manifest already exists"
fi

# 2. Copy agent definition to global agents
mkdir -p "$HOME/.claude/agents"
cp "$SCRIPT_DIR/agents/codex.md" "$HOME/.claude/agents/codex-teammate.md"
echo "  Installed agent definition -> ~/.claude/agents/codex-teammate.md"

# 3. Copy session reset hook
mkdir -p "$HOME/.claude/hooks"
cp "$SCRIPT_DIR/hooks/codex-relay-reset.sh" "$HOME/.claude/hooks/"
chmod +x "$HOME/.claude/hooks/codex-relay-reset.sh"
echo "  Installed session hook -> ~/.claude/hooks/codex-relay-reset.sh"

# 4. Patch settings.json
SETTINGS="$HOME/.claude/settings.json"
if [ -f "$SETTINGS" ]; then
  # Check if already configured
  if grep -q "codex-relay@local-dev" "$SETTINGS"; then
    echo "  Settings already configured"
  else
    echo ""
    echo "  ⚠ Manual step required: Add the following to $SETTINGS"
    echo ""
    echo '  In "extraKnownMarketplaces", add:'
    echo '    "local-dev": {'
    echo '      "source": {'
    echo '        "source": "directory",'
    echo "        \"path\": \"$HOME/.claude/plugins/local\""
    echo '      }'
    echo '    }'
    echo ""
    echo '  In "enabledPlugins", add:'
    echo '    "codex-relay@local-dev": true'
    echo ""
    echo '  In "hooks.SessionStart[0].hooks", add:'
    echo '    { "type": "command", "command": "~/.claude/hooks/codex-relay-reset.sh" }'
  fi
else
  echo "  ⚠ No settings.json found at $SETTINGS — create one manually"
fi

echo ""
echo "Done! Restart Claude Code to activate."
echo ""
echo "Prerequisites:"
echo "  - Codex CLI: npm install -g @openai/codex"
echo "  - Codex login: codex login"
echo "  - Codex plugin: codex@openai-codex enabled in settings.json"
