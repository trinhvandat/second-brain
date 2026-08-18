---
status: current
updated: 2026-08
sources:
  - https://platform.claude.com/docs/en/build-with-claude/prompt-engineering/claude-prompting-best-practices
  - https://platform.claude.com/docs/en/build-with-claude/prompt-engineering/prompting-claude-opus-5
  - https://platform.claude.com/docs/en/build-with-claude/structured-outputs
  - https://developers.openai.com/api/docs/guides/prompt-engineering
  - https://help.openai.com/en/articles/5072518-controlling-the-length-of-openai-model-responses
  - https://developers.openai.com/api/docs/guides/structured-outputs
  - https://ai.google.dev/gemini-api/docs/prompting-strategies
  - https://www.dre.vanderbilt.edu/~schmidt/PDF/prompt-patterns.pdf
  - https://code.claude.com/docs/en/agent-sdk/structured-outputs
  - https://code.claude.com/docs/en/output-styles
  - https://www.dbreunig.com/2026/04/04/how-claude-code-builds-a-system-prompt.html
roadmap: ai-engineer
stage: learning
---

# Writing Good Prompts — chỉ định Length, Format, và Audience

TL;DR:
- **Cần chỉ định gì**: độ dài (length), cấu trúc (format: bullet/table/JSON/markdown), và đối tượng đọc (audience) mong muốn.
- **Vì sao quan trọng**: nếu không nói rõ, model tự đoán — và phán đoán đó thường lệch với nhu cầu thực tế.
- **Khi nào critical**: đặc biệt nguy hiểm nếu output được một chương trình khác parse tiếp theo (downstream parser có thể crash hoặc sai âm thầm).

## Vấn đề: model mặc định theo phán đoán riêng

- Khi prompt không ràng buộc rõ, model phải tự chọn: viết bao nhiêu chữ, dùng văn xuôi hay bullet, trình bày JSON hay markdown, viết cho người mới hay chuyên gia.
- Hệ quả thường gặp:
  - Cần một bảng ngắn 5 dòng nhưng nhận về một bài luận dài.
  - Cần JSON để hệ thống downstream parse nhưng nhận về prose lẫn giải thích.
  - Cần trả lời cho non-technical stakeholder nhưng model dùng thuật ngữ chuyên sâu.
- Các model Claude thế hệ mới (Sonnet 5/Opus 5) có xu hướng **súc tích hơn mặc định**. Chúng có thể bỏ qua summary chi tiết trừ khi được yêu cầu rõ. Nói cách khác, default verbosity đã dịch chuyển — càng cần prompt chỉ định rõ nếu muốn output khác default [^1].
- Với Opus 5, tham số **`effort`** (cờ điều chỉnh "model suy nghĩ/xử lý kỹ đến đâu" trước khi trả lời) **không đáng tin cậy** để thay đổi độ dài phản hồi hiển thị ra ngoài. Phải prompt trực tiếp về độ dài/độ súc tích thay vì trông chờ vào effort setting.

## Bốn trục cần chỉ định rõ

- **Length**: số từ/câu/đoạn mục tiêu (ví dụ "trả lời trong 3 câu", "tối đa 150 từ").
- **Format**: cấu trúc đầu ra — bullet list, table, JSON, markdown headings, prose liền mạch...
- **Tone/register**: trang trọng, thân mật, kỹ thuật, marketing...
- **Audience/expertise level**: người mới bắt đầu, kỹ sư senior, ban lãnh đạo phi kỹ thuật...

## Kỹ thuật chỉ định format (theo Anthropic)

- Nói **model nên làm gì**, thay vì chỉ nói "đừng làm gì" — hướng dẫn tích cực (**positive instruction**) hiệu quả hơn hướng dẫn phủ định (**negative instruction**). Ví dụ:
  - ❌ Negative: "Đừng dùng markdown, đừng viết dài dòng."
  - ✅ Positive: "Trả lời bằng 2-3 đoạn văn xuôi mạch lạc, câu ngắn, không dùng heading hay bullet."
  - Lý do: câu phủ định chỉ nói model tránh gì, không nói model nên làm gì thay vào đó — model dễ "đoán bừa" phần còn thiếu.
- Dùng **XML tag làm format indicator**, ví dụ bọc kết quả mong muốn trong `<smoothly_flowing_prose_paragraphs>` — giúp model bám sát cấu trúc.
- **Match style của prompt với style mong muốn của output**: nếu prompt không chứa markdown, output cũng có xu hướng ít markdown hơn.
- Claude mới mặc định dùng LaTeX cho công thức toán — nếu cần plain text phải nói rõ.
- Với các tác vụ classification/JSON/YAML: kỹ thuật **prefill** cũ (tự viết sẵn phần đầu output, ví dụ ép model bắt đầu bằng ký tự `{`, để "mồi" đúng định dạng) đã được thay thế. Cách hiện đại đơn giản hơn: chỉ cần yêu cầu trực tiếp "hãy tuân theo cấu trúc output sau" — model hiện đại theo schema tốt hơn nếu được yêu cầu rõ, kết hợp retry khi cần.

## Khi output đi vào một chương trình khác (structured output)

- Đây là trường hợp **critical nhất** để chỉ định format — vì downstream parser sẽ crash hoặc silently sai nếu format lệch.
- Cả ba nhà cung cấp lớn đều có cơ chế API riêng để ép format thay vì chỉ dựa vào prompt text:

| Provider | Cơ chế | Ghi chú |
|---|---|---|
| **Anthropic** | Structured Outputs: `output_config.format` với JSON Schema, hoặc `tools[].strict` cho tool call | Đảm bảo response tuân thủ schema (type, required, enum, `additionalProperties: false`) |
| **OpenAI** | Structured Outputs (dùng **constrained decoding** — kỹ thuật ép model chỉ được chọn token hợp lệ với schema tại mỗi bước sinh) vs **JSON mode** | JSON mode chỉ đảm bảo JSON hợp lệ cú pháp; Structured Outputs đảm bảo đúng schema, token không hợp lệ không thể sinh ra |
| **Gemini** | Không có cơ chế ép schema tương đương; khuyến nghị instruction rõ ràng + few-shot examples | Hỗ trợ `max_output_tokens` để kiểm soát độ dài (~4 ký tự/token, ~60-80 từ / 100 token) |

- Lưu ý quan trọng (claim dễ gây lỗi nếu hiểu sai — xem [^2]): JSON Schema của Anthropic Structured Outputs **không hỗ trợ** ràng buộc độ dài chuỗi (`minLength`/`maxLength`) hay số (`minimum`/`maximum`). Nghĩa là **length vẫn phải được chỉ định qua prompt text**, schema chỉ lo phần shape/type. Hai kỹ thuật (schema cho format, prompt cho length) **bổ sung cho nhau**, không thay thế nhau.

## Ví dụ minh họa

Prompt mơ hồ:
```
Tóm tắt bài báo này.
```
→ Model có thể trả về 5 câu hoặc 5 đoạn tùy hứng, văn xuôi hoặc bullet tùy hứng.

Prompt chỉ định rõ:
```
Tóm tắt bài báo dưới đây cho một product manager không có nền tảng kỹ thuật.
Yêu cầu:
- Độ dài: đúng 3 bullet points, mỗi bullet ≤ 20 từ
- Format: markdown bullet list, không dùng bảng
- Tone: đơn giản, tránh thuật ngữ ML chuyên sâu
```
→ Kết quả đồng nhất, dễ đưa vào slide hoặc Slack message có giới hạn ký tự.

Ví dụ downstream-parser (JSON Schema qua Structured Outputs):
```json
{
  "type": "object",
  "properties": {
    "summary": { "type": "string" },
    "sentiment": { "type": "string", "enum": ["positive", "neutral", "negative"] },
    "action_items": { "type": "array", "items": { "type": "string" } }
  },
  "required": ["summary", "sentiment", "action_items"],
  "additionalProperties": false
}
```
→ Không cần đoán "model có trả JSON đúng không" — API enforce đúng shape; nhưng nếu muốn `summary` giới hạn 50 từ thì vẫn phải nói rõ trong prompt vì schema không kiểm soát được length của string field.

## Audience persona pattern

- Nguồn gốc học thuật: paper "A Prompt Pattern Catalog to Enhance Prompt Engineering with ChatGPT" (White et al., Vanderbilt, 2023) đề xuất **Audience Persona Pattern**: cấu trúc "Explain [concept] to [audience type/expertise level]" — giúp model điều chỉnh độ phức tạp, thuật ngữ, góc nhìn phù hợp người đọc [^3].
- Cùng nhóm "Output Customization" còn có Persona/Template/Recipe/Visualization Generator pattern — ràng buộc kiểu output, format, cấu trúc.
- Ứng dụng thực tế: giải thích khái niệm kỹ thuật cho sales/marketing, slide bài giảng, hay cho người hoàn toàn không có nền tảng — audience persona là đòn bẩy rẻ tiền nhất để đổi tông giọng mà không cần đổi nội dung cốt lõi.

## Liên hệ tới các phần khác

- Đây là một trong các kỹ thuật con của [[prompt-writing-good-prompts-be-specific]] — "cụ thể" bao gồm cả cụ thể về format/length/audience, không chỉ cụ thể về nội dung task.
- Bổ sung cho [[prompt-writing-good-prompts-provide-context]]: context giải thích "tại sao", còn length/format/audience quy định "trình bày như thế nào".
- Khi cần minh họa format mong muốn thay vì chỉ mô tả bằng lời, kết hợp với [[prompt-writing-good-prompts-use-examples]] (few-shot input-output pairs) — đặc biệt hiệu quả cho tone/format tinh tế mà chữ khó diễn đạt hết.
- So với workflow/agent phức tạp hơn: trong một lệnh gọi LLM đơn giản hoặc một bước workflow cố định, không có cơ chế nào khác (schema-validating harness, agent tự sửa lỗi) để bắt lỗi format sai trước khi bị downstream tiêu thụ. Vì vậy, chỉ định rõ ngay từ prompt là tuyến phòng thủ đầu tiên và rẻ nhất — nên làm trước khi cân nhắc đầu tư vào RAG hay fine-tuning.

### Áp dụng với Claude Code

- Claude Code có tính năng **Output styles**: chỉnh system prompt để set role, tone, và output format cho cả phiên hội thoại chính (built-in style như Explanatory/Learning cố tình dài hơn Default "by design").
- Tuy nhiên, output style **chỉ áp dụng cho main conversation**. Subagent chạy system prompt riêng và **không tự động kế thừa** ràng buộc length/format/tone của parent, trừ khi dùng chế độ **"fork"** (subagent sao chép/kế thừa toàn bộ system prompt của parent thay vì dùng system prompt mặc định riêng). Đây là điểm cần lưu ý khi delegate task cho subagent: phải tự thêm chỉ định length/format vào prompt gửi cho subagent, không thể trông chờ output style lan truyền.
- Bản thân system prompt mặc định của Claude Code cũng áp dụng chính nguyên tắc này lên chính nó: giới hạn text giữa các tool call ở ≤25 từ, và final response ở ≤100 từ trừ khi task cần chi tiết hơn. Đây là một constraint length được thiết kế riêng cho **hard display constraint** — tức giới hạn hiển thị vật lý cố định, ở đây là terminal/CLI (tương tự chat bubble hay report có độ rộng cố định) [^4].
- Claude Code cũng nói rõ với model rằng output sẽ hiển thị bằng **monospace font** trong terminal — một ví dụ cụ thể về việc display surface giới hạn format nào khả dụng.

## Confidence notes

- [^1]: Anthropic prompting best-practices docs nói rõ điều này — confidence: high.
- [^2]: Xác nhận trực tiếp từ Anthropic Structured Outputs docs — confidence: high.
- [^3]: Trích từ paper học thuật (White et al., Vanderbilt, 2023), không phải doc chính thức của một vendor — confidence: medium.
- [^4]: Nguồn là dbreunig.com, bài blog thứ cấp diễn giải/paraphrase system prompt của Claude Code, chưa đối chiếu bản gốc — confidence: medium. (Xem thêm ghi chú trong "Giới hạn / open questions".)

## Giới hạn / open questions

- Chưa kiểm chứng trực tiếp được nội dung của techlasi.com (bị chặn 403 khi fetch) — các claim liên quan chỉ dùng ở mức tham khảo thấp, không làm anchor chính.
- Chưa có benchmark định lượng (ví dụ: % lệch độ dài khi có/không có chỉ định) để so sánh mức độ cải thiện thực tế giữa các model khác nhau (Claude vs GPT vs Gemini) khi áp dụng kỹ thuật này.
- Chưa rõ hành vi chi tiết của Gemini Structured Output/JSON mode có hỗ trợ ràng buộc length ở schema level hay không (khác gì so với Anthropic/OpenAI) — cần nghiên cứu thêm.
- Nguồn về system prompt Claude Code (dbreunig.com) là thứ cấp, paraphrase/quote lại — nên đối chiếu thêm với bản gốc (ví dụ repo Piebald-AI/claude-code-system-prompts) nếu cần trích dẫn chính xác con số ≤25/≤100 từ.
