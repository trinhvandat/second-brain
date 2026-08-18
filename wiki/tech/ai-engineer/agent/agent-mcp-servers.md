---
status: current
updated: 2026-08
sources:
  - https://modelcontextprotocol.io/specification/2025-06-18
  - https://modelcontextprotocol.io/specification/2025-06-18/architecture
  - https://modelcontextprotocol.io/docs/learn/architecture
  - https://modelcontextprotocol.io/docs/concepts/transports
  - https://www.anthropic.com/news/model-context-protocol
  - https://blog.modelcontextprotocol.io/posts/2026-07-28/
  - https://code.claude.com/docs/en/mcp
  - https://code.claude.com/docs/en/agent-sdk/mcp
  - https://github.com/modelcontextprotocol/servers
  - https://github.com/punkpeye/awesome-mcp-servers
roadmap: ai-engineer
stage: learning
---

# MCP Servers — tiến trình expose tools/resources/prompts cho MCP client qua protocol

**TL;DR**:
- **MCP Server** là một chương trình nhỏ, chỉ phụ trách **một** external system duy nhất (ví dụ: một server GitHub, một server Postgres, một server filesystem).
- Nó tồn tại để "dạy" cho AI app biết cách thao tác với hệ thống đó, qua 3 việc: liệt kê + gọi **tool**, đọc **resource**, lấy **prompt** template.
- Server có thể chạy **local** (subprocess, qua **STDIO** — cách truyền message qua stdin/stdout của một process con) hoặc **remote** (long-running, qua **Streamable HTTP**) — điều cần nhớ nhất: Server luôn là bên **implement thật** logic, còn [[agent-mcp-client]] chỉ là kết nối 1:1 rỗng tới nó.
- **Nếu bạn mới bắt đầu và chỉ cần biết "làm sao thêm một server":** đọc TL;DR này → nhảy thẳng xuống [mục 5 (ví dụ config)](#5-ví-dụ-cụ-thể-một-server-cho-một-external-system) → [Áp dụng với Claude Code](#áp-dụng-với-claude-code). Mục 1 và 3 là lý thuyết về cách protocol vận hành bên trong — không cần đọc để dùng server, chỉ cần khi bạn muốn *build* một server hoặc hiểu sâu cơ chế.

## 1. Server nằm ở đâu trong kiến trúc MCP (nền tảng lý thuyết — có thể bỏ qua nếu chỉ cần biết cách dùng)

- MCP dùng kiến trúc **client-host-server**: [[agent-mcp-hosts]] chứa nhiều [[agent-mcp-client]], mỗi client giữ kết nối **1:1** tới đúng một Server.
- Server **không biết Host là ai** — nó chỉ nói chuyện với Client qua giao thức chuẩn **JSON-RPC 2.0** (định dạng message dạng `{method, params, id}` gửi qua lại giữa hai bên — hiểu đơn giản là "ngôn ngữ chung" để Client gọi Server và nhận kết quả), không quan tâm ứng dụng nào đang dùng client đó.
- Nguyên tắc thiết kế chính thức: Server **"nên cực dễ build"** và **"nên composable cao"** — mỗi server làm đúng một việc, độc lập, và nhiều server có thể ghép lại tự do trong cùng một Host. Đây là lý do hệ sinh thái MCP hình thành theo pattern "một server cho một external system" (GitHub server, Postgres server, Slack server...) thay vì một server "vạn năng".
- MCP lấy cảm hứng thiết kế từ **Language Server Protocol (LSP)** — LSP chuẩn hoá cách IDE tích hợp ngôn ngữ lập trình, MCP chuẩn hoá cách AI app tích hợp context/tool theo cùng tinh thần.

## 2. Server làm gì: 3 primitive expose ra ngoài

Hiểu nhanh bằng loại tương đương trong lập trình bình thường:
- **Tool** ≈ một **function** bạn cho phép AI gọi (đọc file, gọi API, ghi DB...).
- **Resource** ≈ một **file chỉ-đọc** AI có thể nạp vào context (không thực thi gì, chỉ lấy dữ liệu).
- **Prompt** ≈ một **template câu lệnh** dựng sẵn, tái dùng được (system prompt mẫu, few-shot mẫu).

Server công bố tối đa 3 loại capability cho client, mỗi loại có method discovery/call riêng:

| Primitive | Là gì | Method điển hình |
|---|---|---|
| **Tools** | Hàm thực thi được — model quyết định gọi để hành động (đọc file, gọi API, query DB) | `tools/list`, `tools/call` |
| **Resources** | Dữ liệu/context để đọc (nội dung file, bản ghi DB) — không thực thi | `resources/list`, `resources/read` |
| **Prompts** | Template tương tác tái sử dụng (system prompt, few-shot mẫu) | `prompts/list`, `prompts/get` |

Xem thêm khái niệm tool nói chung ở [[agent-what-are-tools]].

## 3. Vòng đời một kết nối: capability negotiation (nâng cao — có thể bỏ qua ở lần đọc đầu)

- Khi Client kết nối, hai bên **khai báo capability** trước khi giao tiếp thật (server hỗ trợ subscribe resource không, tool nào có, prompt nào có...) — cả hai phải tôn trọng đúng những gì đã khai báo trong suốt session.
- Sau khi connect, Host/Client thường gọi ngay `tools/list`, `resources/list`, `prompts/list` để nạp danh sách capability; server có thể gửi notification `list_changed` để báo cập nhật động (thêm/bớt tool) mà không cần reconnect toàn bộ.
- Một bản spec mới hơn (2026-07-28) đang đổi cách khai báo này theo hướng stateless — chi tiết và mức độ tin cậy của thông tin này được gom ở [Giới hạn / open questions](#giới-hạn--open-questions) cuối note; với người dùng Claude Code hiện tại thì **không cần đổi gì** trong config để tương thích.

## 4. Local vs Remote: hai kiểu triển khai

| | Local (STDIO) | Remote (Streamable HTTP) |
|---|---|---|
| Cách chạy | Subprocess do client spawn | Tiến trình long-running độc lập |
| Giao tiếp | Newline-delimited message qua stdin/stdout của process | HTTP POST tới một endpoint; reply là JSON object hoặc SSE stream theo từng request |
| Phục vụ bao nhiêu client | Thường 1 (pipe riêng cho từng subprocess) | Có thể nhiều client cùng lúc |
| Ví dụ chính thức | Claude Desktop tự spawn **filesystem server** local | **Sentry MCP server** chạy trên hạ tầng của Sentry |
| Auth | Không cần — cùng máy, cùng user | Thường cần OAuth/bearer token |

- Semantics của protocol (primitive, message format JSON-RPC) **giống hệt nhau** ở cả hai transport — chỉ khác cách message được truyền đi; custom transport khác cũng được phép miễn tuân thủ semantics này.
- Rule-of-thumb thực dụng: dùng STDIO khi người dùng AI client cũng chính là người kiểm soát máy chạy server (local dev); dùng Streamable HTTP khi server chạy production / phục vụ nhiều remote client.<sup>[1]</sup>

## 5. Ví dụ cụ thể: "một server cho một external system"

Anthropic công bố MCP ngày 25/11/2024 kèm sẵn một loạt server tham chiếu, mỗi cái phụ trách đúng một hệ thống ngoài:

- **Google Drive** — đọc file/tài liệu.
- **Slack** — đọc/gửi message theo channel.
- **GitHub** / **Git** — issue, PR, commit history.
- **Postgres** — query, inspect schema (thường read-only).
- **Puppeteer** — điều khiển browser.

Repo tham chiếu `github.com/modelcontextprotocol/servers` còn có thêm Filesystem, Fetch, Memory, Sequential Thinking, Time — mỗi thư mục là một server riêng, độc lập, đúng pattern "một server, một trách nhiệm". Lưu ý: nhiều server "official" ban đầu (GitHub, Slack, PostgreSQL, Sentry...) sau đó đã được archive/thay bằng bản do chính vendor maintain hoặc fork cộng đồng — nên coi đây là snapshot lịch sử, không phải danh sách canonical cố định.<sup>[2]</sup>

**Ví dụ cụ thể một tình huống thực tế:** sếp giao "cho Claude đọc dữ liệu từ Postgres" — việc cần làm chỉ là thêm entry `postgres` như JSON bên dưới vào file config, xong, không cần hiểu JSON-RPC hay capability negotiation ở mục 1/3.

Ví dụ config một server GitHub remote (transport HTTP) và một server Postgres local (transport stdio) cùng tồn tại trong một Host:

```json
{
  "mcpServers": {
    "github": {
      "type": "http",
      "url": "https://api.githubcopilot.com/mcp/"
    },
    "postgres": {
      "command": "npx",
      "args": ["-y", "@bytebase/dbhub"]
    }
  }
}
```

Hai server này hoàn toàn độc lập: Host tạo hai Client riêng, mỗi Client giữ một kết nối, và tool của chúng được **namespace** riêng — tức tên tool được gắn thêm tiền tố tên server để không trùng nhau khi nhiều server cùng hoạt động (`mcp__github__*` vs `mcp__postgres__*` — xem [[agent-mcp-hosts]] phần namespacing).

## 6. Server khác Client như thế nào

| | Client | Server |
|---|---|---|
| Sống ở đâu | Bên trong Host | Tiến trình độc lập, tách biệt Host |
| Vai trò | Giữ kết nối 1:1, forward request/response | Implement thật logic tool/resource/prompt |
| Ai maintain | Do Host framework build sẵn (theo SDK MCP) | Thường build/maintain độc lập bởi bên thứ ba/vendor của external system |
| Biết gì về nhau | Chỉ biết đúng 1 server đang nói chuyện | Không biết Host là ai, không biết có bao nhiêu client khác |
| Số lượng trong 1 phiên | N (1 cho mỗi server đã kết nối) | N (độc lập với Host, có thể tái dùng ở nhiều Host khác nhau) |

## Liên hệ tới các phần khác

- [[agent-mcp-overview]] — bức tranh tổng: MCP giải quyết bài toán M×N bằng cách để mỗi tool chỉ cần một Server, mỗi AI app chỉ cần một Client.
- [[agent-mcp-hosts]] — nơi mô tả chi tiết cách Host tạo/quản lý nhiều Client, mỗi Client trỏ tới một Server như note này mô tả.
- [[agent-mcp-client]] — vai trò đối xứng của Server, sống bên trong Host, giữ kết nối 1:1.
- [[agent-what-are-tools]] — khái niệm tool nói chung mà primitive "Tools" của Server implement cụ thể.

### Áp dụng với Claude Code

- Claude Code (Host) hỗ trợ đăng ký server qua `claude mcp add` với transport tường minh: `--transport stdio`, `--transport http`, `--transport sse` (deprecated), và `type: "ws"` (WebSocket, cho server cần chủ động đẩy event) — khớp với 2 transport chuẩn (STDIO/Streamable HTTP) ở trên, cộng thêm 2 transport mở rộng riêng của Claude Code.
- Với server **local (stdio)**: Claude Code tự spawn subprocess, set biến môi trường `CLAUDE_PROJECT_DIR`; nếu server crash giữa session, Claude Code **không tự reconnect** (khác với server HTTP/SSE, có exponential backoff tới 5 lần thử lại).
- Với server **remote (HTTP/SSE)**: Claude Code có thể cache sẵn danh sách tool (`cached X ago · connects on first use`) và chỉ thật sự mở kết nối khi tool được gọi lần đầu — khớp với ý "server remote long-running, phục vụ nhiều client" vì Claude Code không cần giữ kết nối idle liên tục.
- Sau khi connect thành công, Claude Code gọi `tools/list`, `prompts/list`, `resources/list` để nạp capability, và hỗ trợ notification `list_changed` để server cập nhật động mà không cần reconnect toàn bộ.
- Mỗi server được đặt trong namespace riêng: tool hiển thị dưới dạng `mcp__<server-name>__<tool-name>` (hoặc `mcp__plugin_<plugin-name>_<server-name>__<tool-name>` nếu server đến từ plugin) — vận hành đúng pattern "một server, một trách nhiệm" mà không sợ đụng tên khi nhiều server cùng hoạt động.
- Server config có 3 scope cài đặt: **local** (`~/.claude.json`, riêng project hiện tại), **project** (`.mcp.json`, chia sẻ qua git), **user** (áp dụng mọi project) — cộng thêm server tới từ plugin hoặc claude.ai-connector, có thứ tự ưu tiên xác định khi trùng tên.
- **Claude Agent SDK** thêm một loại thứ ba không nằm trong split Host/Client/Server cổ điển: **"SDK MCP server"** (tạo qua `createSdkMcpServer`) chạy **in-process** trong chính ứng dụng SDK, tool là hàm code trực tiếp thay vì process/service tách biệt. Loại này không tốn thời gian chờ kết nối ở turn đầu (khác stdio — chờ subprocess start, timeout mặc định ~30s; hoặc HTTP/SSE chưa cache tool list — cũng chờ connect), nhưng vẫn đi qua đúng cơ chế đặt tên tool, permission (`allowedTools`), và tool-search như server ngoài thật — từ góc nhìn model, không phân biệt được đây là server in-process hay server thật.
- OAuth cho remote server: Claude Code (CLI) tự chạy flow OAuth qua browser (`/mcp` hoặc `claude mcp login <name>`), còn Claude Agent SDK thì **không** — nếu server cần OAuth và chưa có token cache sẵn, session tiếp tục chạy nhưng thiếu tool của server đó (trạng thái `needs-auth`), buộc ứng dụng gọi SDK phải tự hoàn tất OAuth bên ngoài rồi inject bearer token qua field `headers`.
- Plugin cho Claude Code có thể đóng gói sẵn MCP server riêng (khai báo trong `.mcp.json` ở root plugin hoặc inline trong `plugin.json`), tự start/stop theo enable/disable plugin — minh hoạ pattern "một server cho một external system, maintain độc lập" được đóng gói thành unit cài đặt được, thay vì cấu hình tay từng server.

## Giới hạn / open questions

- "SDK MCP server" chạy in-process làm mờ ranh giới Server độc lập theo định nghĩa gốc — chưa có nguồn so sánh sâu tradeoff bảo mật/latency giữa in-process server và server ngoài thật (stdio/HTTP).
- Chưa đào sâu cơ chế bảo mật cụ thể cho remote server (scope OAuth, refresh/revoke token, rate limiting phía server) — chỉ mới điểm qua ở mức "khuyến nghị dùng OAuth".
- **Bản spec 2026-07-28** (đổi capability negotiation sang stateless, thêm request `server/discover` bắt buộc — xem mục 3): đây là cập nhật, không phủ định framing "khai báo lúc connect" của spec cũ, nhưng chưa rõ các SDK/Host phổ biến (Claude Code, VS Code, Cursor...) đã áp dụng đầy đủ tới đâu tại thời điểm viết note này (as of blog.modelcontextprotocol.io/posts/2026-07-28, confidence: medium).

### Ghi chú độ tin cậy (confidence notes)

Gom các trích dẫn nội dung để không ngắt mạch đọc ở phần thân bài:

1. Rule-of-thumb "STDIO cho local dev, HTTP cho production" (mục 4) chỉ dựa trên một bài blog cộng đồng, chưa có khuyến nghị chính thức tương đương từ spec (as of dev.to/jefe_cool, confidence: low).
2. Danh sách server "official" (GitHub, Slack, Postgres, Sentry...) trong repo tham chiếu ban đầu của Anthropic (mục 5) đã phần lớn bị archive/thay thế — chưa có bảng đối chiếu đầy đủ server nào còn được maintain chính thức, server nào chỉ còn là snapshot lịch sử (as of tembo.io/blog/best-mcp-servers, confidence: low).
