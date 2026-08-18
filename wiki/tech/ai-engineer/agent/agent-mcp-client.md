---
status: current
updated: 2026-08
sources:
  - https://modelcontextprotocol.io/docs/2026-07-28/learn/architecture
  - https://modelcontextprotocol.io/docs/learn/architecture
  - https://modelcontextprotocol.io/introduction
  - https://modelcontextprotocol.io/docs/2026-07-28/develop/build-client
  - https://www.anthropic.com/news/model-context-protocol
  - https://code.claude.com/docs/en/agent-sdk/mcp
  - https://infranodus.com/docs/mcp-vs-rag-vs-ai-agents
  - https://blog.modelcontextprotocol.io/posts/2026-07-28-release-candidate/
  - https://fast.io/resources/best-mcp-clients/
roadmap: ai-engineer
stage: learning
---

# MCP Client — connector object bên trong Host, giữ kết nối 1:1 với đúng một MCP Server

**TL;DR**: **MCP Client** là object nằm bên trong **MCP Host** (app AI người dùng thấy, ví dụ Claude Code), thay model "nói chuyện protocol" với một **MCP Server** cụ thể — mỗi Client giữ đúng **một kết nối** (1 Client : 1 Server); nếu Host nối tới N server thì sẽ có N Client song song. Client lo 3 việc: bắt tay khai báo khả năng hỗ trợ (capability negotiation), đóng gói lời gọi tool thành message theo chuẩn **JSON-RPC 2.0** (một format request/response dạng JSON), và route kết quả trả về đúng chỗ.

## 1. Client nằm ở đâu trong kiến trúc MCP

- Ba thành phần chính thức: **MCP Host** (app AI mà người dùng thấy, ví dụ Claude Code, Claude Desktop, VS Code) điều phối một hoặc nhiều **MCP Client**; mỗi **MCP Client** giữ kết nối tới một **MCP Server**; **MCP Server** là chương trình độc lập cung cấp tool/resource/prompt.
- **Client vô hình với người dùng cuối** — người dùng chỉ thấy Host (giao diện chat, IDE...); Client là object nội bộ trong runtime của Host, không có UI riêng.
- Quan hệ là **1 Client : 1 Server**, không phải 1 Client : nhiều Server — đây là điểm khác biệt cốt lõi so với việc hiểu nhầm "client" là một service dùng chung cho mọi kết nối.
- Xem thêm bức tranh tổng: [[agent-mcp-overview]] (protocol nói chung), [[agent-mcp-hosts]] (vai trò Host).

## 2. Vì sao mỗi Server có một Client riêng

- Ví dụ minh hoạ từ tài liệu chính thức: khi VS Code (Host) nối tới **Sentry MCP server**, runtime VS Code khởi tạo một object MCP Client giữ kết nối đó; khi người dùng nối thêm **filesystem server** cục bộ, VS Code khởi tạo **thêm một** object Client khác, độc lập với client Sentry.
- Lý do kỹ thuật: mỗi kết nối có transport, phiên capability, trạng thái lỗi/xác thực (OAuth) riêng — gộp chung nhiều server vào một client sẽ làm mất khả năng cô lập lỗi (một server rớt kết nối không ảnh hưởng client khác) và làm rối việc route request đúng đích.
- Trong thực tế theo transport:
  - Server **local** (`stdio`, chạy cùng process/máy) — thường chỉ phục vụ **một** client duy nhất (chính Host đã spawn nó).
  - Server **remote** (Streamable HTTP) — có thể phục vụ **nhiều** client từ nhiều Host khác nhau cùng lúc, nhưng mỗi cặp Client–Server riêng lẻ vẫn là kết nối 1:1 dành riêng, không chia sẻ trạng thái giữa các client.

## 3. Client làm gì: 3 việc "plumbing"

- **Capability negotiation khi connect** — client gửi request khai báo `protocolVersion` + `capabilities` của mình (ví dụ có hỗ trợ **elicitation** hay không); server trả lời version/capability nó hỗ trợ (tools, resources...). Tên method bước này đổi giữa các version spec — spec 2026-07-28 gọi là `server/discover`, spec cũ hơn gọi là `initialize` (as of blog.modelcontextprotocol.io release-candidate note, confidence: medium — nên kiểm tra SDK đang pin version nào trước khi copy tên method vào code).
- **Dịch request của Host thành JSON-RPC 2.0** — khi model (qua Host) muốn gọi một tool, Client đóng gói lời gọi đó thành message JSON-RPC 2.0 rồi gửi qua transport (`stdio` hoặc Streamable HTTP).
- **Route response/notification về đúng chỗ** — khi server trả kết quả hoặc bắn notification (ví dụ danh sách tool đổi), Client nhận, parse, và đưa ngược lại cho Host để Host feed vào context của model.

Luồng gọi tool cụ thể: Host chặn lời gọi tool của LLM → tra "client manager" tìm đúng Client gắn với server sở hữu tool đó → Client gửi request `tools/call` qua JSON-RPC → chờ kết quả → trả content về conversation cho LLM dùng tiếp. Ví dụ message thật (rút gọn) khi gọi một tool tên `get_weather`:

```jsonc
// Request: Client -> Server
{
  "jsonrpc": "2.0",
  "id": 7,
  "method": "tools/call",
  "params": {
    "name": "get_weather",
    "arguments": { "city": "Hanoi" }
  }
}

// Response: Server -> Client
{
  "jsonrpc": "2.0",
  "id": 7,
  "result": {
    "content": [
      { "type": "text", "text": "28°C, mưa rào" }
    ]
  }
}
```

Client là bên tạo request này, gán `id` để khớp response, và forward `result.content` ngược lại cho Host/model.

## 4. Phân biệt Client — Host — Server (dễ nhầm)

| Thành phần | Là gì | Người dùng thấy? | Số lượng trong 1 phiên |
|---|---|---|---|
| **Host** | App AI ngoài cùng (Claude Code, Claude Desktop, VS Code) | Có — đây là app người dùng tương tác | 1 |
| **Client** | Connector object bên trong Host, nói protocol MCP | Không — ẩn trong runtime | N (1 client / server đang nối) |
| **Server** | Process bên ngoài, thật sự implement tool/resource/prompt | Gián tiếp (qua tool nó cung cấp) | N (mỗi server độc lập) |

- Nhầm lẫn phổ biến: gọi "MCP client" khi thực ra đang nói về Host (ví dụ nói "Claude Desktop là một MCP client" — đúng ở nghĩa rộng vì Claude Desktop *chứa* client, nhưng chính xác hơn là Claude Desktop = Host, còn client là object nội bộ nó tạo ra cho từng server).
- Client khác Server ở chỗ: Client **không** tự có tool/resource/prompt nào — nó chỉ là ống dẫn; Server mới là nơi implement logic thật.

## 5. So sánh nhanh với RAG và integration hardcode

- **So với gọi API hardcode**: một integration viết tay nói chuyện với một API cụ thể theo format tuỳ ý, không có bước negotiate. MCP Client thay vào đó dùng một handshake capability chung, một format JSON-RPC 2.0 thống nhất — nên có thể đổi sang server khác mà không sửa code phía Host.
- **So với RAG**: RAG không có khái niệm "connection object" persistent kiểu Client — một pipeline RAG thường chỉ là một lần gọi retrieval nhúng vào bước dựng prompt, không phải phiên đã negotiate. MCP Client, ngược lại, giữ một session có trạng thái. Hai kỹ thuật không loại trừ nhau: một MCP server hoàn toàn có thể bọc một pipeline RAG bên trong và lộ nó ra như một MCP tool — khi đó `tools/call` từ Client sẽ kích hoạt RAG lookup ở phía sau.

## 6. Liên hệ tới các phần khác

### Áp dụng với Claude Code

Khái niệm "MCP Client" **áp dụng đầy đủ** trong Claude Code/Agent SDK, nhưng CLI **không lộ ra API "tạo Client thủ công"** cho người dùng — runtime tự quản lý một Client instance cho mỗi server, đúng semantics 1:1 mà spec MCP mô tả. Cụ thể:

- CLI `claude mcp add/list/get/remove` quản lý từng kết nối server như một đơn vị riêng biệt; slash command `/mcp` trong phiên báo trạng thái sống và chạy OAuth theo từng server — không có khái niệm "một client dùng chung cho mọi server".
- Tool từ MCP được namespace theo dạng `mcp__<server-name>__<tool-name>` (ví dụ `mcp__github__list_issues`), và quyền (`allowedTools`) cấp theo từng server/tool — mỗi server (và client giữ kết nối tới nó) là một đơn vị địa chỉ hoá riêng trong Host.
- Trong **Claude Agent SDK**, mỗi server cấu hình qua `mcpServers` trong `ClaudeAgentOptions`/`query()` có trạng thái kết nối theo dõi **riêng từng server**: field `mcp_servers` trong system init message, và API `mcpServerStatus()`/`get_mcp_status()` trả status per-server (`pending`, `connected`, `failed`, `needs-auth`, `disabled`) — bằng chứng runtime đang track mỗi kết nối client-server độc lập (as of code.claude.com/docs/en/agent-sdk/mcp, confidence: high). Ví dụ đọc status trong code Python:

  ```python
  async for message in query(prompt="...", options=options):
      if message.get("type") == "system" and message.get("subtype") == "init":
          for server_name, status in message["mcp_servers"].items():
              print(server_name, status["status"])  # connected | failed | needs-auth | ...
  ```

- Có 3 kiểu server Claude Agent SDK hỗ trợ: **stdio** (process local), **remote HTTP/SSE**, và **in-process "SDK MCP server"** chạy ngay trong SDK application. Với loại in-process, SDK không dựng transport/JSON-RPC riêng như stdio/HTTP; nó "connect" ngay khi request khởi tạo được xử lý, không có độ trễ handshake qua mạng. Với server remote HTTP/SSE, SDK có thể tái dùng danh sách tool đã cache và **hoãn** handshake thật tới lần gọi tool đầu tiên, thay vì negotiate capability ngay lúc khởi động.

## 7. Giới hạn / open questions

- Chưa có bằng chứng cụ thể mô tả implementation nội bộ (ngôn ngữ, thread model) của object Client trong Claude Code — tài liệu chỉ mô tả hành vi quan sát được (status, namespacing) chứ không phải source code.
- Tên method negotiation (`server/discover` vs `initialize`, xem §3) khác nhau giữa các spec version; ghi chú này theo spec 2026-07-28, cần re-check nếu SDK đang pin version cũ hơn.
- Chưa rõ giới hạn thực tế về số lượng Client instance một Host có thể giữ đồng thời (memory/connection limit) — không tìm thấy con số cụ thể trong các nguồn đã khảo sát.
- Chưa đào sâu cách Client xử lý retry/reconnect khi kết nối remote HTTP bị rớt giữa chừng một tool call đang chờ kết quả.
