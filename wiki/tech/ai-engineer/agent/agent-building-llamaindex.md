---
status: current
updated: 2026-08
sources:
  - https://developers.llamaindex.ai/python/framework/
  - https://developers.llamaindex.ai/python/framework/understanding/rag/
  - https://developers.llamaindex.ai/python/framework/understanding/agent/
  - https://developers.llamaindex.ai/python/framework/understanding/agent/multi_agent/
  - https://developers.llamaindex.ai/python/framework/module_guides/deploying/agents/
  - https://developers.llamaindex.ai/python/framework/module_guides/loading/documents_and_nodes/
  - https://llamahub.ai/
  - https://en.wikipedia.org/wiki/LlamaIndex
  - https://www.llamaindex.ai/blog/llamaindex-is-more-than-a-rag-framework
  - https://www.llamaindex.ai/blog/llamaindex-v0-10-838e735948f8
  - https://github.com/run-llama/llama_index/issues/10747
  - https://www.latent.space/p/llamaindex
  - https://www.anthropic.com/research/building-effective-agents
  - https://claude.com/blog/building-agents-with-the-claude-agent-sdk
  - https://www.statsig.com/perspectives/llamaindex-vs-langchain-rag
  - https://blog.n8n.io/llamaindex-vs-langchain/
roadmap: ai-engineer
stage: learning
---

# LlamaIndex — framework LLM lấy dữ liệu làm trung tâm, mọc thêm tầng agent trên lõi RAG

**TL;DR**: LlamaIndex là framework giúp LLM *trả lời dựa trên dữ liệu riêng của bạn* (kỹ thuật **RAG** — Retrieval-Augmented Generation: tìm đoạn dữ liệu liên quan rồi đưa vào prompt; xem [[llm-rag-basics]] trước nếu khái niệm này còn mới). Nó đi ngược hướng với [[agent-building-langchain]]: LangChain xuất phát từ **chains/agents** (điều phối chuỗi bước xử lý — **orchestration**), còn LlamaIndex xuất phát từ data pipeline (ingestion → indexing → retrieval) rồi mới xây tầng agent lên trên. Chọn nó khi chất lượng retrieval là vấn đề cốt lõi; tránh nó khi bài toán chính là orchestration workflow phức tạp.

## Nguồn gốc: sinh ra từ dữ liệu, không phải từ agent

- Khởi đầu là **GPT Index**, side project của Jerry Liu, công bố trên GitHub tháng 11/2022; đổi tên thành **LlamaIndex** đầu 2023.
- Động cơ ban đầu thuần túy data-centric: GPT-3 chỉ có context 4.096 token, làm sao hỏi đáp trên dữ liệu riêng nằm ngoài training set? Giải pháp: xây **index** trên corpus để model *truy vấn* thay vì nhồi text thô vào context — từ đó có tagline lâu năm "a data framework for your LLM applications".
- Không có paper học thuật gốc (khác **ReAct**) — lineage của nó là repo `run-llama/llama_index`.
- Docs hiện tại tự định vị: "the leading framework for building LLM-powered agents **over your data**" — bài toán lõi là **context augmentation**: dữ liệu riêng "kẹt" trong PDF, slide deck, API, database cần được đưa tới LLM lúc inference.
- Quỹ đạo phát triển là ảnh ngược của LangChain: LangChain đi từ chains → thêm data tooling; LlamaIndex đi từ data pipeline → thêm agents.

## Lõi data pipeline: Documents/Nodes → Index → Query Engine

Docs chia RAG pipeline thành 5 giai đoạn: **Loading → Indexing → Storing → Querying → Evaluation**. Các khối chính:

- **Data connectors (Readers)**: ingest từ file, API, database thành Documents. **LlamaHub** là chợ tích hợp — data loaders, agent tools, Llama Packs — với khoảng 300+ package tích hợp version riêng (số vendor-reported, xem Giới hạn cuối bài).
- **Document**: container generic bọc mọi nguồn dữ liệu (PDF, API output, DB row) kèm text + metadata + relationships.
- **Node**: "đơn vị nguyên tử" — chunk của Document, sinh ra bởi **NodeParser** (vd. `SentenceSplitter`), thừa kế metadata cha và giữ link quan hệ giữa các node. Đây là phiên bản production-hóa của bước "cắt text thành chunk" thô sơ trong [[llm-rag-basics]].
- **Index**: cấu trúc hóa dữ liệu cho LLM; mặc định phổ biến nhất là **VectorStoreIndex** (embed vào vector store cho semantic search).
- Chuỗi truy vấn tách lớp, tùy biến được từng khâu:
  - **Retriever**: tìm các Node liên quan nhất với câu hỏi (thường bằng vector search).
  - **Node Postprocessor**: lọc/xếp hạng lại (rerank) kết quả vừa tìm được trước khi đưa cho LLM.
  - **Response Synthesizer**: ghép các Node đã chọn + câu hỏi thành prompt và gọi LLM sinh câu trả lời cuối.
- **Query Engine**: giao diện hỏi đáp ngôn ngữ tự nhiên end-to-end (hỗ trợ sub-question, multi-step, hybrid); **Chat Engine** thêm hội thoại multi-turn.

Sức hút lớn nhất là quickstart 5 dòng — cả một RAG pipeline thay cho ~100+ dòng tự viết (loader + chunker + embedder + vector store + prompt assembly):

```python
from llama_index.core import SimpleDirectoryReader, VectorStoreIndex

documents = SimpleDirectoryReader("data").load_data()
index = VectorStoreIndex.from_documents(documents)
query_engine = index.as_query_engine()
print(query_engine.query("Chính sách nghỉ phép của công ty là gì?"))
```

## Tầng agent: FunctionAgent, ReActAgent, AgentWorkflow

- Định nghĩa agent theo docs: phần mềm bán tự trị chạy bằng LLM, nhận task và thực thi chuỗi bước, mỗi bước chọn **tool** phù hợp.
- Ba class agent:
  - **FunctionAgent**: dùng native **function/tool calling** của provider — lựa chọn mặc định khi model hỗ trợ.
  - **ReActAgent**: vòng lặp reason+act bằng prompting, cho model không có tool calling.
  - **CodeActAgent**: thực thi tool bằng cách sinh code.
- Agent nhận `tools` + `llm` + system prompt, chạy **async-first** (`await agent.run(...)`); docs cảnh báo cần "capable models" — model nhỏ chạy tool loop kém tin cậy.
- **Điểm mấu chốt**: `QueryEngineTool` cho phép bọc *nguyên một query engine RAG* thành tool cho agent. Đây chính là pattern [[agent-architecture-rag-agent]] (agent tự quyết *khi nào* và *truy vấn gì*) được đóng gói sẵn — ghép hai nửa data + agent của framework là ra:

```python
from llama_index.core.tools import QueryEngineTool
from llama_index.core.agent.workflow import FunctionAgent

# query_engine = index.as_query_engine() từ quickstart ở trên
hr_tool = QueryEngineTool.from_defaults(
    query_engine=query_engine,
    name="hr_docs",
    description="Tra cứu chính sách nhân sự nội bộ",
)
agent = FunctionAgent(tools=[hr_tool], llm=llm,
                      system_prompt="Bạn là trợ lý HR.")
response = await agent.run("Tôi còn bao nhiêu ngày phép?")
```

- Multi-agent có 3 mức, docs xếp theo phổ convenience → control (càng xuống dưới càng tự kiểm soát nhiều, code nhiều):
  1. **AgentWorkflow**: orchestration hand-off out-of-the-box — một root agent nhận message, mỗi agent xử lý bằng tool của mình, chuyển giao qua `can_handoff_to=[...]`, chia sẻ state chung, lặp tới khi có câu trả lời cuối. *Chọn khi*: pipeline tuyến tính, vai trò rõ ràng — ví dụ chính chủ: research agent → writing agent → review agent sinh báo cáo.
  2. **Orchestrator**: agent cấp trên dùng các specialist agent như tools, tự chọn gọi ai tiếp. *Chọn khi*: thứ tự gọi không cố định, muốn LLM tự điều phối (vd. trợ lý support lúc cần tra billing, lúc cần tra kỹ thuật).
  3. **Custom Planner**: tự viết planning prompt (XML/JSON/YAML) và thực thi imperative qua `Workflow` + `@step`. *Chọn khi*: cần kiểm soát chặt từng bước, retry/branching riêng — chấp nhận viết nhiều code nhất.

## Khi nào chọn LlamaIndex vs LangChain

| Tình huống | Nên dùng |
|---|---|
| Knowledge base, document Q&A, tra cứu tài liệu pháp lý/kỹ thuật — retrieval quality là bài toán chính | **LlamaIndex** |
| Workflow orchestration phức tạp: conditional logic, nhiều API, state machine, human-in-the-loop | **LangChain/[[agent-building-langgraph]]** |
| Cần cả hai | Kết hợp: LlamaIndex làm retrieval layer bên trong app orchestrate bằng LangGraph — pattern production khá phổ biến |

- Consensus 2025 của giới practitioner (qua nhiều bài so sánh third-party) nhất quán theo bảng trên — nhưng các con số benchmark kiểu "40% faster retrieval" trong blog vendor không nên trích làm fact.
- LlamaIndex *có* event-driven **Workflows** riêng, nhưng với app nặng orchestration thì LangGraph-style vẫn là lựa chọn phổ biến hơn; chính docs LlamaIndex cũng định vị AgentWorkflow là "convenience".

## Trade-offs thẳng thắn

- **Abstraction chồng chéo, dễ rối**: cả LlamaIndex lẫn LangChain giờ đều có loaders, vector-store wrappers, agents, workflow — ranh giới lịch sử "LlamaIndex = data, LangChain = chains" đã nhòe. Ngay issue tracker của dự án có người hỏi khác biệt giữa `VectorStoreIndex` / `StorageContext` / `VectorStore` (issue #15475) — bằng chứng abstraction gây bối rối cho chính user của nó.
- **API/docs churn nặng, có thể kiểm chứng** — hệ quả thực tế: tutorial và câu trả lời StackOverflow cũ mục rất nhanh:
  - Rename toàn cục: package `gpt-index` → `llama-index`.
  - Bản **v0.10** (02/2024) là breaking refactor lớn — tách hàng trăm integration ra package PyPI riêng quanh `llama-index-core`, deprecate `ServiceContext`, phải ship hẳn CLI `llamaindex-cli upgrade` và package `llama-index-legacy` để migrate (as of release blog + issue #10747, confidence: high).
  - Tầng agent bị viết lại: API `OpenAIAgent`/`AgentRunner` cũ → `FunctionAgent`/`AgentWorkflow` hiện tại.
  - Domain docs cũng đổi: `docs.llamaindex.ai` 301 sang `developers.llamaindex.ai`.
- **Framework lock-in**: cùng nỗi lo với LangChain. Anthropic trong "Building Effective Agents" cảnh báo các framework kiểu này "tạo thêm các lớp abstraction che khuất prompt và response thực, khó debug", và khuyên bắt đầu bằng LLM API trực tiếp, giảm abstraction khi lên production.
- **Trọng tâm thương mại đã dịch chuyển**: homepage 2026 dẫn đầu bằng **LlamaParse**/**LlamaCloud** (document OCR/parsing cho agentic stack, claim 1B+ documents processed — số liệu vendor tự báo); blog chính chủ thừa nhận "no longer just a RAG framework" và industry "đã qua giai đoạn cần nhiều abstraction giữa bạn và model". OSS framework ngày càng funnel về managed services — thêm một chiều lock-in cần cân nhắc.

## Liên hệ tới các phần khác

- [[llm-rag-basics]] — LlamaIndex là phiên bản công nghiệp hóa của đúng các primitive này: chunking → Nodes, embedding + vector search → VectorStoreIndex, prompt assembly → Response Synthesizer.
- [[agent-architecture-rag-agent]] — pattern "agent quyết định khi nào retrieve" chính là `QueryEngineTool` + FunctionAgent; LlamaIndex là RAG-agent toolkit đóng gói sẵn.
- [[agent-building-langchain]] / [[agent-building-langgraph]] — framework "anh em" đi từ hướng ngược lại (chains/orchestration-first); thực tế nhiều team dùng cả hai.
- [[ai-engineer-roadmap]] — mục "Building with frameworks".

### Áp dụng với Claude Code

- Claude Code (và Claude Agent SDK) **cố tình không dùng** mô hình embedding-RAG kiểu LlamaIndex: nó dùng **agentic search** — agent tự chạy `grep`/`glob`/đọc file để kéo đúng context vào, coi cấu trúc thư mục là một dạng context engineering. Blog chính thức mô tả semantic search là "nhanh hơn nhưng kém chính xác, khó bảo trì, kém minh bạch hơn" và khuyên "bắt đầu bằng agentic search, chỉ thêm semantic search khi cần tốc độ".
- Vậy trong hệ sinh thái Claude Code, "tương đương" một LlamaIndex query engine là: (a) một **MCP server** expose tool search/retrieval trên corpus, hoặc (b) agentic file search thuần. Pipeline kiểu LlamaIndex vẫn đáng dùng khi corpus rất lớn, không có dạng file (PDF scan, DB, SaaS API), hoặc nhạy latency — trùng đúng caveat của chính blog SDK.
- Bản thân LlamaIndex-the-framework không được expose qua CLI; nếu muốn dùng, bạn viết app Python riêng hoặc bọc nó thành MCP tool cho Claude Code gọi.

## Giới hạn / open questions

- Con số ~300+ integrations của LlamaHub và các figure thương mại (1B+ documents, 25M+ downloads/tháng) đều là vendor-reported, chưa kiểm chứng độc lập.
- Chưa benchmark trực tiếp chất lượng retrieval LlamaIndex vs hand-rolled RAG vs LangChain trên cùng corpus — các con số so sánh trên blog third-party không đáng tin để trích dẫn.
- Event-driven **Workflows** (`@step`) của LlamaIndex chưa được tìm hiểu sâu — so với LangGraph về khả năng biểu diễn state machine, checkpointing, human-in-the-loop thế nào còn bỏ ngỏ.
- TypeScript port (LlamaIndex.TS) tồn tại nhưng mức độ ngang bằng feature với bản Python chưa được khảo sát.
- CodeActAgent (sinh code để thực thi tool) chưa rõ độ an toàn/sandboxing trong production.
