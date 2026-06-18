---
name: "claude-code-spawn"
description: "Spawn, resume, inspect, and manage Claude Code CLI instances from Codex. Use when the user asks to start Claude Code, keep a Claude instance alive, spawn Claude/Claude Code agents, check whether a Claude session is still running, resume a previous Claude session, list Claude Code skills/agents, or ask which Claude Code model/auth path is being used. Let the spawning agent choose the Claude model for the task: default to the latest Opus alias for complex work, and choose the latest Sonnet alias or Haiku family model when speed, cost, or task simplicity make that more appropriate."
---

# Claude Code Spawn

## Defaults

- Let the spawning agent choose the model based on task complexity, cost, and latency.
- Use the latest Opus alias, `opus`, for complex coding, architecture, debugging, review, or long-running autonomous work. This tracks the newest available Opus model in the local Claude Code CLI, such as Opus 4.8 when available.
- Use the latest Sonnet alias, `sonnet`, for routine implementation, focused edits, medium-complexity investigation, and faster iteration where Opus is not necessary.
- Use the latest Haiku family model only for cheap/fast smoke checks, simple summarization, status inspection, or other low-risk tasks. Prefer `haiku` if the installed CLI supports that alias; otherwise use the current full Haiku model ID.
- Use Claude Code auto permission mode with `--permission-mode auto` by default.
- If the user names a model, family, or cost/speed preference, honor that explicitly.
- Prefer keeping long-running Claude instances in an interactive PTY session so Codex can poll or send more input later.
- Do not use `--bare` for normal user-account Claude Code sessions unless the user wants API-key-only mode.

## Verified Local Facts

- CLI path: `/Users/yohannblanchard/.local/bin/claude`.
- Observed version: `2.1.126 (Claude Code)`.
- Normal Claude Code mode uses the user's Claude Desktop/Claude Max login context when available.
- The visible auth banner showed `Claude Max` for `diabolocreeper@gmail.com's Organization`.
- `--bare` ignores normal Claude Desktop/OAuth/keychain auth and reported `Not logged in` in this environment; it expects `ANTHROPIC_API_KEY` or explicit settings/auth helper.
- `claude --print` starts a task, returns a result, and exits. It may still return a resumable `session_id` unless `--no-session-persistence` is set.
- An interactive `claude ...` process stays live until explicitly exited or killed.
- `claude --model` accepts aliases for the latest available model family, including `opus` and `sonnet`, as well as full model names such as `claude-opus-4-7`. Use a Haiku alias only after confirming the installed CLI supports it, or pass the current full Haiku model ID.

## Start A Persistent Instance

Use a PTY command and keep the returned `session_id`.

```bash
claude --model opus --permission-mode auto --name codex-opus-kept-alive
```

For a repo-specific instance, run it in the target repo's `cwd`.

When Codex starts this through `exec_command`, set `tty=true`; poll it later with `write_stdin` and an empty `chars` string.

## Ask A One-Shot Question

Use `--print` for a one-shot task. It exits after completion.

```bash
claude --print --output-format json --model sonnet --permission-mode auto "List all Claude Code skills available to you."
```

Avoid `--no-session-persistence` when the user may want to resume the session later. Use it only for disposable checks.

## Resume Or Fork

Resume a known session:

```bash
claude --resume <session-id> --model opus
```

Fork from a previous session into a new session:

```bash
claude --fork-session --resume <session-id> --model opus
```

Continue the most recent conversation in the current directory:

```bash
claude --continue --model opus
```

## Worktrees And Tmux

For isolated long-running work:

```bash
claude --worktree <name> --tmux --model opus --permission-mode auto
```

Use this when the user wants Claude Code to work independently for a while or when edits should be isolated from the current dirty checkout.

## Inspect Capabilities

List configured Claude Code agents:

```bash
claude agents list
```

Ask a spawned Claude instance to list visible skills:

```bash
claude --print --output-format json --model sonnet --permission-mode auto "List all Claude Code skills available to you in this session. Return concise JSON with keys: skills, agents, notes."
```

Observed skill categories included Superpowers workflow skills, Unity/game skills, `codex-relay:codex-chat`, `gemini-cli`, Supabase/Stripe/context7 skills, frontend/playground, and review/security-review.

## Model And Cost Notes

- Starting a Claude Code run in a large repo/plugin context can create a large prompt cache and cost materially more than a bare minimal prompt.
- Do not silently downgrade a user-requested model to save cost. Mention cost risk, but use the requested model.
- If the user does not specify a model, pick the cheapest model that is still appropriate for the task. Use Opus for high-risk or complex work, Sonnet for standard coding, and Haiku for low-risk checks when available.
- If a cheap smoke test is needed before real work, clearly state that it is a smoke test and use Haiku when available, otherwise use `sonnet`; choose the normal model for the actual work.
- Prefer aliases such as `opus` and `sonnet` over dated model IDs when the user asks for the latest family member. Use a full model ID when the user explicitly asks for that exact model or when an alias is unavailable.

## Known Startup Noise

If the prompt shows failed MCP servers or missing hooks, treat that as non-blocking unless the task needs those MCP tools.

Observed examples:

- `MCP servers failed` / `MCP servers need auth`
- missing hook: `/Users/yohannblanchard/.claude/hooks/codex-relay-reset.sh`

Report these clearly when they may affect the requested Claude work.
