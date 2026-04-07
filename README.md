# Codex Relay

Persistent conversation relay between Claude Code and Codex CLI. Enables ongoing dialogue where Codex remembers all prior context within a session, and participates as a real teammate in Agent Teams.

## Prerequisites

- **Codex CLI** installed and logged in: `npm install -g @openai/codex && codex login`
- **Codex companion plugin** installed in Claude Code (`codex@openai-codex` in settings.json)
- **Claude Code** with agent teams enabled: `CLAUDE_CODE_EXPERIMENTAL_AGENT_TEAMS=1`

## How It Works

```
Claude Code ──► codex-relay plugin ──► Codex broker daemon ──► codex app-server ──► Codex CLI (gpt-5.4)
                (scripts/relay.mjs)    (existing, detached)     (JSON-RPC/JSONL)
```

The relay sits on top of the existing Codex companion plugin's **broker daemon** — a detached background process that manages a persistent `codex app-server` instance over a Unix socket. The relay adds:

1. **Thread management** — tracks active Codex thread IDs per project in `~/.codex-relay/state.json`
2. **Session scoping** — a SessionStart hook clears state on new Claude sessions (no cross-session bleed)
3. **Agent Teams integration** — a proxy agent definition lets Codex participate as a real teammate

## Installation

### 1. Plugin files

The plugin lives at `~/.claude/plugins/local/codex-relay/` with this structure:

```
codex-relay/
├── .claude-plugin/
│   └── plugin.json              # Plugin manifest
├── scripts/
│   └── relay.mjs                # Core relay script
├── skills/
│   └── codex-chat/
│       └── SKILL.md             # /codex-chat skill definition
├── agents/
│   └── codex.md                 # Agent definition (kept in plugin, not used directly)
└── README.md
```

### 2. Local marketplace registration

Create `~/.claude/plugins/local/.claude-plugin/marketplace.json`:

```json
{
  "name": "local-dev",
  "owner": { "name": "Your Name" },
  "plugins": [
    {
      "name": "codex-relay",
      "source": "./codex-relay"
    }
  ]
}
```

### 3. Settings.json entries

Add to `~/.claude/settings.json`:

```json
{
  "extraKnownMarketplaces": {
    "local-dev": {
      "source": {
        "source": "directory",
        "path": "/absolute/path/to/.claude/plugins/local"
      }
    }
  },
  "enabledPlugins": {
    "codex-relay@local-dev": true
  }
}
```

**Important**: The `path` must be an absolute path (no `~` expansion). Example: `/Users/yourname/.claude/plugins/local`

### 4. Global agent definition

Copy to `~/.claude/agents/codex-teammate.md` (Agent Teams can't load agents from plugins):

```markdown
---
name: codex-teammate
description: Delegates tasks to Codex CLI via the persistent relay.
model: sonnet
maxTurns: 10
tools: Bash, SendMessage
---

You are a thin relay between Claude Code Agent Teams and the Codex CLI.

## Your only job

Forward every message you receive to Codex via the relay script, and return its response verbatim.

## How to relay

**First message** — always start a fresh Codex thread with `--new`:

node ~/.claude/plugins/local/codex-relay/scripts/relay.mjs chat --new "THE MESSAGE"

**All follow-up messages** — continue on the same thread (no `--new`):

node ~/.claude/plugins/local/codex-relay/scripts/relay.mjs chat "THE MESSAGE"

For tasks that require Codex to modify files, add `--write`:

node ~/.claude/plugins/local/codex-relay/scripts/relay.mjs chat --write "THE MESSAGE"

## Rules

- Your FIRST relay call MUST use `--new` to start a fresh thread. All subsequent calls omit `--new`.
- Forward the FULL message text you receive — do not summarize or rephrase it.
- Return Codex's response EXACTLY as-is. Do not add commentary, analysis, or opinions.
- If Codex's response is empty or the command fails, report the error verbatim.
- Default to read-only mode. Only use `--write` if the message explicitly asks to modify files.
- You are NOT Claude. Do not answer questions yourself. Always relay to Codex.
```

### 5. SessionStart hook (session scoping)

Create `~/.claude/hooks/codex-relay-reset.sh`:

```bash
#!/bin/bash
# Reset codex-relay thread state on new Claude session
rm -f ~/.codex-relay/state.json 2>/dev/null
exit 0
```

Make it executable: `chmod +x ~/.claude/hooks/codex-relay-reset.sh`

Add to `~/.claude/settings.json` under `hooks.SessionStart`:

```json
{
  "type": "command",
  "command": "~/.claude/hooks/codex-relay-reset.sh"
}
```

## Usage

### Direct skill: `/codex-chat`

From any Claude Code session:

| Command | Description |
|---------|-------------|
| `/codex-chat <message>` | Send message to Codex (creates new thread if none, resumes if exists) |
| `/codex-chat --new <message>` | Force a new thread |
| `/codex-chat --write <message>` | Allow Codex to modify files |
| `/codex-chat --resume <id> <message>` | Switch to a specific thread |
| `/codex-chat --threads` | List tracked threads |
| `/codex-chat --status` | Show broker, thread, and connection info |
| `/codex-chat --model <model> <message>` | Use a specific Codex model |

You can also ask Claude naturally: "ask Codex about X", "check with Codex", "consult Codex" — Claude will use the skill automatically.

### As an Agent Teams teammate

Spawn Codex as a persistent teammate in any team:

```
TeamCreate({ team_name: "my-team" })
Agent({ subagent_type: "codex-teammate", name: "codex", team_name: "my-team", prompt: "Stand by for tasks." })
SendMessage({ to: "codex", message: "Review the auth middleware" })
```

The teammate:
- Starts a fresh Codex thread on spawn (`--new` on first call)
- Maintains context across follow-up messages within the session
- Is visible via Shift+Down in the terminal
- Can be sent messages with `SendMessage`
- Shuts down cleanly with `SendMessage({ to: "codex", message: { type: "shutdown_request" } })`

### CLI (direct script invocation)

```bash
# Chat
node ~/.claude/plugins/local/codex-relay/scripts/relay.mjs chat "your message"
node ~/.claude/plugins/local/codex-relay/scripts/relay.mjs chat --new "fresh thread"
node ~/.claude/plugins/local/codex-relay/scripts/relay.mjs chat --write "edit the file"

# Management
node ~/.claude/plugins/local/codex-relay/scripts/relay.mjs threads
node ~/.claude/plugins/local/codex-relay/scripts/relay.mjs status
```

## Architecture

### Components

| Component | Location | Persistence |
|-----------|----------|-------------|
| Relay script | `~/.claude/plugins/local/codex-relay/scripts/relay.mjs` | On disk (permanent) |
| Thread state | `~/.codex-relay/state.json` | Cleared each Claude session (hook) |
| Broker daemon | Temp dir (auto-managed by Codex plugin) | Survives Claude restarts, dies on reboot |
| Codex thread history | `~/.codex/sessions/` | On disk (permanent, managed by Codex) |
| Agent definition | `~/.claude/agents/codex-teammate.md` | On disk (permanent) |
| Skill definition | Plugin's `skills/codex-chat/SKILL.md` | On disk (permanent) |

### Session scoping

| Scope | Behavior |
|-------|----------|
| Within a Claude session | Thread persists — Codex remembers all turns |
| New Claude session | Hook clears state → first call creates fresh thread |
| Teammate spawns | `--new` on first call → fresh thread per teammate |
| Teammate shuts down | Thread abandoned, next spawn starts fresh |
| Direct `/codex-chat` | Session-scoped (cleared by hook on new session) |

### How the relay connects to Codex

1. `relay.mjs` auto-discovers the Codex plugin at `~/.claude/plugins/marketplaces/openai-codex/...`
2. Imports `runAppServerTurn` from the plugin's `lib/codex.mjs`
3. `runAppServerTurn` calls `ensureBrokerSession()` which starts the broker daemon if not running
4. The broker spawns `codex app-server` as a child process (JSON-RPC over JSONL on stdin/stdout)
5. The relay sends `turn/start` with the message on the active thread
6. Codex processes the turn and streams notifications back (agent messages, commands, file changes)
7. The relay captures `turn/completed`, formats the response, and prints to stdout

### Cost per relay call

```
Claude (Opus) → Sonnet proxy (~$0.003) → Codex relay → Codex CLI (gpt-5.4)
```

The Sonnet proxy (for Agent Teams) adds ~600-1400 tokens overhead per message. Direct `/codex-chat` usage has zero proxy overhead — it's just the Codex API call.

## Troubleshooting

| Problem | Solution |
|---------|----------|
| `/codex-chat` not found | Use full name: `/codex-relay:codex-chat`. Or restart session. |
| "Codex plugin not found" | Install: `claude plugin add openai-codex` |
| "Codex CLI is not installed" | Run: `npm install -g @openai/codex` |
| Login/auth errors | Run: `! codex login` in the Claude Code prompt |
| Stale thread (Codex confused) | Use `--new` to start fresh |
| Teammate not responding | Check Shift+Down panel. Sonnet model may need a stronger prompt. |
| `codex-teammate` agent not found | Ensure `~/.claude/agents/codex-teammate.md` exists. Restart session. |
| State file corrupt | Delete `~/.codex-relay/state.json` — next call creates a new thread |

## Team Sharing

To share with your team:

1. Copy `~/.claude/plugins/local/codex-relay/` to their machine (same path)
2. Create the marketplace.json at `~/.claude/plugins/local/.claude-plugin/marketplace.json`
3. Add `local-dev` marketplace and `codex-relay@local-dev` to their `~/.claude/settings.json`
4. Copy `~/.claude/agents/codex-teammate.md` to their `~/.claude/agents/`
5. Copy `~/.claude/hooks/codex-relay-reset.sh` and add the SessionStart hook to settings
6. Ensure they have Codex CLI installed and logged in

Or push the plugin to a git repo and reference it as a GitHub marketplace source instead of `directory`.
