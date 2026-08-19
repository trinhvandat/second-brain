---
status: current
updated: 2026-08
sources:
  - https://airflow.apache.org/docs/apache-airflow/stable/core-concepts/dags.html
  - https://airflow.apache.org/docs/apache-airflow/2.5.2/core-concepts/dags.html
  - https://www.astronomer.io/docs/learn/dags
  - https://docs.langchain.com/oss/python/langgraph/graph-api
  - https://docs.langchain.com/oss/python/langgraph/workflows-agents
  - https://en.wikipedia.org/wiki/Directed_acyclic_graph
  - https://arxiv.org/pdf/2510.24663
  - https://interviewkickstart.com/ai-glossary/dag-based-agent-workflow
  - https://medium.com/@arpitnath42/a-practical-perspective-on-orchestrating-ai-agent-systems-with-dags-c9264bf38884
  - https://theaiengineer.substack.com/p/the-4-single-agent-patterns
  - https://www.promptlayer.com/glossary/plan-and-execute-agents/
  - https://www.anthropic.com/engineering/multi-agent-research-system
  - https://claude.com/blog/building-multi-agent-systems-when-and-how-to-use-them
  - https://platform.claude.com/docs/en/managed-agents/multiagent-orchestration
roadmap: ai-engineer
stage: learning
---

# DAG Agents — agent workflow mô hình hoá thành đồ thị có hướng không chu trình, cố định trước khi chạy

TL;DR: DAG (Directed Acyclic Graph) agent biểu diễn workflow bằng một đồ thị **cố định/tính toán trước (precomputed)**: node = task, edge = dependency, không có chu trình (cycle) nên workflow luôn kết thúc; các nhánh độc lập chạy **song song (parallel)**, các nhánh phụ thuộc chờ nhau theo thứ tự — khác hẳn ReAct (vòng lặp mở, không biết trước số bước) hay Planner-Executor (kế hoạch tuyến tính, có thể replan động).

## Ý tưởng cốt lõi

- **Directed** — mỗi edge có chiều: task A → task B nghĩa là B phải chờ A xong.
- **Acyclic** — không được có chu trình quay ngược; nếu có, workflow sẽ không bao giờ kết thúc (giống deadlock). Đây là ràng buộc bắt buộc, không phải tuỳ chọn.
- **Graph** — tập hợp task (node) + dependency (edge) tạo thành cấu trúc, không phải danh sách phẳng tuần tự.
- Điểm khác biệt cốt lõi so với các kiến trúc agent khác trong roadmap này: **đồ thị được xây xong trước khi thực thi bắt đầu** (định nghĩa bằng code/config trước, chạy sau), không phải do model tự quyết định từng bước một trong lúc chạy.

## Vì sao cần "acyclic" (không loop)

- Cycle trong đồ thị dependency đồng nghĩa với việc task A chờ task B, mà B lại chờ A → không có thứ tự hợp lệ nào để bắt đầu, workflow treo vô hạn.
- Cơ chế lập lịch dựa trên **topological sort** — thuật toán sắp xếp các node theo thứ tự sao cho mọi dependency được chạy trước task phụ thuộc nó (ví dụ **Kahn's algorithm**: lặp lại việc lấy ra node nào không còn dependency chưa xong, đánh dấu xong, rồi lặp tiếp) — chỉ khả thi khi đồ thị acyclic.
- Nhờ ràng buộc này, DAG scheduler luôn suy ra được: (1) thứ tự chạy hợp lệ, (2) tập task nào độc lập nên chạy song song được ngay.

## Ví dụ cụ thể: Apache Airflow

Airflow là công cụ phổ biến nhất gắn liền với khái niệm DAG trong data engineering — DAG "encapsulates everything needed to execute a workflow".

- **Task** = đơn vị công việc chạy trên worker.
- Dependency khai báo bằng operator `>>` / `<<`, hoặc `set_upstream()` / `set_downstream()` / `chain()`.
- Task không có dependency lẫn nhau (cùng chờ chung một upstream đã xong) có thể chạy **song song**; DAG Run của cùng một DAG cũng chạy song song được, việc thực thi cụ thể do một thành phần riêng gọi là Executor đảm nhiệm.
- DAG còn đóng gói cả lịch chạy (schedule), retry logic, timeout, callback — tức là bundle sẵn các mối quan tâm vận hành (operational concerns) mà một vòng lặp agent tự viết tay thường thiếu.

Ví dụ khai báo DAG tối thiểu bằng Airflow (chỉ minh hoạ cú pháp, không phải bản đầy đủ chạy được):

```python
from airflow import DAG
from airflow.operators.python import PythonOperator

with DAG(dag_id="content_pipeline", schedule="@daily") as dag:
    extract_a = PythonOperator(task_id="extract_source_a", python_callable=extract_a_fn)
    extract_b = PythonOperator(task_id="extract_source_b", python_callable=extract_b_fn)
    merge = PythonOperator(task_id="merge_and_dedupe", python_callable=merge_fn)
    summarize = PythonOperator(task_id="summarize", python_callable=summarize_fn)

    [extract_a, extract_b] >> merge >> summarize  # fan-in rồi chạy tiếp
```

Cùng pipeline đó dưới dạng đồ thị (fan-out → fan-in):

```
extract_source_A ─┐
extract_source_B ─┼─→ merge_and_dedupe ─→ summarize ─→ publish
extract_source_C ─┘
```

- Ba task `extract_source_*` không phụ thuộc nhau → chạy song song.
- `merge_and_dedupe` chờ cả ba extract xong mới chạy (fan-in).
- `summarize` → `publish` chạy tuần tự vì có dependency trực tiếp.
- Toàn bộ cấu trúc này được định nghĩa **trước khi** bất kỳ task nào chạy — khác với agent loop, nơi bước tiếp theo chỉ được quyết định sau khi có kết quả của bước hiện tại.

## Nguồn gốc khái niệm (ngắn gọn)

- DAG là cấu trúc graph-theory có từ trước (ứng dụng lập lịch sớm nhất là **PERT**, 1958), không có "paper gốc" riêng cho agent workflow.
- Apache Airflow (bắt nguồn từ Airbnb, ~2014-2015) là công cụ phổ biến mô hình DAG cho data/workflow pipeline nhất; cộng đồng AI agent (LangGraph, các framework DAG-agent tự viết) sau này mượn lại ẩn dụ này cho workflow agent tĩnh, tính toán trước.

## So sánh với ReAct và Planner-Executor

| Kiến trúc | Kế hoạch có trước khi chạy? | Có loop/cycle? | Song song được? |
|---|---|---|---|
| [[agent-architecture-react]] | Không — quyết định từng bước một (Thought → Act → Observe) | Có, lặp tới khi model tự dừng | Không — tuần tự nghiêm ngặt, mỗi bước phụ thuộc observation ngay trước |
| [[agent-architecture-planner-executor]] | Có, nhưng thường là danh sách bước tuyến tính; executor có thể yêu cầu replan khi gặp lỗi | Có thể lặp lại vòng plan → execute → replan | Hạn chế — plan thường phẳng (flat list), ít khai báo song song tường minh |
| DAG Agent | Có, là một **đồ thị** (không chỉ danh sách) tính toán trước khi chạy | Không — acyclic là bắt buộc | Có — nhánh độc lập chạy song song theo cấu trúc đồ thị |

- ReAct không parallelize được vì mỗi Action phụ thuộc Observation ngay trước nó — không có khái niệm "hai action độc lập".
- Planner-Executor mở rộng lên một bước: có kế hoạch trước, nhưng plan thường là chuỗi (sequence) chứ chưa phải đồ thị nhánh song song; DAG agent mở rộng tiếp Planner-Executor bằng cách biến plan thành graph tường minh với fan-out/fan-in.
- Trade-off: DAG cho **predictability, dễ debug** (input/output từng node đều trace được) và parallelize "miễn phí", nhưng đánh đổi lại là mất khả năng thích nghi khi số bước/thứ tự không biết trước — đúng lúc đó ReAct/Planner-Executor mới cần thiết.

## Khi nào nên dùng DAG agent

- Workflow có **hình dạng biết trước**: data pipeline/ETL, sinh nội dung nhiều bước (research nhiều nguồn → tổng hợp → viết), report định kỳ.
- Cần **predictable execution**: audit được, retry per-node, monitoring rõ ràng — quan trọng trong production hơn là khả năng "tự do khám phá" của loop mở.
- Pattern triển khai phổ biến: một Coordinator parse DAG, theo dõi trạng thái từng task, quyết định task nào "sẵn sàng chạy" (ready); các sub-agent chuyên biệt (CollectAgent, ExtractAgent, SummariseAgent...) thực thi từng node — Coordinator ở đây không tự sinh graph mới giữa chừng, chỉ điều phối graph đã có sẵn (as of medium.com/@arpitnath42, confidence: low — nguồn thứ cấp, chưa verify sâu).
- Nghiên cứu học thuật OrchDAG đề xuất xây "tool execution DAG" trước như blueprint để chạy tool tuần tự/song song qua nhiều lượt hội thoại, có replanning dựa trên kết quả — một ví dụ cụ thể về DAG-structured tool orchestration khác với ReAct loop thuần (as of arxiv.org/pdf/2510.24663, confidence: medium).

## LangGraph: DAG hay không chỉ DAG?

- LangGraph mô hình hoá workflow bằng **State + Nodes + Edges**: node là hàm nhận state, trả về state cập nhật; edge (kể cả conditional edge) quyết định node kế tiếp chạy.
- Graph phải được `.compile()` trước khi chạy — bước này validate cấu trúc và cấu hình runtime (vd. checkpointer).

Ví dụ tối thiểu: 2 node nối bằng 1 edge, dùng đúng như một DAG (không có cạnh quay ngược):

```python
from langgraph.graph import StateGraph, START, END

graph = StateGraph(MyState)
graph.add_node("extract", extract_fn)
graph.add_node("summarize", summarize_fn)
graph.add_edge(START, "extract")
graph.add_edge("extract", "summarize")
graph.add_edge("summarize", END)

app = graph.compile()
app.invoke({"input": "..."})
```

- Khác với Airflow, LangGraph **hỗ trợ cycle tường minh** — tài liệu chính thức nói rõ "by composing Nodes and Edges, you can create complex, looping workflows" — nghĩa là LangGraph là **superset** của DAG execution: viết được cả pure-DAG workflow lẫn vòng lặp kiểu ReAct trong cùng framework.
- Nói cách khác: một graph LangGraph tuân thủ đúng nghĩa "DAG" chỉ khi người viết cố tình không thêm cạnh quay ngược — bản thân framework không ép acyclic như Airflow.

## Liên hệ tới các phần khác

- Xem [[agent-architecture-react]] để đối chiếu với mô hình loop mở, không precompute.
- Xem [[agent-architecture-planner-executor]] để đối chiếu với mô hình plan tuyến tính có thể replan động.
- Xem [[agent-loop]] cho khung perceive → reason/plan → act → observe chung mà cả ba kiến trúc trên đều là biến thể cụ thể hoá.
- Xem [[ai-engineer-roadmap]] cho vị trí của DAG Agents trong lộ trình tổng thể.

### Áp dụng với Claude Code

**Không áp dụng theo đúng nghĩa DAG cố định — kiến trúc orchestration của Claude Code là dynamic, không phải precomputed graph.**

- Claude Code (qua Claude Agent SDK) dùng mô hình **hub-and-spoke**: orchestrator (session chính) spawn subagent qua Task tool, mỗi subagent có context window/working directory/tool access riêng, không giao tiếp trực tiếp với nhau, chỉ báo kết quả về orchestrator.
- Tập subagent nào được spawn, spawn bao nhiêu, và có spawn thêm hay không đều do orchestrator **quyết định tại runtime**, không phải một đồ thị task/dependency được định nghĩa sẵn trước khi chạy — gần với mô hình orchestrator-worker adaptive loop hơn là DAG tĩnh.
- Bằng chứng tương tự từ hệ thống liên quan: Claude Research (multi-agent research system của Anthropic) — lead agent phân tích query, quyết định số lượng subagent (thường 3-5) và tool phù hợp bằng extended thinking, sau đó **tổng hợp kết quả rồi quyết định có cần research thêm hay không** — một vòng lặp thích nghi (iterative, adaptive), không phải graph cố định trước; bài viết gốc của Anthropic không dùng thuật ngữ DAG.
- **Agent Teams** (thử nghiệm): nhiều agent chia sẻ chung một task list và có thể nhắn tin trực tiếp cho nhau.
- **Fleet mode**: orchestrator spawn hàng chục-hàng trăm subagent trong cùng một session.
- Cả hai vẫn do orchestrator quyết định **động tại runtime**, không phải một DAG được biên dịch trước (as of WebSearch aggregation, confidence: low — chưa xác nhận qua tài liệu chính thức).
- **Tóm lại**: Claude Code đạt được lợi ích "chạy song song việc độc lập" giống DAG (nhiều subagent chạy đồng thời), nhưng không có thuộc tính "đồ thị cố định trước khi chạy" định nghĩa nên DAG agent thực sự — nếu muốn workflow dạng DAG thực trong hệ sinh thái Claude, công cụ phù hợp hơn là LangGraph (viết graph acyclic tường minh) hoặc kết hợp Airflow gọi LLM step như một task trong DAG, chứ không phải Claude Code CLI tự thân.
- **Quy tắc quyết định thực dụng**: đang làm việc trong Claude Code và các bước phụ thuộc lẫn nhau theo kiểu cố định (task B luôn cần output của task A, không đổi giữa các lần chạy) → đừng cố tự tay dựng DAG trong session — viết một script LangGraph (hoặc Airflow nếu cần schedule/retry cấp production) rồi gọi nó như một tool riêng; chỉ nên dựa vào Task tool/subagent của Claude Code khi thứ tự/tập subagent cần **quyết định linh hoạt tại runtime**, không biết trước.

## Giới hạn / open questions

- Chưa có ví dụ production case study nào (ngoài các bài blog/medium confidence thấp) mô tả chi tiết một DAG-agent framework hoàn chỉnh đang chạy thật trong công ty cụ thể — phần "Coordinator + sub-agent theo node" trong note này dựa trên nguồn tổng hợp chưa verify sâu.
- Chưa rõ ranh giới thực tế giữa "DAG agent" và "Plan-and-Execute có song song hoá" trong các framework production hiện nay — nhiều nơi dùng lẫn hai thuật ngữ.
- Chưa đào sâu OrchDAG (arxiv 2510.24663) ở mức chi tiết thuật toán/kết quả benchmark, chỉ mới nêu như một ví dụ nghiên cứu tồn tại.
- Câu hỏi mở: liệu Claude Agent SDK có roadmap hỗ trợ định nghĩa graph/dependency tường minh (giống LangGraph) trong tương lai hay không — chưa tìm được nguồn chính thức xác nhận.
