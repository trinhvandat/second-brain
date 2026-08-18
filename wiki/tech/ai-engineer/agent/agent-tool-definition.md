---
status: current
updated: 2026-08
sources:
  - https://huggingface.co/learn/agents-course/en/unit1/tools
  - https://platform.claude.com/docs/en/agents-and-tools/tool-use/overview
  - https://platform.claude.com/docs/en/agents-and-tools/tool-use/define-tools
  - https://platform.claude.com/docs/en/agents-and-tools/tool-use/tool-reference
  - https://platform.claude.com/docs/en/agents-and-tools/tool-use/strict-tool-use
  - https://platform.claude.com/docs/en/agents-and-tools/tool-use/handle-tool-calls
  - https://developers.openai.com/api/docs/guides/function-calling
  - https://openai.com/index/function-calling-and-other-api-updates/
  - https://modelcontextprotocol.io/specification/2025-11-25/server/tools
  - https://code.claude.com/docs/en/agent-sdk/custom-tools
  - https://www.anthropic.com/engineering/writing-tools-for-agents
  - https://arxiv.org/abs/2210.03629
  - https://arxiv.org/pdf/2302.04761
  - https://arxiv.org/html/2602.14878v1
roadmap: ai-engineer
stage: learning
---

# Tool Definition — bản hợp đồng tĩnh (name + description + schema) mô tả một tool, được viết trước khi agent chạy

**TL;DR**: **Tool Definition** là đặc tả tĩnh của một tool — gồm **name** (định danh), **description** (văn bản tự nhiên giải thích tool làm gì và **khi nào nên dùng** — chính là thứ model đọc để quyết định có gọi hay không), và **input/output schema** (quy định tham số nào, kiểu gì, ràng buộc gì — quyết định một lời gọi có "hợp lệ" để thực thi hay không). Nó khác với bước **Acting/Tool Invocation** trong agent loop: definition là bản thiết kế được author **trước**, invocation là hành động gọi tool diễn ra **tại runtime**.

## 1. Ba thành phần cốt lõi

- **Name** — định danh duy nhất, model dùng để "gọi tên" tool. Anthropic quy định dạng chuỗi khớp regex `^[a-zA-Z0-9_-]{1,64}$`.
- **Description** — mô tả bằng ngôn ngữ tự nhiên, giải thích tool làm gì, **khi nào nên/không nên dùng**, và hành vi/side-effect nếu có. Đây là phần duy nhất model dùng để quyết định **WHEN to call** — không phải code, không phải comment nội bộ.
- **Input schema** (thường là JSON Schema) — tên tham số, kiểu dữ liệu, ràng buộc (required, enum, format...). Đây là phần quyết định lời gọi có **well-formed** để thực thi hay không, độc lập với việc gọi đúng lúc hay sai lúc.
- **Output/output schema** (tuỳ provider, thường tuỳ chọn) — mô tả kết quả trả về.

Ba (hoặc bốn) phần này hội tụ gần như y hệt giữa các nhà cung cấp lớn — cho thấy đây là chuẩn thiết kế chung, không riêng một hãng:

| Provider | Name | Description | Schema |
|---|---|---|---|
| Anthropic (Claude) | `name` | `description` | `input_schema` |
| OpenAI | `name` | `description` | `parameters` |
| MCP | `name` | `description` | `inputSchema` / `outputSchema` |
| Claude Agent SDK (custom tool) | `name` | `description` | Zod schema (TS) / dict (Python) → converted to JSON Schema |

## 2. Description quyết định "WHEN", schema quyết định "well-formed hay không"

- Anthropic nói thẳng: Claude quyết định có gọi tool hay không "dựa trên yêu cầu của user và **mô tả của tool**" — description là input duy nhất cho quyết định gọi/không gọi (as of platform.claude.com/tool-use/overview, confidence: high).
- Anthropic còn khẳng định description **"là yếu tố quan trọng nhất quyết định hiệu năng tool"**, khuyến nghị tối thiểu 3-4 câu, giải thích rõ tool làm gì, khi nào nên/không nên dùng, ý nghĩa từng tham số, và các trường hợp cạnh (as of platform.claude.com/tool-use/define-tools, confidence: high).
- OpenAI đưa ra tiêu chí thực dụng gọi là **"intern test"**: liệu một thực tập sinh mới có thể dùng đúng function chỉ dựa vào name + description + schema (không có gì khác) hay không — nếu không, description chưa đủ rõ. OpenAI cũng khuyến nghị dùng `enum` để ràng buộc tham số mơ hồ thay vì để free-text.
- Ngược lại, schema (JSON Schema) không quyết định model có **muốn** gọi tool hay không — nó chỉ đảm bảo nếu model **đã quyết định gọi**, thì input phát ra đúng kiểu/đúng field bắt buộc. Anthropic có cờ `strict: true` (Strict tool use mode) để ép output luôn khớp chính xác schema — tách bạch rõ 2 mối quan tâm: "có nên gọi" (description) vs "gọi có hợp lệ" (schema).
- Bằng chứng học thuật: một nghiên cứu về MCP tool description "smelly" (mơ hồ, dài dòng, thiếu gợi ý sử dụng) cho thấy chất lượng description ảnh hưởng đo lường được tới độ chính xác chọn tool của agent (as of arxiv.org/html/2602.14878v1, confidence: medium).

## 3. Cơ chế: definition được "tiêm" vào context như thế nào

- Khi gọi API với tham số `tools`, Claude tự dựng một system prompt ẩn nhúng toàn bộ tool definitions dưới dạng JSON Schema — dạng "Here are the functions available in JSONSchema format: {{TOOL DEFINITIONS}}" — được chèn **trước** system prompt riêng của ứng dụng (as of platform.claude.com/tool-use/define-tools, confidence: high).
- MCP nhấn mạnh cùng một điểm: description trong tool definition **không phải comment code cho dev đọc** — nó literally trở thành một phần prompt context của LLM, ví như "cuốn sổ tay hướng dẫn dành cho AI" (as of modelcontextprotocol.io/specification, confidence: high).
- Nói cách khác: Tool Definition không phải tài liệu tĩnh nằm ngoài luồng — nó **là một phần của prompt** mỗi khi model xử lý một lượt có tool khả dụng. Điều này giải thích tại sao chất lượng viết definition quan trọng ngang chất lượng viết prompt.

## 4. Ví dụ cụ thể

Ví dụ tối giản từ tài liệu Anthropic:

```json
{
  "name": "get_weather",
  "description": "Get the current weather for a given location.",
  "input_schema": {
    "type": "object",
    "properties": {
      "location": {
        "type": "string",
        "description": "City and state, e.g. San Francisco, CA"
      }
    },
    "required": ["location"]
  }
}
```

So sánh description "tốt" vs "kém" (theo hướng dẫn thực hành của Anthropic/OpenAI):

| | Kém | Tốt |
|---|---|---|
| Nội dung | "Gets the stock price for a ticker." | "Get the current stock price for a given ticker symbol. Use this when the user asks about a specific stock's price, market cap, or trading volume. Does NOT provide historical data — use get_historical_price for that." |
| Vấn đề | Không rõ khi nào dùng, không phân biệt với tool tương tự | Nêu rõ use case, loại trừ nhầm lẫn với tool khác, giúp model chọn đúng tool giữa nhiều lựa chọn tương tự |

Ví dụ trong Claude Agent SDK (TypeScript), mô tả gắn cả ở cấp field, không chỉ cấp tool:

```ts
tool({
  name: "get_weather",
  description: "Get current weather for a location",
  inputSchema: z.object({
    lat: z.number().describe("Latitude coordinate"),
    lon: z.number().describe("Longitude coordinate"),
  }),
  handler: async (input) => { /* runtime — KHÔNG thuộc definition */ },
})
```
`.describe()` trên từng field cũng được đưa vào JSON Schema gửi cho model — nghĩa là mô tả ở cấp tham số cũng ảnh hưởng tới việc model điền đúng giá trị, không chỉ mô tả cấp tool.

## 5. Nguyên tắc thiết kế thực hành (Anthropic engineering)

- **Namespace tên tool theo domain** khi có nhiều tool cùng lĩnh vực, tránh model nhầm lẫn (ví dụ `github_list_prs`, `slack_send_message` thay vì `list_prs`, `send_message`).
- **Đặt tên tham số không mơ hồ** — ưu tiên `user_id` hơn `user`.
- **Gộp các thao tác liên quan thành ít tool hơn, mỗi tool nhận tham số `action`** thay vì tạo nhiều tool hẹp riêng lẻ — giảm mơ hồ khi model phải chọn giữa nhiều tool tương tự.
- **Viết description như giải thích cho một đồng nghiệp mới (new hire)** — làm rõ ngữ cảnh ngầm định (định dạng query, thuật ngữ chuyên ngành, quan hệ giữa các resource) mà nếu không viết ra, model sẽ đoán sai.
- Ưu tiên description chi tiết hơn là `input_examples`; chỉ thêm ví dụ cho tool có schema phức tạp/nhạy định dạng, vì examples tốn thêm token trong context (~20-50 token cho ví dụ đơn giản, ~100-200 cho ví dụ phức tạp) — cho thấy độ đầy đủ của definition bị đánh đổi trực tiếp với ngân sách context.

## 6. Gốc lịch sử

- Chuẩn "name + description + JSON-schema parameters" bắt nguồn từ **function calling** của OpenAI, ra mắt 13/6/2023 (`gpt-4-0613`, `gpt-3.5-turbo-0613`) — model được fine-tune để tự nhận diện lúc nào cần gọi function và sinh JSON arguments khớp schema (as of openai.com/index/function-calling-and-other-api-updates, confidence: medium). Đây là tiền thân trực tiếp của `input_schema` bên Anthropic và `inputSchema` bên MCP.
- Tiền thân học thuật xa hơn: **ReAct** (Yao et al., 2022, arXiv:2210.03629) thiết lập ý tưởng "action space" — hành động rời rạc gọi tới API/môi trường ngoài — nhưng chưa hình thức hoá thành contract name/description/schema. **Toolformer** (Schick et al., 2023, arXiv:2302.04761) là minh chứng sớm cho việc model có thể tự học chọn API/tham số dựa trên mô tả văn bản trong ngữ cảnh — báo trước nguyên tắc "description dạy model khi nào/cách nào gọi tool" của các chuẩn tool-use hiện nay.

## Liên hệ tới các phần khác

- [[agent-what-are-tools]] — khái niệm tool nói chung (tại sao agent cần tool, các loại tool phổ biến); note này đào sâu riêng phần **đặc tả tĩnh** của một tool.
- [[agent-acting-tool-invocation]] — bước runtime thực thi tool (tool_use → chạy thật → tool_result); Tool Definition chỉ là **input** cho bước này, không phải bản thân hành động gọi.
- [[agent-loop]] — Tool Definition được nạp vào context ở đầu mỗi vòng lặp, còn "Act/invoke tool" mới là bước dùng nó.

### Áp dụng với Claude Code

- Built-in tools của Claude Code (Bash, Read, Edit, Grep...) đều tuân theo đúng contract name + description + input_schema như Messages API — nhưng các definition này được **hard-code sẵn trong harness**, người dùng CLI không tự viết/sửa được description hay schema của chúng qua giao diện CLI thông thường.
- Với **MCP server** (kết nối qua `claude mcp add` hoặc config), definition của mỗi tool do MCP server author và expose ra — Claude Code chỉ đọc và tiêm vào context, không kiểm soát nội dung description.
- Với **Claude Agent SDK** (không phải CLI thuần, mà lớp SDK để build agent tuỳ biến), dev có toàn quyền viết custom tool definition qua `tool()` helper: name, description, input schema (Zod/JSON Schema) — đúng như phần 4 ở trên. Đây là nơi nguyên tắc thiết kế ở mục 5 áp dụng trực tiếp.
- Agent SDK còn có cơ chế **tool search / deferred loading** (bật mặc định): thay vì nhồi full definition của mọi tool vào context mỗi lượt, model chỉ thấy danh sách tên rút gọn và load schema đầy đủ khi cần — một tối ưu kỹ thuật xác nhận rằng bản thân Tool Definition (không chỉ lời gọi) tiêu tốn token/context thật.
- Claude Code CLI (giao diện dòng lệnh) không expose cơ chế chỉnh sửa Tool Definition trực tiếp cho built-in tools — nếu muốn tuỳ biến definition, phải đi qua MCP server hoặc Agent SDK.

## Giới hạn / open questions

- Chưa có công thức định lượng cho "description bao nhiêu là đủ" — Anthropic chỉ khuyến nghị định tính ("3-4 câu trở lên"), chưa rõ ngưỡng nào gây phản tác dụng (quá dài → tốn context, loãng tín hiệu).
- Mức độ chuẩn hoá `output`/`outputSchema` giữa các provider còn yếu — phần lớn tài liệu tập trung vào input schema, output schema thường là tuỳ chọn, chưa rõ tác động thực tế của việc thiếu chuẩn này lên độ tin cậy của agent.
- Annotation kiểu MCP (`readOnlyHint`, `destructiveHint`, `idempotentHint`, `openWorldHint`) là metadata khai báo trên definition nhưng **không được enforce** — chưa rõ mức độ các harness khác nhau (ngoài Claude Agent SDK) có tôn trọng các hint này khi lập lịch/song song hoá tool call hay không.
- Tác động cụ thể của "smelly description" lên độ chính xác chọn tool (theo arxiv.org/html/2602.14878v1) mới ở mức nghiên cứu ban đầu, chưa rõ có benchmark chuẩn hoá rộng rãi trong ngành hay không.
