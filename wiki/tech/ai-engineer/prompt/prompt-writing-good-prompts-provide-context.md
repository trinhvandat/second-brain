---
status: current
updated: 2026-08
sources:
  - https://platform.claude.com/docs/en/docs/build-with-claude/prompt-engineering/be-clear-and-direct
  - https://www.promptingguide.ai/introduction/elements
  - https://www.promptingguide.ai/techniques/fewshot
  - https://developers.openai.com/api/docs/guides/prompting
  - https://code.claude.com/docs/en/memory
  - https://claude.com/blog/the-new-rules-of-context-engineering-for-claude-5-generation-models
  - https://neo4j.com/blog/agentic-ai/context-engineering-vs-prompt-engineering/
  - https://www.godofprompt.ai/blog/what-is-context-in-prompt-engineering
roadmap: ai-engineer
stage: done
---

# Writing Good Prompts — Provide Additional Context — cung cấp bối cảnh nền để model hiểu đúng tình huống trước khi trả lời

**TL;DR**: Prompt tốt phải cung cấp **context** — dữ kiện nền (background facts), ràng buộc (constraints), và mục tiêu (goals) — vì model không tự biết tình huống thực tế của bạn; thiếu context, model buộc phải đoán và dễ ra câu trả lời đúng kỹ thuật nhưng sai ứng dụng.

## Vì sao context quan trọng

Theo tài liệu chính thức của Anthropic (as of platform.claude.com, confidence: high):

- Claude được mô tả như "một nhân viên mới rất giỏi nhưng chưa biết gì về quy ước/phong cách/hoàn cảnh làm việc của bạn" — càng giải thích chính xác bối cảnh, câu trả lời càng tốt.
- **Golden rule** để kiểm tra độ rõ ràng: đưa prompt cho một đồng nghiệp không biết gì về task, bảo họ làm theo — nếu người đó bị rối hoặc phải đoán thông tin còn thiếu, model cũng sẽ fail tương tự.

Không có context, model phải tự suy đoán tình huống dựa trên xác suất phổ biến nhất trong dữ liệu train — không phải tình huống thực tế của bạn. Kết quả là câu trả lời có thể đúng về mặt kỹ thuật nhưng **sai về mặt ứng dụng**.

## Ví dụ minh hoạ: prompt trần vs prompt có context

**Prompt trần** (không context):

```
Tối ưu hàm này.
```

Model không biết: đây là code chạy production hay chỉ là prototype đang thử nghiệm? Ưu tiên tốc độ hay bộ nhớ? Ngôn ngữ/framework nào? → Model phải đoán, và với một hàm cụ thể, nó có thể chọn tối ưu theo hướng giảm memory bằng cách tăng số lần tính toán lặp lại — hợp lý về thuật toán nhưng lại khiến latency tệ hơn trong một service đang cần trả lời real-time.

**Prompt có context**:

```
Đây là hàm xử lý request trong API production (Java, Spring Boot),
chạy trên mỗi request với traffic ~500 req/s. Ràng buộc: latency
p99 phải dưới 50ms, memory không phải vấn đề (server có 16GB RAM
dư dả). Mục tiêu: giảm latency, ưu tiên tốc độ hơn memory.

[code hàm]

Tối ưu hàm này theo đúng ưu tiên trên.
```

Với context này, model biết chính xác trục đánh đổi (speed vs memory) và ràng buộc hệ thống (ngôn ngữ, framework, quy mô traffic) — loại bỏ khả năng đề xuất một giải pháp đúng thuật toán nhưng sai mục tiêu thực dụng.

## Các thành phần của context tốt

Theo hướng dẫn chính thức của Anthropic, các loại thông tin nền đáng đưa vào prompt gồm (as of platform.claude.com, confidence: high):

- **Ai là người dùng cuối / audience** — output này dành cho ai đọc/dùng (dev nội bộ, khách hàng cuối, non-technical stakeholder...).
- **Ràng buộc hệ thống (constraints)** — ngôn ngữ, framework, phiên bản, giới hạn tài nguyên, quy tắc nghiệp vụ phải tuân theo.
- **Workflow/pipeline** — task này là một bước trong quy trình lớn hơn nào, output sẽ được dùng tiếp ra sao (feed vào bước nào tiếp theo).
- **Mục tiêu / định nghĩa "thành công"** — kết quả đạt yêu cầu trông như thế nào, ưu tiên trục nào khi có đánh đổi.
- **Lý do đang làm việc này** — bối cảnh nghiệp vụ giúp model chọn hướng giải quyết phù hợp thay vì hướng "chung chung đúng nhất".

Framework tổng quát hơn (DAIR.AI Prompting Guide) coi **Context** là một trong bốn thành phần chuẩn của prompt — cùng với Instruction, Input Data, Output Indicator — và định nghĩa nó là "thông tin bên ngoài hoặc bối cảnh bổ sung giúp model đưa ra câu trả lời tốt hơn" (as of promptingguide.ai, confidence: high).

## Context khác gì few-shot examples

Đây là điểm hay bị nhầm lẫn: **context là dữ kiện nền (facts/constraints/goals)**, còn **few-shot examples là các cặp input-output mẫu minh hoạ định dạng/pattern mong muốn** — hai thứ khác nhau về bản chất dù cả hai đều "cung cấp thêm thông tin" cho prompt.

| | Context | Few-shot examples |
|---|---|---|
| Bản chất | Dữ kiện nền: ai dùng, ràng buộc, mục tiêu, lý do | Cặp input → output mẫu |
| Vai trò | Định hướng *tình huống* để model hiểu đúng bài toán | Định hướng *định dạng/pattern* output mong muốn |
| Khi thiếu | Model đoán sai bối cảnh → đúng kỹ thuật, sai ứng dụng | Model có thể chọn sai format/structure output |
| Ví dụ | "Đây là code production, ưu tiên latency" | "Input: X → Output: Y" (2-3 cặp mẫu) |

Tài liệu chuẩn hoá về shot-based prompting xác nhận sự tách biệt này: "zero-shot prompt chỉ chứa instruction và context, không có example; few-shot prompt chứa thêm instruction, context, VÀ ví dụ" — tức context và example là hai thành phần cộng dồn riêng biệt, không thay thế nhau (as of promptingguide.ai/techniques/fewshot, confidence: medium). Xem thêm kỹ thuật few-shot cụ thể tại [[prompt-engineering]].

Lưu ý: một vài nguồn thứ cấp (VD godofprompt.ai) không phân biệt rạch ròi hai khái niệm này — họ coi "dùng ví dụ" chỉ là một cách để cung cấp context, không phải một phạm trù riêng biệt. Trong note này, ranh giới được giữ theo cách phân loại của Anthropic/DAIR.AI (context = nền tảng tình huống, example = mẫu định dạng) vì rõ ràng và hữu dụng hơn khi thiết kế prompt thực tế.

## Liên hệ tới các phần khác

- [[prompt-writing-good-prompts-be-specific]] — cung cấp context và viết cụ thể (specific) là hai kỹ năng bổ trợ nhau: context trả lời "model cần biết gì về tình huống", specific trả lời "model cần làm chính xác điều gì".
- [[prompt-engineering]] — few-shot prompting là một kỹ thuật cụ thể, tách biệt với việc cung cấp context nền như mô tả ở trên.
- Ở tầng rộng hơn, ngành gọi việc chủ động kiến trúc mọi thứ model nhìn thấy tại thời điểm suy luận (system prompt, lịch sử hội thoại, memory, tài liệu retrieve qua RAG, kết quả tool call) là **context engineering** — context cung cấp thủ công trong một prompt đơn lẻ là phiên bản nhẹ/tĩnh của việc RAG tự động hoá ở quy mô lớn hơn (as of neo4j.com, confidence: medium).

### Áp dụng với Claude Code

Theo tài liệu chính thức của Claude Code (as of code.claude.com/docs/en/memory, confidence: high):

- **CLAUDE.md** là cơ chế chính thức để cung cấp context bền vững (persistent context) cho Claude Code: build commands, coding conventions, kiến trúc project, ràng buộc hệ thống — đúng loại thông tin "ràng buộc hệ thống" và "lý do đang làm việc này" mà note này mô tả, nhưng được nạp một lần thay vì phải gõ lại mỗi prompt.
- Tài liệu khuyến nghị CLAUDE.md nên chứa fact cụ thể, verify được (VD "Use 2-space indentation", "Run npm test before committing") thay vì mơ hồ — đúng nguyên tắc "context tốt phải rõ ràng, không để model đoán" nêu ở trên.
- **Quan trọng**: CLAUDE.md được nạp như một user message sau system prompt, và được Claude Code coi là "context, not enforced configuration" — tức chỉ định hướng, không đảm bảo tuân thủ tuyệt đối. Muốn ép buộc hành vi (VD luôn chạy lint trước commit) phải dùng **hooks** (PreToolUse), không phải chỉ dựa vào context.
- CLAUDE.md có cấu trúc phân tầng (managed policy > user `~/.claude/CLAUDE.md` > project > local) — nghĩa là "ai là người dùng cuối" và "lý do đang làm việc này" được mã hoá thành *scope của file cấu hình* thay vì nhét text vào một prompt đơn lẻ như prompt engineering thuần tuý.
- Claude Code còn có **Auto memory** (MEMORY.md + topic files) tự động ghi lại pattern/learnings qua các phiên làm việc — một dạng context nền tích luỹ tự động theo thời gian, mở rộng khái niệm "cung cấp bối cảnh" sang chiều nhiều phiên làm việc thay vì chỉ trong một prompt.

## Giới hạn / open questions

- Chưa có benchmark định lượng nào đo mức độ cải thiện accuracy/relevance khi thêm context so với prompt trần trên cùng một task — các claim trong note này chủ yếu dựa trên khuyến nghị định tính từ tài liệu chính thức, không phải số liệu thực nghiệm.
- Ranh giới giữa "context" và "instruction" (yêu cầu cụ thể) đôi khi mờ — VD câu "ưu tiên tốc độ hơn memory" vừa là constraint/goal (context) vừa gần như một instruction trực tiếp; note chưa đào sâu cách phân loại triệt để khi hai thứ chồng lấn.
- Chưa khảo sát cách OpenAI cụ thể hoá vị trí đặt context trong prompt (gần cuối prompt, tách khỏi system message) có áp dụng tương tự với Claude/Anthropic hay không — cần kiểm chứng riêng nếu áp dụng cross-provider.
- Quan hệ giữa "context engineering" (khái niệm ngành rộng hơn, gồm RAG/memory/tool output) và "cung cấp context trong một prompt đơn lẻ" (chủ đề note này) mới được nêu sơ bộ, chưa có note riêng để đào sâu.
