---
status: current
updated: 2026-08
sources:
  - https://help.openai.com/en/articles/5072263-how-do-i-use-stop-sequences-in-the-openai-api
  - https://help.openai.com/en/articles/5072518-controlling-the-length-of-openai-model-responses
  - https://developers.openai.com/api/reference/resources/chat/subresources/completions/methods/create
  - https://platform.claude.com/docs/en/api/handling-stop-reasons
  - https://huggingface.co/docs/transformers/main_classes/text_generation
  - https://huggingface.co/docs/transformers/en/internal/generation_utils
  - https://github.com/huggingface/transformers/blob/main/src/transformers/generation/stopping_criteria.py
  - https://www.metriccoders.com/post/defining-stopping-criteria-in-large-language-models-a-practical-guide
  - https://code.claude.com/docs/en/agent-sdk/agent-loop
  - https://mbrenndoerfer.com/writing/repetition-penalties-language-model-generation
roadmap: ai-engineer
stage: done
---

# Stopping Criteria — các quy tắc quyết định khi nào LLM ngừng sinh token

**TL;DR**: Stopping criteria là tập hợp các điều kiện (cứng và mềm) khiến vòng lặp decode của LLM dừng lại — phổ biến nhất là **max tokens** (giới hạn cứng), **EOS token** (model tự báo hiệu kết thúc), **custom stop string** (chuỗi tuỳ chỉnh do người dùng cấu hình), và các cơ chế mềm hơn như phát hiện lặp/lạc đề; thiếu chúng, model có thể sinh token vô tận, gây tốn thời gian và chi phí.

## Bốn nhóm cơ chế dừng chính

- **Max tokens / max length** — giới hạn cứng theo số lượng token, không quan tâm nội dung đã "xong" hay chưa; rủi ro cắt cụt output giữa câu, giữa `tool_use` block. Đào sâu riêng ở [[llm-max-length]].
- **EOS token (End-Of-Sequence)** — token đặc biệt model học được trong training để đánh dấu điểm kết thúc tự nhiên; khi model tự dự đoán ra token này, vòng lặp generate dừng — đây là cơ chế dừng "do model quyết định", khác với các giới hạn áp đặt từ bên ngoài.
- **Custom stop string/sequence** — chuỗi text tuỳ chỉnh do người dùng cấu hình (VD `"\nHuman:"`, `"<END>"`); khi output khớp chuỗi này, generation dừng ngay, và chuỗi stop đó thường **không** được trả về trong kết quả.
- **Phát hiện lặp / lạc đề (repetition, off-topic)** — cơ chế mềm hơn, thường không nằm trong API chuẩn mà do ứng dụng tự cài đặt: giám sát output theo thời gian thực hoặc theo khối cố định, dừng/regenerate khi phát hiện lặp hoặc trôi khỏi chủ đề.

## Cách OpenAI và Anthropic hiện thực hoá

### OpenAI Chat Completions

- Tham số `stop`: string hoặc mảng tối đa **4 chuỗi**; model dừng ngay khi sinh ra một trong các chuỗi này, và chuỗi đó **không** nằm trong text trả về (as of help.openai.com, confidence: high).
- Tham số `max_tokens`/`max_completion_tokens`: giới hạn số token sinh thêm, hoạt động độc lập và có thể cắt output trước khi chạm được stop sequence.
- Response có field `finish_reason` cho biết lý do dừng:
  - `stop` — đạt điểm dừng tự nhiên hoặc khớp stop sequence, output hoàn chỉnh.
  - `length` — chạm giới hạn token, output có thể chưa hoàn chỉnh.
  - `content_filter` — bị lọc nội dung.
  - `tool_calls`/`function_call` — model gọi tool.
- Ví dụ request/response thật (rút gọn):

```jsonc
// Request
{
  "model": "gpt-4o-mini",
  "messages": [{"role": "user", "content": "Viết 1 câu chào"}],
  "stop": ["\n\n"],
  "max_tokens": 20
}

// Response (khi bị max_tokens cắt cụt)
{
  "choices": [{
    "message": {"content": "Xin chào! Rất vui được"},
    "finish_reason": "length"
  }]
}
```

- Lưu ý thực dụng: stop string có thể không khớp chính xác nếu bị tokenizer tách khác dự kiến (VD `"stop"` bị tách thành `"st"` + `"op"`); tránh dùng từ quá phổ biến (`"a"`, `"the"`) làm stop string vì dễ dừng sớm ngoài ý muốn.

### Anthropic Claude Messages API

- Tham số `stop_sequences`: tối đa **8191 chuỗi** tuỳ chỉnh; khi Claude sinh ra một chuỗi khớp, generation dừng ngay lập tức.
- Mọi response thành công đều có field `stop_reason` (as of platform.claude.com, confidence: high), liệt kê đầy đủ hơn OpenAI:
  - `end_turn` — dừng tự nhiên.
  - `max_tokens` — chạm giới hạn.
  - `stop_sequence` — khớp `stop_sequences`; field `stop_sequence` riêng ghi rõ chuỗi nào khớp, null ở mọi trường hợp khác.
  - `tool_use` — model gọi tool, tức là thay vì trả text, response chứa một khối `tool_use` block (JSON mô tả tên tool + tham số) để hệ thống bên ngoài thực thi.
  - `pause_turn` — vòng lặp server-side tool (model tự gọi tool nhiều lần liên tiếp trong 1 turn) đạt giới hạn lần lặp mặc định là 10.
  - `refusal` — bị content classifier chặn, vẫn trả HTTP 200.
  - `model_context_window_exceeded` — response lấp đầy context window.
- Ví dụ request/response thật (rút gọn):

```jsonc
// Request
{
  "model": "claude-opus-4-20250514",
  "max_tokens": 20,
  "messages": [{"role": "user", "content": "Viết 1 câu chào"}],
  "stop_sequences": ["\n\n"]
}

// Response (khi bị max_tokens cắt cụt)
{
  "content": [{"type": "text", "text": "Xin chào! Rất vui được"}],
  "stop_reason": "max_tokens",
  "stop_sequence": null
}
```

- Xử lý thực tế:
  - Khi `stop_reason = max_tokens`, response có thể bị cắt cụt kể cả giữa một `tool_use` block chưa hoàn chỉnh — nên tăng `max_tokens` và gọi lại, hoặc nối phần đã có vào messages để "tiếp tục" sinh.
  - Khi `pause_turn`, gửi lại nguyên vẹn assistant response trong message mới để Claude tiếp tục vòng lặp — đây không phải lỗi, chỉ là điểm nghỉ giữa các lần gọi tool.

## Hugging Face Transformers: pluggable StoppingCriteria

- Mặc định dừng theo hai điều kiện, cái nào đến trước: sinh ra `eos_token_id` (có thể truyền **danh sách nhiều EOS id** cho model chat/instruct có nhiều điểm kết thúc lượt), hoặc đạt `max_new_tokens` (chỉ đếm token sinh thêm, không tính prompt).
- Abstraction `StoppingCriteria` (một class Python, override hàm `__call__` để tự quyết định "dừng hay chưa" ở mỗi bước sinh token) cho phép cắm logic tuỳ chỉnh, kết hợp OR qua `StoppingCriteriaList`. Các built-in tiêu biểu:
  - `MaxLengthCriteria` — dừng khi **tổng** độ dài (prompt + generated) đạt `max_length`.
  - `EosTokenCriteria` — dừng theo **EOS** (End-Of-Sequence, xem định nghĩa ở mục trên), cơ chế mặc định.
  - `MaxTimeCriteria` — giới hạn theo thời gian thực đã trôi qua (wall-clock time), không phải theo số token.
  - `StopStringCriteria` — dừng khi một chuỗi cụ thể xuất hiện ở cuối text đã sinh, khớp qua logic "token-boundary-aware" (so khớp đúng ranh giới token trong vocabulary của tokenizer, tránh khớp nhầm một phần của token khác).

```python
from transformers import StoppingCriteriaList, MaxLengthCriteria, StopStringCriteria

stopping_criteria = StoppingCriteriaList([
    MaxLengthCriteria(max_length=200),
    StopStringCriteria(tokenizer=tokenizer, stop_strings=["</answer>", "\nUser:"]),
])
outputs = model.generate(**inputs, stopping_criteria=stopping_criteria)
```

## Ví dụ minh hoạ: cùng một prompt, ba cách dừng khác nhau

| Cơ chế | Cấu hình | Output |
|---|---|---|
| Không giới hạn | — | Model có thể sinh vô hạn tới khi hết context window, tốn tiền/thời gian |
| `max_tokens=20` | Giới hạn cứng | `"Hello, my name is John and I work as a soft"` — cắt cụt giữa từ |
| `stop=["\n\n"]` | Custom stop string | `"Hello, my name is John and I work as a software engineer."` — dừng đúng lúc gặp dòng trống, output trọn vẹn |

## Cơ chế mềm: phát hiện lặp và lạc đề

- **Repetition penalty / frequency penalty / presence penalty** không phải stopping criteria — chúng điều chỉnh **logit** (điểm số thô trước khi tính xác suất) của token đã dùng để giảm xác suất bị chọn lại, chứ không dừng hẳn generation; xem chi tiết ở [[llm-frequency-penalty]] và [[llm-presence-penalty]]. Các penalty này chỉ tác động ở cấp token identity nên không ngăn được **lặp ngữ nghĩa** (diễn đạt lại cùng một ý bằng từ khác) (as of mbrenndoerfer.com, confidence: medium).
- Một kỹ thuật thực tế để chủ động dừng khi lặp: `StoppingCriteria` tuỳ chỉnh giám sát output theo khối (block) kích thước cố định, dừng decode nếu một khối mới sinh đã từng xuất hiện trước đó. Nguồn tham khảo cho ý này chưa verify được toàn văn — xem chi tiết ở mục "Giới hạn / open questions".
- **Semantic stopping / off-topic detection**: dùng một model/classifier phụ đánh giá xem output đã "xong" về mặt nội dung hay đã lạc đề, từ đó dừng hoặc yêu cầu regenerate. Hai kiểu classifier hay dùng:
  - **Bi-encoder** — mã hoá câu hỏi và output thành 2 vector riêng rồi so khớp, nhanh (throughput cao) nhưng kém chính xác hơn.
  - **Cross-encoder** — đưa cả câu hỏi và output vào chung một lần chạy model, chậm hơn nhưng chính xác hơn.
  - Đây là cơ chế điều phối ở tầng response/đoạn văn, khác hẳn stopping criteria cấp-token như max_tokens/EOS/stop string. Nguồn cho ý này mới dừng ở mô tả khái niệm, chưa có benchmark — xem "Giới hạn / open questions".
- **Function/tool calling** cũng đóng vai trò một điểm dừng có cấu trúc: model dừng khi đã tạo xong một lời gọi tool hợp lệ theo schema, đảm bảo output có cấu trúc cho hệ thống agent.

## Liên hệ tới các phần khác

- [[llm-temperature]], [[llm-top-p]] định hình *cách chọn* token tiếp theo trong lúc vẫn đang sinh; stopping criteria quyết định *khi nào ngừng chọn nữa* — hai nhóm cơ chế bổ sung, không thay thế nhau.
- [[llm-frequency-penalty]], [[llm-presence-penalty]] giảm khả năng lặp bằng cách hạ logit, còn stopping criteria (đặc biệt cơ chế phát hiện lặp theo khối) chặn đứng hẳn vòng lặp khi lặp đã xảy ra — dùng kết hợp cả hai trong production để vừa giảm lặp vừa có "lưới an toàn" dừng cứng.
- [[llm-context-window]]: khi output sắp lấp đầy context window, đây cũng là một điều kiện dừng bắt buộc (`model_context_window_exceeded` ở Claude), độc lập với `max_tokens` do người dùng đặt.
- [[llm-token-pricing]]: max_tokens vừa là stopping criterion vừa là cơ chế kiểm soát chi phí — sinh không giới hạn đồng nghĩa với chi phí không kiểm soát được.

### Áp dụng với Claude Code

Claude Code (qua Claude Agent SDK) có một lớp stopping criteria riêng ở **cấp agent loop** (chuỗi nhiều lượt gọi Messages API + gọi tool nối tiếp nhau để hoàn thành một tác vụ), nằm ngoài `stop_reason` của một lần gọi Messages API đơn lẻ.

- Hai tham số giới hạn có thể cấu hình:
  - `max_turns`/`maxTurns` — giới hạn số turn có gọi tool (không tính turn chỉ có text); CLI expose qua flag `--max-turns` ở chế độ non-interactive.
  - `max_budget_usd`/`maxBudgetUsd` — giới hạn theo chi phí tích luỹ (USD).
- Khi kết thúc, SDK trả về một `ResultMessage` (message tổng kết toàn bộ agent loop) với field `subtype` cho biết lý do dừng — ví dụ rút gọn:

```jsonc
// ResultMessage khi chạm giới hạn turn
{ "type": "result", "subtype": "error_max_turns", "stop_reason": null }

// ResultMessage khi hoàn thành bình thường
{ "type": "result", "subtype": "success", "stop_reason": "end_turn" }
```

(as of code.claude.com/docs/en/agent-sdk/agent-loop, confidence: high)

- Điều kiện dừng "thành công" của agent loop là khi Claude tạo ra một response **không có tool call nào** ("no tool calls") — đây là stopping criterion chính ở cấp agent, tách biệt với `stop_reason = end_turn` của một request Messages API đơn lẻ.
- Các giá trị `subtype` hay gặp:
  - `success` — vòng lặp kết thúc bình thường; `stop_reason` khi đó phản ánh lý do dừng ở lượt cuối (`end_turn`, `max_tokens`, `refusal`...).
  - `error_max_turns` / `error_max_budget_usd` — chạm giới hạn `max_turns`/`max_budget_usd`.
  - `error_during_execution` — lỗi gián đoạn, VD API lỗi hoặc request bị huỷ.
  - `error_max_structured_output_retries` — không tạo được structured output hợp lệ sau số lần retry cấu hình.
  - Nếu vòng lặp kết thúc do session crash, `stop_reason` là `null`.
- Ý nghĩa thực dụng: nếu một tác vụ dài bị dừng giữa chừng không rõ lý do, nên kiểm tra `ResultMessage.subtype` trước. Nó giúp phân biệt hai nhóm nguyên nhân khác nhau về cách xử lý: chạm `max_turns`/`max_budget_usd` (cần tăng giới hạn hoặc chia nhỏ tác vụ) hay lỗi thực thi (cần debug) — thay vì chỉ nhìn `stop_reason` cấp Messages API.

## Giới hạn / open questions

- Chưa verify được toàn văn các claim liên quan tới kỹ thuật phát hiện lặp theo khối cố định (arxiv 2503.00416) và ảnh hưởng của `early_stopping=True` trong beam search tới tỷ lệ lặp — mới có bản tóm tắt qua search, cần đọc trực tiếp paper để xác nhận số liệu.
- Chưa rõ độ chính xác/latency thực tế của các cơ chế "semantic stopping" hay off-topic classifier trong production (VD threshold, false positive rate) — nguồn metriccoders.com chỉ mô tả khái niệm, không có benchmark cụ thể.
- Các nhà cung cấp khác (Gemini, open-source serving stack như vLLM/TGI) có thể có tên tham số và ngữ nghĩa `stop_reason` khác OpenAI/Anthropic — note này chưa khảo sát các nền tảng đó.
