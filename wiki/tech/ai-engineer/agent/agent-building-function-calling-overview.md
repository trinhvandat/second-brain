---
status: current
updated: 2026-08
sources:
  - https://openai.com/index/function-calling-and-other-api-updates/
  - https://developers.openai.com/api/docs/guides/function-calling
  - https://platform.claude.com/docs/en/agents-and-tools/tool-use/overview
  - https://platform.claude.com/docs/en/agents-and-tools/tool-use/define-tools
  - https://platform.claude.com/docs/en/agent-sdk/permissions
  - https://platform.claude.com/docs/en/agent-sdk/hooks
  - https://platform.claude.com/docs/en/managed-agents/overview
  - https://platform.claude.com/docs/en/agents-and-tools/tool-use/tool-runner
  - https://ai.google.dev/gemini-api/docs/function-calling
  - https://www.emergentmind.com/topics/toolformer
  - https://getstream.io/blog/rag-function-calling/
  - https://www.k2view.com/blog/llm-function-calling/
roadmap: ai-engineer
stage: learning
---

# Function calling (LLM-native) — model tự quyết định khi nào gọi tool, thay vì developer hard-code luồng gọi

TL;DR: Function calling là cơ chế để developer khai báo trước một danh sách "tools" (dạng JSON-schema), rồi **để chính model quyết định** có cần gọi tool nào không, gọi tool nào, và gọi với argument gì — model không tự chạy code, mà chỉ trả về một "yêu cầu gọi hàm" có cấu trúc để ứng dụng thực thi và trả kết quả lại.

## Vấn đề nó giải quyết

- Trước function calling: muốn LLM "dùng dữ liệu ngoài" thì developer phải tự viết logic if/else để quyết định khi nào gọi API nào (workflow tĩnh, hard-code).
- Function calling native: quyết định "có cần gọi tool không, tool nào, argument gì" được **đẩy vào chính model**, dựa trên ngữ cảnh hội thoại + mô tả (`description`) của từng tool.
- Đây chính là phần "model-driven" trong vòng lặp agent — xem thêm [[agent-tool-definition]] (cách khai báo tool) và [[agent-acting-tool-invocation]] (bước "acting" trong agent loop dùng kết quả này).

## Cơ chế chung (provider-agnostic)

4 bước, giống nhau ở cả OpenAI, Anthropic, Gemini:

1. **Khai báo tool**: developer gửi kèm request một danh sách tool, mỗi tool có `name`, `description`, và `parameters`/`input_schema` dạng JSON Schema (kiểu, field bắt buộc, v.v.)
2. **Model trả về lời gọi có cấu trúc**: thay vì (hoặc kèm theo) văn bản thường, response chứa một object dạng "gọi tool X với argument Y" — không phải code, chỉ là dữ liệu JSON.
3. **Ứng dụng (không phải model) thực thi hàm thật**: model **không bao giờ tự chạy code** — nó chỉ đề xuất lời gọi; developer/framework mới là bên thực thi.
4. **Kết quả được gửi lại cho model** trong lượt tiếp theo, model tổng hợp kết quả đó vào câu trả lời cuối cùng (hoặc gọi tiếp một tool khác).

Timeline (chỉ để biết bối cảnh, không bắt buộc đọc kỹ):
- OpenAI công bố function calling ngày 13/6/2023 (blog "Function calling and other API updates"), thêm vào `gpt-4-0613`/`gpt-3.5-turbo-0613`.
- Về học thuật, ý tưởng này từng xuất hiện sớm hơn trong Toolformer (Schick et al., NeurIPS 2023, as of emergentmind.com, confidence: medium) — một cách huấn luyện self-supervised để model tự học dùng tool từ vài ví dụ minh hoạ. OpenAI là bên đầu tiên đưa nó thành tính năng API sản xuất.

## Ví dụ minh hoạ

Giả sử tool `get_weather(location, unit)` được khai báo:

```json
{
  "name": "get_weather",
  "description": "Get current weather for a location",
  "parameters": {
    "type": "object",
    "properties": {
      "location": { "type": "string" },
      "unit": { "type": "string", "enum": ["celsius", "fahrenheit"] }
    },
    "required": ["location"]
  }
}
```

User hỏi: "Hà Nội hôm nay nóng không?" → model không trả lời trực tiếp mà trả về:

```json
{ "name": "get_weather", "arguments": "{\"location\": \"Hanoi\", \"unit\": \"celsius\"}" }
```

Ứng dụng gọi API thời tiết thật với `location=Hanoi`, nhận kết quả (vd `32°C`), gửi lại cho model trong turn kế tiếp → model trả lời cuối: "Hà Nội hôm nay 32°C, khá nóng."

## Điểm chung giữa các provider

| Khía cạnh | OpenAI | Anthropic (Claude) | Gemini |
|---|---|---|---|
| Tên gọi | "function calling" | "tool use" | "function calling" |
| Field khai báo | `parameters` (JSON Schema) | `input_schema` | `parameters` (OpenAPI-like) |
| Model output khi gọi tool | item `function_call` (call_id, name, arguments) | content block `tool_use` (id, name, input), `stop_reason: "tool_use"` | trả `name` + `args`, không tự chạy |
| Gửi kết quả lại | request mới có tool output | content block `tool_result` gắn `tool_use_id` | gửi kết quả lại cho model |

Cả 3 đều tuân theo đúng 4 bước ở trên — khác biệt chủ yếu nằm ở tên field và chi tiết API.

## Điểm khác biệt giữa các provider

_Phần dưới đây là tài liệu tra cứu (reference) — lướt qua lần đầu, quay lại khi cần so field cụ thể của từng provider._

**Parallel tool calls** (model gọi nhiều tool trong cùng 1 turn):
- OpenAI: mặc định bật cho model GPT-5+ khi chỉ dùng function tools; tắt bằng `parallel_tool_calls: false`.
- Anthropic: mặc định cho phép nhiều `tool_use` block trong 1 turn; tắt bằng `disable_parallel_tool_use: true`.
- Gemini: gọi riêng là "parallel function calling" (nhiều hàm độc lập cùng lúc), phân biệt với "compositional function calling" (hàm sau dùng output của hàm trước, tuần tự).

**Forced/required tool choice** (ép model phải gọi tool):
- OpenAI `tool_choice`: `auto` (mặc định) / `required` (bắt buộc gọi ít nhất 1 tool, model tự chọn) / ép cụ thể 1 tool bằng `{"type":"function","name":...}` / `none`. Có thêm `allowed_tools` để giới hạn tập con tool được phép gọi mà vẫn giữ prompt caching.
- Anthropic `tool_choice`: `auto` / `any` (bắt buộc dùng 1 trong các tool, model tự chọn) / `tool` (ép đúng 1 tool cụ thể) / `none`. Khi ép (`any`/`tool`), Claude sẽ không kèm giải thích bằng lời trước khi gọi tool.
- Gemini: `function_calling_config.mode` = `AUTO` / `ANY` (bắt buộc luôn trả function call) / `NONE`.

Ví dụ khác biệt cụ thể (Anthropic), `auto` để model tự quyết định có gọi tool hay không:
```json
{ "tool_choice": { "type": "auto" } }
```
so với `any` — ép Claude phải gọi 1 trong các tool đã khai báo, không được chỉ trả lời bằng text:
```json
{ "tool_choice": { "type": "any" } }
```

**Streaming tool calls** (khi bật `stream: true`, argument JSON đến theo từng phần, client phải tự ghép các mảnh lại thành 1 chuỗi JSON hợp lệ trước khi parse và thực thi):
- OpenAI: chuỗi event `response.output_item.added` (bắt đầu 1 tool call mới) → nhiều `response.function_call_arguments.delta` (mỗi event mang 1 mảnh string, ví dụ `"{\"locat"`, rồi `"ion\": \""`, rồi `"Hanoi\"}"`) → `response.function_call_arguments.done` (mang toàn bộ JSON string đã ghép đủ, sẵn sàng `JSON.parse`).
- Anthropic: tương tự — nhiều `content_block_delta` với `partial_json` (từng mảnh string) dưới cùng 1 `content_block` loại `tool_use`, kết thúc bằng `content_block_stop`; client tự nối các `partial_json` lại rồi parse.
- Gemini: `step.delta` với `partial_arguments`, cần aggregate client-side theo cách tương tự.
- Điểm chung: không có provider nào gửi JSON đã parse sẵn qua stream — luôn là string được cắt nhỏ, code của bạn phải tự nối và `JSON.parse` sau khi nhận event "done"/"stop".

**Riêng của Anthropic** — phân biệt **client tools** (tool do developer định nghĩa, ứng dụng của developer thực thi — đúng như function calling cổ điển) và **server tools** (`web_search`, `code_execution`... chạy ngay trên hạ tầng Anthropic, không cần round-trip `tool_result`) — khái niệm này OpenAI/Gemini không có tương đương trực tiếp.

## So sánh với các cách "cấp context" khác

- **Plain LLM call**: model trả lời chỉ từ tham số đã huấn luyện, không có dữ liệu ngoài, bị giới hạn bởi training cutoff.
- **RAG**: bước "tra cứu" được **hard-code sẵn trong pipeline**, luôn chạy bất kể câu hỏi có cần hay không; model chỉ đọc context được nhét vào prompt, không tự quyết định có cần tra cứu hay không.
- **Function calling**: model là bên **chủ động quyết định** có cần gọi tool không, gọi tool nào — và tool không chỉ để đọc dữ liệu (retrieval) mà còn để **thực hiện hành động** (gửi email, đặt hàng, lấy dữ liệu real-time).
- Workflow tĩnh (linear, mọi bước hard-code sẵn) khác agent loop ở chỗ: agent loop dùng chính function calling native này để model tự quyết định bước tiếp theo tại runtime, thay vì developer định sẵn thứ tự.

## Liên hệ tới các phần khác

- [[agent-tool-definition]] mô tả chi tiết cách viết schema cho 1 tool (input); note này là "cơ chế nền" khiến schema đó thực sự được model dùng để quyết định gọi hay không.
- [[agent-acting-tool-invocation]] mô tả bước "acting" trong agent loop — chính là bước 2-3 ở trên (model output structured call → app execute) nhìn từ góc độ vòng lặp agent.
- Các note nhánh theo provider (OpenAI, Gemini, Anthropic function-calling implementation) sẽ đào sâu API cụ thể từng hãng dựa trên bảng so sánh ở trên.

### Áp dụng với Claude Code

- Claude Code (CLI) dùng đúng cơ chế Messages API tool-use làm nền, nhưng **tự động hoá toàn bộ vòng lặp round-trip** cho người dùng — developer không phải tự viết code gửi `tool_result` lại (as of nguồn cộng đồng augmentcode.com, confidence: medium — nên đối chiếu thêm docs chính thức khi cần chắc chắn 100%).
- Claude Code có sẵn 20+ built-in tool (bash, file edit...) đã pre-wired sẵn implementation — quyết định "khi nào gọi" vẫn do model quyết, nhưng lớp "thực thi" phần lớn do CLI/SDK cung cấp sẵn thay vì code tự viết.
- Khác biệt quan trọng: Claude Code **không** thực thi ngay lời gọi tool của model. Nó chèn thêm một lớp permission/hook ở giữa bước 2 và bước 3 của cơ chế chung ở trên:
  1. Model trả về structured tool call (giống bước 2 ở trên).
  2. `PreToolUse` hook chạy trước — có thể chặn.
  3. Deny rules → permission mode → allow rules được áp dụng theo thứ tự.
  4. Callback `canUseTool` (nếu có) quyết định cuối cùng có cho chạy hay không.
  5. Tool mới thực sự chạy (bước 3 ở cơ chế chung) → `PostToolUse` hook chạy sau khi xong.
  Đây là phần mở rộng riêng của Claude Code, không nằm trong mô tả function-calling chung ở trên.
- Anthropic cũng cung cấp các lựa chọn ở giữa "raw Messages API" và "agent loop tự động hoàn toàn" như Managed Agents và "Tool Runner" SDK helper (tự động chạy tool + gửi `tool_result`) — cho thấy một dải lựa chọn về mức độ developer tự quản lý loop.

## Giới hạn / open questions

- Chưa kiểm chứng trực tiếp được nội dung bài "A Comprehensive Guide to Function Calling in LLMs" (thenewstack.io) — WebFetch chỉ trả về khung trang/nav, không lấy được nội dung bài viết; các claim liên quan không được dùng trong note này.
- Chưa đào sâu chi tiết API cụ thể từng provider (request/response mẫu đầy đủ, edge case lỗi khi model trả JSON không hợp lệ, retry strategy) — để dành cho các note nhánh theo provider.
- Chưa rõ số liệu chính xác về overhead token khi bật tool (Anthropic có đề cập tool_choice khác nhau tốn token hệ thống khác nhau nhưng chưa có con số cụ thể).
- Chưa kiểm chứng độc lập các claim từ nguồn thứ cấp (augmentcode.com) về Claude Agent SDK — nên đối chiếu thêm với docs chính thức khi viết note sâu hơn về Claude Code tool execution.
