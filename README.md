# Codex Relay

Persistent conversation relay between Claude Code and Codex CLI.

## What it does

Manages long-lived Codex conversation threads that survive Claude Code session restarts. Instead of one-shot `codex exec` calls, you get an ongoing dialogue where Codex remembers all prior context.

## Prerequisites

- Codex CLI installed (`npm install -g @openai/codex`)
- Codex companion plugin installed in Claude Code (`openai-codex` marketplace plugin)
- Codex logged in (`codex login`)

## Usage

From Claude Code, use the `/codex-chat` skill:

- `/codex-chat <message>` — Send a message to Codex (creates new thread if none exists)
- `/codex-chat --new <message>` — Start a fresh thread
- `/codex-chat --threads` — List available threads
- `/codex-chat --resume <id> <message>` — Switch to a different thread
- `/codex-chat --status` — Show broker and thread status

## Installation

```bash
claude plugin add ~/.claude/plugins/local/codex-relay
```

## How it works

The plugin sits on top of the Codex companion plugin's broker daemon (a detached process that manages a persistent `codex app-server` instance). The relay:

1. Connects to the broker via Unix socket (starts it if not running)
2. Manages thread IDs per project directory in `~/.codex-relay/state.json`
3. Sends turns on persistent threads — Codex retains full conversation history
4. Returns formatted responses to Claude Code

The broker daemon survives Claude Code session restarts, terminal closes, and machine sleep.
