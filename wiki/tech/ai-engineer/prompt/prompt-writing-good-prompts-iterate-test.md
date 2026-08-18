---
status: current
updated: 2026-08
sources:
  - https://platform.claude.com/docs/en/build-with-claude/prompt-engineering/overview
  - https://platform.claude.com/docs/en/test-and-evaluate/develop-tests
  - https://developers.openai.com/api/docs/guides/prompting
  - https://help.openai.com/en/articles/6654000-best-practices-for-prompt-engineering-with-the-openai-api
  - https://www.deeplearning.ai/short-courses/chatgpt-prompt-engineering-for-developers/
  - https://www.prompthub.us/blog/googles-prompt-engineering-best-practices
  - https://cookbook.openai.com/examples/evaluation/building_resilient_prompts_using_an_evaluation_flywheel
  - https://langfuse.com/docs/prompt-management/features/a-b-testing
  - https://www.promptlayer.com/
  - https://medium.com/@alexrodriguesj/testing-llm-prompts-like-code-regression-evals-in-ci-cd-with-promptfoo-5242b4dcb9be
  - https://arxiv.org/pdf/2311.11123
  - https://claude.com/blog/best-practices-for-prompt-engineering
  - https://code.claude.com/docs/en/best-practices
  - https://github.com/46ki75/skills/blob/main/skills/prompt-evaluation-claude-code/SKILL.md
  - https://www.confluent.io/compare/prompts-vs-workflows-vs-agents/
roadmap: ai-engineer
stage: learning
---

# Writing Good Prompts — Iterate and Test Your Prompts — coi bản v1 của prompt là bản nháp, không phải sản phẩm cuối, và cải thiện dựa trên output thực tế thay vì cảm giác "đọc thấy ổn"

TL;DR: Một prompt "đọc thấy hay" không có nghĩa là nó *hoạt động* đúng — cách duy nhất để biết là chạy thử, quan sát output thật (kể cả edge case và failure mode), rồi sửa từ ngữ/cấu trúc/ví dụ dựa trên bằng chứng quan sát được, lặp lại vòng draft → run → inspect → refine cho tới khi đạt tiêu chí thành công đã định nghĩa từ trước.

**Checklist nhanh** (chi tiết ở các mục bên dưới):
1. Định nghĩa tiêu chí thành công + gom một **eval set** (tập input thử nghiệm) có edge case.
2. Viết prompt v1, chạy trên eval set, đọc output thật — đừng chỉ đọc prompt và đoán.
3. Với mỗi lỗi quan sát được: sửa **một** phần của prompt (rule/format/ví dụ), không sửa nhiều thứ cùng lúc.
4. Lưu prompt như code (version, diff, review trong PR); chạy lại eval set mỗi lần đổi để bắt regression.
5. Lặp lại bước 2–4 tới khi đạt tiêu chí đã định nghĩa ở bước 1.

## Vì sao cần iterate, không chỉ viết một lần

- Các kỹ thuật khác trong nhóm "writing good prompts" — [[prompt-writing-good-prompts-be-specific]], [[prompt-writing-good-prompts-provide-context]], [[prompt-writing-good-prompts-use-examples]] — đều là **input-side techniques**: chúng cải thiện *những gì bạn đưa vào* prompt. Iteration là **vòng feedback** kiểm chứng xem các lựa chọn input-side đó có thực sự hoạt động hay không — nó thuộc về phía *output/đánh giá*, không phải phía soạn thảo.
- Anthropic coi đây là điều kiện tiên quyết của prompt engineering, không phải bước tùy chọn. Trước khi bắt đầu cần có: (1) tiêu chí thành công rõ ràng, (2) cách kiểm tra thực nghiệm (empirical test) theo tiêu chí đó, và (3) một "first draft prompt" — nghĩa là ngay từ đầu, prompt đã được đóng khung như một bản nháp chứ không phải bản chốt.
- Nguyên lý cốt lõi: cách duy nhất để biết một prompt đúng hay không là **test nó và xem kết quả**. Không có cách nào suy luận từ việc đọc prompt text mà biết chắc nó hoạt động đúng trên input thật, đặc biệt là input đa dạng/edge case mà bạn chưa nghĩ tới lúc viết.

## Vòng lặp draft → test → refine

- Anthropic mô tả quy trình chuẩn là một chu trình lặp lại: **Test Cases → Preliminary Prompt → Iterative Testing and Refinement → Final Validation → Ship**, và gọi chu trình này là "trung tâm của prompt engineering".
- DeepLearning.AI's "ChatGPT Prompt Engineering for Developers" (Andrew Ng & Isa Fulford, phối hợp OpenAI) dành hẳn một bài học riêng tên "Iterative", mô tả vòng lặp cụ thể: **Idea → Implementation → Experiment result → Error Analysis** — viết prompt, thử, phân tích chỗ kết quả chưa đúng ý, tinh chỉnh ý tưởng/prompt, lặp lại.
- OpenAI khuyên nên **thay đổi từng phần một** trong một prompt phức tạp (one-variable-at-a-time) để cô lập tác động của mỗi thay đổi — tránh sửa nhiều thứ cùng lúc rồi không biết cải thiện đến từ đâu.
- Một heuristic thực tế: bắt đầu bằng **zero-shot** prompt (prompt không kèm ví dụ mẫu, chỉ có mô tả yêu cầu) và quan sát *nó thất bại như thế nào*. Chính các failure mode cụ thể sẽ chỉ ra cần thêm ví dụ **few-shot** nào (một vài ví dụ input→output mẫu chèn vào prompt để định hướng model), thiếu bước reasoning nào — thay vì viết ví dụ chung chung trước khi biết edge case thật là gì.

## Test case và eval set: cần phủ edge case, không chỉ happy path

- **Eval set** là tập input dùng để thử nghiệm prompt một cách nhất quán (thay vì thử ngẫu nhiên vài câu rồi "thấy ổn"). Eval set nên phản ánh phân bố task thực tế, và **chủ động bao gồm edge case**: input không liên quan, input quá dài, trường hợp mơ hồ — không chỉ test happy path.
- Thực hành phổ biến: xây một **"golden" eval set** — một bộ input cố định (đông cứng, không đổi qua thời gian) khoảng 10–50 input đại diện thực tế¹, mỗi input có ghi rõ expected behavior.
  - Chạy lại bộ này mỗi khi đổi prompt/model/dependency.
  - Chấm điểm bằng deterministic check (so khớp string/regex), human review, và/hoặc **LLM-as-a-judge** (dùng một lời gọi LLM khác để chấm điểm output theo rubric, thay vì so khớp cứng).
  - Đưa vào CI: nếu điểm giảm so với baseline, pipeline fail trước khi thay đổi tới tay user.
- OpenAI Cookbook mô tả "**evaluation flywheel**": quy trình chẩn đoán–đo lường–giải quyết lặp lại, dùng rubric 3–5 tiêu chí (thang 1–3) để chấm output, tạo baseline có thể so sánh xuyên suốt mọi phiên bản prompt.

**Ví dụ chấm điểm cụ thể** — tiếp nối eval set phân loại ticket ở mục dưới, giả sử golden set có 20 ticket với nhãn đúng đã biết trước:

| Ticket # | Nhãn đúng (golden) | Output model | Cách chấm | Kết quả |
|---|---|---|---|---|
| 3 | `urgent-billing` | `urgent-billing` | deterministic (so khớp string) | pass |
| 7 | `feature-request` | `general-question` | deterministic | fail |
| 12 | `urgent-billing` | "Đây là vấn đề thanh toán khẩn cấp: urgent-billing" | LLM-as-a-judge (model khác chấm: "câu trả lời có đúng ý nhãn `urgent-billing` không, dù sai format?") | pass (đúng ý, nhưng ghi nhận thêm lỗi format ở mục sửa v2) |

Baseline = tỷ lệ pass/tổng (VD 17/20 = 85%). Mỗi lần sửa prompt, chạy lại đúng 20 ticket này và so tỷ lệ pass với baseline — tăng thì giữ thay đổi, giảm thì rollback.

## Prompt versioning và A/B testing

- OpenAI khuyên **coi prompt như application code**: lưu nội dung prompt trong module có tên, review thay đổi prompt trong cùng PR với hành vi sản phẩm liên quan, và chạy test/eval mỗi lần publish — "bắt lỗi sớm rẻ hơn sửa lỗi trong production".
- Google's Prompt Engineering whitepaper (Lee Boonstra, 2024) khuyên **theo dõi các lần lặp prompt một cách có hệ thống** vì prompt "sẽ trải qua nhiều vòng lặp trước khi vào codebase" — hàm ý cần versioning kỷ luật, không tùy tiện sửa đè.
- Công cụ prompt-management (VD **Langfuse**) hỗ trợ **A/B testing** bằng cách gắn nhãn nhiều phiên bản prompt, cho traffic thật đi ngẫu nhiên giữa các phiên bản, và theo dõi quality score/latency/cost/token per variant.
- Công cụ như **PromptLayer** triển khai versioning như một registry trung tâm: lịch sử phiên bản bất biến (immutable), diff, release label, rollback — cho phép promote một phiên bản prompt đã test lên production mà không cần redeploy code.
- Khác chain-of-thought (có thể trace về một paper 2022 cụ thể), iterate-and-test **không có "paper gốc" duy nhất** — các docs chính thức (Anthropic, OpenAI, Google) đều coi đây là thực hành kế thừa từ vòng lặp train/eval/refine của phát triển ML/software truyền thống².

## Ví dụ minh họa: một vòng lặp cụ thể

Giả sử prompt v1 để phân loại ticket hỗ trợ:

```
v1: "Classify this support ticket as urgent-billing, feature-request, or general-question."
```

Chạy trên 20 ticket thật, quan sát output:

| Vấn đề quan sát được | Nguyên nhân | Sửa ở v2 |
|---|---|---|
| Ticket vừa hỏi giá vừa báo lỗi bị gán nhầm `general-question` | Prompt không nói rõ ưu tiên nhãn khi ticket mơ hồ/đa ý | Thêm rule: "nếu ticket có cả vấn đề thanh toán, luôn ưu tiên urgent-billing" |
| Output đôi khi kèm giải thích dài dòng thay vì chỉ trả nhãn | Không quy định format output | Thêm: "chỉ trả về đúng 1 từ nhãn, không giải thích" |
| Ticket tiếng Việt bị phân loại sai nhiều hơn tiếng Anh | Không có ví dụ minh họa cho ticket tiếng Việt | Thêm 1–2 ví dụ few-shot bằng tiếng Việt |

Đây chính là failure mode được phát hiện *sau khi chạy*, không thể đoán được chỉ bằng đọc prompt v1 — minh họa lý do iteration là bước bắt buộc, không phải tùy chọn.

## So sánh: prompt engineering đơn lẻ vs RAG/workflow/agent

- **RAG** (Retrieval-Augmented Generation) = trước khi gọi LLM, hệ thống tự động tìm và chèn thêm tài liệu liên quan vào prompt (VD tìm 3 đoạn document khớp câu hỏi user, dán vào context) để model trả lời dựa trên dữ liệu thật thay vì chỉ dựa vào những gì nó đã học lúc train. **Fine-tuning** = huấn luyện lại chính model trên dữ liệu riêng, thay vì chỉ thay đổi prompt.
- Prompt engineering là cách rẻ và nhanh nhất để lặp/prototype, nên thường làm trước tiên.
- RAG được thêm vào khi giới hạn nằm ở *kiến thức/grounding* (model không biết hoặc bịa thông tin) chứ không phải ở cách diễn đạt prompt. VD: prompt đã rất rõ ràng nhưng model vẫn trả lời sai vì không biết chính sách hoàn tiền mới nhất của công ty — đó là dấu hiệu cần RAG, không phải viết lại prompt.
- Hầu hết hệ thống production xếp lớp theo thứ tự: prompt engineering → RAG → (đôi khi) fine-tuning³.
- Với một lệnh gọi LLM đơn (single call), toàn bộ bề mặt hành vi chính là văn bản prompt, nên iterate prompt là đòn bẩy duy nhất.
- Khi có RAG hoặc orchestration nhiều bước (**workflow**: nhiều bước LLM cố định theo thứ tự định trước; **agent**: LLM tự quyết định bước tiếp theo, có thể gọi tool lặp lại), "sửa prompt" chỉ là một trong nhiều đòn bẩy — còn có chất lượng retrieval, cách chunk tài liệu, định nghĩa tool, thứ tự bước.
- Trước khi refine prompt trong một hệ thống nhiều bước, cần khoanh vùng xem lỗi nằm ở prompt hay ở phần còn lại của hệ thống⁴.

## Liên hệ tới các phần khác

- [[prompt-engineering]] — khung tổng quát; iterate-and-test là kỷ luật thực nghiệm xuyên suốt toàn bộ prompt engineering, không riêng một kỹ thuật cụ thể nào.
- [[prompt-writing-good-prompts-be-specific]], [[prompt-writing-good-prompts-provide-context]], [[prompt-writing-good-prompts-use-examples]] — các kỹ thuật input-side; iteration là vòng feedback xác nhận (hoặc bác bỏ) hiệu quả của chúng dựa trên output thật.

### Áp dụng với Claude Code

- Claude Code's best-practices doc coi **CLAUDE.md** như code, không phải văn bản viết một lần: "review nó khi có sự cố, prune thường xuyên, và test thay đổi bằng cách quan sát xem hành vi của Claude có thực sự thay đổi hay không." Nếu Claude liên tục bỏ qua một rule, dấu hiệu chẩn đoán là file quá dài khiến rule đó "bị chìm" — một ứng dụng trực tiếp của nguyên lý iterate-and-test lên system-prompt-like instruction.
- Doc này tổng quát hóa vòng lặp cho cả session: cho Claude một cách kiểm tra nó có thể tự chạy (test, build, screenshot để so sánh); Claude làm việc, chạy check, đọc kết quả, và lặp lại tới khi check pass — cùng cấu trúc draft → run → inspect → refine, áp dụng cho việc thực thi task chứ không chỉ soạn prompt.
- Mục "Course-correct early and often": nếu người dùng sửa Claude cùng một vấn đề quá 2 lần trong một session, khuyến nghị là `/clear` và viết lại prompt ban đầu cụ thể hơn, tích hợp bài học quan sát được — coi mỗi prompt được sửa là một bản nháp mới dựa trên failure mode quan sát được, thay vì vá đè vô hạn.
- Claude Code's non-interactive mode (`claude -p` với `--allowedTools`) khuyến nghị rõ workflow test-rồi-scale: test trên vài file, sau đó chạy quy mô lớn — tinh chỉnh prompt dựa trên lỗi ở 2–3 file đầu, rồi mới chạy trên toàn bộ tập. Đây là ứng dụng thực tế của iterate-before-trusting-a-prompt cho batch/automation prompt.
- Claude Code cũng có pattern tách "người làm" khỏi "người đánh giá" (VD một subagent review chỉ thấy diff + tiêu chí, không thấy lý do đằng sau) — tương tự việc tách prompt-drafting khỏi prompt-testing để tránh self-assessment bias che giấu failure mode.
- Có một community skill (`prompt-evaluation-claude-code`, không phải tính năng chính thức) triển khai eval-driven prompt refinement ngay trong Claude Code:
  - Spawn N subagent "candidate" (mỗi cái trong context riêng biệt) chạy prompt-under-test trên tập eval.
  - Spawn M subagent "judge" chấm điểm binary + lý do, chạy 2 lần với thứ tự đảo ngược để kiểm soát **position bias** (thiên lệch: judge có xu hướng ưu ái câu trả lời xuất hiện trước/sau bất kể chất lượng).
  - Mỗi vòng lặp gom lỗi thành 2–4 chủ đề, đề xuất 1 sửa đổi prompt có mục tiêu, rồi chạy lại trên cùng eval set để đo cải thiện.
  - Đây là bản triển khai nhẹ của prompt versioning + regression-checking ngay trong tool.
- Anthropic Console có tab "**Evaluate**" tích hợp sẵn cho A/B test prompt trên eval set. Claude Code (CLI) **không có** UI/product surface chính thức tương đương — kỷ luật iterate-and-test trong CLI phải tự lắp ráp qua các primitive tổng quát (subagent, hook, git version control cho file prompt, community skill)⁵.

## Giới hạn / open questions

- Chưa có benchmark định lượng cho câu hỏi "cần bao nhiêu vòng lặp / bao nhiêu test case là đủ" trước khi một prompt được coi là production-ready — các nguồn đều nói "iterate tới khi đạt tiêu chí" nhưng không đưa con số cụ thể áp dụng chung.
- Ranh giới giữa "sửa prompt" và "chuyển sang RAG/fine-tuning/agent" khi failure mode không cải thiện qua nhiều vòng iterate chưa được nghiên cứu nào trong danh sách nguồn định lượng rõ ràng — chỉ có khuyến nghị định tính.
- arXiv 2311.11123 ("Is My Prompt Getting Worse?") ghi nhận hiện tượng prompt bị regression âm thầm khi provider cập nhật model nền — nhưng note này chưa đi sâu vào cơ chế kỹ thuật đằng sau paper đó, chỉ trích dẫn kết luận.
- Chưa rõ liệu Anthropic Console's Evaluate tab hay các tool bên thứ ba (Langfuse, PromptLayer) có roadmap tích hợp trực tiếp vào Claude Code CLI hay không — đây là khoảng trống thông tin tại thời điểm viết note (2026-08).

**Ghi chú về độ tin cậy của các claim đánh số ở trên:**
1. Con số 10–50 input cho golden eval set là quy ước phổ biến trong cộng đồng (VD hướng dẫn CI/CD cho promptfoo trên Medium), không phải chuẩn chính thức từ Anthropic/OpenAI (confidence: medium).
2. Nhận định "iterate-and-test không có paper gốc duy nhất, kế thừa từ ML/software truyền thống" là suy luận từ việc thiếu một nguồn trích dẫn rõ ràng trong các docs đã đọc, không phải kết quả của một khảo sát đầy đủ mọi tài liệu về chủ đề này (confidence: medium).
3. Thứ tự xếp lớp "prompt engineering → RAG → fine-tuning" dựa trên bài so sánh của Confluent, một nguồn, chưa đối chiếu với nguồn thứ hai (confidence: medium).
4. Khuyến nghị "khoanh vùng lỗi ở prompt hay ở hệ thống trước khi refine" là suy luận hợp lý từ cấu trúc hệ thống nhiều bước, không phải kết luận đã được đo lường trực tiếp trong nguồn nào (confidence: low).
5. Nhận định "Claude Code CLI không có UI eval chính thức tương đương Console" là suy luận từ việc thiếu vắng tính năng đó trong doc chính thức tại thời điểm viết, không phải một tuyên bố phủ định đã được tài liệu hóa rõ ràng (confidence: low).
