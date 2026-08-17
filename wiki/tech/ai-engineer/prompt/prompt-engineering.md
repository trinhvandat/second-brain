---
status: current
updated: 2026-08
sources:
  - https://www.promptingguide.ai/
  - https://www.promptingguide.ai/techniques/fewshot
  - https://www.promptingguide.ai/techniques/cot
  - https://arxiv.org/abs/2201.11903
  - https://arxiv.org/abs/2205.01068
  - https://medium.com/@aabhi02/prompt-engineering-vs-prompt-tuning-a-detailed-explanation-19ea8ce62ac4
roadmap: ai-engineer
stage: done
---

# Prompt Engineering

Prompt engineering là **kỹ năng thiết kế và tối ưu hoá input text (prompt)** gửi cho LLM để hướng model sinh ra output đúng ý định, không cần thay đổi trọng số model. Về bản chất, đây là cách "lập trình" model thông qua ngôn ngữ tự nhiên thay vì qua code — điều này thành khả thi vì LLM nhạy cảm cao với cách đặt vấn đề trong context (confidence: high).

Prompt engineering không chỉ là "viết prompt khéo hơn" — nó còn bao gồm việc hiểu **khi nào LLM fail** (hallucination, reasoning sai, output sai format...) và chọn kỹ thuật phù hợp để giải quyết từng loại vấn đề đó.

> Liên hệ với [[llm-large-language-model]]: LLM dự đoán token tiếp theo dựa trên context — prompt chính là toàn bộ context đó. Chất lượng prompt ảnh hưởng trực tiếp đến phân phối token được chọn.

## Tại sao prompt engineering quan trọng?

- **Không cần train/fine-tune** — thay đổi ngay lập tức, không tốn GPU, không cần dataset.
- **First step to optimization** — theo OpenAI: nên thử prompt engineering trước, chỉ chuyển sang fine-tuning khi đã tối ưu prompt mà vẫn chưa đạt yêu cầu.
- **Bổ trợ mọi kỹ thuật khác** — dù dùng RAG, fine-tuning, hay agent, prompt vẫn là giao diện chính để giao tiếp với model.

## Các kỹ thuật cơ bản

### Zero-shot prompting

Đặt câu hỏi / giao nhiệm vụ trực tiếp, không cung cấp ví dụ mẫu. Model dựa hoàn toàn vào kiến thức đã học từ pretraining (confidence: high).

```
Phân loại câu sau là tích cực, tiêu cực, hay trung lập:
"Sản phẩm ổn, không có gì đặc sắc."
```

- **Phù hợp**: task đơn giản, rõ ràng, model đã thấy trong pretraining.
- **Giới hạn**: task phức tạp, domain rất đặc thù, hoặc format output khó đoán.

### Few-shot prompting

Cung cấp một số ví dụ input → output trước khi đặt câu hỏi thật. Model học pattern từ ví dụ trong context (**in-context learning**) mà không cập nhật trọng số (confidence: high, Brown et al. 2020 GPT-3 paper).

```
Input: "Tôi ghét bị kẹt xe." → Tiêu cực
Input: "Trời hôm nay đẹp quá." → Tích cực
Input: "Sản phẩm ổn, không có gì đặc sắc." → ?
```

Điểm quan trọng từ nghiên cứu: **định dạng và label space** quan trọng hơn việc ví dụ đúng hay sai. Ngay cả random labels vẫn tốt hơn không có label — model học từ cấu trúc prompt, không chỉ từ nội dung đúng/sai (confidence: medium, promptingguide.ai).

- **Phù hợp**: format output đặc biệt, task classification/extraction, task mà zero-shot thất bại nhưng chưa cần CoT.
- **Giới hạn**: còn fail với complex multi-step reasoning dù có ví dụ.

### Chain-of-Thought (CoT) prompting

Yêu cầu model trình bày **từng bước suy luận trung gian** trước khi đưa ra câu trả lời cuối. Thay vì nhảy thẳng tới kết quả, model "viết ra" reasoning trace trong chính output của mình (confidence: high, Wei et al. 2022).

**Few-shot CoT** — cung cấp ví dụ có chain-of-thought đầy đủ:
```
Hỏi: An có 5 cái kẹo, mua thêm 3, cho bạn 2. Còn lại bao nhiêu?
Lý luận: Ban đầu 5, mua thêm 3 → 5+3=8. Cho bạn 2 → 8-2=6.
Đáp: 6

Hỏi: Bình có 12 tờ tiền, tiêu hết 1/3. Còn lại bao nhiêu?
Lý luận: ?
```

**Zero-shot CoT** — chỉ thêm cụm từ kích hoạt, không cần ví dụ:
```
Giải bài này, trình bày từng bước: [bài toán]

Hãy suy nghĩ từng bước một.
```

Cụm "Let's think step by step" (hoặc tương đương tiếng Việt) tăng đáng kể độ chính xác toán học và logic mà không cần viết ví dụ mẫu (confidence: high, Kojima et al. 2022).

> Liên hệ [[llm-reasoning-vs-standard-models]]: CoT prompting là cách ép standard model "giả lập" một phần reasoning. Reasoning model (o1, extended thinking) thì làm điều này nội tại, không cần prompt.

## Kỹ thuật nâng cao

### Self-Consistency

Thay vì lấy 1 reasoning path, sinh **nhiều chuỗi suy luận** (temperature > 0) rồi chọn câu trả lời phổ biến nhất (majority voting). Cải thiện độ chính xác CoT trên toán và commonsense reasoning (confidence: medium, Wang et al. 2022). Chi phí tăng tuyến tính theo số lần sample.

### Tree of Thoughts (ToT)

Mở rộng CoT thành **cây suy luận**: model explore nhiều nhánh tư duy, đánh giá từng nhánh (tự chấm điểm hoặc qua verifier), và backtrack nhánh sai. Phù hợp với các task cần search qua không gian giải pháp rộng (VD: puzzle, planning phức tạp) (confidence: medium — mạnh về concept, chi phí inference rất cao).

### Meta-prompting

Dùng LLM để **tự viết hoặc cải thiện prompt** cho một task khác — prompt engineer dùng AI như một công cụ thiết kế prompt thay vì tự viết tay. Hữu dụng khi task phức tạp hoặc cần thử nhiều biến thể nhanh.

### ReAct (Reason + Act)

Kết hợp CoT với **action — observation loop**: model xen kẽ giữa Thought (suy luận), Action (gọi tool/search), Observation (kết quả trả về). Đây là pattern nền tảng của agent — không chỉ là prompt trick. Xem chi tiết tại [[llm-reasoning-vs-standard-models]] mục ReAct.

## So sánh nhanh các kỹ thuật

| Kỹ thuật | Cần ví dụ mẫu | Phù hợp cho | Chi phí token | Giới hạn |
|---|---|---|---|---|
| Zero-shot | Không | Task quen thuộc, đơn giản | Thấp | Fail ở task phức tạp/đặc thù |
| Few-shot | Có (vài ví dụ) | Format đặc biệt, classification | Trung bình | Fail ở complex reasoning |
| CoT few-shot | Có (với reasoning steps) | Toán, logic, multi-step | Cao hơn | Cần viết ví dụ tốt |
| Zero-shot CoT | Không (chỉ trigger phrase) | Toán/logic khi không có ví dụ | Trung bình | Kém hơn few-shot CoT |
| Self-Consistency | Có/Không (kết hợp CoT) | Bài toán có 1 đáp án đúng | Rất cao (×N lần sample) | Cost, không phù hợp open-ended |
| ToT | Tuỳ | Planning, puzzle phức tạp | Rất cao | Phức tạp implement |

## Prompt engineering vs Prompt tuning

Hai khái niệm hay bị nhầm lẫn (confidence: high):

**Prompt engineering** — không đụng trọng số model, chỉ thay đổi input text. Nhanh, linh hoạt, không tốn compute training. Đây là kỹ năng của developer/user.

**Prompt tuning** (hay "soft prompt tuning") — học một tập nhỏ **continuous embedding vector** ("soft prompt") gắn vào đầu input, thông qua gradient descent trên data của bạn. Trọng số model gốc bị đóng băng — chỉ soft prompt embeddings được cập nhật (confidence: high). Kết quả: prompt được tối ưu hoá cho task cụ thể bằng data thực, nhưng không thể đọc được bằng mắt người (vì là vector số thực, không phải text).

```
Prompt tuning pipeline:
[soft prompt vectors] + [user input text] → frozen LLM → output
                ↑
      gradient updates chỉ tác động đây
```

| | Prompt Engineering | Prompt Tuning | Fine-tuning |
|---|---|---|---|
| Thay đổi gì | Chỉ text input | Soft prompt vectors | Toàn bộ / phần trọng số model |
| Cần training | Không | Có (data + GPU nhỏ) | Có (data + GPU lớn hơn) |
| Cần dataset | Không | Có | Có |
| Kết quả đọc được | Có | Không | N/A |
| Phù hợp | Prototype nhanh, task đa dạng | Một task cụ thể, tiết kiệm hơn fine-tune | Domain hẹp, format đặc biệt, hiệu năng cao |
| Chi phí | Thấp nhất | Thấp–trung bình | Cao nhất |

Prompt tuning được xem là điểm trung gian giữa prompt engineering (không train) và fine-tuning (train toàn bộ). Nó là một dạng PEFT (Parameter-Efficient Fine-Tuning) — xem thêm tại [[llm-fine-tuning]].

## Best practices tổng quát

- **Rõ ràng và cụ thể** — thay vì "viết hay hơn", nói "viết lại theo giọng điệu chuyên nghiệp, ngắn gọn dưới 3 câu".
- **Thử zero-shot trước** — nếu đủ tốt, không cần thêm complexity.
- **Ví dụ đa dạng** — trong few-shot CoT, diversity của ví dụ giảm bias và tăng generalization.
- **Tách task phức tạp thành bước** — chia nhỏ prompt hoặc dùng multi-turn thay vì nhét hết vào 1 prompt khổng lồ.
- **Bao gồm format output mong muốn** — nếu cần JSON/table/list, nói rõ trong prompt; few-shot ví dụ có format đúng càng tốt.
- **Đánh giá trước khi fine-tune** — theo quy trình OpenAI: build eval → iterate prompt → chỉ fine-tune khi prompt tốt nhất mà vẫn chưa đủ.

## Open questions / cần đọc thêm

- Chưa cover **system prompt vs user prompt** và cách các provider (OpenAI, Anthropic, Google) xử lý phân cấp này khác nhau.
- **Auto-CoT** (tự động chọn ví dụ qua clustering) và **Active-Prompt** — cần đào sâu nếu cần tối ưu few-shot CoT ở scale.
- So sánh empirical prompt tuning vs LoRA/full fine-tune trên cùng task — chưa có benchmark tự đo.
- Liên hệ sâu hơn với agent: prompt design trong agent loop (system prompt, tool descriptions, memory injection) có đặc thù riêng so với single-turn prompting — có thể tách note `agent-prompt-design` sau.
