---
status: current
updated: 2026-08
sources:
  - https://openai.com/index/new-models-and-developer-products-announced-at-devday/
  - https://developers.openai.com/api/docs/assistants/migration
  - https://help.openai.com/en/articles/8550641-assistants-api-v2-faq
  - https://voicebot.ai/2024/04/17/openai-enhances-assistants-api-with-advanced-file-management-and-cost-control-features/
  - https://developers.openai.com/api/docs/deprecations
  - https://community.openai.com/t/assistants-api-beta-deprecation-august-26-2026-sunset/1354666
  - https://simonwillison.net/2025/Mar/11/responses-vs-chat-completions/
  - https://ragwalla.com/blog/key-differences-between-the-openai-responses-api-and-the-assistants-api
  - https://ragwalla.com/blog/openai-assistants-api-vs-openai-responses-api-complete-comparison-guide
  - https://platform.openai.com/docs/guides/migrate-to-responses
  - https://code.claude.com/docs/en/agent-sdk/overview
  - https://code.claude.com/docs/en/agent-sdk/sessions
  - https://platform.claude.com/docs/en/agents-and-tools/tool-use/code-execution-tool
roadmap: ai-engineer
stage: learning
---

# OpenAI Assistant API — API agent stateful cấp cao của OpenAI, đang bị deprecate (sunset 26/8/2026)

TL;DR: Assistants API (ra mắt DevDay 11/2023) là lớp trừu tượng nằm trên Chat Completions, gom sẵn **state phía server** (Threads), **persona cấu hình** (Assistants), **thực thi** (Runs) và **built-in tools** (Code Interpreter, File Search, function calling) thành một API quản lý — nhưng OpenAI đã công bố deprecate 26/8/2025 và sẽ gỡ bỏ hoàn toàn 26/8/2026, khuyến nghị chuyển sang **Responses API** + **Conversations API**. Note này nên đọc như "pattern lịch sử quan trọng cần hiểu", không phải "nên build trên nền tảng này". Nếu bạn đang dùng Claude Code hằng ngày, phần "Áp dụng với Claude Code" ở cuối note giải thích Agent SDK giải quyết cùng vấn đề (state, tool, persona) như thế nào ở tầng local thay vì hosted API.

## Bối cảnh: vấn đề gì mà nó giải quyết so với function calling thuần

- 3 khái niệm cần biết trước khi đọc tiếp: **conversation history** là chuỗi tin nhắn qua lại giữa user và model; **RAG** (Retrieval-Augmented Generation) là kỹ thuật tìm dữ liệu liên quan rồi nhét vào prompt trước khi gọi model, thay vì để model "bịa" từ trí nhớ; **function calling** là cơ chế model tự quyết định gọi một hàm do developer định nghĩa (vd. `get_weather(city)`) thay vì chỉ trả về text.
- Ở [[agent-building-openai-function-calling]] (Chat Completions — API gốc, không có state), developer tự quản lý cả ba việc trên bằng tay: tự lưu `messages[]` lịch sử hội thoại ở phía mình, tự viết pipeline RAG (retrieve → nhét context → gọi model), tự viết sandbox nếu muốn model chạy code.
- Assistants API gom cả ba việc đó thành các primitive (khối xây dựng có sẵn) quản lý phía OpenAI, thay vì developer tự nối từng mảnh — đổi lại, OpenAI giữ state hộ mình thay vì mình tự lưu.

## Object model cốt lõi

4 khái niệm, ánh xạ ngược với Chat Completions:

- **Assistant** — object cấu hình bền vững: model, `instructions` (persona), danh sách tool được bật (Code Interpreter / File Search / function). Tương đương "system prompt + tool config" đóng gói sẵn, tái dùng qua nhiều hội thoại.
- **Thread** — container phía server lưu chuỗi Messages của một hội thoại; developer không cần tự truyền lại toàn bộ lịch sử mỗi request như Chat Completions.
- **Message** — một item nội dung (text, file đính kèm...) bên trong Thread.
- **Run** — hành động thực thi: chạy một Assistant lên một Thread, xử lý bất đồng bộ (tool-calling, sinh phản hồi). "Bất đồng bộ" nghĩa là gọi API tạo Run xong không nhận kết quả ngay — client phải **poll** (gọi lặp lại một endpoint để hỏi "xong chưa") trạng thái Run (`queued` → `in_progress` → `requires_action`/`completed`) cho tới khi xong.

| Assistants API | Vai trò | Responses API tương ứng |
|---|---|---|
| Assistant | persona: model + instructions + tools | Prompt (object cấu hình, quản lý qua dashboard, có versioning) |
| Thread | lưu lịch sử hội thoại phía server | Conversation (lưu nhiều loại item hơn, không chỉ message) |
| Run | thực thi bất đồng bộ, cần poll | Response (gọi request/response trực tiếp, không cần poll) |
| Message | item nội dung trong Thread | Item (khái quát hơn: message, tool call, tool output) |

## Built-in tools

- **Code Interpreter** — chạy Python trong sandbox do OpenAI host, có thể sinh biểu đồ, xử lý file.
- **File Search** (ban đầu gọi là **Retrieval**, đổi tên khi ra bản v2 tháng 4/2024) — tự động parse, chunk, embed file vào **vector store** (kho lưu embedding để tìm kiếm theo nghĩa, không chỉ khớp từ khóa) do OpenAI host; tối đa 10.000 file/assistant. Đây là dạng RAG "quản lý sẵn": so với việc tự viết retrieve → stuff context → gọi model, File Search làm hộ toàn bộ bước chunking/embedding/ranking, đổi lại mất quyền kiểm soát chi tiết cách chunk/rank.
- **Function calling** — cùng cơ chế custom function như [[agent-building-function-calling-overview]], nhưng tool call phát sinh trong vòng đời Run (trạng thái `requires_action`) thay vì trực tiếp trong response.
- v2 (4/2024) còn thêm `tool_choice` tường minh (ép `file_search`/`code_interpreter`/một function cụ thể) và cost controls (giới hạn token input/output, điều chỉnh context truncation). Assistants v1 đã sunset 18/12/2024.

## Deprecation & migration — phần quan trọng nhất

- **26/8/2025**: OpenAI công bố deprecate Assistants API.
- **26/8/2026**: gỡ bỏ hoàn toàn khỏi API — sau mốc này gọi `/v1/assistants`, `/v1/threads`, `/v1/threads/*/runs` sẽ trả lỗi, không có chế độ "chạy giảm cấp" hay grace period.
- **Responses API** (ra mắt 3/2025) là đích migration chính thức: gộp sự đơn giản của Chat Completions (gửi input items, nhận output items) với built-in tools kiểu Assistants (code interpreter, file search, web search, MCP, computer use), cộng thêm state phía server nhưng **không còn object Thread/Run riêng** — state được tham chiếu qua `previous_response_id`, hoặc qua object Conversation trong **Conversations API** song song.
- Quy trình migrate khuyến nghị: tạo Prompt object từ mỗi Assistant hiện có → route hội thoại mới sang Responses/Conversations API → backfill hoặc archive các Thread cũ trước hạn 26/8/2026 (confidence: medium — theo hướng dẫn chính thức của OpenAI nhưng chưa có case study thực tế kiểm chứng bước này chạy trơn tru trên codebase lớn).
- Nhiều bài viết migration độc lập (Ragwalla, ClonePartner, UXContinuum...) đồng thuận: độ phức tạp chính mà Responses API loại bỏ là **polling trên Run** — đưa mental model về gần một lệnh request/response đơn, vẫn giữ built-in tools + state phía server (confidence: low — đây là nhận định từ blog bên thứ ba, không phải tuyên bố chính thức của OpenAI).

## Ví dụ minh hoạ: vòng đời một Run, và cùng việc đó làm bằng Responses API

Assistants API — cần 3 bước tạo trước + 1 vòng lặp poll mới lấy được kết quả:

```
1. POST /v1/assistants            → tạo Assistant (model, instructions, tools: [file_search])
2. POST /v1/threads               → tạo Thread rỗng
3. POST /v1/threads/{id}/messages → thêm Message "Tóm tắt file báo cáo Q3 giúp tôi"
4. POST /v1/threads/{id}/runs     → tạo Run, status="queued"
5. GET  /v1/threads/{id}/runs/{run_id}   (poll lặp lại)
   status: queued → in_progress → completed
6. GET  /v1/threads/{id}/messages → đọc Message mới do Assistant sinh ra
```

Responses API — cùng một việc, gộp lại thành 1 lệnh, trả kết quả ngay (không poll):

```json
POST /v1/responses
{
  "model": "gpt-4.1",
  "instructions": "Bạn là trợ lý tóm tắt báo cáo tài chính.",
  "input": "Tóm tắt file báo cáo Q3 giúp tôi",
  "tools": [{ "type": "file_search", "vector_store_ids": ["vs_abc123"] }]
}
```

Response trả về ngay trong cùng request đó (rút gọn):

```json
{
  "id": "resp_123",
  "output": [
    { "type": "message", "content": [{ "type": "output_text", "text": "Q3 doanh thu tăng 12%..." }] }
  ]
}
```

Muốn tiếp tục hội thoại, gửi request tiếp theo kèm `"previous_response_id": "resp_123"` — không cần tự truyền lại toàn bộ lịch sử, cũng không cần object Thread riêng.

## Liên hệ tới các phần khác

- So với [[agent-building-openai-function-calling]]: bài đó là function calling thuần trên Chat Completions/Responses (developer tự quản state); bài này là lớp quản lý state+retrieval+tool cao hơn hẳn, và đang bị khai tử — nên coi Chat Completions/Responses mới là nền tảng để học, Assistants API chỉ để hiểu lịch sử/đọc code cũ.
- So với [[agent-building-function-calling-overview]]: khung 4 bước function-calling provider-agnostic vẫn áp dụng bên trong một Run, chỉ khác là tool call xuất hiện qua trạng thái `requires_action` thay vì trực tiếp trong response.
- So với [[agent-memory-what-is-agent-memory]]: Thread là một dạng cụ thể của "server-managed conversation memory" — OpenAI sở hữu và lưu trữ lịch sử hộ developer, đánh đổi lấy ít quyền kiểm soát hơn về nơi lưu/cách truy xuất.

### Áp dụng với Claude Code

- Claude Code (CLI) **không dùng và không có khái niệm tương đương Assistants API** — nó chạy trên Claude Agent SDK, kiến trúc khác hẳn: Agent SDK là thư viện chạy agent loop **trong tiến trình của chính developer**, không phải object model hosted (Thread/Run) do Anthropic sở hữu.
- Thay cho Thread server-side, Claude Agent SDK ghi lịch sử hội thoại ra **file JSONL cục bộ** (`~/.claude/projects/<encoded-cwd>/*.jsonl`); resume/continue/fork hoạt động bằng cách đọc lại file đó, không gọi một "thread resource" từ xa — muốn resume cross-machine phải tự đồng bộ file hoặc cắm `SessionStore` adapter tùy biến.
- Agent SDK có built-in tools riêng (Read, Write, Edit, Bash, Glob, Grep, WebSearch, WebFetch...) cộng hooks/subagents/MCP/skills — tinh thần "bundle sẵn tool + persona + state" giống Assistants, nhưng nhắm vào agent lập trình/thao tác file hệ thống, không có tool "File Search"/vector-store hosted tương đương — retrieval phải làm qua MCP server hoặc WebSearch/Grep.
- Muốn có Code Interpreter kiểu Assistants (chạy Python trong container hosted, tái dùng container qua nhiều request), Anthropic cung cấp ở tầng Messages API riêng (code execution tool) — khác tầng với Bash-based tools của Agent SDK/Claude Code.
- Tóm lại: Assistants API "sở hữu" state hộ developer trên server OpenAI; Claude Agent SDK đảo ngược — developer (hoặc SessionStore tự cắm) sở hữu state, chạy trên hạ tầng của chính mình.

## Giới hạn / open questions

- Chưa tự gọi thử API `/v1/assistants` để xác nhận behavior thực tế lúc viết note (OpenAI đã đóng docs build-with-this, chỉ còn trang migration) — mọi mô tả dựa trên tài liệu/bài viết thứ cấp, chưa kiểm chứng bằng code chạy thật.
- Chưa rõ liệu sau 26/8/2026 có API tương thích ngược (wire-compatible) nào từ bên thứ ba (vd. Ragwalla) đủ tin cậy để giữ nguyên code cũ hay không — các bài viết đề cập nhưng confidence thấp, chưa kiểm chứng độc lập.
- Chưa đào sâu chi tiết migrate cost/token billing khác nhau thế nào giữa Assistants Run và Responses call tương đương (vd. có tính phí ẩn nào cho vector store lưu trữ File Search không, so với Conversations API mới).
- Chưa có case thực tế đối chiếu Managed Agents (sản phẩm hosted riêng của Anthropic) với Assistants API — mối liên hệ này mới chỉ nêu ở mức khái niệm, chưa so sánh tính năng chi tiết.
