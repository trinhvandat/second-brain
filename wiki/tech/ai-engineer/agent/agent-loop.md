---
status: current
updated: 2026-08
sources:
  - https://www.anthropic.com/research/building-effective-agents
  - https://www.anthropic.com/engineering/building-effective-agents
  - https://platform.claude.com/docs/en/agents-and-tools/tool-use/how-tool-use-works
  - https://arxiv.org/abs/2210.03629
  - https://developers.openai.com/api/docs/guides/agents/running-agents
  - https://docs.aws.amazon.com/prescriptive-guidance/latest/agentic-ai-foundations/perceive-reason-act.html
  - https://code.claude.com/docs/en/how-claude-code-works
  - https://code.claude.com/docs/en/agent-sdk/agent-loop
  - https://claude.com/blog/building-agents-with-the-claude-agent-sdk
roadmap: ai-engineer
stage: done
---

# Agent loop — vòng lặp perceive → reason/plan → act/invoke tool → observe/reflect

**TL;DR**: Agent loop là cơ chế cốt lõi biến một LLM thành "agent": thay vì trả lời 1 lượt rồi dừng, model chạy lặp lại chu trình **nhận input/quan sát → tự quyết định bước tiếp theo → gọi tool thật → đọc kết quả** cho tới khi đạt mục tiêu hoặc chạm điều kiện dừng — chính model, không phải code cố định, điều khiển vòng lặp này.

## 1. 4 bước của vòng lặp

- **Perceive (nhận input/observation)**: agent thu thập trạng thái hiện tại — task ban đầu, lịch sử hội thoại, và (từ vòng lặp thứ 2 trở đi) kết quả tool vừa nhận được ở bước trước.
- **Reason/plan (LLM quyết định bước tiếp theo)**: model xử lý toàn bộ ngữ cảnh, quyết định: trả lời luôn, hỏi thêm, hay gọi tool nào với tham số gì. Đây là bước duy nhất do LLM đảm nhiệm — 3 bước còn lại do "harness" (code bao quanh model) thực thi.
- **Act/invoke tool (gọi tool thật)**: harness thực thi tool được yêu cầu (đọc file, chạy code, gọi API, tìm kiếm...) — model không tự chạy bất cứ thứ gì, nó chỉ phát ra một yêu cầu có cấu trúc.
- **Observe/reflect (đọc kết quả, lặp lại hoặc dừng)**: kết quả tool được đưa trở lại vào ngữ cảnh, model đọc và tự đánh giá tiến độ, rồi quyết định lặp lại (quay về bước 1) hay dừng và trả lời cuối.

## 2. Cơ chế kỹ thuật cụ thể (Claude tool use)

Theo tài liệu chính thức của Claude Platform, vòng lặp phía client là một `while`-loop dựa trên `stop_reason`:

1. Gửi request gồm `tools` array + user message.
2. Claude trả về `stop_reason: "tool_use"` kèm các `tool_use` block (= bước reason/plan).
3. Ứng dụng thực thi tool, đóng gói kết quả thành `tool_result` block (= bước act).
4. Gửi request mới có kèm `tool_result` (= bước observe — đưa kết quả trở lại cho model).
5. Lặp lại từ bước 2 khi `stop_reason` vẫn là `"tool_use"`; vòng lặp chỉ dừng khi `stop_reason` là `end_turn`, `max_tokens`, `stop_sequence`, hoặc `refusal` — `stop_reason` là trường Claude API trả về để báo model vừa dừng vì lý do gì.

Điểm quan trọng: model **không bao giờ tự thực thi** thứ gì — nó chỉ phát ra `tool_use` (yêu cầu có cấu trúc), harness chạy thật, rồi kết quả quay lại qua `tool_result`. Một số tool (`web_search`, `web_fetch`, `code_execution`) chạy server-side ngay trong hạ tầng Anthropic, có vòng lặp nội bộ riêng (tự search lại nếu cần) và có thể trả về `stop_reason: "pause_turn"` nếu chạm giới hạn vòng lặp nội bộ.

## 3. Gốc học thuật: ReAct

Không cần hiểu paper gốc mới dùng được agent loop — mục này chỉ giúp biết "tên gọi này từ đâu ra" khi gặp lại trong tài liệu khác.

- Pattern "xen kẽ suy luận và hành động" có nguồn gốc từ paper **ReAct: Synergizing Reasoning and Acting in Language Models** (Yao et al., ICLR 2023, confidence: high): model sinh xen kẽ **Thought** (một câu suy luận ngắn giúp lập kế hoạch bước tiếp theo — tương đương bước reason/plan ở mục 1) và **Action** (gọi ra nguồn ngoài để lấy **Observation** — tương đương act + observe ở mục 1).
- Ví dụ cụ thể từ paper: hỏi "Ngoài Apple, còn công ty nào khác được Steve Jobs thành lập?" → `Thought`: cần tra cứu tiểu sử Steve Jobs → `Action`: search("Steve Jobs") → `Observation`: kết quả tìm kiếm → `Thought`: đọc thấy NeXT, Pixar → trả lời. Đây chính là 1 vòng perceive→reason→act→observe.
- ReAct được đánh giá trên 4 benchmark (HotPotQA, Fever, ALFWorld, WebShop); paradigm Reason+Act vượt trội hơn reasoning-only hoặc acting-only, đồng thời giảm hallucination nhờ tra cứu nguồn ngoài thay vì chỉ suy luận nội tại.
- Agent loop hiện đại (OpenAI Agents SDK, Claude tool-use loop) về bản chất là hiện thực hoá pattern Thought → Action → Observation này ở mức runtime/production — chỉ khác là không còn in ra chữ `Thought:`/`Action:` tường minh nữa (xem mục "Áp dụng với Claude Code").

## 4. Gốc lý thuyết xa hơn: BDI

Mục này mang tính lịch sử/bối cảnh — có thể bỏ qua nếu chỉ cần biết cách áp dụng agent loop vào code.

- Trước ReAct, khoa học nhận thức thập niên 1980 đã có kiến trúc **BDI (Belief-Desire-Intention)** của Michael Bratman, mô hình hoá cách một agent (con người hoặc máy) ra quyết định: agent nhận **percept** (tín hiệu từ môi trường) → cập nhật **belief** (những gì agent tin là đúng) → cân nhắc trên **desire** (mục tiêu mong muốn) → chốt thành **intention** (kế hoạch đã cam kết theo đuổi) → chọn hành động để thực hiện intention đó (confidence: medium, nguồn thứ cấp).
- Ánh xạ sang agent loop hiện đại: `belief` ≈ ngữ cảnh model đang có, `desire` ≈ task/goal, `intention` ≈ kế hoạch model chọn ở bước reason/plan. Đây là tiền thân triết học cho pattern perceive-reason-act mà AI engineering hiện dùng (**cognitive cycle** — thuật ngữ chỉ chu trình nhận thức lặp đi lặp lại này).

## 5. Ví dụ cụ thể: sửa 1 test đang fail

| Vòng lặp | Perceive | Reason/plan | Act | Observe |
|---|---|---|---|---|
| 1 | Task: "fix test X" | Cần xem code test trước | gọi `read_file(test_x.py)` | đọc nội dung file, thấy assertion sai |
| 2 | Đã có nội dung test | Cần chạy test để thấy lỗi thật | gọi `bash(pytest test_x.py)` | đọc log lỗi: `AssertionError: expected 5, got 4` |
| 3 | Đã có log lỗi | Sửa hàm liên quan | gọi `edit_file(sum.py)` | file đã sửa |
| 4 | Đã sửa code | Cần xác nhận fix đúng | gọi `bash(pytest test_x.py)` | log: `PASSED` → đạt điều kiện dừng, trả lời cuối |

Mỗi hàng là 1 vòng lặp đầy đủ perceive→reason→act→observe; vòng 4 tự dừng vì model đọc được tín hiệu "đã xong" từ observation, không phải vì có ai bảo dừng.

## 6. Điều kiện dừng (stopping conditions)

- Task hoàn thành: model tự nhận ra qua observation (VD test pass) và trả lời cuối (`stop_reason: end_turn`).
- Giới hạn cứng: số vòng lặp tối đa (`max_turns`), ngân sách tối đa (`max_budget_usd`) — để tránh vòng lặp chạy mãi hoặc tốn kém ngoài kiểm soát.
- Con người can thiệp: dừng thủ công hoặc chỉnh hướng giữa chừng (checkpoint) — nhiều hệ thống production coi con người là một phần của vòng lặp, không chỉ là người khởi động và chờ kết quả cuối.

## 7. Không phải lúc nào cũng cần agent loop

Anthropic khuyến nghị: bắt đầu đơn giản (1 lần gọi LLM, hoặc workflow với các bước cố định) và chỉ thêm agent loop khi độ linh hoạt của task vượt trội hơn chi phí phát sinh — latency cao hơn, tốn kém hơn, và lỗi có thể tích luỹ qua nhiều bước tool-call.

Phân biệt cốt lõi giữa 2 khái niệm hay bị nhầm:

| | Workflow | Agent (agent loop) |
|---|---|---|
| Đường đi | Code cố định định trước (if/else, pipeline bước A→B→C) | Model tự quyết định bước tiếp theo mỗi vòng lặp |
| Khi nào dùng tool | Lập trình viên chọn sẵn tool nào chạy ở bước nào | Model tự chọn tool và tham số |
| Ví dụ | "Luôn tóm tắt → luôn dịch → luôn gửi email" | "Sửa test cho tới khi pass" (không biết trước cần mấy vòng, sửa file nào) |

(as of anthropic.com, confidence: high)

## Liên hệ tới các phần khác

- [[agent-what-are-ai-agents]] — định nghĩa agent nói chung, so sánh với LLM call đơn và RAG cổ điển; agent loop chính là cơ chế kỹ thuật đứng sau định nghĩa đó.
- [[llm-reasoning-vs-standard-models]] — reasoning model có thể tự "suy nghĩ nhiều bước" trong 1 lần gọi, nhưng đó vẫn khác với agent loop (agent loop cần tool-call thật ra môi trường ngoài, không chỉ suy luận nội tại).
- [[ai-engineer-roadmap]] — vị trí của agent loop trong lộ trình học agent.

### Áp dụng với Claude Code

- Claude Code (CLI) chạy trên nền **Claude Agent SDK**, có vòng lặp tương đương nhưng được đóng gói ở mức cao hơn perceive/reason/act/observe kinh điển: Anthropic mô tả chính thức là 3 pha **gather context → take action → verify results**, các pha này "hoà vào nhau" (blend together) thay vì chạy tuần tự cứng nhắc (as of code.claude.com, confidence: high).
- Không có bước "plan" tách biệt: một lần gọi Claude API (1 `AssistantMessage`) có thể vừa chứa text suy luận vừa chứa yêu cầu gọi tool trong cùng 1 lượt — khác với ReAct kinh điển hay tách riêng khối `Thought:` và `Action:`.
- **Gather context** thay thế "perceive" bằng **agentic search** (model tự chủ động tìm thông tin cần, thay vì được đưa sẵn): gọi `Grep`/`Glob`/`Read`/`Bash` để khám phá filesystem theo nhu cầu, thay vì retrieval cố định chạy 1 lần trước khi suy luận (khác RAG cổ điển).
- **Take action** thực thi tool: tool chỉ đọc (Read, Glob, Grep, MCP read-only) chạy song song; tool có side effect (Edit, Write, Bash) chạy tuần tự — tối ưu kỹ thuật không có trong ReAct nguyên bản.
- **Verify results** (= observe/reflect) không chỉ đọc raw output mà kết hợp 3 cơ chế: rules-based feedback (check pass/fail rõ ràng), visual feedback (screenshot để kiểm layout), và LLM-as-judge (một model instance khác chấm kết quả theo tiêu chí mờ).
- Subagent (qua tool `Task`) chạy một bản sao độc lập của chính vòng lặp này trong context window riêng biệt, chỉ trả tóm tắt cuối về cho agent cha — nesting vòng lặp để quản lý context, không có trong ReAct gốc.
- Con người là một phần của vòng lặp: có thể ngắt (Esc) hoặc chỉnh hướng giữa chừng, input được đọc ngay khi tool call hiện tại xong.
- Có giới hạn dừng kỹ thuật: `max_turns`, `max_budget_usd` (chính thức); ngoài ra có nguồn thứ cấp (chưa xác nhận chính thức) mô tả một heuristic dừng sớm nếu 3 lượt liên tiếp sinh ra rất ít token (confidence: medium).
- Compaction (tự tóm tắt lịch sử hội thoại khi gần đầy context window) hoạt động như lớp quản lý bộ nhớ trong vòng lặp, ở mức harness chứ không phải do model tự gọi 1 tool "reflect".

## Giới hạn / open questions

- Ranh giới chính xác giữa "reasoning trace nội tại của reasoning model" và "reason/plan step của agent loop" chưa rõ ràng khi 2 cơ chế này chồng lấn (VD extended thinking + tool use trong cùng 1 lượt).
- Heuristic dừng sớm dựa trên "3 lượt liên tiếp <500 token" của Claude Code chỉ đến từ nguồn thứ cấp (blog phân tích kỹ thuật), chưa được Anthropic xác nhận chính thức trong docs.
- Thuật ngữ "agentic RAG" (agent loop áp dụng cho retrieval) chưa có paper gốc chuẩn hoá, định nghĩa còn khác nhau giữa các nguồn.
- Chưa rõ giới hạn cụ thể (nếu có) về độ sâu nesting subagent-trong-subagent trong Claude Agent SDK, và chi phí/latency thực tế của việc nest nhiều tầng.
