---
status: current
updated: 2026-08
sources:
  - https://www.langchain.com/blog/reflection-agents
  - https://arxiv.org/abs/2303.11366
  - https://arxiv.org/abs/2303.17651
  - https://arxiv.org/abs/2310.04406
  - https://www.anthropic.com/research/building-effective-agents
  - https://github.com/langchain-ai/langgraph-reflection
  - https://arxiv.org/abs/2310.01798
  - https://arxiv.org/html/2606.05976v1
  - https://openai.com/index/finding-gpt4s-mistakes-with-gpt-4/
  - https://www.deeplearning.ai/the-batch/agentic-design-patterns-part-2-reflection
  - https://code.claude.com/docs/en/code-review
  - https://code.claude.com/docs/en/agent-sdk/subagents
roadmap: ai-engineer
stage: learning
---

# Self-Critique Agents (Reflection) — agent tự sinh output, tự phê bình, rồi tự sửa trước khi kết thúc

TL;DR: **Self-critique** (hay **reflection/reflexion**) là vòng lặp **generate → critique → revise**: agent (cùng model được re-prompt, hoặc một "critic" riêng) tạo output, chạy một bước đánh giá **có cấu trúc** dựa trên goal/tiêu chí, sinh feedback cụ thể, rồi sửa lại theo feedback đó — có thể lặp nhiều vòng tới khi đạt điều kiện dừng. Đánh đổi cốt lõi: chất lượng/độ tin cậy tăng, nhưng tốn thêm token/latency mỗi vòng, và tự phê bình bởi **cùng một model** dễ mù trước lỗi hệ thống của chính nó.

## Nói đơn giản: ai làm gì trong vòng lặp này

Trước khi vào thuật ngữ học thuật, một câu tóm tắt bằng ngôn ngữ thường: **model viết ra một thứ (câu trả lời/code), rồi một lượt thứ hai — có thể là cùng model được hỏi lại, có thể là một model khác — soi lại thứ đó để tìm lỗi và đề nghị sửa, rồi model viết lại theo đề nghị đó.** Các thuật ngữ dưới đây chỉ là tên gọi khác nhau cho 2-3 "vai" trong vòng lặp đó, tuỳ paper/nguồn:

- **Generator / Actor**: vai sinh ra output ban đầu (trả lời câu hỏi, viết code...).
- **Critic / Reflector / Evaluator**: vai chấm điểm hoặc chỉ ra vấn đề trong output đó — có thể là cùng model (re-prompt), có thể là model khác, có thể là một agent riêng biệt.
- **Refiner**: vai viết lại output dựa trên feedback từ critic — nhiều khi cũng chính là generator, chỉ khác prompt.

Toàn bộ phần còn lại của note là các biến thể/nghiên cứu cụ thể hoá 3 vai này theo nhiều cách khác nhau.

## Áp dụng nhanh trong Claude Code (chi tiết đầy đủ ở cuối note)

Nếu chỉ cần "làm sao dùng được pattern này ngay hôm nay", đây là phần cốt lõi — phần "Liên hệ tới các phần khác > Áp dụng với Claude Code" ở cuối note nói chi tiết hơn:

- **Đừng tin self-critique cùng model** cho việc quan trọng — dùng **subagent** (context hoàn toàn mới, không kế thừa reasoning trace của agent đã sinh output) hoặc model khác làm critic.
- `/code-review` là ví dụ có sẵn: chạy như fleet các subagent tìm lỗi + bước verification lại với code thực tế, thiết kế để né đúng điểm mù "tự sửa mù" nói ở phần dưới.
- Có thể giới hạn tool của subagent phê bình (chỉ Read/Grep/Glob, không Edit) để nó chỉ đánh giá, không tự sửa luôn.
- Claude Code **không có sẵn** một vòng lặp reflection tự động (kiểu auto re-invoke khi critic tìm ra lỗi) — phải tự điều phối generate → critique-subagent → revise nếu muốn lặp nhiều vòng.

## Khác gì với "hỏi lại/try again"

- Một cuộc hội thoại nhiều lượt bình thường (user nói "sai rồi, sửa lại") không phải reflection — đó là feedback từ bên ngoài, không có bước đánh giá nội tại nào của agent.
- Self-critique yêu cầu một **bước đánh giá tường minh, có cấu trúc**: thường có prompt/persona riêng (vd. "reflector" đóng vai giáo viên phê bình xây dựng), tiêu chí rõ ràng, và output là feedback cụ thể (thiếu gì, thừa gì, sai ở đâu) — không chỉ là "thử lại lần nữa".

## Ba kiến trúc reflection cụ thể (theo LangChain)

LangChain phân loại pattern này theo mức độ phức tạp tăng dần:

1. **Basic Reflection** — 2 lệnh gọi LLM: một "generator" sinh câu trả lời, một "reflector" (đóng vai giáo viên) phê bình mang tính xây dựng; lặp lại cố định số vòng rồi trả kết quả cuối.
2. **Reflexion** (dựa trên Shinn et al. 2023) — actor agent tự phê bình response của mình nhưng **grounded vào dữ liệu bên ngoài** (citations, liệt kê rõ nội dung thiếu/thừa) thay vì chỉ ý kiến nội tại — critique nhờ vậy cụ thể và hữu ích hơn cho vòng sửa tiếp theo.
3. **Language Agent Tree Search (LATS)** (dựa trên Zhou et al., arXiv:2310.04406) — kết hợp reflection/evaluation với Monte Carlo Tree Search: selection → expansion/simulation → reflection/evaluation → backpropagation, khám phá nhiều trajectory song song thay vì một đường thẳng.

## Hai nguồn gốc học thuật song song

- **Reflexion** (Shinn, Cassano, Berman, Gopinath, Narasimhan, Yao — NeurIPS 2023, arXiv:2303.11366): 3 vai trò — Actor (sinh text/action), Evaluator (chấm điểm output), Self-Reflection model (sinh feedback dạng ngôn ngữ, lưu vào **episodic memory buffer** để cải thiện các lần thử sau). Không update trọng số — là giải pháp nhẹ thay thế RL fine-tuning, feedback ở dạng ngôn ngữ tự nhiên chứ không phải gradient. Báo cáo **91% pass@1 trên HumanEval**, so với baseline GPT-4 thuần là 80%.
- **Self-Refine** (Madaan et al. — NeurIPS 2023, arXiv:2303.17651): **cùng một LLM** đóng cả 3 vai — generator, feedback-provider, refiner (3 prompt riêng biệt) — lặp lại mà không cần training/RL/dữ liệu supervised bổ sung. Đánh giá trên 7 task (dialogue, math reasoning...) với GPT-3.5/ChatGPT/GPT-4, báo cáo mức tăng hiệu năng trung bình ~20%.

Điểm khác biệt quan trọng: Reflexion grounding critique vào dữ liệu/tool execution bên ngoài; Self-Refine để chính model tự đánh giá không cần external signal — đây chính là điểm dễ gây "mù" (xem phần dưới).

## Anthropic gọi đây là "Evaluator-Optimizer" workflow

Trong "Building Effective AI Agents", Anthropic liệt kê **Evaluator-Optimizer** là 1 trong 5 workflow pattern chuẩn (cùng với prompt chaining, routing, parallelization, orchestrator-workers): một LLM call sinh response, một LLM call **khác** đánh giá + cho feedback, lặp tới khi evaluator hài lòng — tương tự cách một người viết văn tự sửa bản thảo qua nhiều vòng. Khuyến nghị dùng khi có tiêu chí đánh giá rõ ràng và việc refine lặp lại tạo giá trị đo được (vd. dịch văn học, research/search nhiều vòng); không phù hợp cho real-time/low-latency, tiêu chí đánh giá mơ hồ, hoặc khi chi phí token vượt lợi ích chất lượng.

## Trade-off: chất lượng vs chi phí

- **Được**: bắt được lỗi mà một lượt generate đơn không thấy, cải thiện độ tin cậy — đặc biệt hữu ích cho task knowledge-intensive nơi chất lượng quan trọng hơn tốc độ.
- **Mất**: mỗi vòng critique là một lệnh gọi LLM riêng → cộng dồn latency + token cost; LangChain nói thẳng "reflection takes time" và khuyên tránh dùng cho ứng dụng cần low-latency.
- **Giới hạn quan trọng nếu không grounding**: nếu bước reflection không dựa vào tool/dữ liệu bên ngoài nào, kết quả cuối có thể không tốt hơn đáng kể so với bản gốc — self-critique thuần túy nội tại có sức mạnh hạn chế trong việc tự bắt lỗi của chính mình.

## Điểm mù của self-critique cùng model — bằng chứng phản biện

Đây là phần quan trọng hay bị bỏ qua trong các bài giới thiệu lạc quan về reflection:

- **"LLMs Cannot Self-Correct Reasoning Yet"** (Huang et al., ICLR 2024, arXiv:2310.01798): self-correction **nội tại** (model tự sửa reasoning của chính nó chỉ dựa vào phán đoán của bản thân, không có external feedback) thường **không cải thiện, thậm chí làm giảm** hiệu năng; các kết quả trước đó tuyên bố "self-correction giúp ích" thường dựa vào oracle label hoặc baseline prompt yếu.
- **"Self-Correction Blind Spot"** (arXiv:2606.05976, 2026): cùng một model nhận diện đúng lỗi khi lỗi đó nằm trong nội dung do **người khác/bên ngoài** cung cấp, nhưng **thất bại nhận diện chính lỗi đó** khi nó nằm trong output do chính model tự sinh — tỷ lệ thất bại trung bình **64.5%** trên 14 model được test (as of arxiv.org/html/2606.05976v1, confidence: medium — paper 2026 còn mới, chưa được kiểm chứng rộng). Cơ chế đề xuất: inference path của model đã bị "kích hoạt" theo hướng sinh ra output đó, tương tự việc tác giả không tự nhìn ra lỗi chính tả trong bài viết của mình.

**Cách giảm thiểu thường được khuyến nghị**: dùng model/family khác làm critic thay vì cùng model; viết system prompt cho critic mang tính **adversarial** (chủ động tìm lỗi thay vì chỉ xác nhận); ưu tiên validator khách quan/lập trình được (unit test, schema check, regex assertion) hơn là phán đoán chủ quan của một LLM khác.

## Ví dụ thực tế: CriticGPT (OpenAI)

CriticGPT là model dựa trên GPT-4, được fine-tune bằng RLHF chuyên để viết critique cho output của ChatGPT (kể cả code) — train trên các bug được cố tình cài vào cùng critique do người viết. Đây là ví dụ cụ thể về việc dùng **critic riêng biệt/chuyên biệt** thay vì để model tự phê bình chính mình:

| Chỉ số | Kết quả | Vì sao quan trọng với bạn |
|---|---|---|
| Số bug con người bắt được khi có CriticGPT hỗ trợ | tăng ~60% so với không có | Critic **chuyên biệt, train riêng** giúp reviewer người thật giỏi hơn — gợi ý rằng đầu tư một "critic" tách biệt (không phải re-prompt cùng model) là đáng tiền |
| Tỷ lệ critique của CriticGPT được ưu tiên hơn critique của chính ChatGPT | 63% | Critic tách biệt cho feedback hữu ích hơn self-critique cùng model — cùng kết luận với "Self-Correction Blind Spot" ở trên |
| Vấn đề "nitpick" bị hallucinate | ít hơn so với self-critique của ChatGPT | Critic train riêng ít tạo noise/false positive hơn — quan trọng nếu bạn định tự động hoá bước critique (đỡ phải lọc tay) |

## Ví dụ minh hoạ: vòng lặp code review (theo Andrew Ng)

Andrew Ng (DeepLearning.AI) mô tả reflection là 1 trong 4 pattern agentic cốt lõi (cùng tool use, planning, multi-agent collaboration), với ví dụ code generation cụ thể:

```
1. Generate: model viết đoạn code theo yêu cầu.
2. Critique: prompt model "hãy kiểm tra kỹ code này về tính đúng đắn, style, hiệu năng"
   → model tự liệt kê vấn đề cụ thể (không chỉ nói chung chung "trông ổn").
3. Revise: model viết lại code dựa trên feedback ở bước 2.
4. (tuỳ chọn) Lặp lại bước 2-3, hoặc dừng nếu không còn vấn đề / đạt max round.
```

Ng cũng mô tả 2 biến thể mạnh hơn: grounding bước critique bằng tool (chạy unit test thật, web search) thay vì chỉ ý kiến của model; và multi-agent — một critic agent **riêng biệt** debate với generator agent, thay vì cùng một instance tự phê bình.

## Điều kiện dừng (stop condition) thường gặp

- Đạt **số vòng tối đa** (max rounds) — đơn giản, nhưng có thể dừng sớm khi chưa đủ tốt hoặc dừng muộn khi đã ổn.
- **Critic approve** — reflector/evaluator xác nhận không còn vấn đề đáng kể (LangGraph reflection package implement đúng kiểu này: nếu critique agent không tìm ra issue, loop kết thúc).
- **Không còn thay đổi đáng kể** giữa 2 vòng liên tiếp — dấu hiệu đã hội tụ.

## Ví dụ tự tham chiếu: pipeline viết note trong chính vault này

Skill `ai-engineer-note-pipeline` của vault này (workflow `.claude/workflows/ai-engineer-note-pipeline.js`) là một instance **thực tế, đang chạy** của đúng pattern này: một note được research + sinh ra, sau đó đi qua vòng review **junior → middle → senior** — mỗi reviewer persona đóng vai một "critic" khác nhau, phê bình rồi note được sửa lại theo feedback trước khi hoàn tất. Đây chính là multi-role generate-critique-revise loop, và vì mỗi persona review là một lượt đánh giá riêng (không phải cùng một continuous reasoning trace), nó né được phần nào "same-model blind spot" nói ở trên — gần giống ý tưởng "critic khác" hơn là self-critique thuần.

## Liên hệ tới các phần khác

- Khác với [[agent-architecture-react]]: ReAct là vòng Thought → Action → Observation nhắm vào việc **thu thập thêm thông tin** qua tool call; self-critique là vòng đánh giá **chất lượng của chính output đã sinh** — hai pattern có thể kết hợp (Reflexion thực chất grounding critique vào tool observation, gần với tinh thần ReAct).
- Liên hệ [[agent-observation-reflection]]: observation feed vào reasoning tiếp theo trong agent loop nói chung; self-critique là một dạng "reflection" có cấu trúc chặt hơn, tách hẳn thành bước đánh giá riêng với prompt/persona riêng.
- Liên hệ [[agent-architecture-planner-executor]]: planner-executor tách vai trò theo **giai đoạn** (lập kế hoạch vs thực thi); self-critique tách vai trò theo **chức năng đánh giá** (generate vs critique) — có thể tồn tại độc lập hoặc lồng vào nhau (vd. planner tự phê bình kế hoạch trước khi giao cho executor).
- Xem [[ai-engineer-roadmap]] để biết vị trí của self-critique trong toàn bộ lộ trình agent architecture.

### Áp dụng với Claude Code

**Có áp dụng, chủ yếu qua cơ chế subagent với context riêng biệt** — đây là điểm khác với reflection học thuật kiểu "cùng model tự re-prompt". (Bản tóm tắt nhanh đã nêu ở đầu note; đây là chi tiết đầy đủ.)

- **Code Review** (`/code-review` hoặc GitHub PR integration) chạy như một "fleet of specialized agents"/subagent nền, mỗi agent tìm một loại vấn đề khác nhau, cộng thêm bước **verification** kiểm tra candidate finding lại với hành vi code thực tế trước khi dedupe/xếp hạng/trả kết quả — đây là kiến trúc **cố tình thiết kế để tránh** điểm yếu "same-model blindness" của self-critique naive, không phải "try again" trong cùng hội thoại.
- **Claude Agent SDK subagents** chạy trong context window **hoàn toàn mới**: một subagent (vd. `code-reviewer`) không kế thừa lịch sử hội thoại hay tool result của agent cha, chỉ nhận prompt string + system prompt riêng — đây chính là cơ chế kiến trúc giúp critic không bị "neo" theo reasoning trace của agent đã sinh ra output, giải quyết trực tiếp vấn đề "self-correction blind spot" nêu ở trên.
- SDK còn hỗ trợ **giới hạn tool** cho subagent phê bình (vd. chỉ cho Read/Grep/Glob, không cho Edit) — đảm bảo bước critique chỉ đánh giá thuần túy, không lẫn lộn với việc tự sửa luôn.
- **Không có sẵn** một cơ chế "reflection loop" tự động, tích hợp sẵn kiểu LangGraph's `langgraph-reflection` (auto re-invoke generator khi critic tìm thấy vấn đề) — người dùng/agent phải tự điều phối vòng generate → critique-subagent → revise nếu muốn loop nhiều vòng; Claude Code cung cấp building block (subagent với context cô lập) chứ không đóng gói sẵn state machine của reflection.

## Nguồn & mức tin cậy

Chi tiết claim nào đến từ nguồn nào (danh sách URL đầy đủ đã có trong frontmatter `sources`):

| Nguồn | Claim chính hỗ trợ | Confidence |
|---|---|---|
| langchain.com/blog/reflection-agents | Định nghĩa reflection, 3 kiến trúc (Basic/Reflexion/LATS), khuyến nghị tránh dùng cho low-latency | high |
| arXiv:2303.11366 (Reflexion, Shinn et al.) | 3 vai Actor/Evaluator/Self-Reflection + episodic memory; 91% pass@1 HumanEval | high |
| arXiv:2303.17651 (Self-Refine, Madaan et al.) | Cùng 1 LLM đóng 3 vai; ~20% tăng hiệu năng trung bình trên 7 task | high |
| arXiv:2310.04406 (LATS, Zhou et al.) | Kết hợp reflection với Monte Carlo Tree Search | high (định nghĩa), chưa có so sánh thực nghiệm sâu trong note này |
| anthropic.com/research/building-effective-agents | Evaluator-Optimizer là 1/5 workflow pattern chuẩn của Anthropic | high |
| arXiv:2310.01798 (Huang et al., ICLR 2024) | Self-correction nội tại thường không cải thiện, thậm chí làm giảm hiệu năng reasoning | high |
| arXiv:2606.05976 (Self-Correction Blind Spot) | Tỷ lệ thất bại tự nhận lỗi trung bình 64.5% trên 14 model | medium — paper 2026 còn mới, chưa kiểm chứng rộng |
| openai.com/index/finding-gpt4s-mistakes-with-gpt-4 (CriticGPT) | +60% bug con người bắt được, critique CriticGPT được ưu tiên 63% | high |
| deeplearning.ai/the-batch (Andrew Ng) | Reflection là 1/4 pattern agentic cốt lõi; ví dụ vòng lặp code review | high |
| code.claude.com/docs/en/code-review | Kiến trúc `/code-review`: fleet subagent + verification step | high |
| code.claude.com/docs/en/agent-sdk/subagents | Subagent chạy trong context window hoàn toàn mới | high |

## Giới hạn / open questions

- Chưa có số liệu định lượng trực tiếp so sánh self-critique cùng model vs critic khác model **trên cùng một benchmark cố định** — các con số trong note (CriticGPT 63%, Self-Correction Blind Spot 64.5%) đến từ 2 nghiên cứu khác nhau, không thể cộng gộp thành một kết luận thống nhất.
- Paper "Self-Correction Blind Spot" (arXiv:2606.05976) là nghiên cứu 2026 còn khá mới, chưa rõ mức độ được cộng đồng academic kiểm chứng lại/replicate.
- Chưa đào sâu quan hệ giữa LATS (tree search + reflection) và các pattern search-based khác (MCTS thuần, beam search với self-eval) — note chỉ nêu định nghĩa từ LangChain, chưa so sánh hiệu năng thực nghiệm.
- Chưa rõ trong pipeline note của vault này (`ai-engineer-note-pipeline`), các reviewer persona (junior/middle/senior) có thực sự dùng model/context tách biệt hoàn toàn hay chỉ là prompt persona khác nhau trong cùng phiên — cần đọc code workflow để xác nhận mức độ "critic khác" thực sự đạt được.
