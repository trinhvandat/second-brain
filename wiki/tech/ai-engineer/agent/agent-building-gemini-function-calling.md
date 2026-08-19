---
status: current
updated: 2026-08
sources:
  - https://ai.google.dev/gemini-api/docs/function-calling
  - https://ai.google.dev/gemini-api/docs/generate-content/function-calling
  - https://ai.google.dev/gemini-api/docs/generate-content/tool-combination
  - https://ai.google.dev/gemini-api/docs/tool-combination
  - https://ai.google.dev/gemini-api/docs/interactions/tool-combination
  - https://ai.google.dev/gemini-api/docs/migrate-to-interactions
  - https://github.com/google-gemini/cookbook/blob/main/quickstarts/Function_calling.ipynb
  - https://ai.google.dev/gemini-api/docs/samples/generativeaionvertexai-function-calling-generate-parallel-calls
  - https://github.com/GoogleCloudPlatform/generative-ai/blob/main/gemini/function-calling/parallel_function_calling.ipynb
  - https://discuss.ai.google.dev/t/function-call-response-should-not-have-a-user-role/66336
  - https://github.com/spring-projects/spring-ai/issues/866
  - https://www.marktechpost.com/2026/04/07/how-to-combine-google-search-google-maps-and-custom-functions-in-a-single-gemini-api-call-with-context-circulation-parallel-tool-ids-and-multi-step-agentic-chains/
  - https://platform.claude.com/docs/en/agents-and-tools/tool-use/overview
  - https://platform.claude.com/docs/en/agents-and-tools/tool-use/parallel-tool-use
roadmap: ai-engineer
stage: learning
---

# Gemini Function Calling — cách Google Gemini hiện thực function calling qua Gemini API

TL;DR: **Function calling** là cách cho model gọi hàm/API bên ngoài (thời tiết, database, tool nội bộ...) thay vì chỉ trả lời bằng text thuần. Gemini hiện thực nó bằng cách: khai báo hàm dưới dạng `FunctionDeclaration` gom trong `Tool`, model trả về `functionCall` (name + args) khi cần gọi, rồi ứng dụng thực thi và gửi kết quả về bằng `functionResponse`. Note này là bản cụ thể-theo-Gemini của khung 4 bước chung ở [[agent-building-function-calling-overview]] — nên đọc note đó trước nếu chưa quen khái niệm function calling nói chung.

## Vấn đề nó giải quyết (dành cho người mới)

- Model ngôn ngữ (LLM) mặc định chỉ sinh ra text — nó không tự tra được thời tiết hiện tại, không tự query được database, không tự gọi API thanh toán.
- **Function calling** cho phép developer "giới thiệu" cho model một danh sách hàm nó được phép nhờ gọi (tên hàm, hàm làm gì, hàm cần tham số gì). Khi câu hỏi của user cần tới một hàm đó, model sẽ trả về một *đề xuất gọi hàm* (không tự chạy hàm) — ứng dụng của developer mới là bên thực thi hàm thật, rồi gửi kết quả về lại cho model để model dùng kết quả đó trả lời user.
- Ví dụ cụ thể: user hỏi "Paris hôm nay bao nhiêu độ?" → model trả về đề xuất gọi `get_current_weather(location="Paris")` → ứng dụng gọi API thời tiết thật, được `18°C, nhiều mây` → gửi kết quả này về cho model → model trả lời user bằng câu văn tự nhiên dựa trên kết quả đó.
- Mỗi provider (Gemini, OpenAI, Anthropic) hiện thực đúng vòng lặp này nhưng đặt tên field và cấu trúc message khác nhau — phần so sánh chi tiết nằm ở [[#Liên hệ tới các phần khác]] cuối note.

## Khai báo tool: `FunctionDeclaration` → `Tool` → `tools`

- Mỗi **FunctionDeclaration** gồm `name`, `description`, `parameters` (object dạng schema tương thích một tập con OpenAPI: `type`/`properties`/`required`, có thể có `enum` để giới hạn giá trị).
- Nhiều `FunctionDeclaration` được gom vào một **Tool**: `{"function_declarations": [...]}`.
- `Tool` (hoặc danh sách `Tool`) truyền vào request qua field `tools` — REST: field `tools` của `generateContent`; Python SDK: `GenerateContentConfig(tools=[...])`.
- SDK Python có thể tự sinh `FunctionDeclaration` trực tiếp từ một hàm Python thường qua `types.FunctionDeclaration.from_callable(callable=fn, client=client)`, đọc tên hàm/docstring/type annotation — nhiều trường hợp không cần tự tay dựng schema.

```python
from google.genai import types

get_weather = types.FunctionDeclaration(
    name="get_current_weather",
    description="Get the current weather for a location",
    parameters={
        "type": "object",
        "properties": {
            "location": {"type": "string"},
            "unit": {"type": "string", "enum": ["celsius", "fahrenheit"]},
        },
        "required": ["location"],
    },
)
tools = types.Tool(function_declarations=[get_weather])
```

## Vòng round-trip: `functionCall` → `functionResponse`

1. Gửi request kèm `tools`.
2. Model trả về content chứa một **`functionCall` part** (`name` + `args`) thay vì (hoặc kèm) text — model không tự chạy hàm, chỉ đề xuất lời gọi.
3. Ứng dụng thực thi hàm cục bộ.
4. Gửi kết quả về bằng một **`functionResponse` part** (`name`, `response`) đặt trong turn kế tiếp.

Điểm gây nhầm lẫn nhất của Gemini: Gemini **không có role riêng dạng "tool"** như OpenAI. Tài liệu chính thức hiện tại nhất quán dùng `role: "user"` để bọc `functionResponse` part; một số thảo luận cộng đồng/SDK cũ (vd issue trên spring-ai) từng kỳ vọng hoặc dùng `role: "function"`, nên khi đọc code/tutorial cũ cần kiểm tra lại theo phiên bản SDK đang dùng — chi tiết độ tin cậy xem mục "Giới hạn / open questions".

Với các model dòng Gemini 3, mỗi `functionCall` có thêm field `id`; khi gửi `functionResponse` về phải echo đúng `id` đó để model khớp đúng kết quả với lời gọi tương ứng — quan trọng nhất khi có nhiều lời gọi song song trong cùng một turn.

```json
// Model trả về
{"functionCall": {"name": "get_current_weather", "args": {"location": "Paris"}}}

// Ứng dụng gửi lại (role: "user")
{"role": "user", "parts": [
  {"functionResponse": {"name": "get_current_weather", "response": {"content": "18°C, nhiều mây"}}}
]}
```

## `function_calling_config.mode`

Vấn đề nó giải quyết: giống `tool_choice` của OpenAI/Anthropic — kiểm soát mức độ chủ động của model khi gọi tool, chỉ khác là Gemini lồng field này trong `tool_config.function_calling_config` thay vì để `tool_choice` phẳng ở top-level.

| Giá trị | Ý nghĩa |
|---|---|
| `AUTO` (mặc định) | model tự quyết định trả text hay gọi function |
| `ANY` | bắt buộc gọi ít nhất 1 function; có thể thu hẹp bằng `allowed_function_names` |
| `NONE` | tắt hoàn toàn khả năng gọi function, tương đương không truyền `tools` |
| `VALIDATED` | model bị ràng buộc bởi **constrained decoding** (kỹ thuật ép output của model phải khớp đúng một schema/định dạng cho trước, thay vì để model tự do sinh text rồi hy vọng nó đúng cấu trúc) để đảm bảo lời gọi hàm luôn khớp schema; là mode bắt buộc (thay `AUTO`) khi kết hợp built-in tools với custom function trong cùng request |

```python
tool_config = types.ToolConfig(
    function_calling_config=types.FunctionCallingConfig(mode="ANY")
)
```

So với OpenAI (`auto`/`required`/`none`/named-function) và Anthropic (`auto`/`any`/`tool`/`none`): Gemini không có giá trị riêng để "ép đúng 1 tool cụ thể" như `tool` của Anthropic hay named-function của OpenAI — muốn ép 1 tool duy nhất phải dùng `ANY` + `allowed_function_names=["tenHam"]`.

## Parallel và compositional function calling

- **Parallel**: model có thể trả về nhiều `functionCall` part trong cùng một turn khi các tác vụ độc lập nhau (vd hỏi thời tiết Boston và San Francisco cùng lúc → 2 lời gọi `get_current_weather` trong 1 response) — ứng dụng thực thi song song thay vì round-trip tuần tự.
- **Compositional (sequential/chained)**: model có thể dùng kết quả của lời gọi này làm đầu vào để quyết định lời gọi tiếp theo, qua nhiều turn, cho đến khi đủ thông tin trả lời cuối cùng — SDK có thể tự động hoá vòng lặp này, hoặc tự viết loop cho tới khi response không còn `functionCall` part nào.

## Kết hợp built-in tools với custom function

- Gemini (đặc biệt dòng Gemini 3, đang Preview) cho phép trộn **built-in tools phía server** — Google Search (dùng để **grounding**, tức bắt model trả lời dựa trên kết quả tìm kiếm thật thay vì chỉ dựa vào kiến thức đã học sẵn), Google Maps, URL Context, File Search, Code Execution — với `function_declarations` tự định nghĩa trong cùng một request.
- Cơ chế đứng sau việc trộn này gọi là "**tool context circulation**": kết quả của built-in tool được Google tự động giữ lại và luân chuyển trong context của cùng một request, để model có thể vừa dùng built-in tool vừa dùng custom function mà không cần developer tự chuyển tiếp kết quả qua lại. Bật bằng flag `include_server_side_tool_invocations: true`.
- Lời gọi built-in tool trả về dưới dạng part `toolCall`/`toolResponse` riêng biệt (khác `functionCall`/`functionResponse` của custom function) và được Google quản lý tự động; developer chỉ cần tự thực thi phần custom function call.
- Giới hạn quan trọng: khi bật `include_server_side_tool_invocations`, chỉ `VALIDATED` mode được hỗ trợ — `AUTO` không dùng được trong cấu hình này; thông tin vị trí/thời gian mâu thuẫn giữa `system_instruction` và mô tả function có thể phá vỡ grounding của Google Search — độ tin cậy của mục này xem "Giới hạn / open questions".

## API cũ (`generateContent`) vs Interactions API mới

**Nên dùng API nào cho project mới hôm nay?** Toàn bộ nội dung ở các mục phía trên (`FunctionDeclaration`/`Tool`/`functionCall`/`functionResponse`/`function_calling_config`) là API `generateContent` cổ điển — vẫn là lựa chọn mặc định an toàn, được hỗ trợ đầy đủ và có nhiều tài liệu/ví dụ nhất. Google đang giới thiệu song song một **Interactions API** mới, dùng shape hoàn toàn khác (không tương thích ngược), nhưng ở giai đoạn hiện tại thông tin còn ít nên note này chỉ tóm tắt để nhận diện, không đi sâu:

- Interactions API quản lý lịch sử hội thoại phía server (qua `previous_interaction_id` thay vì tự gửi lại toàn bộ history mỗi lần), biểu diễn tool call như một timeline các bước có kiểu (`thought`/`function_call`/`function_result`) thay vì nested parts như cổ điển, và hỗ trợ stream argument tăng dần.
- API `generateContent` cổ điển vẫn được hỗ trợ đầy đủ tính đến 2026, nay được xếp vào mục "(Legacy)" trong docs, nhưng Interactions API được Google khuyến nghị cho phát triển mới về lâu dài.
- Field đổi tên hoàn toàn: `tool_choice` (thay `function_calling_config.mode`), `type: "function"`, `previous_interaction_id` để giữ state — không thể copy-paste code giữa hai API này.

## Liên hệ tới các phần khác

- So với [[agent-building-function-calling-overview]]: bài đó là khung 4 bước chung provider-agnostic; bài này cụ thể hoá field/shape của Gemini (`FunctionDeclaration`/`Tool`/`functionCall`/`functionResponse`/`function_calling_config`).
- So với [[agent-building-openai-function-calling]]: OpenAI dùng message/item riêng biệt để trả kết quả (`role: "tool"` hoặc `function_call_output`); Gemini không có role "tool" riêng, gói `functionResponse` vào trong turn `role: "user"` — về mặt cấu trúc, Gemini gần Anthropic hơn OpenAI ở điểm này.
- So với [[agent-building-anthropic-tool-use]]: cả hai đều nhét kết quả vào message `user` thay vì role riêng; khác nhau ở tên field điều khiển ép-gọi-tool (`function_calling_config.mode` AUTO/ANY/NONE/VALIDATED của Gemini so với `tool_choice` auto/any/tool/none của Anthropic) và ở việc Anthropic có `disable_parallel_tool_use` riêng còn Gemini không có công tắc tương đương tường minh cho song song.
- Xem [[agent-tool-definition]] cho nguyên tắc chung viết schema tool (áp dụng cho cả ba provider).

### Áp dụng với Claude Code

- Claude Code (CLI) chạy trên Anthropic Messages API (xem [[agent-building-anthropic-tool-use]]), **không dùng Gemini API** — mọi field đặc thù Gemini trong note này (`FunctionDeclaration`, `functionCall`/`functionResponse`, `function_calling_config.mode`, cơ chế tool context circulation) **không áp dụng trực tiếp** cho Claude Code.
- Claude Code không expose khái niệm tương đương `function_calling_config.mode` cho người dùng cuối trong vận hành bình thường — nó chạy theo hành vi `tool_choice: auto` mặc định của Claude, ẩn trong agent loop; thay vào đó Claude Code kiểm soát **việc thực thi** tool đã được model gọi (không phải việc model có được phép gọi hay không) qua hệ thống permission (allow/ask/deny theo từng tool) — khác cơ chế của Gemini vốn gate ngay ở tầng model qua `mode`.
- Điểm tương đồng về kiến trúc: cả Claude Code (built-in tool như Bash, WebSearch cộng với MCP-server tool tự định nghĩa) lẫn Gemini (built-in tool như Google Search, Code Execution cộng với custom `function_declarations`) đều hội tụ về mô hình "native tool + tool tự định nghĩa cùng nằm trong một danh sách tools của agent loop".

## Giới hạn / open questions

- **`role: "function"` ở SDK cũ** (mục "Vòng round-trip"): chưa tự kiểm chứng trực tiếp shape response khi `role` cho `functionResponse` là `"function"` ở các phiên bản SDK cũ hơn — chỉ dựa trên thảo luận cộng đồng (discuss.ai.google.dev, spring-ai issue), chưa đối chiếu từng phiên bản SDK cụ thể còn dùng convention này (as of nguồn cộng đồng, confidence: medium).
- **Field `id` bắt buộc echo ở Gemini 3** (mục "Vòng round-trip"): chi tiết dựa trên một bài blog bên thứ ba (marktechpost.com), chưa tự test lại với Gemini 3 thật (as of marktechpost.com, confidence: low).
- **Mode `VALIDATED` là bắt buộc khi kết hợp built-in + custom tool, và rủi ro phá vỡ grounding** (mục "mode" và "Kết hợp built-in tools"): dựa trên docs chính thức ai.google.dev/tool-combination, nhưng đây là tính năng đang Preview nên có thể đổi hành vi (as of ai.google.dev/tool-combination, confidence: medium).
- **"Tool context circulation"**: chi tiết chính xác (built-in tool result được tự động giữ trong context ra sao, khác gì với việc tự chèn lại kết quả) mới chỉ có ở mức mô tả tổng quan từ docs Preview + bài blog bên thứ ba nêu trên; chưa test thực tế với Gemini 3 (confidence: low).
- Chưa rõ liệu Gemini có roadmap thêm một mode kiểu "ép đúng 1 tool cụ thể" (tương tự `tool` của Anthropic) độc lập với `ANY` + `allowed_function_names`, hay sẽ giữ nguyên cách tiếp cận hiện tại.
- Thời điểm chính xác API `generateContent` cổ điển sẽ bị deprecate hẳn (nếu có) sau khi Interactions API ổn định — chưa thấy tuyên bố deadline chính thức trong nguồn đã có.
- Chưa đào sâu số liệu token overhead/latency khi bật đồng thời built-in tools + custom function trong cùng request so với chỉ dùng custom function riêng lẻ.
