---
status: current
updated: 2026-08
sources:
  - https://modelcontextprotocol.io/introduction
  - https://modelcontextprotocol.io/docs/2026-07-28/learn/architecture
  - https://www.anthropic.com/news/model-context-protocol
  - https://github.com/modelcontextprotocol/modelcontextprotocol
  - https://en.wikipedia.org/wiki/Model_Context_Protocol
  - https://code.claude.com/docs/en/mcp
  - https://code.claude.com/docs/en/agent-sdk/mcp
  - https://code.claude.com/docs/en/agent-sdk/custom-tools
  - https://www.klavis.ai/blog/mcp-solving-n-x-m-integration-problem
  - https://www.softwareseni.com/how-mcp-reduces-ai-tool-integration-from-mxn-custom-connectors-to-mn-standard-interfaces/
  - https://www.merge.dev/blog/rag-vs-mcp
  - https://guptadeepak.com/the-complete-guide-to-model-context-protocol-mcp-enterprise-adoption-market-trends-and-implementation-strategies/
roadmap: ai-engineer
stage: learning
---

# Model Context Protocol (MCP) — chuẩn mở kết nối AI application với tool/data source bên ngoài

**TL;DR**: **MCP** là một **client-server protocol** mở (Anthropic công bố 11/2024) định nghĩa cách một AI application đóng gói context và giao tiếp với **external systems** (data, tool, prompt) qua một giao diện chung duy nhất — thay vì mỗi framework phải viết connector riêng cho từng tool (bài toán **M×N**), MCP biến nó thành bài toán **M+N**: mỗi tool viết một MCP server, mỗi client viết hỗ trợ MCP một lần, rồi ghép tự do với nhau.

## 1. MCP là gì

- Định nghĩa chính thức: **"an open-source standard for connecting AI applications to external systems"** — cho phép AI app (Claude, ChatGPT...) kết nối tới data source (file, database), tool (search engine, calculator), và workflow (prompt chuyên biệt).
- Analogy kinh điển: **"USB-C for AI applications"** — như USB-C chuẩn hoá cách cắm thiết bị điện tử, MCP chuẩn hoá cách AI app cắm vào external system.
- MCP ra đời để giải quyết tình trạng phân mảnh: mỗi AI assistant từng bị "nhốt" sau các silo dữ liệu/hệ thống legacy, cần một connector bespoke cho từng nguồn — Anthropic công bố MCP ngày **25/11/2024** với spec mở, SDK, hỗ trợ MCP server local trong Claude Desktop, và một kho server dựng sẵn (Google Drive, Slack, GitHub, Postgres...).
- MCP được tạo bởi kỹ sư Anthropic **David Soria Parra** và **Justin Spahr-Summers**, đặt tên vấn đề gốc là **"N×M data integration problem"**.
- Xem thêm khái niệm nền: [[agent-what-are-tools]], [[agent-tool-definition]].

## 2. Bài toán M×N và cách MCP giảm về M+N

- **Không có chuẩn chung**: nối M AI client (Claude, ChatGPT, Cursor...) với N tool/data source (Slack, GitHub, Postgres...) đòi hỏi M×N connector riêng lẻ — thêm 1 model hoặc 1 tool mới buộc viết lại hàng loạt integration.
- **Có MCP**: mỗi tool chỉ cần lộ diện qua **một** MCP server; mỗi AI app chỉ cần implement **một** MCP client — số lượng implementation giảm còn M+N.

Ví dụ minh hoạ bằng số:

| | Không có MCP (M×N) | Có MCP (M+N) |
|---|---|---|
| 5 AI client × 10 tool | 5 × 10 = **50** connector riêng | 5 client-impl + 10 server-impl = **15** |
| Thêm 1 tool mới | +5 connector (viết cho từng client) | +1 server (dùng ngay cho mọi client) |
| Thêm 1 client mới | +10 connector (viết cho từng tool) | +1 client (dùng ngay mọi server có sẵn) |

## 3. Kiến trúc: Host — Client — Server

Theo tài liệu kiến trúc chính thức, MCP có ba thành phần:

- **MCP Host** — AI application điều phối (ví dụ Claude Code, Claude Desktop); host tạo và quản lý một hoặc nhiều MCP client.
- **MCP Client** — sống bên trong host, giữ kết nối **1:1** với đúng một MCP server (host tạo 1 client cho mỗi server nó nối tới).
- **MCP Server** — chương trình độc lập cung cấp context (tool/resource/prompt) cho client; có thể chạy **local** (transport `stdio`, ví dụ filesystem server do Claude Desktop tự spawn, thường phục vụ 1 client) hoặc **remote** (transport Streamable HTTP, ví dụ Sentry MCP server, thường phục vụ nhiều client cùng lúc).

MCP được chia làm 2 tầng — vài thuật ngữ dùng ở đây giải thích nhanh bên dưới:
- **Data layer** — protocol dựa trên **JSON-RPC 2.0** (một chuẩn cũ, gọn nhẹ để đóng gói request/response dạng JSON qua bất kỳ kênh truyền nào — không phải riêng của MCP), định nghĩa discovery, **capability negotiation** (bước client và server "bắt tay" khai báo mình hỗ trợ tính năng nào trước khi giao tiếp thật) và các primitive cốt lõi.
- **Transport layer** — `stdio` (giao tiếp qua process nội bộ, dùng khi server chạy cùng máy) hoặc **Streamable HTTP** (kênh HTTP cho server chạy remote, khuyến nghị dùng **OAuth** — chuẩn cấp quyền truy cập bằng token thay vì gửi password trực tiếp — để xác thực).
- Protocol hiện tại là **stateless**: mỗi request tự mang theo protocol version + capability metadata (field `_meta`) thay vì dựa vào trạng thái phiên trước đó; server công bố version/capability qua request bắt buộc `server/discover`.

## 4. Các primitive MCP định nghĩa

Phía server lộ ra:
- **Tools** — hàm thực thi được, agent gọi để hành động (đọc file, gọi API, ghi DB...) — xem chi tiết ở [[agent-what-are-tools]] và [[agent-tool-definition]].
- **Resources** — nguồn dữ liệu cung cấp context (đọc, không thực thi).
- **Prompts** — template tương tác tái sử dụng được (workflow soạn sẵn).

Phía client lộ ra:
- **Elicitation** — server có thể yêu cầu client hỏi lại người dùng để lấy input bổ sung.
- **Sampling** và **Logging** — đã bị đánh dấu **deprecated** kể từ protocol version 2026-07-28, thay bằng tích hợp LLM provider trực tiếp và logging qua stderr/OpenTelemetry.

## 5. So sánh MCP với RAG và lời gọi LLM thuần

- **LLM thuần**: chỉ dựa vào kiến thức nội tại (đóng băng tại thời điểm train), không có retrieval hay hành động ngoài.
- **RAG**: truy xuất context từ tài liệu/kho tri thức đã index — chỉ **đọc**, phù hợp dữ liệu tương đối tĩnh, phi cấu trúc.
- **MCP**: là lớp hạ tầng/plumbing — vừa lấy dữ liệu **live** từ API/database, vừa **thực hiện hành động** (tạo ticket, gửi email, update record) — bao trùm cả retrieval lẫn action.
- RAG và MCP/agent không cạnh tranh nhau: RAG là kỹ thuật retrieval, agent (thường dùng MCP để gọi tool) là pattern kiến trúc cho tác vụ tự trị; agent thường dùng RAG như một trong các tool khả dụng của nó.

## 6. Hệ sinh thái và mốc thời gian

| Thời điểm | Sự kiện |
|---|---|
| 11/2024 | Anthropic công bố MCP; đối tác sớm gồm Block, Apollo, và dev tool Zed, Replit, Codeium, Sourcegraph |
| 3/2025 | OpenAI chính thức hỗ trợ MCP (ChatGPT desktop app, Agents SDK, API) |
| 4/2025 | Google DeepMind hỗ trợ MCP; Demis Hassabis gọi MCP là chuẩn mở đang lên cho AI agentic |
| 5/2025 | Microsoft/GitHub gia nhập steering committee của MCP tại Build 2025 |
| 9/2025 | OpenAI mở MCP cho third-party app trong ChatGPT |
| 12/2025 | Anthropic chuyển giao quyền quản trị MCP cho **Agentic AI Foundation (AAIF)** — directed fund dưới Linux Foundation, đồng sáng lập bởi Anthropic, Block, OpenAI; MCP chuyển từ dự án do Anthropic dẫn dắt sang chuẩn mở trung lập do foundation quản trị |

- Tăng trưởng ecosystem: lượt tải server tăng từ ~100.000 (11/2024) lên hơn **8 triệu** (4/2025), với **5.800+** MCP server và **300+** MCP client được ghi nhận (as of en.wikipedia.org/wiki/Model_Context_Protocol, confidence: medium) — xem là ước lượng, chưa phải số liệu kiểm toán chính thức.
- Adopter doanh nghiệp tiêu biểu: Block xây 60+ MCP server nội bộ tích hợp Snowflake, Jira, Slack, Google Drive, phục vụ AI assistant nội bộ "Goose" cho hàng nghìn nhân viên, được báo cáo giảm tới **75%** thời gian cho công việc kỹ thuật hàng ngày (as of guptadeepak.com, confidence: low — số liệu marketing, chưa kiểm chứng độc lập).

## 7. Ví dụ dùng thực tế (theo tài liệu chính thức)

- Agent truy cập Google Calendar/Notion để hỗ trợ cá nhân hoá.
- Claude Code sinh web app từ thiết kế Figma.
- Chatbot doanh nghiệp truy vấn nhiều database nội bộ qua chat.
- AI model thiết kế mô hình 3D trong Blender rồi gửi tới máy in 3D.

## Liên hệ tới các phần khác

### Áp dụng với Claude Code

- Claude Code (CLI) là một **MCP host** — thêm server bằng `claude mcp add`, hỗ trợ 3 transport: **stdio** (process local, phù hợp tool cần truy cập hệ thống trực tiếp), **HTTP** (khuyến nghị cho remote/cloud, hỗ trợ OAuth), **SSE** (transport remote cũ, đã deprecated). Còn có transport **WebSocket** (`type: ws`) cho server cần chủ động đẩy sự kiện.
- Config MCP server tồn tại ở nhiều **scope**: local, project (`.mcp.json`), user (`~/.claude.json`); server ở scope project cần người dùng **approve** trước khi dùng (hiển thị "Pending approval" trong `claude mcp list`) — đây là lớp trust/security đặt thêm trên nền protocol gốc.
- Claude Code implement cả các feature protocol ngoài tool-calling: set `CLAUDE_PROJECT_DIR` cho stdio server, trả lời request `roots/list` bằng working directory của session.

**Ví dụ 1 — thêm một stdio server (filesystem) bằng CLI:**

```bash
claude mcp add filesystem --scope project -- npx -y @modelcontextprotocol/server-filesystem /path/to/allowed/dir
```

Lệnh trên tạo/cập nhật `.mcp.json` ở project scope, tương đương tự tay viết:

```json
{
  "mcpServers": {
    "filesystem": {
      "command": "npx",
      "args": ["-y", "@modelcontextprotocol/server-filesystem", "/path/to/allowed/dir"]
    }
  }
}
```

**Ví dụ 2 — SDK MCP server chạy in-process (không spawn process riêng), dùng khi muốn lộ hàm nội bộ của app dưới dạng tool kiểu MCP:**

```ts
import { createSdkMcpServer, tool } from "@anthropic-ai/claude-agent-sdk";
import { z } from "zod";

const myServer = createSdkMcpServer({
  name: "my-internal-tools",
  tools: [
    tool(
      "get_order_status",
      "Tra cứu trạng thái đơn hàng theo order id",
      { orderId: z.string() },
      async ({ orderId }) => ({ content: [{ type: "text", text: `Order ${orderId}: shipped` }] })
    ),
  ],
});
```

- **Claude Agent SDK** (SDK lập trình mà chính Claude Code được xây trên đó) hỗ trợ cùng loại external MCP server (stdio/HTTP/SSE) qua option `mcpServers` trong `query()`, đồng thời hỗ trợ thêm **SDK MCP server** như ví dụ trên — không tốn thời gian chờ kết nối ở turn đầu, là cách khuyến nghị để lộ hàm nội bộ của app dưới dạng tool kiểu MCP mà không cần dựng server thật.
- Mọi tool qua MCP (server ngoài hay in-process) đều theo cùng convention đặt tên `mcp__<server-name>__<tool-name>` và cần permission tường minh qua `allowedTools` (hỗ trợ wildcard `mcp__servername__*`) — chứng tỏ Claude Code coi "custom tool" viết trực tiếp trong code app cũng là MCP server hạng nhất, không phải cơ chế riêng biệt.
- Khi có nhiều MCP tool, schema tool có thể chiếm nhiều context window — Claude Code/Agent SDK có **MCP tool search** (bật mặc định): giữ lại schema đầy đủ ngoài context, chỉ load khi cần, là một engineering adaptation trên nền chuẩn MCP để scale tới nhiều server/tool.
- MCP server nối vào Claude Code còn dùng được như "channel" event-driven (đẩy message vào session khi có event Telegram/Discord/webhook) — mở rộng phạm vi gốc của MCP (tool/resource/prompt) sang cơ chế trigger bất đồng bộ, đặc thù cho sản phẩm Claude Code.
- Thư mục MCP connector đã review của Anthropic (claude.ai/directory) dùng chung hạ tầng MCP với Claude Code — bất kỳ server nào trong đó thêm được trực tiếp bằng `claude mcp add`, minh hoạ lợi ích M+N trong thực tế.

## Giới hạn / open questions

- Các con số tăng trưởng ecosystem (8 triệu lượt tải, 5.800+ server, 300+ client) lấy từ Wikipedia, chưa đối chiếu với báo cáo gốc — cần verify lại khi có số liệu chính thức mới hơn.
- Case study Block ("giảm 75% thời gian") đến từ bài blog marketing bên thứ ba (guptadeepak.com), độ tin cậy thấp, chưa có nguồn Anthropic/Block chính thức xác nhận con số này.
- Chưa đào sâu chi tiết kỹ thuật của **Elicitation** (client-exposed primitive) và cách nó khác với tool-calling thông thường trong thực tế triển khai.
- Chưa khảo sát chi tiết mô hình bảo mật/OAuth cho remote MCP server (permission scope, token refresh, revocation) — cần một note riêng nếu đào sâu.
- Chưa rõ AAIF (Agentic AI Foundation) sẽ ảnh hưởng thế nào tới tốc độ ra spec version mới của MCP sau khi chuyển giao quản trị (12/2025) — cần theo dõi thêm.
