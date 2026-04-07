#!/bin/bash
# Reset codex-relay thread state on new Claude session
# This ensures each Claude session starts with a fresh Codex thread
rm -f ~/.codex-relay/state.json 2>/dev/null
exit 0
