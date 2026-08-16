---
status: current
updated: 2026-08
sources:
  - https://platform.claude.com/docs/en/build-with-claude/streaming
  - https://www.assemblyai.com/blog/decoding-strategies-how-llms-choose-the-next-word
  - https://www.promptlayer.com/glossary/time-to-first-token/
  - https://redis.io/blog/ttft-meaning/
  - https://www.spheron.network/blog/structured-output-function-calling-inference-guide/
roadmap: ai-engineer
stage: learning
---

# Streamed vs Un-streamed response

> Thay vì đợi có response đầy đủ mới trả về và hiển thị cho user, hệ thống AI có thể **stream** response theo từng chunk nhỏ để user thấy phản hồi mượt mà hơn — đối lập là **un-streamed (blocking)**: server xử lý xong toàn bộ response rồi mới trả một lần duy nhất.

## Streaming là gì?
Streaming response cho phép hệ thống AI sinh và hiển thị câu trả lời tăng dần theo thời gian (incremental) thay vì đợi sinh xong toàn bộ rồi mới hiển thị — server gửi từng chunk ngay khi chunk đó sẵn sàng. Kỹ thuật này phổ biến ở hầu hết chat AI hiện nay: ChatGPT, Claude, Gemini... (confidence: high).

## Un-streamed (blocking/synchronous) response là gì?
Client gửi request, server xử lý **toàn bộ** quá trình generate (từ token đầu tới token cuối) rồi mới trả về nguyên khối response một lần (một HTTP response body hoàn chỉnh). Đây là chế độ mặc định của hầu hết API (`stream: false`) nếu không bật cờ streaming (confidence: high).

### So sánh nhanh

| Tiêu chí | Streaming | Un-streamed |
|---|---|---|
| **Perceived latency** | Thấp — user thấy token đầu tiên gần như ngay lập tức (đo bằng **TTFT**, xem mục dưới) | Cao — user phải đợi tới khi *toàn bộ* response sinh xong mới thấy gì |
| **Tổng thời gian thực tế** | Gần như bằng nhau — streaming không làm model sinh nhanh hơn, chỉ hiển thị sớm hơn | Giống streaming về tổng thời gian, nhưng cảm giác chờ đợi lâu hơn |
| **Parse structured output / tool-use JSON** | Phức tạp hơn — JSON đến theo từng mảnh (partial), phải ghép/validate dần hoặc đợi block đó `stop` | Đơn giản — JSON đã hoàn chỉnh, parse một lần |
| **Retry khi lỗi giữa chừng** | Phức tạp — phải xử lý trạng thái dở dang (client đã hiển thị 1 phần) | Đơn giản — lỗi thì toàn bộ request coi như fail, retry sạch |
| **Phù hợp** | Chat UI, trợ lý tương tác real-time, mọi nơi cần "cảm giác phản hồi nhanh" | Batch job, pipeline xử lý ngầm không cần hiển thị real-time, khi cần response hoàn chỉnh mới xử lý tiếp (VD: parse tool call rồi gọi tool ngay) |

> Ghi chú thực dụng cho agent loop: nhiều framework agent vẫn cần **đợi hết một content block** (VD: toàn bộ `tool_use` block) trước khi thực thi tool, dù response tổng thể đang stream — streaming ở đây chủ yếu cải thiện UX phần text hiển thị cho user, không nhất thiết đổi logic gọi tool.

## Streaming response hoạt động như thế nào?

### Generate theo token-by-token
LLM sinh và hiển thị text từng token một tại một thời điểm. Một token là một đơn vị text, có thể là:
- Một từ hoàn chỉnh (VD: "happy")
- Một phần của từ (VD: "happ-" trong "happiness")
- Một ký tự đơn hoặc dấu câu (VD: "a", ",")

Khi user gửi query, LLM bắt đầu generate token tuần tự. Ngay khi token đầu tiên sẵn sàng, nó được gửi tới client, và tiến trình lặp lại cho tới khi response hoàn tất.

### Streaming APIs
Hầu hết LLM provider hỗ trợ streaming qua API bằng một flag (`stream: true`). Quy trình chung:
1. Client gửi request kèm flag `stream: true`.
2. Server bắt đầu xử lý input (prefill) và generate token.
3. Từng chunk được gửi về ngay khi sẵn sàng — không đợi toàn bộ response.
4. Client ghép các chunk lại và hiển thị real-time.

**Ví dụ cụ thể — Claude Messages API:** khi bật `stream: true`, response không phải một JSON object đơn mà là một chuỗi **event** SSE theo thứ tự cố định (as of platform.claude.com) (confidence: high):

```text
event: message_start
data: {"type":"message_start","message":{"id":"msg_...","model":"claude-...","role":"assistant",...}}

event: content_block_start
data: {"type":"content_block_start","index":0,"content_block":{"type":"text","text":""}}

event: content_block_delta
data: {"type":"content_block_delta","index":0,"delta":{"type":"text_delta","text":"Xin"}}

event: content_block_delta
data: {"type":"content_block_delta","index":0,"delta":{"type":"text_delta","text":" chào"}}

event: content_block_stop
data: {"type":"content_block_stop","index":0}

event: message_delta
data: {"type":"message_delta","delta":{"stop_reason":"end_turn"},"usage":{"output_tokens":12}}

event: message_stop
data: {"type":"message_stop"}
```

- `message_start`/`message_stop` đánh dấu bắt đầu/kết thúc toàn bộ message.
- `content_block_start`/`content_block_delta`/`content_block_stop` lặp lại cho mỗi block nội dung (có thể nhiều block nếu model vừa "suy nghĩ" — `thinking_delta` — vừa trả text, hoặc gọi tool — `input_json_delta` chứa JSON args của tool được gửi từng phần).
- Đây chính là lý do parse structured output/tool-use lúc streaming phức tạp hơn: `input_json_delta` gửi JSON theo từng mảnh chưa hợp lệ cú pháp cho tới khi ghép đủ.

### Real-time rendering ở client side
Client được thiết kế để render token/chunk ngay khi nhận được:
- Web app cập nhật UI ngay khi token mới tới (thường thấy hiệu ứng chữ chạy).
- Chương trình terminal in từng token ra output để tạo hiệu ứng như đang gõ phím (typewriter effect).

## Key technologies enabling streaming

### Server-Sent Events (SSE)
SSE là một giao thức cho phép server push update tới client real-time qua **một kết nối HTTP đơn, một chiều** (server → client), dùng chunked transfer encoding của HTTP bên dưới. Mỗi chunk data được gửi như một event tách biệt, mỗi dòng `data:` là một payload.

```text
data: Hello
data: how
data: are
data: you?
```

Đây là công nghệ được hầu hết LLM API (OpenAI, Anthropic, Google) dùng cho streaming, vì đơn giản hơn WebSocket khi chỉ cần luồng 1 chiều.

### WebSocket
WebSocket cung cấp kênh giao tiếp **2 chiều** (full-duplex) giữa client và server trên cùng một kết nối — hữu dụng khi client cũng cần gửi dữ liệu liên tục tới server trong lúc nhận response (VD: voice streaming, ứng dụng real-time đa chiều). Với chat completion đơn thuần (client chỉ gửi 1 request rồi nhận nhiều chunk), SSE thường đủ và đơn giản hơn WebSocket — WebSocket phù hợp hơn khi cần tương tác 2 chiều thật sự trong cùng phiên (confidence: medium — lựa chọn cụ thể tuỳ kiến trúc từng hệ thống).

### Asynchronous programming
Mô hình lập trình bất đồng bộ (`asyncio` ở Python, event loop của Node.js...) là nền tảng để server xử lý streaming hiệu quả — cho phép:
- Xử lý nhiều client request đồng thời trên cùng một process.
- Gửi token tới client mà không block việc tiếp tục sinh token kế tiếp.

## Pipeline optimization trong LLM

### Transformer architecture
LLM dùng kiến trúc Transformer: xử lý **input** (prompt, giai đoạn "prefill") một cách song song, nhưng **generate output** một cách tuần tự (autoregressive) — mỗi token mới được dự đoán dựa trên toàn bộ context (prompt + các token đã sinh trước đó). Bản chất tuần tự này của bước generate chính là lý do streaming khả thi: token nào sinh xong có thể gửi đi ngay, không cần đợi các token sau.

### Decoding strategies
Cách chọn token tiếp theo từ phân phối xác suất model output ảnh hưởng trực tiếp tới việc có stream mượt được hay không:

- **Greedy decoding** — luôn chọn token có xác suất cao nhất tại mỗi bước. Tương thích tự nhiên với streaming vì quyết định được đưa ra ngay lập tức ở từng bước, không cần biết trước phần còn lại của chuỗi.
- **Sampling (Top-K / Nucleus / Top-P sampling)** — đưa yếu tố ngẫu nhiên có kiểm soát vào, giới hạn lựa chọn trong tập ứng viên xác suất cao nhất để cân bằng giữa chất lượng và đa dạng. Cũng tương thích tốt với streaming vì mỗi token vẫn được quyết định độc lập theo từng bước.
- **Beam search** — sinh song song nhiều chuỗi ứng viên (theo beam width B), giữ lại B chuỗi tốt nhất ở mỗi bước, chỉ chốt chuỗi cuối cùng khi *toàn bộ* quá trình generate hoàn tất. **Về bản chất không tương thích tốt với streaming token-by-token**: thuật toán chưa biết token nào nên gửi cho user cho tới khi đã đánh giá xong tất cả các beam — đây là điểm bản nháp gốc nhầm khi liệt kê beam search ngang hàng với 2 chiến lược trên như thể cả 3 đều dùng được cho streaming (as of assemblyai.com) (confidence: high). Trong thực tế, hầu hết API chat streaming (OpenAI, Claude...) dùng **greedy/sampling**, không dùng beam search.

## Metric quan trọng: TTFT (Time To First Token)
**TTFT** = độ trễ từ lúc gửi request tới lúc token đầu tiên tới client — chỉ số "cảm giác phản hồi nhanh hay chậm" quan trọng nhất với streaming UX, khác với **throughput** (tốc độ sinh token/giây sau khi đã bắt đầu). TTFT gồm: thời gian chờ hàng đợi (queueing), thời gian xử lý prompt (prefill), và bước decode đầu tiên của model (as of promptlayer.com, redis.io) (confidence: high).

- Streaming cải thiện **TTFT cảm nhận được** (user thấy chữ chạy ngay), nhưng không làm giảm tổng thời gian model cần để sinh hết response.
- Structured output/function calling có thể làm tăng TTFT: compile grammar/schema cho constrained decoding tốn thêm 50–100ms ở lần gọi đầu với schema mới; các lần sau (agent loop lặp lại cùng schema) chi phí này được cache lại, giảm đáng kể (as of spheron.network) (confidence: medium).
- Tối ưu TTFT (VD: giảm batch size để trả lời nhanh hơn từng request) có thể đánh đổi với throughput tổng của hệ thống khi tải cao — hai chỉ số này không phải lúc nào cũng tối ưu cùng chiều.

## Reconnect/resume khi SSE bị đứt giữa chừng

### Cơ chế "chuẩn" mà SSE spec định nghĩa
SSE có sẵn cơ chế resume trong spec (HTML Living Standard), nhưng phải cả 2 phía server + client cùng implement mới hoạt động (confidence: high):
- Mỗi event server gửi có thể kèm field `id:` (event ID).
- Trình duyệt/`EventSource` client tự lưu lại `lastEventId` từ event gần nhất nhận được.
- Khi kết nối rớt, `EventSource` **tự động reconnect** (mặc định đợi ~3000ms, hoặc theo giá trị server gợi ý qua field `retry:`), và gửi kèm header `Last-Event-ID: <id cuối cùng>` trong request reconnect.
- Nếu server có implement lưu lại stream theo ID, nó có thể "tua" tiếp từ đúng chỗ đã dừng thay vì gửi lại từ đầu.

Đây là cơ chế **`EventSource` (browser API) tự làm sẵn** — nhưng LLM API không dùng `EventSource` thuần cho request (vì cần POST + headers auth, còn `EventSource` chỉ hỗ trợ GET), nên hầu hết SDK client tự parse SSE bằng `fetch` + `ReadableStream`, và phần auto-reconnect/`Last-Event-ID` này **không tự động có** — SDK phải tự cài đặt.

### Thực tế: OpenAI SDK và Anthropic SDK làm gì?
- **OpenAI**: SSE response từ OpenAI **không dùng `Last-Event-ID`** — nếu client reconnect, toàn bộ event bị replay lại từ đầu chứ không resume đúng vị trí (as of buildwithfern.com research, community.openai.com) (confidence: medium — hành vi cụ thể có thể khác theo từng endpoint/version, cần re-check khi triển khai).
- **Anthropic**: API gửi định kỳ comment `:ping` trong stream để giữ kết nối sống/giúp client phát hiện kết nối "chết" (khác với thật sự đóng kết nối — TCP có thể chết âm thầm mà không phát sinh error event, đặc biệt khi mạng chập chờn/máy sleep). Không có tài liệu công khai cho thấy Anthropic SDK hỗ trợ resume đúng vị trí qua `Last-Event-ID` cho Messages API streaming (confidence: medium).
- **Retry logic có sẵn trong SDK (`max_retries`, exponential backoff)** áp dụng cho việc **thiết lập kết nối ban đầu** (request chưa nhận được byte nào) — không áp dụng cho việc "resume" một stream đã nhận một phần rồi bị đứt giữa chừng. Nếu đứt giữa chừng, cách xử lý mặc định của SDK là coi cả request đó fail, client phải tự quyết định gọi lại từ đầu.

### Vì sao "gọi lại từ đầu" không đơn giản như tưởng
- Model generate mang tính **non-deterministic** (trừ khi decode thuần greedy + cùng seed) — gọi lại cùng prompt có thể ra output khác, không nối liền mạch được với phần đã nhận trước đó.
- Gọi lại từ đầu = tốn lại **toàn bộ token của prompt** (dù có thể được cache một phần nhờ prompt caching) + tốn lại token output đã sinh trước đó — chi phí và độ trễ tăng gấp đôi nếu stream đứt ở giữa/cuối response dài.
- Đây là gap có thật, không phải lý thuyết suông: Claude Code có hẳn issue công khai (`anthropics/claude-code#26729` — "Streaming Resilience: Detect network loss, save in-flight state, and auto-resume on reconnect") đề xuất chính tính năng này vì chưa có sẵn.

### Pattern thực dụng để tự xây resumable streaming (khi cần độ tin cậy cao)
Vì provider chưa cho resume "free", muốn resume thật sự phải tách rời **quá trình generate** (chạy server-side, không phụ thuộc client có đang kết nối hay không) khỏi **quá trình delivery** (đường ống gửi cho client xem):
1. Khi nhận request, server tạo một `stream_id`, bắt đầu gọi LLM API và **lưu từng token/chunk sinh ra vào storage phía server** (DB, Redis...) song song với việc forward cho client — quá trình generate LLM tiếp tục chạy dù client có ngắt kết nối hay không.
2. Nếu client rớt kết nối, nó reconnect kèm `stream_id` đã biết (tự quản lý, không phải cơ chế `Last-Event-ID` gốc của SSE).
3. Server trả lại phần đã lưu (backfill) rồi tiếp tục stream phần còn lại (nếu generate vẫn đang chạy) hoặc trả nốt phần còn thiếu (nếu đã generate xong).

Đây chính là cách các sản phẩm chat production (ChatGPT web, Claude web...) và các thư viện như Vercel AI SDK ("resumable streams") xử lý — không dựa vào SSE `Last-Event-ID` gốc mà tự quản lý state ở tầng application (as of ai-sdk.dev "Chatbot Resume Streams") (confidence: medium — chi tiết implementation riêng của từng provider không public đầy đủ).

### WebSocket thì sao?
Khác với `EventSource`, **WebSocket không có cơ chế tự động reconnect** — ứng dụng phải tự cài retry với exponential backoff nếu dùng WebSocket cho streaming.

## Open questions / cần đọc thêm
- Chưa so sánh chi tiết chi phí ($ / token) giữa streaming và non-streaming — về lý thuyết giống nhau (tính theo token sinh ra), cần verify lại theo pricing cụ thể của từng provider khi áp dụng thực tế.
- Liên hệ: streaming JSON delta cho tool-use (`input_json_delta`) là điểm giao thoa trực tiếp với [[ai-engineer-roadmap]] mục "Building Agents" (LLM-native function calling) — nên đọc note đó cùng lúc khi implement agent loop có streaming.
- Prompt caching (giảm chi phí re-send prompt khi phải gọi lại từ đầu sau khi đứt stream) chưa có note riêng — liên quan trực tiếp tới phần "gọi lại từ đầu" ở trên, nên đọc chung khi cần tối ưu chi phí retry.
