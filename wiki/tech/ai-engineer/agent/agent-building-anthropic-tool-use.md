---
status: current
updated: 2026-08
sources:
  - https://platform.claude.com/docs/en/agents-and-tools/tool-use/overview
  - https://platform.claude.com/docs/en/agents-and-tools/tool-use/define-tools
  - https://platform.claude.com/docs/en/agents-and-tools/tool-use/parallel-tool-use
  - https://platform.claude.com/docs/en/build-with-claude/extended-thinking
  - https://www.anthropic.com/engineering/writing-tools-for-agents
  - https://code.claude.com/docs/en/agent-sdk/custom-tools
  - https://platform.claude.com/docs/en/agent-sdk/mcp
roadmap: ai-engineer
stage: learning
---

# Anthropic Tool Use — cách Claude gọi tool qua Messages API, cụ thể hoá phần "tool calling" nói chung

TL;DR: Anthropic hiện thực function calling qua **Messages API**: developer khai báo tool trong mảng `tools`, Claude trả về `tool_use` block khi muốn gọi, ứng dụng thực thi rồi gửi lại `tool_result` khớp `tool_use_id` trong message `user` tiếp theo — và **chất lượng mô tả tool** (`description`) là yếu tố quan trọng nhất quyết định model có gọi đúng tool hay không.

Đây là phần cụ thể-theo-provider của [[agent-building-function-calling-overview]] — 4 bước chung (khai báo → model trả lời cấu trúc → ứng dụng thực thi → gửi kết quả lại) giữ nguyên, nhưng bài này đi vào chi tiết implementation của Anthropic.

## Thuật ngữ cần biết trước (dành cho người mới)

Nếu chưa quen Messages API của Anthropic, đọc nhanh 4 khái niệm này trước — chúng xuất hiện xuyên suốt bài:

- **Content block**: mỗi message (`user`/`assistant`) không chỉ chứa 1 đoạn text, mà là một **mảng các block** với `type` khác nhau — `text`, `tool_use`, `tool_result`, `thinking`... Một message có thể vừa có block text vừa có block tool_use.
- **`stop_reason`**: field trong response cho biết Claude dừng vì lý do gì — `"end_turn"` (trả lời xong bình thường), `"tool_use"` (Claude muốn gọi tool, chờ bạn thực thi), `"max_tokens"` (hết token)...
- **System prompt**: đoạn hướng dẫn "vai trò/ngữ cảnh chung" gửi kèm mỗi request (field `system`), tách biệt với `messages`. Anthropic tự chèn thêm system prompt ẩn khi bạn dùng `tools` (xem phần Overhead token bên dưới).
- **Prompt caching**: cơ chế cache một phần prompt (system, tool definitions...) giữa các request để giảm token/độ trễ khi phần đầu request không đổi. Chỉ cần biết: **đổi cấu hình tool** (thêm/bớt tool, đổi `tool_choice`...) có thể làm cache bị "invalidate" (mất hiệu lực), tốn lại token như lần đầu.

Nếu bạn mới làm tool-use lần đầu, hai section trên là đủ để đọc phần "Khai báo tool" và "Vòng round-trip" bên dưới — có thể **bỏ qua phần "Tương tác với extended thinking"** ở lượt đọc đầu, quay lại sau khi đã chạy được một tool call cơ bản.

## Khai báo tool (`tools` array)

- Mỗi tool trong mảng top-level `tools` gồm:
  - `name`: khớp regex `^[a-zA-Z0-9_-]{1,64}$`
  - `description`: văn bản thuần, càng chi tiết càng tốt (tool làm gì, khi nào nên/không nên dùng, hành vi ra sao)
  - `input_schema`: JSON Schema object định nghĩa tham số đầu vào
  - `input_examples` (optional): mảng ví dụ input hợp lệ, hữu ích cho input phức tạp/lồng nhau
- Có thể thêm `strict: true` để đảm bảo input của tool call luôn khớp chính xác JSON Schema đã khai báo ("strict tool use").

Ví dụ tối giản:

```json
{
  "tools": [{
    "name": "get_weather",
    "description": "Lấy thời tiết hiện tại cho một địa điểm cụ thể. Dùng khi user hỏi về nhiệt độ, trời mưa/nắng ở một thành phố. Không dùng cho dự báo nhiều ngày.",
    "input_schema": {
      "type": "object",
      "properties": { "location": { "type": "string" } },
      "required": ["location"]
    }
  }]
}
```

## Vòng round-trip: `tool_use` → thực thi → `tool_result`

1. Claude quyết định gọi tool → response có `stop_reason: "tool_use"`, chứa một hoặc nhiều `tool_use` content block, mỗi block có `id` (chính là `tool_use_id`), `name`, `input`. Claude có thể chèn thêm `text` block giải thích trước khi gọi (trừ khi bị ép buộc — xem phần `tool_choice`).
2. Ứng dụng thực thi tool tương ứng với `input` đó.
3. Ứng dụng gửi request tiếp theo, trong đó `messages` phải chứa lại message `assistant` gốc (có `tool_use` block) rồi thêm một message `user` mới với content là `tool_result` block, trường `tool_use_id` phải khớp đúng `id` ở bước 1.

Đây chính là bước "acting" trong agent loop — xem [[agent-acting-tool-invocation]].

## `tool_choice`: điều khiển việc model có gọi tool hay không

| Giá trị | Ý nghĩa |
|---|---|
| `auto` | Mặc định khi có `tools` — model tự quyết định |
| `any` | Bắt buộc gọi một tool nào đó, không chỉ định tool nào |
| `tool` | Ép gọi đúng một tool cụ thể (theo tên) |
| `none` | Cấm gọi tool — mặc định khi không có `tools` |

- `disable_parallel_tool_use` (boolean, đi kèm `tool_choice`): với `auto` giới hạn tối đa 1 lời gọi/lượt; với `any`/`tool` ép đúng 1 lời gọi. Không hỗ trợ cùng programmatic tool calling.
- Khi `tool_choice` là `any`/`tool`, API **prefill** assistant message để ép tool use — nghĩa là Claude sẽ **không** chèn text giải thích trước, kể cả khi prompt yêu cầu giải thích trước. Muốn vừa có giải thích vừa ép gọi tool thì dùng `auto` + chỉ dẫn rõ trong user message.
- Đổi `tool_choice` giữa các request sẽ làm invalidate cache của message blocks (prompt caching), dù tool definitions/system prompt vẫn được cache (confidence: medium).

## Tương tác với extended thinking (phần nâng cao — có thể bỏ qua ở lần đọc đầu)

**Extended thinking là gì?** Đây là chế độ Claude "suy nghĩ ra tiếng" trước khi trả lời — response chứa thêm một `thinking` content block (chuỗi lý luận nội bộ) đứng trước block text/tool_use. Bật bằng `thinking: {type: "enabled", budget_tokens: N}`, trong đó `budget_tokens` là số token tối đa dành cho phần suy nghĩ đó. Không liên quan gì đến tool-use nếu bạn không dùng — phần dưới chỉ nói về việc **kết hợp** hai tính năng này.

- Với **manual extended thinking** (tự set `thinking: {type: "enabled"}`): `tool_choice` `any`/`tool` **không được hỗ trợ** — request sẽ trả lỗi, chỉ `auto`/`none` dùng được. Ví dụ cụ thể: nếu gửi `thinking: {type: "enabled", budget_tokens: 2000}` cùng `tool_choice: {type: "any"}`, API trả lỗi 400 vì hai cấu hình xung đột (ép gọi tool ngay lập tức thì không thể vừa "suy nghĩ" trước). Adaptive thinking (model mới, thinking bật mặc định, không cần tự cấu hình) thì hỗ trợ ép tool use bình thường.
- **Interleaved thinking**: Claude có thể "nghĩ" xen giữa các lần gọi tool trong cùng một lượt assistant (nghĩ → gọi tool → nghĩ về kết quả → gọi tool khác → nghĩ → trả lời) — thay vì chỉ nghĩ một lần ở đầu lượt. Trên các model dùng adaptive thinking (vd Opus 4.6/Sonnet 4.6) cơ chế này tự động bật; trên các model Claude 4 cũ hơn cần header beta `interleaved-thinking-2025-05-14`; Claude Haiku 4.5 không hỗ trợ (header bị bỏ qua).
- Với interleaved thinking, `budget_tokens` có thể **vượt** `max_tokens` vì budget trải dài toàn bộ các thinking block trong một lượt (nhiều lần gọi tool) — đây là ngoại lệ duy nhất của quy tắc thông thường `budget_tokens < max_tokens`.
- Vì sao nên quan tâm: đây chính là cơ chế nền cho các bước tool-call nhiều vòng của Claude Code (đọc file → nghĩ → sửa → nghĩ → chạy test) — nhưng để **tự viết** một tool-use call đầu tiên, bạn chưa cần bật `thinking` chút nào.

## Client tools vs server tools (built-in)

- **Client tools**: chạy trong ứng dụng gọi API — gồm cả tool tự định nghĩa (custom) lẫn tool theo schema của Anthropic mà vẫn do client thực thi (`bash`, `text_editor`, `computer use`). Cần đúng vòng `tool_use` → `tool_result`.
- **Server tools**: chạy trên hạ tầng của Anthropic — `web_search`, `web_fetch`, `code_execution`, `tool_search`, `advisor`, kết nối `MCP connector`. Kết quả trả về trực tiếp trong cùng response, không cần code xử lý phía ứng dụng — trừ khi bị gộp parallel cùng một client tool.
- Ví dụ: server tool `{"type": "web_search_20260209", "name": "web_search"}` không cần code thực thi — Claude tự chạy search và trả kết quả có trích dẫn ngay trong response; còn `get_weather` (client tool) cần đủ round-trip 2 request.

## Overhead token khi dùng `tools`

- API tự chèn thêm một system prompt ẩn khi có `tools`, chi phí token khác nhau theo model và theo `tool_choice`. Ví dụ (as of nguồn, confidence: high): Claude Opus 5 tốn 286 token cho `auto`/`none` vs 406 token cho `any`/`tool`; Claude Sonnet 5 tốn 354 vs 474 token.
- Nếu không truyền `tools` và `tool_choice` là `none` → không tốn thêm token nào.

## Best practice viết tool description (quan trọng nhất!)

Từ tài liệu chính thức + bài "Writing tools for agents" của Anthropic:

- **Mô tả càng chi tiết càng tốt** — đây là yếu tố ảnh hưởng lớn nhất đến việc model chọn đúng tool. Nên có ít nhất 3-4 câu: tool làm gì, khi nào nên/không nên dùng, ý nghĩa từng tham số, giới hạn/caveat.
- Viết như đang giải thích cho một đồng nghiệp mới vào team — làm rõ context ngầm định (định dạng query đặc thù, thuật ngữ nội bộ).
- Đặt tên tham số rõ nghĩa (`user_id` thay vì `user`).
- **Gộp các thao tác liên quan vào ít tool hơn** bằng tham số `action`, thay vì tạo nhiều tool đơn lẻ (vd một tool `github` với action create/review/merge, thay vì 3 tool riêng) — giảm nhập nhằng khi model chọn tool.
- **Namespacing tên tool** khi có nhiều service (`github_list_prs`, `slack_send_message`) — đặc biệt quan trọng khi dùng tính năng tool search; Anthropic ghi nhận sự khác biệt đáng kể giữa prefix-based và suffix-based namespacing.
- **Response của tool nên trả về thông tin có tín hiệu cao**: dùng identifier ngữ nghĩa/ổn định thay vì UUID nội bộ mù mờ, chỉ trả field model thực sự cần, hỗ trợ pagination/filter/truncate để tiết kiệm token (Claude Code giới hạn tool response ở 25.000 token).
- Error message nên actionable/hướng dẫn được, không chỉ là mã lỗi khô khan.
- Đánh giá tool bằng task đa bước thực tế (vd lên lịch họp kèm đính kèm tài liệu), đo cả accuracy lẫn runtime/số lần gọi tool/token/tỷ lệ lỗi, dùng verifier linh hoạt (chấp nhận cách diễn đạt hợp lệ khác nhau), và test trên tập held-out để tránh overfit mô tả tool vào chính ví dụ dùng để tinh chỉnh.
- Anthropic từng dùng chính Claude (kể cả dán transcript đánh giá vào Claude Code) để review và viết lại tool description cho MCP server Slack/Asana của họ, đo được cải thiện performance rõ rệt — một ví dụ AI tối ưu tool cho chính nó (confidence: medium).

Ví dụ minh hoạ chênh lệch mô tả (theo doc chính thức):

| Kiểu | `get_stock_price` |
|---|---|
| Tốt | Đoạn văn đầy đủ: phạm vi dữ liệu, input hợp lệ, và nói rõ tool **không** trả về gì (vd không có dữ liệu real-time intraday) |
| Kém | `"Gets the stock price for a ticker."` — không mô tả tham số, dễ khiến model gọi sai hoặc gọi mơ hồ |

## Liên hệ tới các phần khác

- So với [[agent-building-function-calling-overview]]: bài đó là khung 4 bước chung cho mọi provider; bài này là cách Anthropic hiện thực cụ thể (tên field, `tool_use`/`tool_result`, `tool_choice`, built-in server tools).
- So với [[agent-tool-definition]]: đó là nguyên tắc khai báo tool nói chung (schema, mô tả); bài này bổ sung phần đặc thù Anthropic (`input_schema`, `strict`, `input_examples`, namespacing).
- Liên quan [[agent-building-manual-from-scratch]]: nếu tự viết agent loop bằng Messages API trực tiếp (không qua SDK), đây chính là cơ chế round-trip `tool_use`/`tool_result` cần tự quản lý.

### Áp dụng với Claude Code

- Claude Code (CLI) và Claude Agent SDK **dùng chính cơ chế này bên dưới**, nhưng ẩn round-trip khỏi người dùng: built-in tool (Bash, Read, Edit...) và custom tool (in-process MCP server chạy trong ứng dụng host) đều được đưa vào cùng một mảng `tools` với `name`/`description`/`input_schema` như Messages API thô, rồi SDK tự lo việc gửi lại `tool_result`.
- Interleaved thinking (nghĩ xen giữa các lần gọi tool) là cơ chế nền cho pattern nhiều bước quen thuộc trong Claude Code: đọc file → suy nghĩ → sửa file → suy nghĩ → chạy test.
- `allowedTools` trong Agent SDK/Claude Code permission model chỉ kiểm soát việc **có cần hỏi user xác nhận** trước khi chạy tool hay không — đây là lớp permission nằm trên cơ chế `tool_use`/`tool_result` gốc, không thay thế nó (confidence: medium).
- `tool_choice`, `disable_parallel_tool_use`, hay việc tinh chỉnh token overhead theo `tool_choice` là các tham số ở tầng Messages API thô — Claude Code không expose trực tiếp các tham số này cho người dùng cuối qua CLI; chúng nằm trong lớp điều phối nội bộ của SDK.

## Giới hạn / open questions

- Chưa rõ chi tiết cách Claude Code/Agent SDK map `allowedTools` và cấu hình permission cụ thể xuống các trường `tool_choice`/`disable_parallel_tool_use` ở tầng Messages API — nguồn tham khảo chỉ ở mức tóm tắt (confidence: medium), cần đọc kỹ hơn `agent-sdk/custom-tools` và `agent-sdk/mcp` khi có thời gian.
- Số liệu token overhead theo `tool_choice`/model (vd Opus 5: 286 vs 406 token) là con số tại một thời điểm cụ thể, có thể thay đổi khi Anthropic cập nhật system prompt nội bộ — nên coi là minh hoạ độ lớn, không phải hằng số cố định.
- Chưa research sâu về "programmatic tool calling" (nhắc tới trong nguồn parallel-tool-use) — không rõ đây có phải một chế độ tách biệt với tool_use thông thường hay chỉ là một biến thể cấu hình.
- Chưa kiểm chứng độc lập tuyên bố về "non-trivial effects" của namespacing prefix vs suffix trong bài "Writing tools for agents" — chỉ dựa trên báo cáo của chính Anthropic, chưa có benchmark bên thứ ba.
