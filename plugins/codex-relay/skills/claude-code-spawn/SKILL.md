---
name: "claude-code-spawn"
description: "Spawn, resume, inspect, and manage Claude Code CLI instances from Codex. Use when the user asks to start Claude Code, keep a Claude instance alive, spawn Claude/Claude Code agents, use Claude Code swarm/workflows/ultracode, check whether a Claude session is still running, resume a previous Claude session, list Claude Code skills/agents, or ask which Claude Code model/auth path is being used."
---

# Claude Code Spawn

## Ground Rules

- Use `/Users/yohannblanchard/.local/bin/claude` unless a fresh `command -v claude` proves otherwise.
- Treat this skill as a local wrapper around Anthropic's official Claude Code CLI for the current user's own work. Do not use it as a hosted/shared third-party harness, subscription proxy, credential relay, or resale path.
- OAuth/Claude Max auth is only for ordinary first-party Claude Code usage by the logged-in user. For products, shared services, CI fleets, or other users' workloads, use an Anthropic API-key/Agent SDK path instead.
- Prefer aliases (`opus`, `sonnet`, `haiku`) over dated model IDs unless the user requests an exact model.
- Use `opus` for complex architecture, autonomous implementation, debugging, review, and long-running work.
- Use `sonnet` for routine edits, focused investigation, and faster iteration where Opus is not needed.
- Use Haiku only for cheap smoke checks or low-risk summarization, and only after confirming the alias/model exists.
- Do not silently downgrade a user-requested model, effort, or workflow mode. If a requested mode is not available through a spawn path, report that and choose the closest working path.
- Do not use `--bare` for normal user-account Claude Code sessions. It bypasses the usual Claude Desktop/OAuth/keychain auth context and may report `Not logged in`.
- Prefer interactive PTY sessions for long-running Claude workers, swarm/workflow runs, and any task where Codex may need to poll or send follow-up input.
- Use `--print` only for bounded one-shot questions or implementation jobs where interactive-only features are not required.

## Verified Local Facts

- CLI path observed: `/Users/yohannblanchard/.local/bin/claude`.
- Version observed on 2026-06-20: `2.1.185 (Claude Code)`.
- Normal Claude Code mode uses the user's Claude Max login context when available.
- The interactive banner may show model and effort, for example `Fable 5 with medium effort - Claude Max`.
- The startup hook `/Users/yohannblanchard/.claude/hooks/codex-relay-reset.sh` may be missing. Treat that as startup noise unless the task depends on the hook.
- `claude --help` in 2.1.185 lists `--effort <level>` values as `low`, `medium`, `high`, `xhigh`, and `max`.
- Anthropic documents `ultracode` as a Claude Code workflow setting, available through the interactive `/effort` UI, `ultracode:` prompts, and `--settings '{"ultracode":true}'`.
- `ultracode` is not a valid `--effort` flag value. `claude --print --effort ultracode ...` prints a warning in 2.1.185 and falls back to the default effort.
- `ultracode` can be enabled non-interactively through `--settings '{"ultracode":true}'`.
- `--settings '{"ultracode":true}'` with Claude Code 2.1.185 was observed to expose the `Workflow` tool and launch a dynamic workflow task ID/run ID from `--print`.
- Verified successful ultracode workflow on 2026-06-20 used `--print --verbose --output-format stream-json --model sonnet --permission-mode bypassPermissions --settings '{"ultracode":true}'`, then a prompt beginning with `ultracode:` that explicitly required the `Workflow` tool, one implementer subagent, one verifier subagent, and no full-file returns from subagents.
- A real workflow run emits evidence such as `Workflow` in the available tools, a `Workflow` tool call, `task_started`, `task_id`, `runId`, and workflow/subagent transcript paths under `~/.claude/projects/.../subagents/workflows/`.
- Interactive `/effort` can select the visual `ultracode` mode, but that alone is insufficient. If `/workflows` reports `No dynamic workflows in this session`, no swarm/workflow has actually launched yet.
- Default Fable 5 may be unavailable. If the default model errors with a Fable availability message, retry with `--model sonnet` or `--model opus`.
- `claude --model` accepts aliases for available model families, including `opus` and `sonnet`.
- `claude --print` starts a task, returns a result, and exits. It may still return a resumable `session_id` unless `--no-session-persistence` is set.
- An interactive `claude ...` process stays live until explicitly exited or killed.

## Known Working Ultracode Recipe

Use this path when the user requires `ultracode`, `swarm`, `workflows`, or "Claude agents" and Codex is only coordinating/reviewing:

```bash
/Users/yohannblanchard/.local/bin/claude --print --verbose --output-format stream-json \
  --model sonnet \
  --permission-mode bypassPermissions \
  --settings '{"ultracode":true}' \
  --max-budget-usd 8 \
  "ultracode: use the Workflow tool now. Keep the workflow bounded. Use one implementer subagent and one verifier subagent. Do not ask subagents to return full file contents. Preserve unrelated dirty-tree changes. Do not commit, push, deploy, or revert unrelated files."
```

Why this is the preferred path:

- `--settings '{"ultracode":true}'` turns on the documented workflow-capable ultracode mode in Claude Code 2.1.185.
- `--effort ultracode` is wrong for this CLI version; it warns and falls back because valid CLI effort values are only `low`, `medium`, `high`, `xhigh`, and `max`.
- `--verbose --output-format stream-json` gives enough evidence for Codex to audit whether a workflow really launched.
- `--model sonnet` avoids the observed default Fable 5 availability failure while still supporting Workflow.
- `--permission-mode bypassPermissions` avoids permission prompts blocking noninteractive workflow runs. Use `auto` only when manual approval is acceptable.
- A narrow prompt is load-bearing: tell Claude to use the `Workflow` tool, constrain subagent count, forbid full-file returns, list allowed edit paths, and name the verification gates.

Authorization boundary:

- Allowed: Codex launching the user's installed `claude` binary locally, under the user's own Claude Code login, for the user's own coding/review work.
- Not allowed: wrapping Claude subscription OAuth as a third-party product/service, proxying other users through the user's login, sharing credentials, pooling subscription capacity, or using this skill to bypass Anthropic billing or service protections.
- When in doubt, use the official API-key/Agent SDK route instead of Claude Max/OAuth.

Treat the run as failed or incomplete if any of these happen:

- The command prints `unknown effort ultracode` or `unknown value for --effort`.
- No `Workflow` tool is exposed in the stream.
- No `Workflow` tool call appears.
- No `task_id` and `runId` are emitted.
- The run only shows `xhigh` thinking or plain `Task` subagents without a dynamic workflow.
- `/workflows` in an interactive session says `No dynamic workflows in this session`.

## Effort Selection

Before spawning work where effort matters, check the current CLI:

```bash
/Users/yohannblanchard/.local/bin/claude --version
/Users/yohannblanchard/.local/bin/claude --help | rg -n "effort|ultracode|xhigh|max"
```

Use these paths:

- For `low`, `medium`, `high`, `xhigh`, or `max`: either interactive PTY or `--print --effort <level>` is valid.
- For user-requested `ultracode`: use `--settings '{"ultracode":true}'` and require evidence that the `Workflow` tool was exposed and a workflow task ID/run ID was launched. Do not use `--effort ultracode`.
- Interactive fallback: start an interactive PTY, run `/effort`, select `ultracode`, confirm it, then send the task prompt. Do not claim `--effort ultracode` worked unless the CLI help lists it.
- For "swarm", "workflows", or "ultracode + swarm": use interactive `ultracode` and explicitly trigger a dynamic workflow in the task prompt. Use the exact keyword form `ultracode:` or ask Claude to "run a workflow"; do not rely on effort selection alone.
- Verify true workflow dispatch with `/workflows` or visible workflow/subagent progress. If the session only says "thinking with xhigh effort" and never shows workflow progress, treat that as not yet using the ultracode workflow system.
- Do not pass a restrictive `--tools Read,Edit,Write,Bash,Task` allowlist when workflows are required. That can hide or discourage the `Workflow` tool. Use default tools with `--permission-mode bypassPermissions` or include `Workflow` explicitly if using a tool allowlist.

## Start An Interactive Worker

Use a PTY command and keep the returned `session_id`.

```bash
/Users/yohannblanchard/.local/bin/claude --model opus --permission-mode auto --name codex-opus-worker
```

For a repo-specific worker, run it with the repo as `cwd`.

When Codex starts this through `exec_command`, set `tty=true`; poll it later with `write_stdin` and an empty `chars` string.

If the user requires ultracode, do this after the prompt is ready:

1. Start the interactive PTY.
2. Send `/effort`.
3. Select `ultracode` in the interactive effort UI and press Enter.
4. Verify the visible banner or status indicates ultracode when possible.
5. Send a workflow-triggering task prompt that starts with `ultracode:` and explicitly asks Claude to create/run a dynamic workflow.
6. After submission, run `/workflows` in the PTY or inspect visible workflow progress before assuming swarm/subagent orchestration is active.

The exact key sequence for the effort UI can change. If direct command text such as `/effort ultracode` is rejected, use arrow keys in the PTY until `ultracode` is selected, then press Enter.

Example task opening:

```text
ultracode: create and run a dynamic workflow for this task. First audit the current repo state, then dispatch focused subagents/workflow steps for loader, build-script, and tests, then have one writer apply only the allowed edits, then verify with the requested commands.
```

## Ask A One-Shot Question

Use `--print` for a one-shot task when no interactive-only mode is required:

```bash
/Users/yohannblanchard/.local/bin/claude --print --output-format json --model sonnet --permission-mode auto "List all Claude Code skills available to you."
```

For complex one-shot work, use Opus and the highest supported non-interactive effort:

```bash
/Users/yohannblanchard/.local/bin/claude --print --output-format stream-json --model opus --effort max --permission-mode auto "Do the requested task..."
```

For ultracode workflow/swarm work in `--print`, use settings rather than `--effort`:

```bash
/Users/yohannblanchard/.local/bin/claude --print --verbose --output-format stream-json \
  --model sonnet \
  --permission-mode bypassPermissions \
  --max-budget-usd 8 \
  --settings '{"ultracode":true}' \
  "ultracode: use the Workflow tool. Launch a small workflow with one implementer subagent and one verifier subagent. Do not return full file contents from subagents. Preserve unrelated dirty-tree changes. Do not commit, push, deploy, or revert unrelated files."
```

In the stream, look for `tools` containing `Workflow`, then a `Workflow` tool call, `task_started`, `task_id`, and `runId`. Also capture workflow transcript paths when present. If default Fable is unavailable, retry with `--model sonnet` or `--model opus`.

Avoid `--no-session-persistence` when the user may want to resume the session later. Use it only for disposable checks.

## Resume Or Fork

Resume a known session:

```bash
/Users/yohannblanchard/.local/bin/claude --resume <session-id> --model opus
```

Fork from a previous session into a new session:

```bash
/Users/yohannblanchard/.local/bin/claude --fork-session --resume <session-id> --model opus
```

Continue the most recent conversation in the current directory:

```bash
/Users/yohannblanchard/.local/bin/claude --continue --model opus
```

## Worktrees And Tmux

For isolated long-running work:

```bash
/Users/yohannblanchard/.local/bin/claude --worktree <name> --tmux --model opus --permission-mode auto
```

Use this when the user wants Claude Code to work independently for a while or when edits should be isolated from the current dirty checkout.

Do not convert a dirty existing checkout to a sparse/partial layout blindly. If disk footprint matters, prefer a new partial clone or worktree-specific setup and document the workflow.

## Inspect Capabilities

List configured Claude Code agents:

```bash
/Users/yohannblanchard/.local/bin/claude agents list
```

Ask a spawned Claude instance to list visible skills:

```bash
/Users/yohannblanchard/.local/bin/claude --print --output-format json --model sonnet --permission-mode auto "List all Claude Code skills available to you in this session. Return concise JSON with keys: skills, agents, notes."
```

If a task depends on swarm/subagents, check whether the run exposes a `Task` tool or equivalent workflow capability. In prompts, explicitly say whether Claude is implementer, reviewer, or coordinator.

## Review/Coordinator Pattern

When the user says Codex is only the reviewer and Claude should implement:

1. Codex prepares the prompt, constraints, allowed files, and gates.
2. Claude performs implementation.
3. Codex inspects the diff and runs verification.
4. Codex reports failures back to Claude or the user instead of silently implementing the slice itself.

For dirty worktrees, always state allowed edit paths in the Claude prompt and tell Claude not to commit, push, deploy, or revert unrelated changes.

## Known Startup Noise

Treat these as non-blocking unless the task needs the affected integration:

- `MCP servers failed`
- `MCP servers need auth`
- missing hook: `/Users/yohannblanchard/.claude/hooks/codex-relay-reset.sh`

Report startup noise clearly when it may affect the requested Claude work.

## Cost Notes

- Starting Claude Code in a large repo/plugin context can create a large prompt cache and cost materially more than a minimal prompt.
- Mention material cost risk when relevant, but honor explicit user requests.
- A cheap smoke test can use Haiku or Sonnet, but the actual work should use the requested model/effort/workflow.
