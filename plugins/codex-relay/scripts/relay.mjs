#!/usr/bin/env node

/**
 * codex-relay — persistent conversation relay between Claude Code and Codex CLI.
 *
 * Commands:
 *   chat <message>   Send a message (new or continued thread)
 *   threads          List all tracked project threads
 *   status           Show Codex availability and current project state
 *   help             Show usage
 *
 * Chat flags:
 *   --new            Start a fresh thread (ignore saved state)
 *   --write          Allow file writes (sandbox=write, approvalPolicy=on-failure)
 *   --model <m>      Override model (e.g. gpt-5.4)
 *   --effort <e>     Override effort level
 *   --resume <id>    Resume a specific thread by ID
 */

import { existsSync, mkdirSync, readFileSync, readdirSync, writeFileSync } from "node:fs";
import { homedir } from "node:os";
import { join, resolve } from "node:path";

// ---------------------------------------------------------------------------
// Codex plugin auto-detection
// ---------------------------------------------------------------------------

function findCodexPlugin() {
  // Env override
  if (process.env.CODEX_PLUGIN_PATH) {
    const candidate = resolve(process.env.CODEX_PLUGIN_PATH);
    const libDir = join(candidate, "lib");
    if (existsSync(join(libDir, "codex.mjs"))) {
      return libDir;
    }
    // Maybe they pointed at the plugin root (scripts/lib inside)
    const altLib = join(candidate, "scripts", "lib");
    if (existsSync(join(altLib, "codex.mjs"))) {
      return altLib;
    }
    throw new Error(`CODEX_PLUGIN_PATH=${candidate} does not contain lib/codex.mjs`);
  }

  // Scan marketplace directories
  const marketplaces = join(homedir(), ".claude", "plugins", "marketplaces");
  if (!existsSync(marketplaces)) {
    throw new Error(
      "Cannot find ~/.claude/plugins/marketplaces/. Is the Codex companion plugin installed?"
    );
  }

  // Known location for the openai-codex plugin
  const knownPath = join(
    marketplaces,
    "openai-codex",
    "plugins",
    "codex",
    "scripts",
    "lib"
  );
  if (existsSync(join(knownPath, "codex.mjs"))) {
    return knownPath;
  }

  // Fallback: scan all marketplace dirs
  for (const entry of readdirSync(marketplaces, { withFileTypes: true })) {
    if (!entry.isDirectory()) continue;
    const candidate = join(marketplaces, entry.name, "plugins", "codex", "scripts", "lib");
    if (existsSync(join(candidate, "codex.mjs"))) {
      return candidate;
    }
  }

  throw new Error(
    "Cannot find the openai-codex plugin. Install it from the Claude Code plugin marketplace."
  );
}

let _codexLib = null;

async function getCodexLib() {
  if (_codexLib) return _codexLib;
  const libDir = findCodexPlugin();
  const codexModule = await import(join(libDir, "codex.mjs"));
  _codexLib = {
    runAppServerTurn: codexModule.runAppServerTurn,
    findLatestTaskThread: codexModule.findLatestTaskThread,
    getCodexAvailability: codexModule.getCodexAvailability,
    getCodexLoginStatus: codexModule.getCodexLoginStatus,
    getSessionRuntimeStatus: codexModule.getSessionRuntimeStatus,
    buildPersistentTaskThreadName: codexModule.buildPersistentTaskThreadName,
  };
  return _codexLib;
}

// ---------------------------------------------------------------------------
// State management
// ---------------------------------------------------------------------------

const STATE_DIR = join(homedir(), ".codex-relay");
const STATE_FILE = join(STATE_DIR, "state.json");

function loadState() {
  try {
    if (existsSync(STATE_FILE)) {
      return JSON.parse(readFileSync(STATE_FILE, "utf8"));
    }
  } catch {
    // Corrupted — start fresh
  }
  return { projects: {} };
}

function saveState(state) {
  mkdirSync(STATE_DIR, { recursive: true });
  writeFileSync(STATE_FILE, JSON.stringify(state, null, 2) + "\n", "utf8");
}

function getProjectState(state, projectPath) {
  return state.projects[projectPath] ?? null;
}

function setProjectState(state, projectPath, data) {
  state.projects[projectPath] = {
    ...data,
    lastUsed: new Date().toISOString(),
  };
  saveState(state);
}

// ---------------------------------------------------------------------------
// Output formatting
// ---------------------------------------------------------------------------

function formatSection(title, content) {
  if (!content) return "";
  return `\n--- ${title} ---\n${content}\n`;
}

function formatResult(result) {
  const parts = [];

  // Thread metadata
  parts.push(`[thread: ${result.threadId}]`);
  if (result.turnId) {
    parts.push(`[turn: ${result.turnId}]`);
  }
  parts.push(`[status: ${result.status === 0 ? "completed" : "failed"}]`);
  parts.push("");

  // Main message
  if (result.finalMessage) {
    parts.push(formatSection("Response", result.finalMessage));
  }

  // Reasoning
  if (result.reasoningSummary?.length > 0) {
    parts.push(
      formatSection(
        "Reasoning",
        result.reasoningSummary.map((s) => `- ${s}`).join("\n")
      )
    );
  }

  // Commands executed
  if (result.commandExecutions?.length > 0) {
    const cmds = result.commandExecutions.map((cmd) => {
      const exitInfo = cmd.exitCode != null ? ` (exit ${cmd.exitCode})` : "";
      return `- ${cmd.command ?? "unknown"}${exitInfo}`;
    });
    parts.push(formatSection("Commands", cmds.join("\n")));
  }

  // File changes
  if (result.touchedFiles?.length > 0) {
    parts.push(
      formatSection("Files Changed", result.touchedFiles.map((f) => `- ${f}`).join("\n"))
    );
  }

  // Errors
  if (result.error) {
    const errMsg =
      typeof result.error === "string"
        ? result.error
        : result.error.message ?? JSON.stringify(result.error);
    parts.push(formatSection("Error", errMsg));
  }

  // Stderr
  if (result.stderr?.trim()) {
    parts.push(formatSection("Stderr", result.stderr.trim()));
  }

  return parts.join("\n").trim();
}

// ---------------------------------------------------------------------------
// Commands
// ---------------------------------------------------------------------------

async function cmdChat(cwd, message, flags) {
  if (!message) {
    console.error("Error: no message provided. Usage: relay.mjs chat <message>");
    process.exit(1);
  }

  const lib = await getCodexLib();
  const state = loadState();
  const projectState = getProjectState(state, cwd);

  // Determine thread to resume
  let resumeThreadId = null;
  if (flags.resume) {
    resumeThreadId = flags.resume;
  } else if (!flags.new && projectState?.activeThreadId) {
    resumeThreadId = projectState.activeThreadId;
  }

  const sandbox = flags.write ? "workspace-write" : "read-only";
  const approvalPolicy = flags.write ? "on-failure" : "never";

  const threadName = lib.buildPersistentTaskThreadName(message);

  const progressHandler = (update) => {
    const text = typeof update === "string" ? update : update?.message;
    if (text) {
      process.stderr.write(`[codex] ${text}\n`);
    }
  };

  try {
    const result = await lib.runAppServerTurn(cwd, {
      prompt: message,
      resumeThreadId,
      persistThread: true,
      threadName,
      model: flags.model ?? undefined,
      effort: flags.effort ?? undefined,
      sandbox,
      approvalPolicy,
      onProgress: progressHandler,
    });

    // Save thread state
    setProjectState(state, cwd, {
      activeThreadId: result.threadId,
      model: flags.model ?? projectState?.model ?? null,
    });

    console.log(formatResult(result));
  } catch (err) {
    // If resume failed, try starting fresh
    if (resumeThreadId && !flags.resume) {
      process.stderr.write(
        `[codex] Resume failed (${err.message}), starting new thread...\n`
      );
      try {
        const result = await lib.runAppServerTurn(cwd, {
          prompt: message,
          persistThread: true,
          threadName,
          model: flags.model ?? undefined,
          effort: flags.effort ?? undefined,
          sandbox,
          approvalPolicy,
          onProgress: progressHandler,
        });

        setProjectState(state, cwd, {
          activeThreadId: result.threadId,
          model: flags.model ?? projectState?.model ?? null,
        });

        console.log(formatResult(result));
        return;
      } catch (retryErr) {
        console.error(`Error: ${retryErr.message}`);
        process.exit(1);
      }
    }
    if (flags.resume) {
      console.error(
        `Error: failed to resume thread "${flags.resume}": ${err.message}\n` +
          `Hint: the thread may be stale or expired. Try again without --resume to start a new thread.`
      );
    } else {
      console.error(`Error: ${err.message}`);
    }
    process.exit(1);
  }
}

async function cmdThreads(cwd) {
  const state = loadState();
  const projects = Object.entries(state.projects);

  if (projects.length === 0) {
    console.log("No tracked threads. Use `relay.mjs chat <message>` to start one.");
    return;
  }

  console.log("Tracked Codex threads:\n");
  for (const [projectPath, info] of projects) {
    const isCurrent = cwd && projectPath === cwd;
    console.log(`  Project: ${projectPath}${isCurrent ? " (current)" : ""}`);
    console.log(`  Thread:  ${info.activeThreadId ?? "(none)"}`);
    console.log(`  Model:   ${info.model ?? "(default)"}`);
    console.log(`  Used:    ${info.lastUsed ?? "unknown"}`);
    console.log("");
  }
}

async function cmdStatus(cwd) {
  const lib = await getCodexLib();

  // Availability
  const availability = lib.getCodexAvailability(cwd);
  console.log(`Codex CLI: ${availability.available ? "available" : "NOT available"}`);
  console.log(`  Detail: ${availability.detail}`);

  // Login status
  if (availability.available) {
    const login = lib.getCodexLoginStatus(cwd);
    console.log(`  Logged in: ${login.loggedIn ? "yes" : "no"}`);
    console.log(`  Auth: ${login.detail}`);
  }

  // Runtime status
  if (availability.available) {
    const runtime = lib.getSessionRuntimeStatus(process.env, cwd);
    console.log(`  Runtime: ${runtime.label}`);
    if (runtime.endpoint) {
      console.log(`  Endpoint: ${runtime.endpoint}`);
    }
  }

  // Project state
  const state = loadState();
  const projectState = getProjectState(state, cwd);
  console.log("");
  console.log(`Project: ${cwd}`);
  if (projectState) {
    console.log(`  Active thread: ${projectState.activeThreadId ?? "(none)"}`);
    console.log(`  Model: ${projectState.model ?? "(default)"}`);
    console.log(`  Last used: ${projectState.lastUsed ?? "unknown"}`);
  } else {
    console.log("  No tracked thread for this project.");
  }

  console.log("");
  console.log(`State file: ${STATE_FILE}`);
}

function cmdHelp() {
  console.log(`codex-relay — persistent conversation relay for Codex CLI

Usage:
  relay.mjs chat <message>    Send a message to Codex (continues existing thread)
  relay.mjs threads           List all tracked project threads
  relay.mjs status            Show Codex availability and project state
  relay.mjs help              Show this help

Chat flags:
  --new              Start a fresh thread (discard saved thread)
  --write            Allow file writes (sandbox=write, approvalPolicy=on-failure)
  --model <model>    Override model (e.g. gpt-5.4)
  --effort <level>   Override effort level
  --resume <id>      Resume a specific thread by ID
`);
}

// ---------------------------------------------------------------------------
// CLI argument parsing
// ---------------------------------------------------------------------------

function parseArgs(argv) {
  const args = argv.slice(2); // skip node + script
  const command = args[0] ?? "help";
  const flags = {};
  const rest = [];

  let i = 1;
  while (i < args.length) {
    const arg = args[i];
    if (arg === "--new") {
      flags.new = true;
      i++;
    } else if (arg === "--write") {
      flags.write = true;
      i++;
    } else if (arg === "--model" && i + 1 < args.length) {
      flags.model = args[i + 1];
      i += 2;
    } else if (arg === "--effort" && i + 1 < args.length) {
      flags.effort = args[i + 1];
      i += 2;
    } else if (arg === "--resume" && i + 1 < args.length) {
      flags.resume = args[i + 1];
      i += 2;
    } else {
      rest.push(arg);
      i++;
    }
  }

  return { command, flags, message: rest.join(" ") };
}

// ---------------------------------------------------------------------------
// Entry point
// ---------------------------------------------------------------------------

async function main() {
  const cwd = process.cwd();
  const { command, flags, message } = parseArgs(process.argv);

  switch (command) {
    case "chat":
      await cmdChat(cwd, message, flags);
      break;
    case "threads":
      await cmdThreads(cwd);
      break;
    case "status":
      await cmdStatus(cwd);
      break;
    case "help":
    case "--help":
    case "-h":
      cmdHelp();
      break;
    default:
      console.error(`Unknown command: ${command}`);
      cmdHelp();
      process.exit(1);
  }
}

main().catch((err) => {
  console.error(`Fatal: ${err.message}`);
  if (process.env.DEBUG) {
    console.error(err.stack);
  }
  process.exit(1);
});
