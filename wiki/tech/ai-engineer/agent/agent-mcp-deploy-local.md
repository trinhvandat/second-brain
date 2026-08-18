---
status: current
updated: 2026-08
sources:
  - https://modelcontextprotocol.io/docs/2026-07-28/learn/architecture
  - https://modelcontextprotocol.io/specification/2025-03-26/basic/transports
  - https://modelcontextprotocol.io/docs/develop/connect-local-servers
  - https://www.anthropic.com/news/model-context-protocol
  - https://code.claude.com/docs/en/agent-sdk/mcp
  - https://code.claude.com/docs/en/mcp-quickstart
roadmap: ai-engineer
stage: learning
---

# MCP deployment modes — Local Desktop: server chạy ngay trên máy của bạn qua STDIO

**TL;DR**: Ở chế độ **Local Desktop**, **MCP server** chạy như một **subprocess** do **Host** (Claude Desktop, Claude Code) spawn ra ngay trên máy local, giao tiếp qua **STDIO** (stdin/stdout) — đây là chế độ mặc định, đơn giản nhất, không cần mạng hay auth vì Host và Server là hai process cùng chạy dưới cùng một user, ngầm định tin tưởng lẫn nhau.

## 1. Cơ chế hoạt động (STDIO transport)

- **Host** (ví dụ Claude Desktop, Claude Code) launch **MCP server** như một **subprocess con** trên chính máy của user.
- Giao tiếp qua **JSON-RPC** trên **stdin/stdout**: client ghi message vào stdin của server, server đọc và trả kết quả qua stdout.
- Ràng buộc kỹ thuật (theo spec): message phải **newline-delimited**, không được chứa newline nhúng bên trong; server **không được** ghi bất cứ gì ra stdout ngoài MCP message hợp lệ (log thì đẩy sang **stderr** để không làm hỏng luồng JSON-RPC) (as of modelcontextprotocol.io/specification/2025-03-26/basic/transports, confidence: high).
- Vòng đời: client đóng stdin và terminate subprocess → server dừng theo, không có cơ chế nào để server tồn tại độc lập với Host.
- STDIO là 1 trong 2 transport chuẩn của MCP (transport còn lại là **Streamable HTTP**, dùng cho remote); client "SHOULD support stdio whenever possible" theo spec.

## 2. Vì sao không cần auth

- Host và Server là hai process **local, cùng một user account** — MCP coi đây là quan hệ tin tưởng ngầm định (implicit trust), không có lớp authentication/authorization nào ở tầng transport.
- Tài liệu chính thức cảnh báo thẳng: **server chạy với quyền của user hiện tại**, nên nó có thể thực hiện bất kỳ file operation nào mà user có thể làm thủ công (as of modelcontextprotocol.io/docs/develop/connect-local-servers, confidence: high) — nói cách khác, "an toàn" ở đây là an toàn theo nghĩa *không lộ ra mạng*, chứ không phải server bị giới hạn quyền.
- So sánh: **Streamable HTTP** (remote) bắt buộc xử lý Origin validation, localhost binding, OAuth/bearer token... vì server chạy ngoài máy, đa người dùng, có network exposure thật sự.

## 3. Ví dụ thực tế

- **Filesystem server**: Claude Desktop chạy `@modelcontextprotocol/server-filesystem` qua `npx` như subprocess STDIO, giới hạn quyền truy cập theo path truyền vào CLI args.
- **Local Postgres qua DBHub**: `npx -y @bytebase/dbhub --config dbhub.toml` — một server STDIO khác, khớp đúng ví dụ "local Postgres server" trong Claude Code.
- Cấu hình trong Claude Desktop nằm ở `~/Library/Application Support/Claude/claude_desktop_config.json` (macOS), mỗi entry là `{command, args, env}`.
- Claude Code CLI: `claude mcp add <name> -- <command> <args>` — nếu không truyền `--transport`, mặc định là **stdio**, vì đây là chuẩn cho server local/cùng máy (as of code.claude.com/docs/en/mcp-quickstart, confidence: high).

| Thuộc tính | Local Desktop (STDIO) | Remote (Streamable HTTP) |
|---|---|---|
| Nơi chạy | Subprocess trên máy user | Server độc lập, hosted trên cloud |
| Auth | Không cần (cùng user, ngầm tin tưởng) | Bắt buộc (OAuth, bearer token...) |
| Số user phục vụ | 1 (mỗi user tự chạy bản riêng) | Nhiều user cùng lúc |
| Vòng đời | Gắn với Host process, tắt Host là tắt server | Độc lập, chạy liên tục |
| Ví dụ | filesystem server, local Postgres qua DBHub | Sentry MCP server |

## 4. Tradeoffs so với Remote

- **Single-user only**: mỗi người dùng phải tự chạy bản server riêng của mình, không share được instance.
- **Không persistent**: server chết theo Host process — tắt Claude Desktop/Claude Code là server biến mất, phải khởi động lại session mới có server (trừ khi tự externalize state ra disk).
- **Giới hạn bởi máy local**: server chỉ truy cập được những gì máy local truy cập được (file, DB local, network mà máy đó reach tới) — không tận dụng được tài nguyên/compute của cloud.
- Bù lại: đây là **con đường nhanh nhất** để chạy MCP server, và là **mặc định an toàn nhất** cho bất cứ thứ gì đụng tới tài nguyên nhạy cảm local (filesystem, DB dev local) vì không expose port ra ngoài.

## 5. Liên hệ tới các phần khác

- Xem thêm kiến trúc tổng quan tại [[agent-mcp-overview]], vai trò client tại [[agent-mcp-client]], và cách xây server tại [[agent-mcp-servers]].
- So sánh với chế độ triển khai khác: MCP deployment modes — Remote / Cloud (server hosted, đa user, cần auth) là mặt đối lập trực tiếp của Local Desktop.

### Áp dụng với Claude Code

- Claude Code hỗ trợ đầy đủ Local Desktop mode: `claude mcp add <name> -- <command> <args>` spawn server STDIO subprocess, mặc định không cần chỉ định `--transport`.
- Config được lưu ở 3 scope: **local** (`~/.claude.json`, per-project, private, mặc định), **project** (`.mcp.json` ở repo root, share qua git với team), **user** (`~/.claude.json` top-level, private, mọi project). Lưu ý: scope "project" chỉ share **config**, mỗi teammate vẫn tự spawn subprocess riêng của mình — vẫn giữ tính chất single-user của STDIO.
- Claude Code thêm một lớp **consent gate** không có trong spec MCP gốc: lần đầu chạy server STDIO khai báo trong `.mcp.json` (project scope), Claude Code bắt buộc user approve thủ công — mục đích để một repo clone về không thể tự ý spawn process trên máy bạn mà không xin phép.
- Ngoài ra, mọi tool call từ MCP server (kể cả STDIO) đều đi qua **permission system** riêng của Claude Code (`mcp__<server>__<tool>`), có thể prompt approve từng lần hoặc pre-approve qua `allowedTools` — một lớp trust bổ sung nằm trên cả lớp OS-level process trust mà MCP spec giả định.
- Trong Agent SDK, server STDIO chỉ là 1 trong 3 kiểu MCP server hỗ trợ (STDIO subprocess, HTTP/SSE remote, in-process "SDK MCP server" chạy ngay trong code, không spawn process riêng). Với STDIO, SDK delay lượt turn đầu tiên tới khi subprocess connect xong (mặc định 30s qua `MCP_TIMEOUT`).

## 6. Giới hạn / open questions

- Chưa rõ hành vi chính xác khi nhiều Claude Code session cùng lúc chạy chung một server STDIO trỏ tới cùng resource (ví dụ cùng file DB local) — có race condition gì không, MCP spec không nói rõ phần này.
- Nguồn gốc bài viết seed (blog.stackademic.com/build-simple-local-mcp-server) trả về HTTP 403 khi fetch, chưa verify được nội dung cụ thể — các claim liên quan tới nguồn này (nếu có) nên coi là chưa xác thực.
- Chưa đào sâu: cách một MCP server STDIO có thể externalize state ra disk để "giả lập" persistence qua các session Host restart — đây chỉ là suy luận kiến trúc, chưa có tài liệu chính thức mô tả pattern này.
