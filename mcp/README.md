# Using the vault from Claude Desktop (MCP filesystem)

Claude Desktop can read & write this vault through the MCP filesystem server, giving you a
chat-style surface alongside Claude Code. Both point at the same Markdown files.

> 📘 **Prefer a full step-by-step walkthrough?** See [`../docs/install-claude-desktop.md`](../docs/install-claude-desktop.md). This file is the quick reference.

## Prerequisites
- Node.js 18+ (`npx` must be on PATH) — the server runs via `npx @modelcontextprotocol/server-filesystem`.
- Claude Desktop installed.

## 1. Add the server to your Desktop config
Config file (macOS): `~/Library/Application Support/Claude/claude_desktop_config.json`

Merge the `second-brain` entry from `claude_desktop_config.snippet.json` into the existing
`mcpServers` object. **Preserve any servers already there** — add a key, don't overwrite the file.
Result should look like:

```json
{
  "mcpServers": {
    "second-brain": {
      "command": "npx",
      "args": ["-y", "@modelcontextprotocol/server-filesystem", "/Users/leonard/Workspace/code/personal/second-brain"]
    }
    // ...your other servers stay here...
  }
}
```

Tip: back up first — `cp claude_desktop_config.json claude_desktop_config.json.bak`.

## 2. Restart & verify
Quit Claude Desktop completely (⌘Q), reopen it. Look for the tools (🔨) indicator — you should
see `second-brain` with filesystem tools (read / write / list).

## 3. Prime the rules (important — Desktop ≠ Claude Code)
Claude **Code** auto-loads the skill (`SKILL.md → AGENTS.md`) when you `cd` into the vault.
Claude **Desktop** only gets raw filesystem access — it does **not** know the operating rules
until you point it at them. Two options:

**Quick (per chat):** paste at the start of a new conversation:
```
Read index.md then AGENTS.md in the second-brain folder, and follow those rules
for the rest of this conversation.
```

**Durable (recommended):** create a Claude Desktop **Project** named "Second Brain" with these
custom instructions, so every chat in it follows the rules automatically:
```
You operate my second brain at /Users/leonard/Workspace/code/personal/second-brain.
At the start, read index.md, CRITICAL_FACTS.md, then AGENTS.md, and strictly follow
AGENTS.md for all capture / query / compile / lint / lifecycle actions.
```

## What works where
- **Capture & query** work great in Desktop (write to `raw/`, read & cite from `wiki/`).
- **Heavy compile / lint** (running `scripts/*.sh`) is better in Claude Code — the MCP
  filesystem server reads/writes files but does not execute scripts.

## Troubleshooting
- Server not showing up: confirm `node`/`npx` are installed and the vault path in the config is correct; check Desktop's MCP logs.
- Restore a backup: `cp claude_desktop_config.json.bak claude_desktop_config.json` then restart.
