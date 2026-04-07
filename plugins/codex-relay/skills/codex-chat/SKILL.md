---
name: codex-chat
description: Send a message to Codex on a persistent conversation thread. Use for consulting Codex, delegating research, or having an ongoing dialogue that survives session restarts.
user-invocable: true
---

# Codex Chat

Send messages to a persistent Codex conversation. The thread survives Claude Code session restarts — Codex remembers everything from prior turns.

## How to use

Run the relay script via Bash. The script path is:
`${CLAUDE_PLUGIN_ROOT}/scripts/relay.mjs`

### Send a message (default — continues existing thread)

```bash
node "${CLAUDE_PLUGIN_ROOT}/scripts/relay.mjs" chat "your message here"
```

### Start a new thread

```bash
node "${CLAUDE_PLUGIN_ROOT}/scripts/relay.mjs" chat --new "your message here"
```

### Allow Codex to write files

```bash
node "${CLAUDE_PLUGIN_ROOT}/scripts/relay.mjs" chat --write "your message here"
```

### Resume a specific thread

```bash
node "${CLAUDE_PLUGIN_ROOT}/scripts/relay.mjs" chat --resume <thread-id> "your message here"
```

### List threads

```bash
node "${CLAUDE_PLUGIN_ROOT}/scripts/relay.mjs" threads
```

### Check status

```bash
node "${CLAUDE_PLUGIN_ROOT}/scripts/relay.mjs" status
```

## Rules

- Always run the script from the project's working directory so thread state is associated with the correct project.
- Read the full output from the script — it contains Codex's response, any commands it ran, and files it modified.
- When the user asks to "talk to Codex", "ask Codex", "check with Codex", or "consult Codex", use this skill.
- For follow-up questions in the same conversation, just call `chat` again — the thread is automatic.
- Use `--new` only when the user explicitly wants a fresh conversation topic.
- Use `--write` when the user wants Codex to make file changes, not just discuss.
- The script prints progress to stderr and the final response to stdout. Capture stdout for the response.
- If the script fails with a login error, tell the user to run `! codex login` in their terminal.
