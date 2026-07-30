---
status: current
updated: 2026-07
sources:
  - https://www.anthropic.com/engineering/building-effective-agents
  - https://www.anthropic.com/engineering/multi-agent-research-system
  - https://www.langchain.com/blog/langgraph-multi-agent-workflows
  - https://docs.langchain.com/oss/python/langgraph/graph-api
  - https://github.com/langchain-ai/langgraph-supervisor-py
  - https://cognition.com/blog/dont-build-multi-agents
  - https://www.confluent.io/blog/event-driven-multi-agent-systems/
  - https://www.truefoundry.com/blog/graph-engineering-enterprise-guide
  - https://www.aibuilderclub.com/blog/graph-engineering-with-claude-code
  - https://alexop.dev/posts/claude-code-workflows-deterministic-orchestration/
  - https://www.productcompass.pm/p/claude-code-dynamic-workflows
  - https://hidekazu-konishi.com/entry/claude_code_subagents_and_orchestration_guide.html
---

# Graph Engineering — điều phối multi-agent dưới dạng đồ thị

> Bộ tài liệu tổng hợp từ deep-research đa nguồn (Anthropic, LangChain/LangGraph, Cognition, Confluent, TrueFoundry + các bài blog thực chiến). Mọi claim quan trọng có confidence marker và trích dẫn nguồn. Nối tiếp [[agentic-workflow-patterns]], [[agentic-systems-taxonomy]], [[augmented-llm]].

## Mục lục

1. [TL;DR](#tldr)
2. [Graph engineering là gì](#1-graph-engineering-là-gì)
3. [Phân biệt với prompt / context / flow engineering và với workflow tuyến tính](#2-phân-biệt-với-các-engineering-khác-và-với-workflow-tuyến-tính)
4. [Ba thành phần cốt lõi: State — Nodes — Edges](#3-ba-thành-phần-cốt-lõi-state--nodes--edges)
5. [Các topology / pattern chính](#4-các-topology--pattern-chính)
6. [Frameworks: LangGraph, langgraph-supervisor, event-driven](#5-frameworks)
7. [Bằng chứng thực nghiệm (Anthropic multi-agent research)](#6-bằng-chứng-thực-nghiệm)
8. [Phản biện quan trọng: đừng vội build multi-agent](#7-phản-biện-quan-trọng-đừng-vội-build-multi-agent-cognition)
9. [Áp dụng cho Claude Code harness của bạn](#8-áp-dụng-cho-claude-code-harness-của-bạn)
10. [Ví dụ cụ thể từ các blog](#9-ví-dụ-cụ-thể-từ-các-blog)
11. [Checklist: khi nào dùng graph, khi nào không](#10-checklist-khi-nào-dùng-graph-khi-nào-không)
12. [Caveats & câu hỏi mở](#caveats--câu-hỏi-mở)
13. [Nguồn tham khảo](#nguồn-tham-khảo)

---

## TL;DR

- **Graph engineering** = thiết kế *topology* (cấu trúc đồ thị) của một hệ multi-agent: những **node** nào tồn tại (agent, hàm deterministic, router, human checkpoint), những **transition/edge** nào được phép, và **state** chảy như thế nào — thay vì viết một chuỗi bước tuyến tính cố định. (confidence: medium — thuật ngữ còn mới, xem [caveats](#caveats--câu-hỏi-mở))
- Trục phân biệt nền tảng (Anthropic): **workflows** = LLM + tools điều phối qua *predefined code paths*; **agents** = LLM *tự định hướng động* quá trình và tool của chính nó. Graph engineering nằm ở lớp tổ chức nhiều loop agent lại với nhau. (confidence: high)
- **LangGraph** là hiện thân chuẩn: mô hình `State / Nodes / Edges`, `conditional edges` cho routing động, và **cycles** (khác biệt cốt lõi so với DAG) cho retry/self-correction. (confidence: high)
- Bằng chứng: hệ multi-agent của Anthropic vượt single-agent **+90.2%** trên eval research nội bộ, nhưng tốn **~15× token** và **kém hơn cho coding** (task cần shared context, ít parallelizable). (confidence: high)
- **Caveat then chốt cho coding harness**: Cognition (Devin) lập luận multi-agent song song *không đáng tin cho production* vì subagents quyết định từ giả định xung đột → khuyến nghị **single-threaded linear agent + continuous context**. Đây chính là vùng rủi ro nhất khi bạn muốn fan-out các plugin coding song song. (confidence: high)
- **Khuyến nghị lai cho bạn**: fan-out (graph) cho các subtask *read-only / research* (đọc code, tra cứu, QA phân tích); giữ *linear + shared context* cho các bước *ghi/sửa code* (backend, web, fix-bug). Xem [mục 8](#8-áp-dụng-cho-claude-code-harness-của-bạn).

---

## 1. Graph engineering là gì

**Định nghĩa (TrueFoundry, gần verbatim):** "Graph engineering *designs the topology* of a multi-agent system — which nodes exist (agents, deterministic functions, routers, human checkpoints), which transitions are permitted, and how runtime work graphs form and mutate." Tức là: bạn không lập trình *các bước*, bạn lập trình *hình dạng của đồ thị* mà công việc chảy qua. (confidence: medium)

Một cách phát biểu thực dụng hơn (aibuilderclub, "Graph Engineering with Claude Code"): graph engineering là **nối nhiều agent loop thành một hệ được điều phối** gồm *"parallel branches, verifiers, handoffs, and stop conditions"*. Trong khung này:

- **Node** = một agent/step làm *đúng một việc*.
- **Edge** = routing: node nào chạy tiếp theo (gồm branch, fan-out, fan-in, loop).
- **Shared state** = dữ liệu chảy dọc các edge.
- Một agent loop đơn lẻ chính là **đồ thị nhỏ nhất**: một node với một self-edge. (confidence: medium — nguồn blog vendor/practitioner)

> Ý niệm cốt lõi: workflow tuyến tính (chain/pipeline) là **đường thẳng cố định**; DAG là **đồ thị có hướng không chu trình**; còn agent graph cho phép **chu trình (cycles)** và **routing động do LLM quyết định** — đây là điểm làm nó khác về chất.

## 2. Phân biệt với các "engineering" khác và với workflow tuyến tính

**Phân biệt nền tảng của Anthropic** (bài *Building Effective Agents*, 12/2024) — verbatim:

> "Workflows are systems where LLMs and tools are orchestrated through *predefined code paths*. Agents, on the other hand, are systems where LLMs *dynamically direct their own processes* and tool usage, maintaining control over how they accomplish tasks."

(confidence: high — nguồn primary, được Simon Willison, Spring AI, Cobus Greyling corroborate. Một số người coi đây là *spectrum* hơn là nhị phân cứng.)

Đặt các "engineering" cạnh nhau:

| Lớp | Câu hỏi trọng tâm | Đơn vị làm việc |
|-----|-------------------|-----------------|
| **Prompt engineering** | Nói gì với model trong *một* lượt gọi? | 1 prompt |
| **Context engineering** | Đưa *thông tin/tool/bộ nhớ* nào vào context window? | 1 context |
| **Flow engineering** | Chuỗi bước LLM đi qua theo trình tự nào? | 1 chain/pipeline (thường tuyến tính hoặc DAG) |
| **Graph engineering** | *Topology* nào nối các agent loop: node nào, edge/transition nào được phép, state chảy ra sao, khi nào dừng? | 1 đồ thị nhiều node dị chất |

Graph engineering là lớp *bao ngoài*: mỗi node bên trong vẫn cần context engineering + prompt engineering tốt. (confidence: medium — bảng là tổng hợp/diễn giải, không phải một nguồn primary duy nhất; xem caveat 4)

## 3. Ba thành phần cốt lõi: State — Nodes — Edges

Theo docs LangGraph (primary), một agent graph gồm đúng 3 primitive: (confidence: high)

- **State** — "A shared data structure … typically defined using a shared state schema" (TypedDict/Pydantic). Đây là bộ nhớ chung mà mọi node đọc/ghi.
- **Nodes** — "Functions that encode the logic … receive current state, perform computation, return updated state." → **"nodes do the work"**.
- **Edges** — "Functions that determine which Node to execute next." → **"edges tell what to do next"**.

Blog LangChain phát biểu gọn (verbatim): *"each agent is a node in the graph, and their connections are represented as an edge … The control flow is managed by edges, and they communicate by adding to the graph's state."* (confidence: high)

**Cơ chế thực thi (execution model):** LangGraph dùng *message passing* lấy cảm hứng từ **Google Pregel** — chạy theo các *"discrete super-steps"*, node có message thì active, không có thì *vote-to-halt*; đồ thị kết thúc khi **mọi node inactive và không còn message in transit**. (confidence: high — docs primary + "From Pregel to LangGraph")

## 4. Các topology / pattern chính

### 4.1. Năm pattern của Anthropic → ánh xạ topology đồ thị

Anthropic định nghĩa 5 pattern *composable*; cộng đồng (LangChain) ánh xạ trực tiếp lên topology node/edge: (confidence: high cho 5 pattern; ánh xạ topology là diễn giải chính thống)

| Pattern (Anthropic) | Mô tả (verbatim rút gọn) | Topology đồ thị |
|---------------------|--------------------------|-----------------|
| **Prompt chaining** | "a sequence of steps" | Sequential (đường thẳng, có gate) |
| **Routing** | "classifies an input and directs it to a specialized followup task" | **Conditional edges** (branch) |
| **Parallelization** | sectioning + voting | **Fan-out → fan-in** |
| **Orchestrator-workers** | "a central LLM dynamically breaks down tasks, delegates them to worker LLMs, and synthesizes their results" | **Supervisor** |
| **Evaluator-optimizer** | "one LLM call generates … while another provides evaluation and feedback *in a loop*" | **Feedback cycle** |

Chi tiết 5 pattern này đã có trong [[agentic-workflow-patterns]]. Điểm mới ở đây: chúng là *các viên gạch topology* để lắp thành đồ thị lớn hơn.

### 4.2. Orchestrator-workers / Supervisor (fan-out)

"A central LLM dynamically breaks down tasks, delegates them to worker LLMs, and synthesizes their results." Đây là topology **supervisor**: một node điều phối, nhiều node worker, một node tổng hợp. Khác với parallelization ở chỗ **subtask được xác định động lúc runtime**, không định trước. (confidence: high)

### 4.3. Hierarchical agent teams (đồ thị lồng đồ thị)

LangGraph document 3 pattern multi-agent cụ thể: (confidence: high)

1. **Multi-agent collaboration** — shared scratchpad + router luật lệ (chạy tool / trả về khi thấy `FINAL ANSWER` / route sang agent khác).
2. **Agent supervisor** — supervisor route giữa các specialized agent, mỗi agent có scratchpad *riêng* (không chia sẻ).
3. **Hierarchical agent teams** — verbatim: *"the agents in the nodes are actually other langgraph objects themselves"* → mỗi node bản thân là một đồ thị con. Đây là chìa khoá để mô hình hoá "team of teams".

### 4.4. Map-reduce / fan-out qua `Send` API

Khi số lượng worker *không biết trước lúc compile* (ví dụ: spawn N subagent QA cho N file), LangGraph dùng **`Send`**: một conditional edge trả về *list* các `Send` object, mỗi cái target một node với một *state slice* riêng. (confidence: high)

```python
# conditional edge trả về danh sách Send — số edge tạo ra lúc runtime
def continue_to_jokes(state):
    return [Send("generate_joke", {"subject": s}) for s in state["subjects"]]

graph.add_conditional_edges("node_a", continue_to_jokes)
# docs: "The number of objects may be unknown ahead of time
#        (meaning the number of edges may not be known)."
```

### 4.5. Event-driven & Blackboard (họ pattern thay thế)

Confluent (Kafka) mô tả 4 pattern *event-driven* — agents *emit/listen event tự chủ* qua consumption bất đồng bộ thay vì request/response đồng bộ: (confidence: medium — single vendor blog, nhiều corroboration độc lập)

- **Orchestrator-worker** qua key-based partitioning trên Kafka topic + consumer group (decouple orchestrator khỏi việc quản lý kết nối trực tiếp).
- **Hierarchical** đệ quy: *"each non-leaf node is the orchestrator for its respective subtree"* → cây/đồ thị không hardcode.
- **Blackboard** — một *shared knowledge base* (Kafka topic) mà agents produce/consume; *"agents collaborate asynchronously without direct communication"*, hợp cho bài toán cần đóng góp tăng dần từ nhiều agent (giống kiến trúc AI cổ điển Hearsay-II).
- **Event-driven autonomous** — agents phản ứng theo sự kiện, không có orchestrator trung tâm.

## 5. Frameworks

### 5.1. LangGraph (chuẩn de-facto của tư duy graph)

- Mô hình `State / Nodes / Edges` (mục 3). (confidence: high)
- **Khác biệt cốt lõi so với chain/DAG**: hỗ trợ **cycles** — blog LangChain: một package mới *"to better enable creation of LLM workflows containing cycles, which are a critical component of most agent runtimes."* Cobus Greyling: LangChain chains là *DAG* (không có chu trình), *"LangGraph introduces the capability for cycles."* → cần cho retry, self-correction, iterative reasoning. (confidence: high)
- **Routing động**: `graph.add_conditional_edges(source, routing_function, path_map)` — giá trị trả về của routing_function chính là *tên node kế tiếp*. (confidence: high)

```python
# solid edge = deterministic; conditional edge = LLM/state quyết định nhánh
graph.add_conditional_edges(
    "node_a",
    routing_function,               # trả về "node_b" hoặc "node_c" (hoặc list)
    {True: "node_b", False: "node_c"},
)
```

### 5.2. `langgraph-supervisor` (Python) — supervisor/hierarchical đóng gói sẵn

README (primary), verbatim: *"A Python library for creating hierarchical multi-agent systems using LangGraph … specialized agents are coordinated by a central supervisor agent. The supervisor controls all communication flow and task delegation, making decisions about which agent to invoke based on the current context and task requirements."* (confidence: high)

- **Routing giữa các agent = tool-based handoff**: `create_handoff_tool`. Với `handoff_tool_prefix="delegate_to"` → sinh ra các tool tên `delegate_to_research_expert`, `delegate_to_math_expert`. → **handoff tools chính là các edge tới node plugin.**
- Caveat: LangChain gần đây khuyến nghị *tool-calling supervisor pattern* thay cho library này trong nhiều trường hợp (khuyến nghị usage, không phủ nhận mô tả). (confidence: high)

### 5.3. Google ADK, OpenAI Swarm / Agents SDK

Nghiên cứu này **chỉ có bằng chứng gián tiếp** (Swarm bị Cognition phê phán như ví dụ multi-agent song song rủi ro). Thiếu mô tả primary về mô hình graph/handoff/state của Google Agent Development Kit và OpenAI Agents SDK để so sánh trực tiếp với LangGraph. → xem [câu hỏi mở](#caveats--câu-hỏi-mở). (confidence: low — gap dữ liệu)

## 6. Bằng chứng thực nghiệm

Hệ **multi-agent research system** của Anthropic (bài engineering, 6/2025) — kiến trúc **orchestrator-worker**: (confidence: high, primary)

- *"a lead agent coordinates the process while delegating to specialized subagents that operate in parallel."*
- Mỗi subagent cần *"an objective, an output format, guidance on the tools and sources to use, and clear task boundaries."*
- Fan-out: *"The lead agent spins up **3-5 subagents in parallel** rather than serially … Subagents use **3+ tools in parallel** … These changes cut research time by **up to 90%** for complex queries."*

**Hiệu năng & giới hạn kinh tế** (rất quan trọng cho coding harness): (confidence: high)

- *"a multi-agent system with **Claude Opus 4 as the lead agent and Claude Sonnet 4 subagents** outperformed single-agent Claude Opus 4 by **90.2%** on our internal research eval."* — mạnh nhất cho **breadth-first query** (nhiều hướng độc lập).
- NHƯNG: *"most **coding tasks** involve fewer truly parallelizable tasks than research, and LLM agents are not yet great at coordinating and delegating."*
- Và: *"multi-agent systems use about **15× more tokens** than chats"* → chỉ đáng dùng khi *"the value of the task is high enough."*

> Số liệu +90.2% / cắt 90% thời gian / 15× token là **self-reported internal eval** (không benchmark độc lập, eval không được đặt tên). Giữ hedge khi trích.

## 7. Phản biện quan trọng: "đừng vội build multi-agent" (Cognition)

Đây là **caveat then chốt nhất** khi áp graph engineering vào **coding agents**. Cognition (Walden Yan, *"Don't Build Multi-Agents"*): (confidence: high, primary)

- *"libraries such as swarm by OpenAI and autogen by Microsoft actively push concepts which I believe to be the wrong way of building agents."*
- **Nguyên lý 2**: *"Actions carry implicit decisions, and conflicting decisions carry bad results."*
- Ví dụ **Flappy Bird**: subagent 1 dựng con chim, subagent 2 dựng background — *"Subagent 1 and subagent 2 cannot see what the other was doing and so their work ends up being inconsistent"* → chim và nền lệch phong cách.
- Khuyến nghị: *"the simplest way to follow the principles is to just use a **single-threaded linear agent**"* với *"context is continuous"*, và *"**Share context, and share full agent traces, not just individual messages.**"*

Quan trọng: Anthropic **không phủ nhận** failure mode này — họ chỉ giới hạn phạm vi multi-agent vào task *tự nhiên parallelizable* (như research), và thừa nhận phê phán của Cognition *"lands hardest exactly here"* (đúng chỗ coding). → Cả hai phe đồng ý: **coding tasks là nơi multi-agent song song rủi ro nhất** vì nhu cầu shared context cao. (confidence: high)

## 8. Áp dụng cho Claude Code harness của bạn

Bạn đang có các plugin: **backend, web, fix-bug, QA, design**. Cách nghĩ graph-engineering: mỗi plugin = một **node**; quyết định gọi plugin nào = **edge**; kết quả chia sẻ qua **state**. Nhưng đừng fan-out mù — hãy đọc kỹ [mục 7](#7-phản-biện-quan-trọng-đừng-vội-build-multi-agent-cognition).

### 8.1. Nguyên lý nền của Claude Code sub-agents

- Sub-agent Claude Code là **instance cô lập, context window độc lập**; *"only the subagent's final message returns to the parent"* — parent nhận *"only the conclusion, not the work that produced it"* (hidekazu-konishi). → **giảm token/nhiễu cho orchestrator**, nhưng cũng chính là nguồn gốc vấn đề "conflicting assumptions" của Cognition. (confidence: medium — nguồn blog practitioner)
- **Deterministic orchestration** (alexop.dev, verbatim): *"Code owns the order, the routing, and the stop condition. They run the same way every time, instead of depending on whether the model feels done."* (confidence: medium)
- **Inversion** (productcompass, Pawel Huryn): *"You write the control flow as plain code, and each individual step is delegated to a fresh subagent."* → **harness/loop = code; mỗi node = một fresh subagent.** (confidence: medium)

### 8.2. Kiến trúc lai đề xuất (an toàn cho coding)

```
                    ┌─────────────────────────┐
   user request →   │  ORCHESTRATOR (code)     │  ← control flow = deterministic
                    │  Claude Code main session │     (code owns order + stop cond.)
                    └───────────┬──────────────┘
                                │ routing (conditional edge)
             ┌──────────────────┼───────────────────────┐
             │ READ-ONLY / research subtree              │  WRITE subtree
             │  (an toàn fan-out song song)              │  (giữ LINEAR + shared context)
             ▼                  ▼               ▼         ▼
        [explore]         [QA-analyze]      [design]   [backend] → [web] → [fix-bug]
        (node)             (node)           (node)      tuần tự, cùng continuous context
             └──── fan-in → SHARED STATE (blackboard) ──┘        │
                                │                                 ▼
                                └────────► [VERIFIER node] ◄──── (evaluator-optimizer loop)
                                             │ pass? ──► done (stop condition)
                                             │ fail? ──┘ retry cycle
```

**Quy tắc rút ra:**

1. **Fan-out chỉ cho read-only / research** — đọc code, tra cứu, phân tích QA, khảo sát design. Đây là chỗ multi-agent thắng (breadth-first, ít dependency). Dùng pattern **orchestrator-workers** / `Send`.
2. **Giữ linear + continuous context cho các bước GHI code** (backend → web → fix-bug). Không để 2 subagent sửa code song song từ giả định xung đột (bài học Flappy Bird).
3. **Verifier / QA là node feedback loop** (evaluator-optimizer): pass → stop; fail → retry cycle. Đây chính là *cycle* mà DAG không có.
4. **Human-in-the-loop = node checkpoint** trước các bước không thể đảo (deploy, migration, xoá).
5. **Share full traces, không chỉ final message** khi các bước phụ thuộc nhau — dựng một *shared state / blackboard* để các node write đọc được quyết định của nhau.
6. **Stop condition do code quyết định**, không để model "cảm thấy xong".

### 8.3. Ánh xạ plugin → node/edge (cụ thể)

| Plugin của bạn | Vai trò node | Topology phù hợp | Song song? |
|----------------|--------------|------------------|-----------|
| explore/research | read-only worker | orchestrator-workers, `Send` fan-out | ✅ Có |
| **QA** (phân tích) | evaluator | evaluator-optimizer (feedback cycle) | ✅ (nhiều lens/voting) |
| **design** | worker (khảo sát/đề xuất) | fan-out cho *nhiều phương án*, rồi chọn | ✅ (đề xuất) / ❌ (khi commit 1 design) |
| **backend** | writer | sequential, shared context | ❌ Không fan-out ghi song song |
| **web** | writer | sequential sau backend (edge phụ thuộc) | ❌ |
| **fix-bug** | writer + verifier loop | cycle: fix → test → (fail) → fix | ❌ ghi song song |

> Liên hệ [[claude-code-fork]]: fork cho phép chạy song song *nhiều **cách tiếp cận*** (approaches) chứ không chỉ nhiều task — hữu ích ở subtree design/research (voting), tránh ở subtree ghi code.

## 9. Ví dụ cụ thể từ các blog

- **Anthropic — Multi-agent research system** (primary): lead agent Opus 4 + 3–5 subagent Sonnet 4 song song, mỗi subagent có objective/output-format/tool-guidance/task-boundary; +90.2% vs single-agent, cắt tới 90% thời gian, ~15× token. Nguồn: `anthropic.com/engineering/multi-agent-research-system`.
- **Anthropic — Building effective agents** (primary): 5 pattern (chaining/routing/parallelization/orchestrator-workers/evaluator-optimizer) + định nghĩa workflows vs agents. Nguồn: `anthropic.com/engineering/building-effective-agents`.
- **LangChain — LangGraph multi-agent workflows** (primary): 3 pattern collaboration/supervisor/hierarchical; hierarchical = "agents in the nodes are actually other langgraph objects themselves". Nguồn: `langchain.com/blog/langgraph-multi-agent-workflows`.
- **LangGraph docs — Graph API** (primary): `add_conditional_edges`, `Send` map-reduce, execution kiểu Pregel super-steps. Nguồn: `docs.langchain.com/oss/python/langgraph/graph-api`.
- **langgraph-supervisor-py** (primary): supervisor + `create_handoff_tool`, `handoff_tool_prefix="delegate_to"` → `delegate_to_research_expert`. Nguồn: `github.com/langchain-ai/langgraph-supervisor-py`.
- **Cognition — Don't Build Multi-Agents** (primary, phản biện): "Actions carry implicit decisions…"; ví dụ Flappy Bird; khuyến nghị single-threaded linear + share full traces. Nguồn: `cognition.com/blog/dont-build-multi-agents`.
- **Confluent — Event-driven multi-agent systems** (secondary): orchestrator-worker/hierarchical/blackboard/event-driven trên Kafka. Nguồn: `confluent.io/blog/event-driven-multi-agent-systems`.
- **TrueFoundry — Graph engineering enterprise guide** (blog, nguồn định nghĩa): "designs the topology of a multi-agent system…". Nguồn: `truefoundry.com/blog/graph-engineering-enterprise-guide`.
- **aibuilderclub — Graph Engineering with Claude Code** (blog, on-target nhất cho harness): subagent = node, quyết định spawn = edge; "connecting several agent loops … parallel branches, verifiers, handoffs, and stop conditions"; agent loop đơn = đồ thị nhỏ nhất. Nguồn: `aibuilderclub.com/blog/graph-engineering-with-claude-code`.
- **alexop.dev — Deterministic orchestration** (blog): "Code owns the order, the routing, and the stop condition." Nguồn: `alexop.dev/posts/claude-code-workflows-deterministic-orchestration`.
- **productcompass (Pawel Huryn) — Claude Code dynamic workflows** (blog): "You write the control flow as plain code, and each individual step is delegated to a fresh subagent." Nguồn: `productcompass.pm/p/claude-code-dynamic-workflows`.

## 10. Checklist: khi nào dùng graph, khi nào không

**Nên dùng graph / fan-out khi:**
- Task **breadth-first**, nhiều hướng *độc lập* (research, khảo sát, đọc nhiều file/nguồn).
- Cần **nhiều perspective** để tăng confidence (voting: nhiều agent review security/bug).
- Giá trị task đủ cao để *bù* chi phí ~15× token.
- Có **verification/retry cycle** rõ ràng (evaluator-optimizer).

**Nên giữ single-threaded linear khi:**
- Task **ghi/sửa code** có nhiều dependency, cần **shared context liên tục**.
- Các quyết định của bước sau phụ thuộc quyết định bước trước (Flappy Bird problem).
- Ngân sách token hạn chế / task giá trị thấp.
- Bạn chưa có cơ chế **share full traces** giữa các subagent.

**Luôn luôn:**
- Để **code** (harness) sở hữu order + routing + stop condition; đừng để model tự "cảm thấy xong".
- Chèn **human checkpoint** trước hành động không đảo ngược.
- Đo lường rồi mới tăng độ phức tạp topology (bắt đầu từ đồ thị nhỏ nhất: 1 loop).

## Caveats & câu hỏi mở

1. **Thuật ngữ "graph engineering" còn mới**: nguồn định nghĩa chính là *một* blog vendor (TrueFoundry); được nhiều nguồn corroborate về khái niệm nhưng **chưa có định nghĩa academic chuẩn hoá**. (confidence: medium)
2. **Pattern event-driven** đều từ *một* nguồn secondary (Confluent, vendor Kafka) — góc nhìn thiên về hạ tầng streaming.
3. **Chỉ số Anthropic** (+90.2%, cắt 90% thời gian, 15× token) là **self-reported internal eval**, không benchmark độc lập, eval không được đặt tên.
4. **Ánh xạ "5 pattern Anthropic → topology đồ thị"** là *diễn giải* — Anthropic KHÔNG dùng từ graph/node/edge; ánh xạ do LangChain/cộng đồng thực hiện.
5. **Time-sensitivity**: API LangGraph tiến hoá nhanh (`langgraph-supervisor` nay được khuyến nghị thay bằng tool-calling supervisor trong nhiều case); URL docs & signature có thể đổi.
6. **Tranh luận chưa ngã ngũ**: Anthropic (pro multi-agent cho task parallelizable) vs Cognition (anti multi-agent, pro single-threaded). Cả hai đồng ý **coding tasks là nơi rủi ro nhất**.

**Câu hỏi mở (chưa có nguồn reference cụ thể):**
- Kiến trúc reference *cụ thể* cho Claude Code sub-agents dưới dạng graph (chưa nguồn nào đưa ra sơ đồ chính thức — mục 8 là tổng hợp/đề xuất, không phải reference chuẩn).
- Mô hình graph/handoff/state của **Google ADK** và **OpenAI Agents SDK** (thiếu mô tả primary để so sánh trực tiếp với LangGraph).
- Ví dụ code cụ thể chèn **human-approval / verification-retry cycle** vào agent graph cho coding.
- Cơ chế graph cụ thể để **reconcile conflicting decisions** của subagents (shared state reducers, blackboard, full-trace passing) minh hoạ cho tình huống coding thực tế.

## Nguồn tham khảo

**Primary:**
- Anthropic — *Building Effective Agents* (Erik Schluntz, Barry Zhang, 12/2024): https://www.anthropic.com/engineering/building-effective-agents
- Anthropic — *How we built our multi-agent research system* (6/2025): https://www.anthropic.com/engineering/multi-agent-research-system
- LangChain — *LangGraph: Multi-Agent Workflows*: https://www.langchain.com/blog/langgraph-multi-agent-workflows
- LangGraph docs — *Graph API*: https://docs.langchain.com/oss/python/langgraph/graph-api
- `langgraph-supervisor-py` (README): https://github.com/langchain-ai/langgraph-supervisor-py
- Cognition (Walden Yan) — *Don't Build Multi-Agents*: https://cognition.com/blog/dont-build-multi-agents

**Secondary / blog:**
- Confluent (Sean Falconer) — *Event-Driven Multi-Agent Systems*: https://www.confluent.io/blog/event-driven-multi-agent-systems/
- TrueFoundry — *Graph Engineering (enterprise guide)*: https://www.truefoundry.com/blog/graph-engineering-enterprise-guide
- aibuilderclub (Shirley) — *Graph Engineering with Claude Code*: https://www.aibuilderclub.com/blog/graph-engineering-with-claude-code
- alexop.dev — *Claude Code workflows: deterministic orchestration*: https://alexop.dev/posts/claude-code-workflows-deterministic-orchestration/
- productcompass (Pawel Huryn) — *Claude Code dynamic workflows*: https://www.productcompass.pm/p/claude-code-dynamic-workflows
- hidekazu-konishi — *Claude Code subagents & orchestration guide*: https://hidekazu-konishi.com/entry/claude_code_subagents_and_orchestration_guide.html

---

> Phương pháp: tổng hợp bằng deep-research harness — 5 góc tìm kiếm → 22 nguồn fetch → 110 claim trích xuất → 25 claim verify (3-vote đối kháng, 25/25 confirmed, 0 bị bác) → synthesis 14 finding. Xem thêm [[agentic-workflow-patterns]], [[agentic-systems-taxonomy]], [[augmented-llm]], [[claude-code-fork]].
