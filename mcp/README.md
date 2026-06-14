# Bật Claude Desktop đọc/ghi vault qua MCP filesystem

1. Mở file cấu hình Claude Desktop:
   - macOS: `~/Library/Application Support/Claude/claude_desktop_config.json`
2. Merge nội dung `claude_desktop_config.snippet.json` vào (gộp khoá `mcpServers`).
3. Khởi động lại Claude Desktop.
4. Trong chat, yêu cầu Claude đọc `index.md` rồi `AGENTS.md` trước khi thao tác.

Lưu ý: server `@modelcontextprotocol/server-filesystem` cho phép đọc & GHI trong
đúng thư mục vault — đây là điều kiện để Desktop capture/compile được như Claude Code.
Cần có Node.js (npx) trên máy.
