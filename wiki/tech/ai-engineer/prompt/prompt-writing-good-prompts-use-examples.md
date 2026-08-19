---
status: current
updated: 2026-08
sources:
  - https://arxiv.org/pdf/2005.14165
  - https://platform.claude.com/docs/en/build-with-claude/prompt-engineering/claude-prompting-best-practices
  - https://www.promptingguide.ai/techniques/fewshot
  - https://developers.openai.com/api/docs/guides/prompt-engineering
roadmap: ai-engineer
stage: done
---

# Writing Good Prompts — Use Examples (Few-Shot) — đưa ví dụ input->output mẫu vào prompt để model học pattern qua in-context learning

TL;DR: Thay vì mô tả bằng lời (zero-shot), few-shot đưa vào prompt 2-5 cặp ví dụ input->output cụ thể để model tự suy ra pattern qua **in-context learning** — đặc biệt hiệu quả khi định dạng output khó diễn tả bằng văn bản hoặc zero-shot đã thất bại.

## Few-shot là gì

- **In-context learning** (model học task từ các ví dụ minh họa ngay trong prompt, tại thời điểm inference, không cần cập nhật gradient/fine-tune): khái niệm này bắt nguồn từ paper "Language Models are Few-Shot Learners" giới thiệu GPT-3 (Brown et al., 2020), phân biệt 3 chế độ: zero-shot (0 ví dụ), one-shot (1 ví dụ), few-shot (nhiều ví dụ, thường 10-100 trong paper gốc, nhưng trong thực hành prompt engineering hiện nay con số nhỏ hơn nhiều — xem mục "Số lượng ví dụ" bên dưới).
- Về bản chất, few-shot là một **alternative cho fine-tuning**: thay vì train lại model, bạn "dạy" pattern ngay trong prompt bằng một vài cặp ví dụ.
- Anthropic gọi kỹ thuật này là **multishot prompting** (tên Anthropic dùng cho kỹ thuật few-shot) và xác nhận đây là "một trong những cách đáng tin cậy nhất để định hướng format, tone, và cấu trúc output" của Claude.

## Khi nào few-shot đặc biệt hữu ích

- **Định dạng output khó diễn tả bằng lời** — VD một cấu trúc JSON đặc thù với nhiều field lồng nhau, hoặc một văn phong/giọng văn riêng (formal, playful, technical) — mô tả bằng tính từ rất khó chính xác, nhưng cho model 1 ví dụ output mẫu thì nó bám theo ngay.
- **Task classification/extraction với label set không chuẩn** — khi tập nhãn không phải là các category phổ biến (sentiment positive/negative), mà là nhãn đặc thù domain (VD "urgent-billing", "feature-request-P2"), few-shot giúp model hiểu ranh giới giữa các nhãn qua ví dụ thay vì định nghĩa từ điển.
- **Khi zero-shot đã fail** — đây là tín hiệu rõ ràng nhất trong thực tế: nếu prompt mô tả bằng lời đã thử nhiều lần vẫn sai format/logic, bước tiếp theo hợp lý là chuyển sang few-shot trước khi nghĩ đến fine-tuning.
- Few-shot cũng áp dụng được với **extended thinking** (chế độ Claude tự suy luận công khai trước khi trả lời): đặt tag `<thinking>` mẫu bên trong ví dụ để dạy Claude phong cách lập luận, model sẽ tự generalize style đó sang các block reasoning của chính nó.

## Nguyên tắc chọn ví dụ

> Các khuyến nghị trong phần này (tiêu chí chọn ví dụ, số lượng 3-5) lấy từ Anthropic prompt-engineering docs, confidence: high — xem `sources` ở đầu bài.

- **Diversity (đa dạng)** — ví dụ phải bao quát nhiều trường hợp, kể cả **edge case** (trường hợp hiếm/biên, khác với trường hợp phổ biến), tránh model **overfit** (bám quá chặt vào 1 pattern hẹp, rồi áp dụng sai cho input khác đi một chút) vào 1 pattern hẹp. Anthropic liệt kê 3 tiêu chí cho ví dụ tốt: **Relevant** (bám sát use case thực tế), **Diverse** (đủ đa dạng để model không nhặt ra pattern giả/không mong muốn), **Structured** (bao trong `<example>`/`<examples>` để model phân biệt ví dụ với instruction).
- **Định dạng nhất quán** — giữa các ví dụ với nhau, và giữa ví dụ với câu hỏi thật. Nghiên cứu của Min et al. (2022), được promptingguide.ai tổng hợp, cho thấy: độ chính xác của từng nhãn (label) ít quan trọng hơn việc **format** và **phân bố nhãn** trong demonstration có "thực" (realistic) hay không — thậm chí nhãn ngẫu nhiên vẫn tốt hơn hẳn không có nhãn miễn là giữ đúng format (as of promptingguide.ai/techniques/fewshot, confidence: medium). Ví dụ thực tế: nếu bạn có 5 ví dụ classify sentiment nhưng cố tình gán sai 1 nhãn (VD 1 câu tích cực bị gán nhãn "negative"), model vẫn học đúng định dạng trả lời tốt hơn là không có ví dụ nào — vì điều quan trọng hơn là *cách trình bày* input->output, không phải từng nhãn có chính xác tuyệt đối hay không.
- **Số lượng ví dụ (2-5)** — đánh đổi giữa chất lượng và chi phí token. Anthropic khuyến nghị cụ thể "3-5 ví dụ là tối ưu"; OpenAI khuyên 2-4 cặp và lưu ý quá nhiều ví dụ có thể khiến model "quên" các ví dụ đầu, gây output không nhất quán. Nhiều ví dụ hơn thường giúp task phức tạp hơn nhưng tăng token/latency tuyến tính.
- **Giới hạn**: few-shot thường không đủ cho task đòi hỏi lập luận nhiều bước (VD toán nhiều bước) — những trường hợp này cần chain-of-thought (kỹ thuật yêu cầu model trình bày từng bước suy luận) thay vì (hoặc kết hợp với) few-shot thuần túy.

## Ví dụ minh họa

Zero-shot (mô tả bằng lời, dễ bị model diễn output theo cách khác):

```
Classify the sentiment of this support ticket as urgent-billing, feature-request, or general-question.

Ticket: "My card was charged twice this month, please fix ASAP."
```

Few-shot (đưa 3 cặp ví dụ để model bám theo định dạng và ranh giới nhãn):

```
<examples>
<example>
Ticket: "I was charged $49 twice on my last invoice."
Label: urgent-billing
</example>
<example>
Ticket: "Would be great if you added dark mode to the dashboard."
Label: feature-request
</example>
<example>
Ticket: "How do I export my data as CSV?"
Label: general-question
</example>
</examples>

Ticket: "My card was charged twice this month, please fix ASAP."
Label:
```

Với few-shot, model không chỉ biết "phải trả về một trong 3 nhãn" mà còn học được đúng định dạng trả lời (`Label: <tên-nhãn>`, không giải thích thêm) từ chính các ví dụ — điều mà mô tả bằng lời rất khó truyền đạt chính xác.

## Phân biệt với "provide context"

- **Few-shot** = ví dụ cụ thể input->output, dạy model *cách làm* một task qua demonstration.
- **Provide context** ([[prompt-writing-good-prompts-provide-context]]) = cung cấp thông tin nền/tài liệu/vai trò chung, không nhất thiết thể hiện hình dạng output mong muốn.
- **RAG** là kỹ thuật liên quan nhưng khác: nó *động* (retrieve tại thời điểm query) tài liệu/context từ nguồn ngoài, có thể bao gồm cả ví dụ few-shot-style được chọn động, thay vì hardcode ví dụ cố định vào prompt (as of WebSearch synthesis Vellum.ai + PromptHub, confidence: low).

## Liên hệ tới các phần khác

- [[prompt-engineering]] — few-shot là một trong các kỹ thuật prompt engineering cơ bản, thường kết hợp với [[prompt-writing-good-prompts-be-specific]] (ví dụ giúp làm rõ "cụ thể" là như thế nào) và [[prompt-writing-good-prompts-provide-context]] (context là nền, ví dụ là minh họa cụ thể trên nền đó).
- Liên quan tới các kỹ thuật generation-control khác trong roadmap như chain-of-thought — few-shot không thay thế CoT cho task lập luận phức tạp.

### Áp dụng với Claude Code

- Claude Code không có config/flag riêng cho "few-shot mode" qua CLI — đây là nguyên tắc **viết prompt/instruction** mà người dùng tự áp dụng khi soạn task hoặc file CLAUDE.md/AGENTS.md.
- Trong thực hành, có thể đưa ví dụ vào CLAUDE.md hoặc vào chính prompt gửi cho Claude Code để định hướng định dạng output (VD "ví dụ commit message đúng chuẩn của repo này là: ..."), giúp agent bám đúng convention của project mà không cần giải thích dài dòng.
- Đối với các skill/slash command tùy chỉnh (`.claude/skills/`), tác giả skill có thể nhúng sẵn few-shot examples ngay trong nội dung skill để định hướng output của Claude Code khi skill được gọi — đây là cách áp dụng few-shot ở cấp "system-level" thay vì từng prompt riêng lẻ.

## Giới hạn / open questions

- Chưa có bằng chứng từ paper gốc kiểm chứng rõ ràng cho claim few-shot có thể **làm giảm** hiệu năng trên các reasoning model đời mới (VD dòng o1) — thông tin này chỉ đến từ nguồn tổng hợp thứ cấp, cần kiểm chứng thêm trước khi áp dụng như quy tắc chung (as of starpop.ai blog, confidence: low).
- Chưa rõ con số "3-5 ví dụ" của Anthropic có thay đổi theo độ phức tạp task hay không — hướng dẫn hiện tại mang tính chung chung, chưa có benchmark công khai chi tiết cho từng loại task (classification vs. structured-output vs. style-transfer).
- Ranh giới giữa few-shot và RAG-với-ví-dụ-động còn mờ — chưa rõ trong thực hành khi nào nên hardcode ví dụ cố định vs. retrieve ví dụ động theo từng query.
