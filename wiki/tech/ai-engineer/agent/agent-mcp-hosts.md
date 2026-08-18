---
status: current
updated: 2026-08
sources:
  - https://modelcontextprotocol.io/docs/learn/architecture
  - https://modelcontextprotocol.io/introduction
  - https://www.anthropic.com/news/model-context-protocol
  - https://en.wikipedia.org/wiki/Model_Context_Protocol
  - https://github.com/modelcontextprotocol/modelcontextprotocol
  - https://code.claude.com/docs/en/mcp
  - https://code.claude.com/docs/en/agent-sdk/mcp
  - https://natoma.ai/blog/model-context-protocol-how-one-standard-eliminates-months-of-ai-integration-work
roadmap: ai-engineer
stage: learning
---

# MCP Hosts — ứng dụng/môi trường mà user tương tác trực tiếp, điều phối một hay nhiều MCP client để nối tới MCP server

**TL;DR**:
- **MCP Host** = ứng dụng mà người dùng thực sự mở lên và cấu hình (Claude Desktop, Claude Code, một IDE như Cursor/VS Code).
- Host sở hữu **session, UI, và agent loop** (vòng lặp LLM suy luận + gọi tool — xem [[agent-acting-tool-invocation]]).
- Host đọc config để quyết định kết nối tới **MCP server** nào, rồi tạo một **MCP client** riêng cho mỗi server để giữ kết nối 1:1.

## 0. Vài từ khoá cần biết trước (dành cho người mới)

Ghi nhanh nghĩa của các từ sẽ xuất hiện lặp lại bên dưới, để không phải nhảy sang note khác giữa chừng:

- **Tool** = một hàm/API cụ thể mà model được phép gọi (ví dụ: "tìm kiếm issue trên GitHub", "đọc file"). Model không tự chạy code — nó chỉ "yêu cầu gọi tool", còn ai đó (Host) mới thực thi và trả kết quả lại. Chi tiết ở [[agent-what-are-tools]].
- **Context** = toàn bộ thông tin model đang "nhìn thấy" tại một thời điểm để suy luận (câu hỏi user, lịch sử hội thoại, kết quả tool trả về...). MCP là chuẩn để lấy context này từ nguồn dữ liệu ngoài một cách thống nhất — do đó có tên "**Model Context Protocol**".
- **Agent loop** = vòng lặp model suy nghĩ → gọi tool → đọc kết quả → suy nghĩ tiếp, lặp tới khi xong việc. Ví dụ đơn giản: user hỏi "sửa bug X" → model gọi tool đọc file → nhận nội dung file → model gọi tool sửa file → nhận kết quả → model báo "đã sửa xong". Xem [[agent-acting-tool-invocation]] để hiểu format `tool_use`/`tool_result` bên trong vòng lặp này (model phát ra một khối `tool_use` yêu cầu gọi tool gì với tham số gì, hệ thống chạy tool rồi gửi lại một khối `tool_result` chứa output).
- **STDIO** = một cách hai chương trình nói chuyện với nhau qua *standard input/output* (giống khi bạn gõ lệnh CLI và đọc kết quả in ra terminal), dùng cho server chạy ngay trên máy local.
- **Namespacing** = kỹ thuật đặt tên để tránh trùng: khi hai MCP server khác nhau đều có tool tên `search`, Host đổi tên hiển thị thành `mcp__<tên-server>__search` để model phân biệt được đang gọi tool của server nào.

Với các khái niệm trên, phần 1 dưới đây mô tả ba "vai" chính trong MCP.

## 1. Ba lớp trong kiến trúc MCP

Tài liệu chính thức mô tả MCP theo kiến trúc **client-host-server**, với ba vai trò tách biệt rõ ràng (as of modelcontextprotocol.io/docs/learn/architecture, confidence: high):

- **MCP Host** — ứng dụng AI mà người dùng thấy và điều phối, quản lý một hoặc nhiều MCP client. Ví dụ: Claude Code, Claude Desktop, VS Code.
- **MCP Client** — một đối tượng ở tầng giao thức, giữ kết nối tới một MCP server và lấy context từ đó cho Host dùng. Thường là **1 client : 1 server**.
- **MCP Server** — tiến trình thực sự expose tools/resources/prompts cho client gọi tới (ví dụ: server đọc GitHub issues, server truy vấn Sentry).

Nói ngắn gọn: **Host chứa nhiều Client, mỗi Client giữ một kết nối riêng tới một Server.** Xem thêm [[agent-what-are-tools]] cho khái niệm tool nói chung.

## 2. Trách nhiệm cụ thể của Host

- **Sở hữu session và UI** — Host là chương trình người dùng mở lên, gõ chat, xem tool call chạy.
- **Sở hữu agent loop** — vòng lặp gọi tool (xem định nghĩa ở phần 0) nằm trong Host, không nằm trong MCP spec — spec chỉ định nghĩa cách trao đổi context giữa client/server, không quy định Host phải dùng LLM ra sao. Vì vậy mỗi Host (Claude Desktop, Claude Code, Cursor...) tự quyết định UX và cách dùng LLM, miễn tuân thủ giao thức khi nói chuyện với server.
- **Quyết định kết nối server nào** — dựa trên config do user/tổ chức thiết lập (file JSON, UI settings, allowlist...), không phải model tự chọn.
- **Tạo và quản lý nhiều MCP client** — mỗi khi Host kết nối thêm một server mới, nó khởi tạo thêm một client object riêng cho kết nối đó.
- **Gộp (aggregate) tool từ nhiều client thành một registry** cho LLM dùng — ví dụ Claude Code/Agent SDK dùng **namespacing** (đặt tên tool theo khuôn `mcp__<tên-server>__<tên-tool>`, ví dụ `mcp__sentry__search_issues`) để hai server khác nhau không bị đụng tên tool.
- **Gatekeeping quyền** — Host quyết định tool nào được phép gọi (ví dụ `allowedTools`/`disallowedTools` trong Claude Agent SDK), dù client đã "thấy" toàn bộ danh sách tool của server.

## 3. Ví dụ cụ thể: VS Code làm Host

Tài liệu chính thức dùng VS Code minh hoạ:

- VS Code kết nối tới **Sentry MCP server** → runtime của VS Code khởi tạo **một MCP client object** riêng cho kết nối này.
- VS Code kết nối thêm tới **local filesystem MCP server** → khởi tạo **thêm một client object khác**, độc lập với client trước.

Mô hình cardinality: **1 Host : N Client : N Server**, mỗi cặp Client–Server là **1:1**. Tuy nhiên transport ảnh hưởng tới cách hiểu "1:1" ở tầng process:

| Transport | Là gì | Server phục vụ bao nhiêu client? |
|---|---|---|
| **STDIO** | Server chạy local như một subprocess, giao tiếp qua stdin/stdout (giống gọi CLI) | Thường chỉ 1 client (pipe riêng cho từng process) |
| **Streamable HTTP** | Server chạy remote, client gọi qua HTTP request/response (có thể stream) | Thường phục vụ nhiều client cùng lúc (nhiều Host/user khác nhau) |

Mỗi kết nối Client–Server vẫn là "dedicated" (riêng), nhưng một server process remote có thể đứng sau nhiều client toàn cầu — refine framing "1:1" thành "mỗi client có một kết nối riêng tới server", không phải "mỗi server chỉ có đúng một client".

## 4. Host khác gì Client và Server

| | Host | Client | Server |
|---|---|---|---|
| Là gì | Ứng dụng AI người dùng thấy/cấu hình (Claude Desktop, Claude Code, VS Code) | Đối tượng protocol-level, thường 1 client/server | Tiến trình expose tools/resources |
| Sở hữu | Session, UI, agent loop (LLM) | Một kết nối stateful tới 1 server | Logic thực thi tool, dữ liệu |
| Quyết định | Kết nối server nào (theo config user) | Không tự quyết — chỉ transport | Không biết về các server khác |
| Số lượng trong 1 phiên | 1 | N (một cho mỗi server đã cấu hình) | N (độc lập với host) |

## 5. Vì sao cần tách riêng khái niệm "Host" (bối cảnh ngắn gọn)

- MCP giải quyết bài toán **M×N integration**: không có chuẩn, kết nối M ứng dụng AI với N nguồn dữ liệu cần tới M×N tích hợp riêng; MCP giảm còn **M+N** vì mỗi Host chỉ cần implement client-side một lần, mỗi tool/data source implement server-side một lần. Đây là lý do thực dụng để có một chuẩn chung, thay vì mỗi app tự viết integration riêng.
- Anthropic công bố MCP ngày **25/11/2024**; sau khi các bên khác (OpenAI, Google DeepMind, Zed, Cursor...) áp dụng, vocabulary ba lớp Host/Client/Server được dùng để giữ thuật ngữ trung lập vendor, không gói gọn trong app của Anthropic (as of anthropic.com/news/model-context-protocol, confidence: medium).

## 6. Liên hệ tới các phần khác

- [[agent-what-are-tools]] — MCP server là một cách chuẩn hoá để expose tool cho agent; Host là nơi các tool từ nhiều MCP server được gộp lại thành registry cho model dùng.
- [[agent-acting-tool-invocation]] — vòng lặp tool_use/tool_result nằm trong agent loop của Host, sau khi Host đã tổng hợp tool list từ các client.
- [[ai-engineer-roadmap]] — mục "Model Context Protocol / MCP" trong roadmap.

### Áp dụng với Claude Code

- **Claude Code chính là một MCP Host** — tài liệu Claude Code tự mô tả nó kết nối tới hàng trăm tool/data source bên ngoài qua MCP, và dẫn thẳng tới spec `modelcontextprotocol.io/introduction` (as of code.claude.com/docs/mcp, confidence: high).
- Claude Code quản lý config server (server nào được kết nối) ở **3 scope**: `local` (mặc định, riêng tư, lưu trong `~/.claude.json`), `project` (`.mcp.json` ở root repo, chia sẻ qua version control), `user` (global, áp dụng mọi project).

  **Ví dụ thêm một MCP server bằng CLI** (scope `project`, dùng chung với team qua `.mcp.json`):
  ```bash
  claude mcp add --scope project sentry -- npx -y @sentry/mcp-server --auth-token=$SENTRY_TOKEN
  ```
  File `.mcp.json` sinh ra ở root repo trông như:
  ```json
  {
    "mcpServers": {
      "sentry": {
        "command": "npx",
        "args": ["-y", "@sentry/mcp-server", "--auth-token=${SENTRY_TOKEN}"]
      }
    }
  }
  ```
  Sau khi thêm, Claude Code (Host) tự khởi tạo một MCP client riêng để giữ kết nối STDIO tới process `sentry` này.
- **Kiểm tra kết nối bằng lệnh `claude mcp list`** — cách "try it yourself" nhanh nhất để xem Host đang quản lý những client nào. Output trông đại khái:
  ```
  sentry: npx -y @sentry/mcp-server --auth-token=*** - ✓ Connected
  filesystem: npx -y @modelcontextprotocol/server-filesystem /repo - ✓ Connected
  broken-server: node ./my-server.js - ✗ Failed to connect
  ```
  Mỗi dòng ứng với một MCP client riêng mà Host đang giữ; trạng thái có thể là `Connected`, `Failed to connect`, `pending`, hoặc `needs-auth` (server cần OAuth chưa hoàn tất). Nội bộ, message `system init` lúc khởi động session cũng mang đúng danh sách trạng thái này — Host theo dõi và hiển thị trạng thái của từng client-connection bên dưới, đúng vai trò "coordinate nhiều client 1:1".
- **Khi tên tool bị trùng giữa hai server** (ví dụ cả `sentry` và `github` đều expose tool tên `search`), Host không báo lỗi/crash — nhờ **namespacing** (phần 0), model chỉ thấy hai tool riêng biệt `mcp__sentry__search` và `mcp__github__search` trong danh sách tool, tự chọn đúng cái cần dùng theo tên server. Người dùng thường chỉ nhận ra namespacing tồn tại khi đọc log tool call và thấy tiền tố `mcp__<server>__` này.
- Ở cấp doanh nghiệp, có thể deploy `managed-mcp.json` để ép mọi session Claude Code của dev phải kết nối một số server bắt buộc, và dùng `allowedMcpServers` (glob pattern) để giới hạn server nào được phép thêm — xác nhận việc chọn server là quyết định ở tầng Host/tổ chức, không phải ở tầng model.
- **Claude Agent SDK** (dùng để build ứng dụng dựa trên Claude Code) không dùng từ "host" tường minh trong docs, nhưng ứng dụng nhúng SDK (qua `query()`/`ClaudeAgentOptions`) đóng đúng vai trò Host: giữ session, giữ agent loop, cấu hình `mcpServers` (stdio/HTTP/SSE hoặc "SDK MCP server" chạy in-process), và gatekeeping quyền qua `allowedTools`.

## 7. Giới hạn / open questions

- Chưa có nguồn xác nhận rõ liệu Claude Code khi tự chạy **như một MCP server** (expose tool Bash/Read/Write cho Host khác) có làm thay đổi vai trò "Host" của chính nó trong cùng phiên hay không — claim này chỉ ở mức confidence thấp trong dữ liệu nghiên cứu, cần đào sâu thêm.
- Chưa rõ cơ chế chính xác Host xử lý xung đột tên tool giữa nhiều server (ngoài namespacing `mcp__<server>__<tool>`) khi số lượng server lớn — chưa có benchmark/case study cụ thể.
- "SDK MCP server" (chạy in-process, không transport thật) làm mờ ranh giới Host/Client/Server truyền thống — note này chưa đào sâu tradeoff giữa in-process server và server ngoài (stdio/HTTP) về mặt bảo mật, latency.
- Cách các Host khác (Cursor, VS Code) triển khai UI cấu hình server cụ thể ra sao (so với `.mcp.json`/CLI của Claude Code) mới chỉ dựa trên nguồn confidence thấp, cần kiểm chứng thêm.
