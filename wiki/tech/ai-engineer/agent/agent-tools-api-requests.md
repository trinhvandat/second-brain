---
status: current
updated: 2026-08
sources:
  - https://platform.claude.com/docs/en/agents-and-tools/tool-use/overview
  - https://platform.claude.com/docs/en/agents-and-tools/tool-use/implement-tool-use
  - https://platform.claude.com/docs/en/agents-and-tools/tool-use/how-tool-use-works
  - https://www.anthropic.com/engineering/advanced-tool-use
  - https://code.claude.com/docs/en/agent-sdk/custom-tools
  - https://code.claude.com/docs/en/agent-sdk/mcp
  - https://developers.openai.com/api/docs/guides/function-calling
  - https://www.promptingguide.ai/applications/function_calling
  - https://developer.mozilla.org/en-US/docs/Learn_web_development/Extensions/Client-side_APIs/Introduction
  - https://arxiv.org/abs/2210.03629
  - https://arxiv.org/abs/2302.04761
  - https://www.eesel.ai/blog/stripe-agent-toolkit
  - https://deepwiki.com/stripe/ai/2-agent-toolkit
  - https://www.gravitee.io/blog/mcp-credential-brokering-keep-api-keys-from-ai-agents
  - https://blog.christianposta.com/credential-brokering-patterns-for-ai-agent-egress/
  - https://owasp.org/API-Security/editions/2023/en/0xa2-broken-authentication/
  - https://www.reversinglabs.com/blog/owasp-top-10-for-llm-apps-excessive-agency
  - https://www.pontil.com/blog/rag-vs-tool-calling-which-one-your-agent-actually-needs
roadmap: ai-engineer
stage: learning
---

# API Request Tool — tool cho phép agent gọi trực tiếp một HTTP API bên ngoài để lấy dữ liệu sống hoặc kích hoạt hành động thật

**TL;DR**: Tool này cho AI "bấm nút" gọi một API thật ở bên ngoài — model chỉ quyết định khi nào gọi và gọi với tham số gì, còn code của developer mới là bên thực sự gửi request, giữ mật khẩu/API key, và kiểm tra tham số.

Nói kỹ hơn: **API request tool** là dạng **agent tool** tổng quát nhất — bọc một (hoặc vài) endpoint HTTP/REST/GraphQL của một hệ thống bên ngoài (thời tiết, thanh toán, CRM, microservice nội bộ...) đằng sau một **schema** tham số; việc thực thi request thật, giữ credential, giới hạn rate, và kiểm tra tham số trước khi bắn ra hệ thống thật luôn nằm ở phía code của developer, không phải phía model.

## 1. Vấn đề mà tool này giải quyết

- **Web search** (xem [[agent-tools-web-search]]) và **database query** (xem [[agent-tools-database-queries]]) đều là các trường hợp đặc biệt của một pattern chung rộng hơn: cho model quyền "chạm" vào thế giới bên ngoài prompt của nó.
- API request tool tổng quát hoá pattern đó cho **bất kỳ hệ thống nào có giao diện HTTP** — không giới hạn ở search engine hay database do agent sở hữu: gọi API thời tiết, tạo payment link Stripe, mở ticket trên hệ thống CRM/helpdesk, gọi một microservice nội bộ của công ty.
- Khác biệt cốt lõi so với workflow cố định: developer không hardcode "luôn gọi API X với tham số Y" — model tự suy luận có cần gọi hay không, gọi endpoint nào, với tham số nào, dựa trên ngữ cảnh hội thoại.

## 2. Cơ chế hoạt động chung

- Vòng lặp tool-calling cho API request giống hệt cấu trúc chung của tool use (xem [[agent-tool-definition]]):
  1. Developer khai báo tool: `name`, `description`, `input_schema` (**JSON Schema** — một cách mô tả hình dạng dữ liệu, ví dụ "field `latitude` phải là số") mô tả tham số của endpoint.
  2. Model trả về một `tool_use` block (Claude) hay `function_call` (OpenAI) — tên tool + JSON arguments — **model không tự chạy request**.
  3. Code ứng dụng (hoặc, với "server tool", hạ tầng của provider) thực thi request HTTP thật tới API bên ngoài.
  4. Kết quả (response body, status) được đưa lại vào context dưới dạng `tool_result`, model dùng nó để trả lời tiếp hoặc gọi tool khác.
- Anthropic phân biệt hai loại tool: **client tool** (schema + logic gọi API do ứng dụng của bạn tự viết và tự chạy — bạn kiểm soát toàn bộ) và **server tool** (Anthropic tự chạy trên hạ tầng của họ, ví dụ `web_search`, `code_execution` — bạn chỉ bật/tắt). API request tool bọc một endpoint tuỳ ý gần như luôn là **client tool**.
- Ví dụ kinh điển trong cả docs Anthropic lẫn OpenAI là tool `get_weather` nhận tham số `location`, minh hoạ chính xác pattern "cho model quyền truy cập một API thời tiết bên ngoài thay vì chỉ dựa vào kiến thức nội tại".
- Nguồn gốc học thuật: **ReAct** (Yao et al., ICLR 2023) đặt nền cho vòng lặp reasoning + action gọi API bên ngoài; **Toolformer** (Schick et al., Meta AI, 2023) là tiền thân sớm cho việc LLM tự quyết định gọi API nào, tham số gì, khi nào.

## 3. Ví dụ triển khai: Claude Agent SDK custom tool gọi API thời tiết

SDK định nghĩa tool với schema kiểu mạnh (Zod ở TypeScript, dict/JSON Schema ở Python) — schema này được validate **trước khi** handler chạy, đây chính là lớp sanitize tham số do model sinh ra trước khi nó chạm tới hệ thống thật.

```python
from claude_agent_sdk import tool
import httpx

@tool(
    "get_temperature",
    "Lấy nhiệt độ hiện tại theo toạ độ",
    {"latitude": float, "longitude": float},
)
async def get_temperature(args):
    async with httpx.AsyncClient() as client:
        resp = await client.get(
            "https://api.open-meteo.com/v1/forecast",
            params={"latitude": args["latitude"], "longitude": args["longitude"],
                    "current_weather": True},
        )
    return {"content": [{"type": "text", "text": resp.text}]}
```

- **MCP** (Model Context Protocol) là một chuẩn giao tiếp mở để "cắm" tool/dữ liệu ngoài vào agent — một **MCP server** là một process độc lập expose sẵn một tập tool theo chuẩn đó, agent chỉ cần kết nối tới thay vì tự viết code gọi API.
- Tool `get_temperature` ở trên được gom vào một **SDK MCP server** chạy in-process (không phải server riêng), tên đầy đủ dạng `mcp__{server_name}__{tool_name}`, và phải được liệt kê rõ trong `allowedTools` mới được gọi mà không hỏi permission — tức allowlist tường minh, không mặc định cấp quyền.
- Ngoài custom tool tự viết, SDK còn kết nối tới MCP server ngoài qua 3 transport (stdio, HTTP, SSE) để chạm tới API tuỳ ý (GitHub, Slack, database, REST/GraphQL nội bộ) mà không cần tự viết code gọi API — xem thêm [[agent-what-are-tools]].

## 4. Ba mối lo sản xuất (production concerns)

### 4.1 Auth / credential handling

- **Nguyên tắc cốt lõi**: model không bao giờ nên thấy secret thật — nó chỉ thấy schema tham số của tool và kết quả trả về, còn credential được tiêm ở tầng transport/config, ngoài turn của model.
- Trong Claude Agent SDK, API key/token được truyền qua field `env` của MCP server (stdio) hoặc header HTTP (`Authorization: Bearer ${API_TOKEN}`) tại lúc cấu hình server, không nằm trong input schema mà model nhìn thấy.
- Với OAuth2 cho remote MCP server, SDK **không tự chạy flow OAuth** — ứng dụng của developer phải tự hoàn tất OAuth và chỉ truyền access token qua header; nếu chưa có token, server báo `needs-auth` và agent tiếp tục mà không có tool đó.
- Pattern công nghiệp rộng hơn gọi là **credential broker / proxy gateway**: tool call của agent chỉ mang một placeholder/identifier, một component riêng biệt (broker/gateway) mới thay vào credential thật khi request egress ra ngoài — agent chưa từng cầm secret thật trong tay.
- Pattern này đang được chuẩn hoá qua draft IETF "Credential Broker 4 Agents" (as of 2026-03, confidence: low — draft mới công bố, chưa rõ mức độ áp dụng thực tế trong ngành).

### 4.2 Rate limiting

- OWASP API Security Top 10 (2023) xếp thiếu rate limiting vào nhóm **Broken Authentication (API2:2023)**, khuyến nghị rate limit chặt hơn bình thường cho các endpoint nhạy cảm — cơ sở lý do vì sao tool gọi API thật (có thể tạo side-effect, tốn tiền, hoặc bị lạm dụng để DoS hệ thống ngoài) cần giới hạn tần suất gọi.
- MCP tool result trong Agent SDK còn bị giới hạn dung lượng đầu ra (mặc định 25.000 token qua `MAX_MCP_OUTPUT_TOKENS`); response quá lớn được lưu ra file và trả về error kèm đường dẫn — một biện pháp bảo vệ vận hành khác cho các API có thể trả payload không giới hạn kích thước.

### 4.3 Validate / sanitize tham số do model tạo ra

- JSON Schema chỉ đảm bảo tham số **đúng cấu trúc** (đúng type, đúng field bắt buộc) — nó **không** đảm bảo tham số đó *hợp lý về mặt nghiệp vụ*.
  - Ví dụ: schema chấp nhận `amount: 999999999` là số hợp lệ, nhưng đó có thể là một giao dịch thanh toán sai lệch tai hại. Validate nghiệp vụ (giới hạn amount, kiểm tra customer tồn tại...) phải nằm ở code handler, sau bước validate schema.
- Ví dụ cụ thể trong Agent SDK: MCP server DBHub (Postgres) có cờ cấu hình `readonly = true` chặn cứng mọi câu lệnh INSERT/UPDATE/DELETE/DDL ở tầng server, **bất kể** model sinh ra SQL gì — ràng buộc được đặt ở biên tool-server, không tin tưởng hoàn toàn vào model.
- OWASP LLM Top 10 (2026) xếp **Excessive Agency** vào top 3 rủi ro, với 3 nguyên nhân gốc liên quan trực tiếp tới API request tool:
  - *Excessive functionality*: tool làm được nhiều hơn mục đích công bố (ví dụ tool "đọc doc" nhưng lại có quyền xoá).
  - *Excessive permissions*: credential được cấp quyền UPDATE/DELETE trong khi feature chỉ cần đọc.
  - *Excessive autonomy*: hành động không thể đảo ngược được thực thi mà không cần con người duyệt.
- Best practice từ Stripe Agent Toolkit: chỉ bọc một **tập con nhỏ, có chủ đích** của API thật (không expose toàn bộ Stripe API). Lý do: càng nhiều tool, xác suất model chọn nhầm tool càng cao — đây vừa là biện pháp UX vừa là biện pháp an toàn.

## 5. Ví dụ thực tế: Stripe Agent Toolkit

| Thành phần | Vai trò |
|---|---|
| Endpoint thật | Stripe REST API (tạo payment link, quản lý subscription, billing) |
| Tool wrapper | Một tập con nhỏ các hàm/tool (không phải toàn bộ Stripe API) |
| Framework hỗ trợ | OpenAI Agent SDK, LangChain, CrewAI, Vercel AI SDK, MCP |
| Input model tạo ra | Ví dụ: "tạo payment link cho khách hàng mới" → agent tự điền tham số amount, currency, customer_id... |
| Nơi chạy request thật | Server-side, dùng Stripe secret key — agent không cầm key |

## Nguồn & độ tin cậy

Các claim dưới đây có mức độ chắc chắn khác nhau tuỳ nguồn — gom lại một chỗ thay vì chú thích rải rác trong bài:

| Claim | Nguồn | Độ tin cậy |
|---|---|---|
| Phân loại client tool / server tool | platform.claude.com/docs | high |
| ReAct / Toolformer là tiền thân học thuật của tool-calling | arxiv.org/abs/2210.03629, arxiv.org/abs/2302.04761 | medium |
| Pattern credential broker / proxy gateway | blog.christianposta.com | medium |
| JSON Schema không đảm bảo tính hợp lý nghiệp vụ | anthropic.com/engineering/advanced-tool-use | medium |
| Taxonomy Excessive Agency (OWASP LLM Top 10) | reversinglabs.com | medium |
| Framing "RAG = đọc, tool calling = làm" | pontil.com/blog/rag-vs-tool-calling | medium |

## Liên hệ tới các phần khác

- So với [[agent-tools-web-search]]: web search là một trường hợp đặc biệt của API request tool, thường được cấp dưới dạng **server tool** hosted sẵn (Anthropic tự chạy search), trong khi API request tool tổng quát hầu như luôn là **client tool** do developer tự viết logic gọi và tự giữ credential.
- So với [[agent-tools-database-queries]]: database query cũng là một dạng đặc biệt — "API" ở đây là driver/connection tới DB nội bộ thay vì HTTP endpoint bên ngoài; các mối lo về validate tham số (chặn DELETE/UPDATE khi không cần) và auth (connection string ngoài schema) giống hệt nhau.
- Một cách nhìn ngắn gọn: **RAG** là cách agent "đọc" (lấy thông tin để grounding), còn **tool/API calling** là cách agent "làm" (tạo hành động thật hoặc lấy dữ liệu sống ngoài mọi index có sẵn).

### Áp dụng với Claude Code

- Claude Code (CLI) không cho người dùng tự khai báo một "API request tool" tuỳ ý kiểu low-level `input_schema` như khi dùng trực tiếp Messages API hay Agent SDK.
- Thay vào đó, Claude Code chạm tới API bên ngoài chủ yếu qua **MCP server** cấu hình trong `.claude.json`/`.mcp.json` — mỗi MCP server đã tự đóng gói sẵn các tool gọi API thật (ví dụ MCP server cho GitHub, Slack, Notion...), Claude Code chỉ là client gọi các tool đó qua giao thức MCP.
- Việc giữ credential cũng nằm ngoài phạm vi model: API key/token được cấu hình trong config của MCP server (biến môi trường, header), Claude Code không tự sinh hay hiển thị credential thật cho model.
- Với các tác vụ kiểu HTTP request đơn giản không qua MCP, Claude Code CLI dùng công cụ `Bash`/`curl` như một escape hatch chung — lúc này việc validate/sanitize tham số hoàn toàn phụ thuộc vào permission system (allow/deny rule, PreToolUse hook) chứ không có input schema chuyên biệt như một custom tool trong Agent SDK.

## Giới hạn / open questions

- Chưa có ví dụ đo lường cụ thể (số liệu thật) về hiệu quả của credential-broker pattern trong production — các nguồn hiện tại (blog, draft IETF) mới ở mức mô tả pattern, chưa có case study định lượng.
- Draft IETF "Credential Broker 4 Agents" (CB4A) mới công bố 2026-03, chưa rõ mức độ được ngành áp dụng rộng rãi hay chỉ là đề xuất ban đầu.
- Chưa rõ Claude Code CLI có roadmap cho phép định nghĩa custom tool gọi API trực tiếp (không qua MCP server) như Agent SDK hay không — cần kiểm tra changelog tương lai.
- Câu hỏi mở về rate limiting: tài liệu Agent SDK mô tả giới hạn output token của MCP tool result, nhưng không thấy cơ chế rate-limit số lần gọi tool có sẵn "out of the box" — có vẻ đây vẫn là trách nhiệm của MCP server/API đích, chưa kiểm chứng kỹ.
