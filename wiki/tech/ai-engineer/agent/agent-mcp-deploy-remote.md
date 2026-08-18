---
status: current
updated: 2026-08
sources:
  - https://modelcontextprotocol.io/specification/2025-03-26/basic/transports
  - https://modelcontextprotocol.io/specification/draft/basic/transports/streamable-http
  - https://modelcontextprotocol.io/specification/draft/basic/authorization
  - https://modelcontextprotocol.io/docs/2026-07-28/tutorials/security/authorization
  - https://blog.modelcontextprotocol.io/posts/2025-12-19-mcp-transport-future/
  - https://blog.modelcontextprotocol.io/posts/2026-mcp-roadmap/
  - https://www.descope.com/blog/post/mcp-auth-spec
  - https://aembit.io/blog/mcp-oauth-2-1-pkce-and-the-future-of-ai-authorization/
  - https://www.anthropic.com/news/model-context-protocol
  - https://en.wikipedia.org/wiki/Model_Context_Protocol
  - https://blog.christianposta.com/the-updated-mcp-oauth-spec-is-a-mess/
  - https://blog.cloudflare.com/mcp-demo-day/
  - https://github.com/getsentry/sentry-mcp
  - https://github.com/iannuttall/mcp-boilerplate
  - https://docs.bswen.com/blog/2026-08-04-mcp-v2-stateless-no-sticky-sessions/
  - https://www.solo.io/blog/mcp-stateless-spec-changes-the-engineering-details
  - https://community.atlassian.com/forums/Atlassian-Remote-MCP-Server/HTTP-SSE-Deprecation-Notice/ba-p/3205484
  - https://code.claude.com/docs/en/mcp
  - https://platform.claude.com/docs/en/agents-and-tools/mcp-connector
  - https://www.truefoundry.com/blog/mcp-vs-rag
  - https://www.contentful.com/blog/mcp-vs-rag/
  - https://www.merge.dev/blog/rag-vs-mcp
roadmap: ai-engineer
stage: learning
---

# MCP deployment modes — Remote / Cloud — server chạy trên cloud, phục vụ nhiều người dùng qua Streamable HTTP

TL;DR: Ở chế độ Remote/Cloud, **MCP server** không còn được spawn cục bộ theo từng người dùng mà chạy như một tiến trình long-running trên cloud, giao tiếp qua **Streamable HTTP**; đổi lại việc chia sẻ một server cho nhiều **Host/Client**, đội deploy phải tự giải quyết các bài toán production thực sự: xác thực (**OAuth 2.1**), TLS, rate limiting, và scaling/session management.

## Bảng thuật ngữ nhanh (cho người mới)

- **STDIO**: kênh giao tiếp qua standard input/output của tiến trình — cách chế độ local ([[agent-mcp-deploy-local]]) truyền message, chỉ hoạt động khi client và server chạy chung máy.
- **Streamable HTTP**: transport (giao thức truyền tải) qua HTTP thường, dùng cho remote server — client và server có thể ở hai máy khác nhau, giao tiếp qua network.
- **Host/Client**: "Host" là ứng dụng người dùng thấy (Claude Code, Claude Desktop...); "Client" là phần trong Host quản lý 1 kết nối MCP tới 1 server cụ thể.
- **JSON-RPC**: định dạng message dạng JSON mà MCP dùng để gọi hàm từ xa (request có `method`/`params`, response có `result`/`error`) — là "ngôn ngữ" bên trong mọi transport (STDIO lẫn HTTP).
- **OAuth 2.1**: chuẩn xác thực phổ biến trên web, cho phép user cấp quyền cho 1 ứng dụng (client) truy cập tài nguyên mà không cần đưa mật khẩu trực tiếp — ở đây dùng để server MCP xác minh ai đang gọi mình.
- **PKCE** (Proof Key for Code Exchange): một bước bảo mật thêm vào OAuth, sinh ra 1 secret ngẫu nhiên ở phía client cho mỗi lần đăng nhập để chống kẻ tấn công đánh cắp "authorization code" giữa chừng — bắt buộc với client không giữ được secret an toàn (ví dụ app CLI/desktop).
- **DNS rebinding**: một kiểu tấn công web, kẻ tấn công đổi DNS để trình duyệt nạn nhân "tưởng" đang gọi domain hợp lệ nhưng thực chất request lại đi tới server nội bộ (localhost/mạng LAN) — validate header `Origin` giúp server phát hiện và chặn request giả mạo kiểu này.

## Vì sao cần chế độ Remote/Cloud

- **Multi-user access**: nhiều Host/Client (Claude Code, Claude Desktop, agent khác...) cùng kết nối vào một server instance duy nhất, thay vì mỗi người tự chạy server riêng.
- **Centralized maintenance**: sửa bug/nâng cấp một lần trên server, tất cả người dùng nhận bản vá ngay — không cần mỗi máy tự cập nhật.
- **Truy cập tài nguyên chỉ reachable từ cloud**: hệ thống nội bộ công ty, database dùng chung, API nội mạng — những thứ máy cá nhân của user không với tới được nhưng server cloud thì có.
- So sánh với [[agent-mcp-deploy-local]] (server spawn cục bộ qua **STDIO**): local đơn giản, không cần auth/TLS vì chỉ có 1 user + 1 process, nhưng không chia sẻ được và không tiếp cận được tài nguyên nội bộ của tổ chức.

## Transport: Streamable HTTP thay thế HTTP+SSE

- Vấn đề transport cũ (HTTP+SSE) gặp phải: cần 2 kết nối riêng (1 để server đẩy sự kiện, 1 để client gửi lệnh), khó chuẩn hoá và khó đặt sau load balancer/proxy thông thường. Spec **2025-03-26** giới thiệu **Streamable HTTP** để giải quyết việc này, thay thế transport **HTTP+SSE** cũ (spec 2024-11-05) — spec ghi rõ: "This replaces the HTTP+SSE transport from protocol version 2024-11-05" (as of modelcontextprotocol.io/specification/2025-03-26, confidence: high).
- Cơ chế cũ (HTTP+SSE): 2 endpoint riêng — client GET để mở SSE stream, server push một sự kiện `endpoint` rồi client mới POST được. Cơ chế mới (Streamable HTTP): **1 endpoint MCP HTTP duy nhất** nhận cả POST và GET, server có thể trả JSON thường hoặc nâng cấp lên SSE stream khi cần.
- Nhờ vậy server hoạt động như "một tiến trình độc lập xử lý nhiều kết nối client" — đúng bản chất "long-running process" thay vì bị spawn theo từng user như chế độ local.
- Trong thực tế, các vendor lớn đã migrate: Atlassian Rovo MCP server công khai deprecate HTTP+SSE để chuyển hẳn sang Streamable HTTP.
- Bản spec 2026-07-28 gần đây còn bỏ luôn GET-stream endpoint và session ở tầng protocol, yêu cầu header `MCP-Protocol-Version` trên mọi POST — hướng tới stateless hoàn toàn để dễ scale ngang.

## Session management & horizontal scaling

- Ban đầu, Streamable HTTP dùng handshake `initialize` trả về `Mcp-Session-Id`, ghim client vào đúng 1 server instance — nếu đặt sau load balancer thì request thứ 2 có thể rơi vào pod khác và bị lỗi `400 Session Not Found` (as of docs.bswen.com, confidence: medium).
- Đây chính là lý do "session management" trở thành một mối lo riêng của chế độ remote: 1 tiến trình server giờ phục vụ nhiều client đồng thời, không thể giả định 1 request luôn đi tới cùng 1 instance như khi chạy local.
- Bản sửa gần đây (2026-07-28) làm Streamable HTTP **stateless ở tầng core** (bỏ session ID/handshake protocol-level) để bất kỳ request nào cũng có thể rơi vào bất kỳ instance nào; state bền vững (nếu cần) phải đẩy ra store dùng chung như Redis/DB thay vì giữ trên 1 instance cụ thể.

## Authentication: OAuth 2.1

- MCP khuyến nghị **OAuth 2.1** làm cơ chế xác thực chuẩn cho remote server — server đóng vai trò OAuth resource server, có authorization server riêng cấp token.
- Spec yêu cầu một loạt cơ chế con, mỗi cái giải quyết 1 vấn đề cụ thể:
  - **PKCE**: bắt buộc vì client MCP thường là "public client" (CLI/desktop app) không lưu được client secret an toàn — xem giải thích ở [Bảng thuật ngữ nhanh](#bảng-thuật-ngữ-nhanh-cho-người-mới) phía trên.
  - **Authorization Server Metadata (RFC 8414)**: 1 endpoint chuẩn để client tự động dò ra nơi cấp token (authorization server) thay vì phải hard-code URL.
  - **Protected Resource Metadata**: tương tự nhưng ở phía server MCP — cho client biết server này thuộc authorization server nào.
  - **Resource Indicators**: cho phép client chỉ định rõ token đang xin cấp là để gọi server MCP nào, tránh 1 token bị dùng nhầm sang service khác.
  - **Dynamic Client Registration (RFC 7591)** (khuyến nghị, không bắt buộc): cho phép client tự đăng ký với authorization server lúc runtime thay vì phải đăng ký thủ công trước.
- Ngược lại, chế độ local (STDIO) không cần vòng OAuth này — có thể dùng biến môi trường hoặc credential nhúng sẵn của bên thứ ba.
- Thực tế triển khai: giới thực hành đánh giá spec OAuth 2.1 hiện tại của MCP là phức tạp/khó áp dụng cho enterprise ("a mess for enterprise") — tức "bật OAuth" không đơn giản như một công tắc, cần tích hợp đáng kể (as of blog.christianposta.com, confidence: medium).
- Ví dụ production: Sentry MCP server chạy như middleware tập trung trước API của Sentry, client xác thực bằng cách gửi upstream Sentry API token qua HTTP header tới transport hosted trên Cloudflare — minh hoạ rõ "fix once, all users benefit" và "truy cập hệ thống chỉ cloud mới tới được".

## Các mối lo production khác

- **TLS/HTTPS**: spec yêu cầu bắt buộc validate header `Origin` (chống tấn công **DNS rebinding** — xem [Bảng thuật ngữ nhanh](#bảng-thuật-ngữ-nhanh-cho-người-mới)), chỉ bind localhost khi chạy local, và có "proper authentication for all connections" khi expose ra ngoài.
- **Rate limiting**: công việc spec gần đây (2026) bổ sung header `Mcp-Method`/`Mcp-Name` để gateway/load balancer/rate limiter có thể route mà không cần đọc body JSON-RPC — phản ánh đúng nhu cầu rate limiting chỉ phát sinh khi 1 server phục vụ nhiều client.
- Nhiều vendor SaaS lớn (Asana, Atlassian, Block, Intercom, Linear, PayPal, Sentry, Stripe, Webflow) đã hợp tác với Anthropic ra mắt remote MCP server hosted, phần lớn xây trên hạ tầng Cloudflare — bằng chứng cụ thể cho mô hình multi-user + centralized maintenance.

## Ví dụ minh hoạ

| Khía cạnh | Local (STDIO) | Remote/Cloud (Streamable HTTP) |
|---|---|---|
| Tiến trình | spawn theo từng user, chết khi client đóng | long-running process, phục vụ nhiều client |
| Auth | env var / credential nhúng sẵn | OAuth 2.1 (PKCE, resource server) |
| Network | không cần, chạy trong máy | bắt buộc TLS/HTTPS |
| Nhiều user | không chia sẻ được | 1 server phục vụ N client |
| Truy cập nội bộ | chỉ tài nguyên máy user | DB/hệ thống công ty chỉ cloud với tới |
| Scaling | không cần | horizontal scaling, session/state phải ra shared store |

Request path điển hình: client POST 1 message JSON-RPC (ví dụ `tools/call`) tới endpoint `https://mcp.example.com/mcp`, kèm `Authorization: Bearer <token>` (đã lấy qua flow OAuth 2.1) và `MCP-Protocol-Version` header; server trả JSON thường hoặc SSE stream tuỳ nhu cầu.

## Liên hệ tới các phần khác

- Liên quan tới [[agent-mcp-servers]] (khái niệm server nói chung), [[agent-mcp-creating-servers]] (cách build server), [[agent-mcp-deploy-local]] (chế độ ngược lại), [[ai-engineer-roadmap]].

### Áp dụng với Claude Code

- Claude Code hỗ trợ native remote MCP server qua `claude mcp add --transport http <name> <url>` — docs gọi HTTP là "the recommended option for connecting to remote MCP servers... the most widely supported transport for cloud-based services" (as of code.claude.com/docs/en/mcp, confidence: high).
- Transport SSE cũ vẫn được hỗ trợ (`--transport sse`) nhưng đã bị đánh dấu **deprecated** — khuyến nghị dùng HTTP khi server hỗ trợ, xác nhận đúng việc Streamable HTTP thay thế HTTP+SSE.
- Ví dụ terminal cụ thể (thêm 1 remote server rồi login OAuth):

  ```bash
  claude mcp add --transport http sentry https://mcp.sentry.dev/mcp
  # -> Added remote MCP server "sentry" (transport: http)

  claude mcp login sentry
  # -> mở trình duyệt, hoàn tất OAuth 2.1 flow, token được lưu và tự refresh sau này
  ```

- Trong config (`.mcp.json`/`~/.claude.json`), field `type` chấp nhận `streamable-http` như alias của `http` — khớp trực tiếp tên transport chính thức của spec. Ví dụ 1 entry `.mcp.json` cho server ở ví dụ trên:

  ```json
  {
    "mcpServers": {
      "sentry": {
        "type": "http",
        "url": "https://mcp.sentry.dev/mcp"
      }
    }
  }
  ```
- Claude Code tự động xử lý OAuth 2.1: phát hiện server cần auth (401/403 hoặc header `WWW-Authenticate`), người dùng hoàn tất flow qua `/mcp` hoặc `claude mcp login <name>`, sau đó tự refresh token khi hết hạn.
- Trong chế độ non-interactive (`claude -p`, Agent SDK, cloud session): không có panel `/mcp` để login trực tiếp — nếu server cần auth mà chưa được authorize trước, Claude sẽ được báo là tool không khả dụng thay vì lỗi âm thầm; phải chạy `/mcp` hoặc `claude mcp login` tương tác từ trước.
- Với server project-scoped từ `.mcp.json` checked-in repo, prompt approval bảo mật (bình thường bắt hỏi trước khi dùng) **không hiện được** trong `claude -p`/Agent SDK/cloud session — các server này (kể cả remote) được load thẳng trừ khi bị loại trừ tường minh qua `disabledMcpjsonServers`.
- Với HTTP/SSE remote server, Claude Code có cơ chế resilience riêng không tồn tại ở local: tự reconnect với exponential backoff (tối đa 5 lần), retry kết nối ban đầu tối đa 3 lần khi gặp lỗi 5xx/connection-refused/timeout, và idle timeout 5 phút cho request bị treo (so với 30 phút ở stdio) — phản ánh đúng các mối lo production riêng của chế độ remote.
- Ở tầng Messages API (không phải CLI), **MCP connector** (`mcp_servers`, beta header `mcp-client-2025-11-20`) yêu cầu server phải public qua HTTP (Streamable HTTP hoặc SSE) — "Local STDIO servers cannot be connected directly." Đây là bằng chứng rõ nhất: ở tầng API hosted, chế độ remote/cloud là **bắt buộc**, local hoàn toàn không được hỗ trợ (as of platform.claude.com/docs/en/agents-and-tools/mcp-connector, confidence: high). Tuy vậy, API tự nó không thực hiện OAuth handshake — caller phải tự lấy và refresh `authorization_token` trước khi gọi.

## Giới hạn / open questions

- Chưa rõ Claude Code CLI có support đầy đủ Dynamic Client Registration (RFC 7591) hay chỉ hỗ trợ các provider OAuth đã cấu hình sẵn thủ công.
- Mức độ "mess for enterprise" của spec OAuth 2.1 MCP mới chỉ có 1 nguồn (blog cá nhân, medium confidence) — chưa kiểm chứng độc lập bằng case study thực tế nào khác.
- Chưa rõ chi tiết cách các MCP server production hiện nay (Sentry, Stripe...) triển khai rate limiting cụ thể (per-user token bucket? per-IP?) — mới chỉ có bằng chứng định tính về sự tồn tại của rate limiting, chưa có số liệu.
- Header `Mcp-Method`/`Mcp-Name` để gateway routing không phải kiểm tra body còn đang trong giai đoạn "refining" (mid-2026) — chưa chắc đã final trong spec chính thức tại thời điểm viết note.
- WebSocket transport (`type: ws`) của Claude Code không hỗ trợ OAuth — chưa rõ đây là giới hạn tạm thời hay chủ đích lâu dài của thiết kế.
