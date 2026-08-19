---
status: current
updated: 2026-08
sources:
  - https://www.langchain.com/blog/planning-agents
  - https://arxiv.org/abs/2305.04091
  - https://arxiv.org/abs/2210.03629
  - https://arxiv.org/abs/2305.18323
  - https://arxiv.org/pdf/2312.04511
  - https://langchain-ai.github.io/langgraphjs/tutorials/plan-and-execute/plan-and-execute/
  - https://claude.com/blog/building-multi-agent-systems-when-and-how-to-use-them
  - https://code.claude.com/docs/en/agent-sdk/subagents
  - https://claudelog.com/mechanics/plan-mode/
  - https://github.com/anthropics/claude-code/issues/48188
  - https://github.com/anthropics/claude-code/issues/60329
  - https://arxiv.org/pdf/2509.08646
roadmap: ai-engineer
stage: learning
---

# Planner–Executor — kiến trúc agent tách "lập kế hoạch" khỏi "thực thi"

**TL;DR**: Planner–Executor tách agent thành 2 vai trò riêng: một **planner** lập toàn bộ kế hoạch nhiều bước trước, rồi một (hoặc nhiều) **executor** thực thi từng bước đó bằng cách gọi tool. Khác với [[agent-architecture-react]] — nơi "nghĩ" và "làm" đan xen liên tục trong 1 vòng lặp — ở đây plan là một danh sách bước tường minh, xem/sửa được trước khi bất kỳ hành động nào xảy ra.

## 1. Định nghĩa và nguồn gốc

- **Planner**: nhận goal, sinh ra một danh sách bước có thứ tự (structured task list) để hoàn thành goal đó — thường chỉ 1 lần gọi LLM, không tự invoke tool.
- **Executor**: nhận từng bước trong plan (kèm query gốc), gọi 1 hoặc nhiều tool để hoàn thành bước đó, trả kết quả về.
- Cái tên/pattern này được LangChain đặt ra: **"Plan-and-Execute Agents"** — planner tạo kế hoạch nhiều bước, executor(s) nhận từng bước + query gốc để invoke tool hoàn thành bước đó.
- Gốc học thuật/ý tưởng: **Plan-and-Solve Prompting** (Wang et al., arXiv:2305.04091) — kỹ thuật zero-shot buộc LLM "hiểu đề rồi lập kế hoạch, sau đó thực hiện từng bước", ban đầu nhắm vào chất lượng chuỗi suy luận (reasoning), chưa phải agent dùng tool; và dự án **BabyAGI** của Yohei Nakajima được LangChain trích dẫn là nguồn ảnh hưởng cho phần agent hoá ý tưởng này.

## 2. So sánh với ReAct

| | ReAct | Planner–Executor |
|---|---|---|
| Vòng lặp | Thought → Act → Observation, xen kẽ chặt, 1 lần gọi LLM lớn cho **mỗi** tool call | Plan 1 lần upfront → thực thi tuần tự/song song, executor không nhất thiết cần LLM lớn |
| Model dùng | Cùng 1 model xuyên suốt, phải "thông minh" ở mọi bước | Planner dùng model lớn/đắt, executor dùng model nhỏ/rẻ (hoặc không cần LLM) |
| Plan có tường minh không | Ẩn trong chuỗi Thought, khó review trước khi chạy | Tường minh, là 1 artifact có thể inspect/edit trước khi thực thi |
| Điểm yếu | Có thể ra quyết định cận-tối-ưu vì chỉ nhìn 1 sub-problem/lần | Plan có thể "cũ" (stale) nếu thực thi phát hiện thông tin mới → cần re-plan |

- ReAct (Yao et al., ICLR 2023, xem thêm [[agent-reason-plan]]) là baseline kinh điển mà Planner–Executor được so sánh cùng: ReAct đan reasoning và action theo từng lượt trong 1 vòng lặp duy nhất.
- Lập luận ủng hộ Planner–Executor: vì ReAct chỉ "nhìn" 1 sub-problem tại một thời điểm, nó dễ đi vào quỹ đạo hành động kém tối ưu hơn so với việc lập kế hoạch cho toàn bộ task ngay từ đầu.

## 3. Các biến thể trong họ Plan-and-Execute

**2 điều cần nhớ, không cần thuộc hết chi tiết học thuật bên dưới**:
- Cả 3 biến thể đều theo công thức chung: **lập plan trước, chạy sau**.
- Khác nhau ở 2 điểm: plan cứng/tuần tự hay linh hoạt/cho phép **song song** (parallel — nhiều bước chạy cùng lúc thay vì chờ nhau), và có bước "re-plan" (lập lại plan giữa chừng) hay không.

Phần dưới đây là chi tiết cho ai muốn đối chiếu với 3 paper/tài liệu gốc — có thể bỏ qua nếu chỉ cần nắm ý chính ở trên.

| Biến thể | Ý tưởng khác biệt chính | Số liệu nổi bật |
|---|---|---|
| **Plan-and-Execute** (LangChain/LangGraph) | Planner sinh plan → executor chạy từng bước → có bước **re-plan** sau khi thực thi để quyết định có cần sửa/thêm bước không. LangGraph có tutorial chính thức: state = list các bước + kết quả, planner node chạy 1 lần rồi loop executor node. | — |
| **ReWOO** — *Reasoning WithOut Observation* (Xu et al., arXiv:2305.18323) | Tách hẳn 3 module **Planner / Worker / Solver**. Planner sinh **toàn bộ** plan 1 lần, dùng biến tham chiếu (VD `#E2`) để bước sau lấy output bước trước — không cần gọi LLM lại trong vòng lặp cho mỗi bước. Worker gọi tool; Solver tổng hợp câu trả lời cuối. | ~64% ít token hơn so với loop kiểu ReAct, +4.4% accuracy tuyệt đối trên 6 benchmark (confidence: high) |
| **LLMCompiler** (Kim et al., arXiv:2312.04511) | Đẩy xa hơn: plan là một **DAG** — viết tắt của *Directed Acyclic Graph* (đồ thị có hướng, không chu trình: các task nối với nhau bằng mũi tên chỉ chiều phụ thuộc, không bao giờ vòng lại chính nó) — các task có dependency rõ ràng, cho phép chạy song song các bước độc lập thay vì tuần tự. | Tăng tốc tới **3.6x** so với gọi tool tuần tự kiểu ReAct (confidence: medium — số liệu lấy qua bài tóm tắt của LangChain, chưa đọc trực tiếp paper gốc) |

## 4. Vì sao tách vai trò lại có lợi: model routing

- Vì planner chỉ gọi 1 lần (hoặc vài lần khi re-plan), có thể dùng model lớn/đắt/thông minh nhất cho bước này — model lớn chỉ bị gọi ở bước (re-)plan, không phải mỗi tool call.
- Executor chạy nhiều lần hơn (1 lần/bước), nên hợp lý khi dùng model nhỏ/rẻ/nhanh, hoặc thậm chí không cần LLM (chỉ cần map bước → tool call cố định).
- Ví dụ thực tế ở quy mô lớn hơn: hệ thống multi-agent research của Anthropic dùng kiến trúc **orchestrator–worker** (1 agent điều phối/lập kế hoạch — chính là vai trò planner — đứng trên nhiều agent-con chỉ lo thực thi, chính là vai trò executor) — lead agent (planner) phân tích query, lập chiến lược, chia thành các subtask có mục tiêu/ranh giới rõ ràng, rồi sinh 3–5 subagent chạy song song để thực thi tìm kiếm/tool-use. Trong triển khai thực tế, **Claude Opus 4 làm planner, Claude Sonnet 4 làm executor**, cho kết quả tốt hơn **90.2%** so với 1 agent Opus 4 đơn lẻ làm hết, đổi lại tốn **~15x token** so với 1 lần chat đơn agent (as of claude.com/blog/building-multi-agent-systems-when-and-how-to-use-them, confidence: medium — số liệu cụ thể đối chiếu qua bài tóm tắt thứ cấp, xem "Giới hạn" bên dưới). Vì chi phí token cao, Anthropic khuyến nghị pattern này chỉ dùng cho task giá trị cao, có thể song song hoá.

### 4.1 Cấu trúc gọi API rút gọn (pseudocode)

Hình dung planner và executor như 2 lời gọi LLM tách biệt, nối với nhau bằng một cấu trúc dữ liệu "plan" ở giữa. **Đây là pseudocode minh hoạ luồng dữ liệu, không phải code chạy được** — `llm_call(...)` là hàm giả định đứng cho bất kỳ lệnh gọi LLM thật nào (VD Anthropic Messages API, hoặc 1 node trong LangGraph):

```python
# 1. Planner: 1 lần gọi model lớn, KHÔNG tự invoke tool
plan = llm_call(
    model="opus",
    system="Bạn là planner. Sinh danh sách bước để hoàn thành goal.",
    user=goal,
    output_schema=list[Step],  # Step = {id, description, tool, depends_on}
)

# 2. Executor: 1 lần gọi/bước, model nhỏ, CÓ invoke tool
results = {}
for step in topological_order(plan):          # topological order = duyệt các bước theo đúng thứ tự phụ thuộc (depends_on), bước nào cần input của bước khác thì luôn chạy sau bước đó
    results[step.id] = llm_call(
        model="sonnet",
        system="Bạn là executor. Hoàn thành bước này bằng tool được cấp.",
        user=render(step, context=results),    # bơm kết quả bước trước nếu cần
        tools=[step.tool],
    )

# 3. Re-plan (tuỳ chọn): nếu 1 executor phát hiện thông tin mâu thuẫn plan
if needs_replan(results):
    plan = llm_call(model="opus", system="Cập nhật plan dựa trên kết quả mới.", ...)
```

Đây là bộ khung chung; LangGraph/ReWOO/LLMCompiler chỉ khác nhau ở cách biểu diễn `plan` (list tuần tự vs DAG) và có/không bước re-plan.

## 5. Ví dụ minh hoạ cụ thể

Goal: "So sánh doanh thu quý gần nhất của 3 công ty A, B, C và viết báo cáo tóm tắt."

```
Planner (1 lần gọi LLM lớn):
  Step 1: Tìm doanh thu quý gần nhất của công ty A (tool: web_search)
  Step 2: Tìm doanh thu quý gần nhất của công ty B (tool: web_search)
  Step 3: Tìm doanh thu quý gần nhất của công ty C (tool: web_search)
  Step 4: Tổng hợp 3 số liệu thành bảng so sánh (tool: none — reasoning)
  Step 5: Viết đoạn tóm tắt nhận xét xu hướng (tool: none — reasoning)

Executor (nhiều lần gọi, có thể song song Step 1-3):
  chạy Step 1, 2, 3 song song (executor rẻ, model nhỏ) → trả 3 kết quả
  chạy Step 4, 5 tuần tự (phụ thuộc kết quả 1-3)

Re-plan (nếu cần):
  Nếu Step 2 phát hiện công ty B mới đổi ticker → gọi lại planner
  để chèn thêm bước "xác nhận ticker mới" trước khi tiếp tục.
```

- Step 1–3 độc lập nhau → đây chính là chỗ LLMCompiler tận dụng để chạy song song thay vì tuần tự.
- Bước "re-plan" ở cuối minh hoạ đúng tradeoff nêu trong đề bài: plan lập sẵn có thể lỗi thời khi thực thi phát hiện thông tin mới (VD công ty đổi ticker), buộc phải quay lại planner.

## 6. Khi nào nên dùng, khi nào không

- **Phù hợp**: workflow có hình dạng biết trước, dễ dự đoán — multi-hop Q&A khi đã biết cần tra cứu gì, tạo report tổng hợp từ nhiều nguồn độc lập.
- **Không phù hợp / rủi ro**: môi trường quá động/mơ hồ, nơi mỗi observation có thể đổi hẳn hành động tiếp theo (troubleshooting real-time, phân tích dữ liệu mở).
  - Trong tình huống đó, re-plan sẽ kích hoạt liên tục trên gần như mọi bước.
  - Hệ quả: hệ thống phải trả phí plan ban đầu **và** phí re-plan lặp lại.
  - Kết quả cuối: mất luôn lợi thế hiệu quả so với dùng ReAct thuần ngay từ đầu.
- So với các kiến trúc lân cận: một lời gọi LLM đơn thuần (không tool) chỉ sinh 1 lượt từ tri thức tham số, không có bước grounding ngoài; RAG là pipeline 2 bước cố định (retrieve rồi generate), không phải danh sách task được LLM sinh động; workflow tĩnh (simple workflow) có step list do người viết hard-code sẵn, khác với Planner–Executor nơi plan do LLM sinh động theo từng goal.

## Liên hệ tới các phần khác

### Áp dụng với Claude Code

- Vòng lặp chính (top-level) của Claude Code **không** mặc định là Planner–Executor tách rời — nó vận hành kiểu ReAct: cùng 1 model reason rồi act theo từng lượt trong 1 context (xem [[agent-loop]]).
- **Plan Mode** là lớp tuỳ chọn (opt-in, người dùng bật) mô phỏng gần với ý tưởng planner: khi bật, agent bị giới hạn chỉ dùng tool read-only (Read, Grep, Glob, WebSearch, TodoWrite...), chặn Edit/Write/Bash, buộc phải trình bày 1 plan tường minh trước khi được phép thực thi — nhưng plan và phần thực thi sau đó vẫn chạy trên **cùng một agent/model**, không tách thành 2 model riêng như LangChain hay hệ thống Anthropic multi-agent.
- **TodoWrite** tạo ra danh sách task có cấu trúc (pending/in_progress/completed), được bơm lại vào context sau mỗi tool call — đóng vai trò "plan neo" tường minh, có thể xem/sửa, nhưng vẫn là in-loop approximation chứ không phải kiến trúc Planner–Executor đầy đủ.
- **Claude Agent SDK** (không phải Claude Code CLI trực tiếp) mới hỗ trợ Planner–Executor đúng nghĩa: subagent có context riêng, tool set riêng, và **model override riêng** (VD subagent quan trọng gán `model: opus`, subagent thường gán `sonnet`/`haiku`) — cho phép lập trình viên tự thiết kế 1 planner model lớn + nhiều executor model nhỏ chạy song song, đúng như mô tả trong đề bài.
- Điểm yếu re-plan cũng xuất hiện đúng như dự đoán: sau khi `ExitPlanMode` được duyệt và thực thi bắt đầu, Claude Code (tính đến các issue đã ghi nhận) **chưa có cơ chế người dùng-facing để quay lại plan mode giữa chừng** nếu thực thi phát hiện plan sai — đây là gap đã được cộng đồng report, chưa phải vấn đề đã giải quyết.

## Giới hạn / open questions

- Số liệu "90.2% cải thiện" và "15x token" của Anthropic multi-agent system lấy một phần từ bài tóm tắt thứ cấp (theaiengineer.substack.com), chưa đối chiếu trực tiếp với số gốc trong blog chính thức — cần verify lại nếu dùng làm căn cứ quyết định kỹ thuật.
- Chưa rõ ranh giới rõ ràng giữa "re-plan" trong Plan-and-Execute (LangChain) và "replan" trong ReWOO — mức độ ReWOO cũng cần re-plan hay gần như không cần (do đã tách reasoning khỏi observation) chưa được xác nhận kỹ trong tài liệu đã đọc.
- Bài "Architecting Resilient LLM Agents: A Guide to Secure Plan-then-Execute Implementations" (arXiv:2509.08646) mới chỉ được liệt kê như tín hiệu cho thấy pattern này đã "chín" tới mức cần guidance bảo mật riêng — chưa đọc sâu nội dung cụ thể của paper này.
- Chưa có ví dụ đo lường thực tế (benchmark tự chạy) so sánh Planner–Executor vs ReAct trong chính vault này — các con số hiện tại đều trích dẫn từ nguồn ngoài.
