# Enable Claude Desktop to read/write the vault via MCP filesystem

1. Open the Claude Desktop config file:
   - macOS: `~/Library/Application Support/Claude/claude_desktop_config.json`
2. Merge the contents of `claude_desktop_config.snippet.json` (combine the `mcpServers` key).
3. Restart Claude Desktop.
4. In chat, ask Claude to read `index.md` then `AGENTS.md` before doing anything.

Note: the `@modelcontextprotocol/server-filesystem` server allows reading & WRITING within
the vault directory — this is what lets Desktop capture/compile just like Claude Code.
Requires Node.js (npx) on the machine.
