---
status: current
updated: 2026-08
sources:
  - https://developers.openai.com/api/docs/guides/function-calling
  - https://developers.openai.com/api/docs/guides/structured-outputs
  - https://developers.openai.com/api/docs/deprecations
  - https://developers.openai.com/api/docs/guides/migrate-to-responses
  - https://developers.openai.com/api/reference/resources/chat/subresources/completions/methods/create
  - https://cookbook.openai.com/examples/how_to_call_functions_with_chat_models
  - https://openai.com/index/introducing-structured-outputs-in-the-api/
  - https://openai.com/index/function-calling-and-other-api-updates/
  - https://platform.claude.com/docs/en/agents-and-tools/tool-use/overview
  - https://code.claude.com/docs/en/agent-sdk/overview
roadmap: ai-engineer
stage: learning
---

# OpenAI Functions Calling — cách OpenAI hiện thực function calling qua Chat Completions và Responses API

TL;DR: OpenAI khai báo tool trong mảng `tools` (`type: "function"` + `name`/`description`/`parameters` JSON Schema), model trả về lời gọi có cấu trúc (`tool_calls` trong Chat Completions, hoặc `function_call` item trong Responses API), ứng dụng thực thi rồi gửi kết quả về bằng message `role: "tool"` (Chat Completions) hoặc item `function_call_output` (Responses API) — đây là phần cụ thể-theo-provider của [[agent-building-function-calling-overview]], khác Anthropic chủ yếu ở **shape API gửi kết quả về**.

## Hai API song song: Chat Completions vs Responses

OpenAI hiện có 2 API hỗ trợ function calling, khác nhau ở shape request/response:

| Khía cạnh | Chat Completions (cũ hơn, vẫn được hỗ trợ) | Responses API (mới, khuyến nghị) |
|---|---|---|
| Model trả lời gọi tool | `message.tool_calls[]`, mỗi phần tử có `id`, `type: "function"`, `function: {name, arguments}` | item trong mảng `output` có `type: "function_call"`, gồm `call_id`, `name`, `arguments` |
| Gửi kết quả về | message mới `role: "tool"`, `tool_call_id` khớp `id` ở trên, `content` là kết quả | item `type: "function_call_output"`, `call_id` khớp `call_id` ở trên, `output` là kết quả, append vào mảng `input` |
| Cấu trúc state | mảng `messages` (list các message có role) | mảng `input` tích lũy (accumulating input list), không phải "message list" theo nghĩa chat truyền thống |

- Docs chính thức hiện dùng Responses API làm ví dụ chính, coi đây là API kế nhiệm; Chat Completions vẫn là bề mặt hợp lệ, riêng biệt, với shape `tool_calls`/`role: "tool"` của chính nó.
- Assistants API (cũng có function calling) đã bị deprecate, dự kiến ngừng hoạt động 26/8/2026 — không nên dùng cho code mới.

## Khai báo tool (`tools` array)

Mỗi tool có `type: "function"`, kèm `name`, `description`, `parameters` (JSON Schema); có thể thêm `strict: true`.

```json
{
  "type": "function",
  "name": "get_weather",
  "description": "Get current weather for a location",
  "parameters": {
    "type": "object",
    "properties": {
      "location": { "type": "string" },
      "unit": { "type": "string", "enum": ["celsius", "fahrenheit"] }
    },
    "required": ["location", "unit"],
    "additionalProperties": false
  },
  "strict": true
}
```

## Vòng round-trip theo từng API

**Responses API:**
1. Gọi `client.responses.create()` với `input` + `tools`.
2. Model trả `output` chứa item `type: "function_call"` với `call_id`, `name`, `arguments` (chuỗi JSON).
3. Ứng dụng thực thi hàm, rồi append vào `input` một item `{"type": "function_call_output", "call_id": ..., "output": "<kết quả dạng string>"}`.
4. Gọi lại `responses.create()` với `input` đã cập nhật.

**Chat Completions API:**
1. Gọi `chat.completions.create()` với `messages` + `tools`.
2. Assistant message trả về có `tool_calls: [{id: "call_12345xyz", type: "function", function: {name, arguments}}]`.
3. Ứng dụng thực thi hàm, rồi append message `{"role": "tool", "tool_call_id": "call_12345xyz", "content": "<kết quả>"}` vào `messages`.
4. Gọi lại `chat.completions.create()` với `messages` đã cập nhật.

Khác biệt cốt lõi so với Anthropic: OpenAI dùng **message riêng biệt `role: "tool"`** (Chat Completions) hoặc **item `function_call_output` trong `input` list** (Responses API) để trả kết quả — còn Anthropic gói kết quả thành **content block `tool_result` nằm bên trong message `role: "user"`**, không có role/message loại "tool" riêng. Cùng một ý nghĩa (khớp lời gọi ↔ kết quả qua id), nhưng khác cấu trúc dữ liệu ở tầng API.

**Xử lý khi tool gọi lỗi:** nếu hàm thực thi ném exception hoặc trả lỗi, vẫn phải gửi một `content`/`output` hợp lệ khớp `tool_call_id`/`call_id` tương ứng (ví dụ chuỗi mô tả lỗi như `"Error: location not found"`) rồi để model tự quyết định bước tiếp theo (thử lại, hỏi lại user, báo lỗi) — không được bỏ qua việc gửi kết quả, vì thiếu `tool_call_id` khớp sẽ khiến request kế tiếp bị OpenAI từ chối (400) do state không nhất quán.

## `tool_choice`

Vấn đề nó giải quyết: cho phép ứng dụng kiểm soát mức độ chủ động của model trong việc gọi tool — từ "tự do quyết định" đến "bắt buộc gọi đúng 1 tool cụ thể".

| Giá trị | Ý nghĩa |
|---|---|
| `auto` (mặc định) | model tự quyết định gọi 0, 1, hay nhiều tool |
| `required` | bắt buộc gọi ít nhất 1 tool, model tự chọn tool nào |
| `none` | tắt hoàn toàn khả năng gọi tool |
| named/forced function `{"type": "function", "name": "..."}` | ép gọi đúng 1 tool cụ thể |
| `allowed_tools` | giới hạn tập con tool được phép gọi trong lượt này |

So với Anthropic (`auto`/`any`/`tool`/`none`): tương đương gần như 1-1, chỉ khác tên (`required` ↔ `any`, forced-function ↔ `tool`). Riêng `allowed_tools` là khái niệm OpenAI có mà Anthropic không có tương đương trực tiếp trong bảng `tool_choice`.

## `parallel_tool_calls`

Vấn đề nó giải quyết: khi model cần dữ liệu từ nhiều tool độc lập cùng lúc (vd thời tiết Paris + thời tiết London), flag này cho phép trả về nhiều tool call trong 1 turn thay vì phải round-trip tuần tự từng cái.

- Boolean, mặc định `true` trên model hỗ trợ — cho phép model trả nhiều tool call trong cùng 1 turn.
- Set `false` để ép tối đa 1 tool call/turn.
- Tương đương `disable_parallel_tool_use` của Anthropic, nhưng OpenAI đặt nó là flag top-level riêng biệt thay vì lồng trong object `tool_choice`.

## `strict` mode — Structured Outputs cho function calling

Vấn đề nó giải quyết: bình thường model có thể sinh ra `arguments` JSON sai kiểu, thiếu field, hoặc lệch khỏi schema đã khai báo — `strict` mode ép model tuân thủ đúng schema 100%, giảm code phòng thủ (validate/retry) ở phía ứng dụng.

- `strict: true` trên tool definition bật **Structured Outputs**, đảm bảo argument model sinh ra khớp chính xác JSON Schema đã khai báo — không còn hiện tượng model bỏ sót field, sai kiểu dữ liệu.
- Yêu cầu bắt buộc: `additionalProperties: false` trên mọi object, mọi property phải có mặt trong `required` (field optional biểu diễn bằng union nullable, vd `"type": ["string", "null"]` thay vì bỏ khỏi `required`).
- Ra mắt 6/8/2024 cùng Structured Outputs; theo công bố của OpenAI, các model đời `gpt-4o-2024-08-06` trở lên đạt tỷ lệ tuân thủ schema gần như tuyệt đối khi bật strict, cao hơn đáng kể so với khi không bật.
- Tương đương chức năng với `strict: true` của Anthropic (cùng mục đích: ép output khớp schema), nhưng yêu cầu cấu trúc schema (mọi field vào `required`, dùng nullable union cho optional) là đặc thù OpenAI.

## Sự dịch chuyển `functions`/`function_call` → `tools`/`tool_choice`

Bối cảnh: đây là 2 thế hệ field API của OpenAI cho cùng một tính năng (function calling) — biết sự khác biệt giúp nhận ra code cũ/tutorial cũ và tránh copy nhầm field đã lỗi thời.

- OpenAI công bố function calling lần đầu 13/6/2023, dùng field `functions` (khai báo) và `function_call` (điều khiển) trên Chat Completions, thêm vào các model snapshot `gpt-4-0613`/`gpt-3.5-turbo-0613`.
- Các field `functions`/`function_call` này hiện đã **deprecated**, thay bằng `tools`/`tool_choice` — không chỉ đổi tên mà còn thêm khả năng mới: `tools` hỗ trợ **gọi nhiều function song song trong 1 turn** (`parallel_tool_calls`), điều `functions`/`function_call` không làm được vì chỉ thiết kế cho đúng 1 lời gọi/turn.
- Code cũ dùng `functions`/`function_call` vẫn chạy được, nhưng OpenAI khuyến nghị chuyển sang `tools`/`tool_choice` cho phát triển mới.
- Không có paper học thuật nào cho "function calling" của OpenAI — khác với các kỹ thuật như ReAct hay Toolformer, đây thuần là tính năng sản phẩm/API, xuất phát từ blog announcement + docs sống, không phải từ nghiên cứu peer-reviewed.

## Ví dụ minh hoạ đầy đủ (cả 2 API)

Request có tool `get_weather`, user hỏi "Paris hôm nay thế nào?":

```json
// 1. Request
{
  "model": "gpt-4o",
  "messages": [{"role": "user", "content": "What's the weather in Paris?"}],
  "tools": [{"type": "function", "name": "get_weather", "description": "...", "parameters": {...}}]
}

// 2. Response — model trả tool_calls
{
  "role": "assistant",
  "tool_calls": [{
    "id": "call_12345xyz",
    "type": "function",
    "function": {"name": "get_weather", "arguments": "{\"location\":\"Paris\"}"}
  }]
}

// 3. Ứng dụng gọi API thời tiết thật, rồi gửi kết quả về
{"role": "tool", "tool_call_id": "call_12345xyz", "content": "18°C, nhiều mây"}

// 4. Gọi lại chat.completions.create() với messages đã có message "tool" ở trên
// → model trả lời cuối: "Paris hôm nay 18°C, trời nhiều mây."
```

Cùng kịch bản, viết theo Responses API — khác Chat Completions ở chỗ không có "message role tool" riêng, mà append thẳng item `function_call_output` vào mảng `input`:

```json
// 1. Request
{
  "model": "gpt-4o",
  "input": [{"role": "user", "content": "What's the weather in Paris?"}],
  "tools": [{"type": "function", "name": "get_weather", "description": "...", "parameters": {...}}]
}

// 2. Response — item function_call trong mảng output
{
  "output": [{
    "type": "function_call",
    "call_id": "call_12345xyz",
    "name": "get_weather",
    "arguments": "{\"location\":\"Paris\"}"
  }]
}

// 3. Ứng dụng gọi API thời tiết thật, rồi append kết quả vào input
{"type": "function_call_output", "call_id": "call_12345xyz", "output": "18°C, nhiều mây"}

// 4. Gọi lại responses.create() với input đã có item function_call_output ở trên
// → model trả lời cuối: "Paris hôm nay 18°C, trời nhiều mây."
```

## Liên hệ tới các phần khác

- So với [[agent-building-function-calling-overview]]: bài đó là khung 4 bước chung provider-agnostic; bài này cụ thể hoá field/shape của OpenAI (`tools`/`tool_calls`/`role: "tool"` vs `function_call`/`function_call_output`).
- So với [[agent-building-anthropic-tool-use]]: cùng 4 bước, nhưng khác shape gửi-kết-quả-về (message `role: "tool"` riêng biệt của OpenAI vs content block `tool_result` lồng trong message `user` của Anthropic) và khác tên field `tool_choice` (`required`/forced-function vs `any`/`tool`).
- Xem [[agent-tool-definition]] cho nguyên tắc chung viết schema tool (áp dụng cho cả OpenAI lẫn Anthropic).

### Áp dụng với Claude Code

- Claude Code (CLI) không dùng OpenAI API — nó chạy trên Anthropic Messages API (xem [[agent-building-anthropic-tool-use]]), nên các field đặc thù OpenAI trong note này (`tool_calls`, `role: "tool"`, `function_call_output`, field `functions`/`function_call` cũ) **không áp dụng trực tiếp** cho Claude Code.
- Claude Agent SDK (nền tảng của Claude Code) tự quản lý toàn bộ vòng lặp tool-call/tool-result nội bộ, nên dù là OpenAI hay Anthropic, người dùng CLI không cần tự tay dựng JSON theo shape nào cả — điểm này đúng cho cả hai provider, không riêng gì OpenAI.
- Với dự án dùng OpenAI SDK trực tiếp (không qua Claude Code) mà muốn đối chiếu hành vi, bảng so sánh `tool_choice`/`parallel_tool_calls`/`strict` ở trên là nơi tra cứu nhanh field tương đương.

## Giới hạn / open questions

- Chưa tự kiểm chứng trực tiếp con số "100% schema-adherence" của Structured Outputs — lấy từ tóm tắt tìm kiếm trích dẫn blog gốc (openai.com/index/introducing-structured-outputs-in-the-api), chưa fetch trực tiếp trang openai.com để xác nhận điều kiện đo (model nào, bộ eval nào, cỡ mẫu bao nhiêu). **Confidence: medium.**
- Không rõ ngày cụ thể `functions`/`function_call` sẽ bị gỡ bỏ hẳn khỏi API — trang deprecations chính thức không nêu deadline. **Confidence: medium.**
- Ngày công bố function calling lần đầu (13/6/2023) và các model snapshot đi kèm (`gpt-4-0613`/`gpt-3.5-turbo-0613`) lấy theo blog gốc + nguồn thứ cấp, chưa đối chiếu changelog chính thức của OpenAI. **Confidence: medium.**
- Việc Responses API "là API kế nhiệm/khuyến nghị" suy ra từ cách docs hiện tại trình bày ví dụ, chưa có tuyên bố dứt khoát "Chat Completions sẽ bị thay thế hoàn toàn". **Confidence: medium.**
- Kết luận "không có paper học thuật cho function calling của OpenAI" dựa trên việc không tìm thấy paper qua tìm kiếm, không phải một khẳng định đã kiểm chứng đầy đủ (có thể có nghiên cứu chưa tìm ra). **Confidence: low.**
- Chưa đào sâu shape response khi bật `parallel_tool_calls` với nhiều tool call cùng lúc trong Responses API (thứ tự các `function_call_output` khi gửi lại, có bắt buộc đúng thứ tự không).
- Chưa so sánh chi tiết chi phí token/overhead hệ thống khi bật `tools` trên OpenAI (Anthropic có số liệu cụ thể theo model, chưa tìm thấy con số tương đương cho OpenAI trong nguồn đã có).
