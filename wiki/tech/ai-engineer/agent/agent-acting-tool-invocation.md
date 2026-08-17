---
status: current
updated: 2026-08
sources:
  - https://huggingface.co/learn/agents-course/en/unit1/tools
  - https://platform.claude.com/docs/en/agents-and-tools/tool-use/how-tool-use-works
  - https://platform.claude.com/docs/en/agents-and-tools/tool-use/overview
  - https://code.claude.com/docs/en/agent-sdk/agent-loop
  - https://code.claude.com/docs/en/hooks
  - https://react-lm.github.io/
  - https://developers.openai.com/api/docs/guides/function-calling
roadmap: ai-engineer
stage: done
---

# Acting / Tool Invocation — bước 3 trong agent loop, biến "ý định" thành hành động thật

**TL;DR**: Acting là bước agent chọn một **tool** phù hợp (function, API call, DB query, code execution...) và thực thi nó để lấy dữ liệu thật hoặc thay đổi trạng thái thế giới ngoài. Nó khác căn bản với LLM call thuần — vốn chỉ sinh text từ tri thức đã học, không chạm gì vào thế giới ngoài. Điểm mấu chốt cần nhớ: **model chỉ quyết định** gọi tool nào với tham số gì, còn **runtime/harness mới là bên thực sự thực thi** lệnh gọi đó và trả kết quả về.

## 1. Vị trí trong agent loop

- Trong [[agent-loop]], 4 bước là perceive → [[agent-reason-plan]] → **act/invoke tool** → observe/reflect. Acting là bước 3, ngay sau khi model đã quyết định "cần làm gì tiếp theo".
- **Input**: quyết định từ bước Reason/Plan — tên tool + tham số (dạng structured request).
- **Output**: kết quả thực thi thật (dữ liệu trả về, trạng thái thay đổi, hoặc lỗi) — output này sẽ trở thành input cho bước Observation & Reflection kế tiếp.
- Đây là bước duy nhất trong loop có tác động **ra ngoài context của model** — gọi API thật, chạy code thật, ghi file thật, đổi dữ liệu trong DB thật.

## 2. Hai lớp bắt buộc phải phân biệt

Đây là điểm dễ nhầm lẫn nhất khi mô tả bước Acting: có **2 tác nhân khác nhau** tham gia, không phải 1.

| Lớp | Ai làm | Làm gì |
|---|---|---|
| (1) Model quyết định | LLM (Claude, GPT, ...) | Tự quyết định "cần gọi tool nào, với tham số gì" dựa trên mô tả tool trong system prompt — chỉ **sinh ra một structured request** (text/JSON), không thực thi được gì cả |
| (2) Runtime/harness thực thi | Code bao quanh (agent framework, Claude Code, ứng dụng của bạn, hoặc hạ tầng server-side của provider) | Đọc structured request đó, **thực sự chạy** function/API/query tương ứng, rồi format kết quả gửi lại cho model |

- HuggingFace Agents Course mô tả rất rõ: LLM không thể tự thực thi tool — nó chỉ sinh text mô tả ý định gọi tool (VD `call weather_tool('Paris')`); Agent (runtime) mới là bên đọc, thực thi thật, lấy dữ liệu thật rồi nối kết quả vào hội thoại trước khi đưa lại cho LLM. Từ góc nhìn người dùng, trông như LLM "tự" gọi tool, nhưng thực chất toàn bộ việc thực thi diễn ra ở harness phía sau.
- Anthropic mô tả tool use như một **hợp đồng** giữa ứng dụng và model: bạn định nghĩa operation + input/output shape, Claude quyết định khi nào và gọi thế nào, nhưng "**model không bao giờ tự thực thi bất cứ điều gì**" — nó chỉ emit structured request, code của bạn (hoặc server của Anthropic) chạy operation, rồi kết quả quay lại hội thoại.
- OpenAI mô tả tương tự cho function calling: model không tự chạy function — nó chỉ chọn function + tham số, backend của bạn thực thi và trả kết quả về cho model.

> Cả 3 nguồn trên đồng thuận cùng 1 điểm, xem bảng "Nguồn & độ tin cậy" cuối bài.

## 3. Ai thực thi tool — 3 nhóm (theo Anthropic)

Không phải lúc nào "runtime" cũng là code của bạn — Anthropic chia tool thành 3 nhóm dựa trên nơi code thực sự chạy. Biết nhóm nào đang dùng quan trọng vì nó quyết định **bạn có phải tự viết code thực thi tool và tự gửi `tool_result` về hay không**:

1. **User-defined client-executed tools**: bạn viết schema, bạn tự thực thi code, bạn tự gửi `tool_result` về.
2. **Anthropic-schema client-executed tools** (`memory`, `bash`, `text_editor`, `computer`): vẫn chạy phía client (ứng dụng của bạn), nhưng dùng schema có sẵn từ Anthropic — Claude được train để gọi các tool này ổn định hơn và tự phục hồi tốt hơn khi gặp lỗi.
3. **Server-executed tools** (`web_search`, `web_fetch`, `code_execution`, `tool_search`): chạy hoàn toàn trên hạ tầng của Anthropic — bạn không cần tự build `tool_result`, kết quả trả về trực tiếp.

Với nhóm (3), Anthropic còn chạy một **vòng lặp Act nội bộ** (có thể tự gọi lại web_search nhiều lần) với giới hạn số vòng lặp; nếu chưa xong mà chạm giới hạn, API trả `stop_reason: "pause_turn"` thay vì `"end_turn"` (`stop_reason` là field cho biết vì sao model dừng sinh text — giá trị `pause_turn` nghĩa là model tạm dừng giữa chừng vì chạm giới hạn nội bộ, chưa thực sự xong lượt), và caller phải gửi lại hội thoại để model tiếp tục.

## 4. Vòng lặp Act cụ thể (client-executed tools)

Đây là while-loop thực tế mà hầu hết framework agent (kể cả Claude Agent SDK) triển khai:

1. Gửi request kèm mảng `tools` cho model.
2. Model trả về `stop_reason: "tool_use"` (nghĩa là model dừng sinh text vì đang muốn gọi tool) cùng một hoặc nhiều **`tool_use` block** — mỗi block là 1 object JSON gồm tên tool + tham số đầu vào, được model điền theo **`input_schema`** (bản mô tả cấu trúc tham số hợp lệ mà bạn khai báo sẵn cho từng tool, giống schema của 1 API request).
3. Ứng dụng (harness) **thực thi từng tool** và format output thành các **`tool_result` block** (object JSON chứa kết quả chạy tool, gắn lại đúng `tool_use_id` tương ứng).
4. Ứng dụng gửi request mới kèm các `tool_result` đó.
5. Lặp lại khi `stop_reason` vẫn là `"tool_use"` — thoát vòng lặp khi gặp `end_turn` (model đã trả lời xong), `max_tokens`, `stop_sequence`, hoặc refusal.

Ví dụ minh hoạ 1 vòng (rút gọn):

```json
// Model trả về (bước 2)
{
  "stop_reason": "tool_use",
  "content": [
    { "type": "tool_use", "id": "toolu_01A", "name": "get_weather",
      "input": { "location": "Paris" } }
  ]
}

// Harness thực thi get_weather("Paris") thật, rồi gửi lại (bước 4)
{
  "role": "user",
  "content": [
    { "type": "tool_result", "tool_use_id": "toolu_01A",
      "content": "15°C, mưa nhẹ" }
  ]
}
```

Model không hề chạm vào API thời tiết thật — nó chỉ nhìn thấy chuỗi text `"15°C, mưa nhẹ"` được harness đưa vào context.

## 5. Trường hợp cụ thể: Claude Code / Claude Agent SDK

- SDK mô tả loop tương tự: nhận prompt → Claude đánh giá và trả lời (có thể kèm yêu cầu gọi tool) → **SDK (không phải model) thực sự chạy tool**, thu kết quả, đưa lại cho Claude → lặp lại tới khi một lượt không còn tool call nào → trả kết quả cuối.
- Việc model "muốn" gọi tool không đồng nghĩa nó **được phép** — Claude Code có lớp permission riêng (`allowed_tools`/`disallowed_tools`, `permission_mode`: `default`, `acceptEdits`, `plan`, `dontAsk`, `auto`, `bypassPermissions`). Khi bị từ chối, Claude nhận một rejection message **như thể đó là kết quả tool** (tool_result báo lỗi), rồi thường tự thử cách khác hoặc báo không làm được — đây là ví dụ cụ thể cho việc "tool call bị chặn/lỗi" chảy ngược vào bước Observation & Reflection.
- Hooks cho phép harness can thiệp quanh bước Act: `PreToolUse` chạy **trước** khi tool thực thi và có thể chặn (exit code 2 chặn cuộc gọi, stderr trở thành lý do chặn gửi cho model; exit 0 cho phép); `PostToolUse` chạy sau khi tool đã chạy xong, dùng để audit — với các sự kiện chỉ-quan-sát này, exit 2 không hoàn tác hành động nhưng vẫn đưa stderr về model.
- Khi model yêu cầu nhiều tool call trong 1 lượt, SDK **song song hoá** các tool chỉ-đọc (Read, Glob, Grep, MCP tool đánh dấu read-only), còn tool thay đổi trạng thái (Edit, Write, Bash) chạy **tuần tự** để tránh xung đột.

## 6. Lỗi thường gặp ở bước Acting

- **Sai tool**: agent chọn nhầm tool trong tập tool có sẵn, hoặc hallucinate ra tên tool không tồn tại.
- **Sai tham số**: tên tham số đúng nhưng giá trị/định dạng sai; hoặc thiếu tham số bắt buộc. Với Claude, hành vi khi thiếu tham số **khác theo model**: Opus có xu hướng nhận ra và hỏi lại người dùng, còn Sonnet có thể tự đoán (hallucinate) giá trị còn thiếu — hành vi này không được đảm bảo, cần validate ở tầng ứng dụng.
- **Silent failure**: tool trả về `status: success` với response hợp lệ về mặt cấu trúc nhưng bản chất được tính từ tham số sai — khó phát hiện vì không có lỗi tường minh, và lỗi nhỏ ở bước Act có thể âm thầm lan sang mọi bước phụ thuộc phía sau.
- Điểm chung: cả 3 loại lỗi trên đều chỉ lộ ra ở bước Observation & Reflection tiếp theo — nếu bước đó không kiểm tra kỹ (chỉ tin tưởng mù quáng vào tool_result), lỗi sẽ tích luỹ qua nhiều vòng lặp. Chi tiết nguồn và độ tin cậy của các claim trên xem bảng cuối bài.

## 7. Ví dụ so sánh 3 kiến trúc liền kề

| Kiến trúc | Có bước Act (thay đổi trạng thái ngoài) không? |
|---|---|
| LLM call thuần | Không — chỉ sinh text từ tri thức đóng băng lúc train |
| RAG | Không — chỉ thêm bước retrieve dữ liệu (đọc), chưa "hành động" thay đổi gì |
| Agent với tool use | Có — có thể gọi API, ghi file, chạy code, tức thực sự thay đổi trạng thái thế giới ngoài |

## Liên hệ tới các phần khác

- [[agent-loop]] — bức tranh tổng thể 4 bước, Acting là bước 3.
- [[agent-reason-plan]] — bước ngay trước, nơi model quyết định "gọi tool gì" (nhưng chưa thực thi).
- [[agent-perception-user-input]] — bước 1, nơi input ban đầu được thu thập.

### Áp dụng với Claude Code

Claude Code là ví dụ cụ thể và trực tiếp nhất của bước Acting: mọi lệnh gọi tool (Read, Edit, Bash, WebFetch, MCP tool...) đều đi qua đúng 2 lớp mô tả ở mục 2 — Claude (model) chỉ quyết định gọi tool nào với tham số gì, còn **Claude Code SDK (harness)** mới là bên thực sự chạy lệnh đó trên máy người dùng. Lớp permission (`allowed_tools`, `permission_mode`, hooks `PreToolUse`/`PostToolUse`) là cơ chế cụ thể để kiểm soát/can thiệp vào bước Act này trước khi nó chạm vào hệ thống thật — không có trong mô tả tool-use chung chung của Anthropic API mà là đặc thù của harness Claude Code.

## Nguồn & độ tin cậy

| Claim | Nguồn | Confidence |
|---|---|---|
| Model chỉ sinh text mô tả ý định gọi tool, harness (agent) mới thực thi thật (mục 2) | huggingface.co/learn/agents-course | high |
| "Model không bao giờ tự thực thi bất cứ điều gì" trong tool use — luôn cần code phía app/server chạy thay (mục 2) | platform.claude.com/tool-use/how-tool-use-works | high |
| Server-executed tools có vòng lặp Act nội bộ, giới hạn bằng `stop_reason: pause_turn` (mục 3) | platform.claude.com/tool-use/how-tool-use-works | medium |
| Claude Agent SDK: SDK (không phải model) là bên thực sự chạy tool trong agent loop (mục 5) | code.claude.com/agent-sdk/agent-loop | high |
| Hành vi khi thiếu tham số khác nhau giữa Opus và Sonnet (mục 6) | platform.claude.com/tool-use/overview | high |
| Silent failure (status success nhưng tính sai) là 1 failure mode phổ biến của agent (mục 6) | openlayer.com/blog/ai-agent-failure-modes | medium |

## Giới hạn / open questions

- Số liệu benchmark cụ thể về tần suất mỗi loại lỗi (sai tool / sai tham số / silent failure) trong production chưa được nghiên cứu sâu — các nguồn dùng để tổng hợp mục 6 có độ tin cậy medium (blog, chưa phải paper).
- Cơ chế "vòng lặp Act nội bộ" của server-executed tools (mục 3) mới chỉ biết ở mức API-level (`pause_turn`), chưa rõ giới hạn số vòng lặp cụ thể là bao nhiêu hoặc có cấu hình được không.
- Chưa khảo sát cách các framework agent khác (LangChain, LlamaIndex, AutoGen) triển khai bước Acting có gì khác biệt so với Anthropic/OpenAI — note này tập trung vào 2 provider đó và Claude Code.
