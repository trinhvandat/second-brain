# Install: Second Brain in Claude Desktop

A complete, from-zero walkthrough to use this vault from the Claude Desktop app via the MCP
filesystem server. ~5 minutes. After this, you can capture and query your brain directly in
Desktop chat, alongside Claude Code.

> How it differs from Claude Code: Claude **Code** auto-loads the vault's skill (`SKILL.md → AGENTS.md`)
> when you `cd` in. Claude **Desktop** only gets raw file read/write — so you must point it at the
> rules once (Step 5).

## Prerequisites

- **Claude Desktop** installed (macOS or Windows).
- **Node.js 18+** — the MCP server runs via `npx`. Check: `node --version`. Install from <https://nodejs.org> if missing.
- The vault on disk. If you don't have it yet:
  ```bash
  git clone <your-remote> ~/Workspace/code/personal/second-brain
  cd ~/Workspace/code/personal/second-brain && chmod +x scripts/*.sh
  ```
  Note your vault's **absolute path** — you'll need it in Step 3.

---

## Step 1 — Locate the Claude Desktop config file

- **macOS:** `~/Library/Application Support/Claude/claude_desktop_config.json`
- **Windows:** `%APPDATA%\Claude\claude_desktop_config.json`

If the file doesn't exist yet, create it with `{}` as its contents.

**Back it up first** (it may already hold other MCP servers / API keys):
```bash
cp "$HOME/Library/Application Support/Claude/claude_desktop_config.json" \
   "$HOME/Library/Application Support/Claude/claude_desktop_config.json.bak"
```

## Step 2 — Add the second-brain MCP server

Merge the `second-brain` entry into the `mcpServers` object. **Preserve any servers already
there — add a key, never overwrite the whole file.** Use your vault's absolute path as the last arg.

```json
{
  "mcpServers": {
    "second-brain": {
      "command": "npx",
      "args": ["-y", "@modelcontextprotocol/server-filesystem", "/Users/leonard/Workspace/code/personal/second-brain"]
    }
    // ← keep your other servers here
  }
}
```

The ready snippet is in [`../mcp/claude_desktop_config.snippet.json`](../mcp/claude_desktop_config.snippet.json).

**Checkpoint:** the file must be valid JSON. Verify:
```bash
python3 -c "import json,os;json.load(open(os.path.expanduser('~/Library/Application Support/Claude/claude_desktop_config.json')));print('valid JSON')"
```

## Step 3 — Restart & verify

Quit Claude Desktop **completely** (⌘Q on macOS — not just closing the window), then reopen it.
Look for the tools indicator (🔨) in the chat box — you should see **`second-brain`** with
filesystem tools (read / write / list / search).

## Step 4 — Prime the rules (required)

Desktop has file access now but doesn't know the operating rules yet. Pick one:

**Quick (per chat)** — paste at the start of a new conversation:
```
Read index.md then AGENTS.md in the second-brain folder, and follow those rules
for the rest of this conversation.
```

**Durable (recommended)** — create a Claude Desktop **Project** named "Second Brain" with these
custom instructions, so every chat in it follows the rules automatically:
```
You operate my second brain at /Users/leonard/Workspace/code/personal/second-brain.
At the start, read index.md, CRITICAL_FACTS.md, then AGENTS.md, and strictly follow
AGENTS.md for all capture / query / compile / lint / lifecycle actions.
```

## Step 5 — First-use test

In a Desktop chat (inside the Project, or after pasting the primer):
```
note this: testing the vault from Claude Desktop
```
→ Claude writes a file into `raw/inbox/` via MCP. Then:
```
ask the brain: what is the LLM Wiki pattern?
```
→ It answers from the vault with a `[[llm-wiki]]` citation. Ask something not in the vault and it
replies `Not in the second brain.`

## What works where

- **Capture & query** work great in Desktop (write to `raw/`, read & cite from `wiki/`).
- **Heavy compile / lint** (running `scripts/*.sh`) is better in **Claude Code** — the MCP
  filesystem server reads/writes files but does not execute shell scripts.

## Troubleshooting

- **`second-brain` not in the 🔨 list:** confirm `node`/`npx` are installed and the vault path in
  the config is correct and absolute; fully quit & reopen Desktop; check Desktop's MCP logs.
- **JSON error / Desktop ignores config:** re-validate (Step 2 checkpoint); a stray comma or the
  `//` comment above will break strict JSON — remove comments in the real file.
- **Restore the backup:**
  ```bash
  cp "$HOME/Library/Application Support/Claude/claude_desktop_config.json.bak" \
     "$HOME/Library/Application Support/Claude/claude_desktop_config.json"
  ```
