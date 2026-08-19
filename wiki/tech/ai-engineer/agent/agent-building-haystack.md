---
status: current
updated: 2026-08
sources:
  - https://haystack.deepset.ai/
  - https://haystack.deepset.ai/blog/haystack-2-release
  - https://haystack.deepset.ai/blog/haystack-3-release
  - https://docs.haystack.deepset.ai/docs/pipelines
  - https://docs.haystack.deepset.ai/docs/agents
  - https://docs.haystack.deepset.ai/docs/serialization
  - https://docs.haystack.deepset.ai/docs/document-store
  - https://docs.haystack.deepset.ai/docs/hayhooks
  - https://github.com/deepset-ai/haystack
  - https://github.com/deepset-ai/hayhooks
  - https://haystack.deepset.ai/integrations
  - https://en.wikipedia.org/wiki/Deepset
roadmap: ai-engineer
stage: learning
---

# Haystack — framework LLM pipeline-first, production-oriented của deepset

**TL;DR**: **Haystack** (deepset, Berlin) là framework Python mã nguồn mở ra đời từ 2019 cho **search/extractive QA** thời BERT, được viết lại toàn diện thành 2.x (3/2024) quanh mô hình **component/pipeline** — đồ thị tường minh, có kiểu, serialize được sang YAML. Nó mạnh nhất ở **RAG/search service production** với văn hóa engineering-first, nhưng có ít mindshare hơn LangChain/LlamaIndex trong mảng agent.

## Bối cảnh & lịch sử

- deepset thành lập 6/2018 (Milos Rusic, Malte Pietsch, Timo Möller); **Haystack** phát hành mã nguồn mở 11/2019 — ban đầu là framework **neural search**: document retrieval + **extractive QA** trên **BERT**, tức ra đời trước ChatGPT khoảng 3 năm.
- Đây là một trong những codebase **lâu đời và ổn định nhất** trong không gian này: 2019, so với LangChain (10/2022) và LlamaIndex (11/2022).
- **Haystack 2.0** (stable 11/3/2024, beta từ 12/2023) là bản **viết lại hoàn toàn**: giả định 1.x (Node, pipeline acyclic) không hợp thời LLM; 2.x xây lại quanh component tái sử dụng, hỗ trợ **cyclic graph** (loop cho agentic routing), unified **Document Store** interface, structured logging, **OpenTelemetry** tracing. Package đổi từ `farm-haystack` (1.x, chỉ bảo trì) sang `haystack-ai` — lộ trình migration dài, có chủ đích.
- **Haystack 3.0** ra mắt qua "Launch Week" 20–24/7/2026: core nhẹ hơn, agentic first-class — agent **Skills**, **hooks** kiểm soát agent loop, run introspection, agent budgets, pre-built agents (deep research); 2.31 nhận security patch tới cuối 10/2026 (as of haystack.deepset.ai/blog/haystack-3-release, confidence: high).
- Không có paper học thuật giới thiệu framework; nguồn gốc nằm ở blog deepset + GitHub repo (confidence: medium).

## Mô hình component/pipeline

- Hai abstraction cốt lõi:
  - **Component**: class Python với input/output socket **có kiểu**, giao diện `run()` thống nhất; viết custom component là năng lực được document chính thức.
  - **Pipeline**: directed multigraph nối tường minh các socket qua `add_component()` + `connect()`; **kiểu được validate ngay lúc nối dây**, trước khi chạy.
- Pipeline hỗ trợ **branching** (routing file type sang converter khác nhau), **loop** có giới hạn vòng lặp (self-correction), và async (`run_async`, `run_async_generator`, `stream`).
- Serialize sang **YAML** qua `dumps()`/`dump()` và nạp lại bằng `loads()`/`load()`; deserialization có **allowlist bảo mật** (mặc định chỉ `haystack`, `haystack_integrations`, `builtins`; mở rộng qua env `HAYSTACK_DESERIALIZATION_ALLOWLIST`) — nền tảng cho pipeline khai báo, version-control được.
- Về tinh thần kiến trúc: đồ thị node/edge tường minh này **gần [[agent-building-langgraph]] hơn** là abstraction cao cấp `create_agent` của [[agent-building-langchain]] (nhận xét biên tập, confidence: medium).

### Ví dụ: RAG pipeline tối giản

```python
from haystack import Pipeline
from haystack.components.embedders import SentenceTransformersTextEmbedder
from haystack.components.retrievers.in_memory import InMemoryEmbeddingRetriever
from haystack.components.builders import ChatPromptBuilder
from haystack.components.generators.chat import OpenAIChatGenerator

pipe = Pipeline()
pipe.add_component("embedder", SentenceTransformersTextEmbedder())
pipe.add_component("retriever", InMemoryEmbeddingRetriever(document_store=store))
pipe.add_component("prompt", ChatPromptBuilder(template=template))
pipe.add_component("llm", OpenAIChatGenerator())

pipe.connect("embedder.embedding", "retriever.query_embedding")  # kiểu được check tại đây
pipe.connect("retriever.documents", "prompt.documents")
pipe.connect("prompt.prompt", "llm.messages")

pipe.dump(open("rag.yaml", "w"))  # serialize toàn pipeline sang YAML
```

Cùng một mô hình biểu diễn được cả "thang" độ phức tạp: 1 **Chat Generator** = gọi LLM trần; embedder → retriever → prompt → generator = RAG; pipeline nhiều nhánh + router = workflow; **Agent** component (hoặc cyclic pipeline) = agent.

## RAG: Document Store & tích hợp

- **DocumentStore** protocol chỉ yêu cầu 4 method: `count_documents`, `filter_documents`, `write_documents`, `delete_documents`; mỗi store thường đi kèm một **Retriever** tương ứng — tự viết store mới chỉ cần thỏa protocol.
- Backend: Pinecone, Weaviate, Qdrant, Elasticsearch, OpenSearch, MongoDB Atlas, Chroma, FAISS, pgvector, AstraDB, Supabase...; tổng cộng **~172 integrations** (model provider, evaluation như Ragas/DeepEval, monitoring, ranker...) (as of haystack.deepset.ai/integrations, confidence: high).
- Model provider: OpenAI, Azure, Google Vertex, **Anthropic** (`anthropic-haystack`: `AnthropicChatGenerator` hỗ trợ Claude, prompt caching, tool calling), Cohere, Mistral, Hugging Face, Ollama, Groq, LiteLLM — vendor-agnostic.

## Agent & tool (kể cả MCP)

- **Agent** là một component dựng sẵn chạy trọn **tool-calling loop**: gọi LLM → invoke tool → cập nhật state → lặp đến điều kiện dừng. Tham số chính: `chat_generator` (bắt buộc, phải hỗ trợ tool), `tools`, `system_prompt` (string hoặc Jinja2), `exit_conditions` (mặc định `["text"]` — dừng khi LLM trả lời không gọi tool), `state_schema` (state có kiểu chia sẻ giữa các tool), `streaming_callback`, `max_agent_steps` (mặc định 100).
- Vì Agent cũng là component, nó **nhúng thẳng vào pipeline** được — vòng lặp tự trị đặt bên trong một luồng định trước (predictability-first).
- Hỗ trợ human-in-the-loop duyệt tool call, multi-agent, multimodal.
- Hệ tool: `@tool` decorator / `Tool` (hàm Python), **ComponentTool** (bọc component), **PipelineTool** (bọc cả pipeline), **Toolset/SearchableToolset** (catalog lớn, tìm tool theo keyword), và **MCPTool/MCPToolset** — agent Haystack tiêu thụ **MCP server** bên ngoài, auto-load tool (lọc bằng `tool_names`).

## Deploy: Hayhooks & deepset platform

- **Hayhooks** (`deepset-ai/hayhooks`): deploy pipeline/agent thành **REST API** với boilerplate tối thiểu (`BasePipelineWrapper` + `hayhooks pipeline deploy-files`), gồm endpoint **OpenAI-compatible** chat (streaming, dùng được từ open-webui), và tự chạy như **MCP Server** expose mỗi pipeline thành MCP Tool; cũng hỗ trợ **A2A protocol**.
- Thương mại: deepset bán **Enterprise Support** và **deepset platform** (Studio thiết kế pipeline trực quan, access control, cloud/on-prem); khách hàng nêu tên gồm Airbus, NVIDIA, Accenture.
- Triển khai cloud-agnostic, Kubernetes-ready; pipeline YAML + typed interface + tracing tạo nên vị thế "engineering-first".

## So sánh thẳng thắn với LangChain / LlamaIndex

| Tiêu chí | Haystack | [[agent-building-langchain]] | [[agent-building-llamaindex]] |
|---|---|---|---|
| Ra đời | 11/2019 (lâu đời nhất) | 10/2022 | 11/2022 |
| GitHub stars (8/2026) | ~26.3k | ~144.6k | ~51.7k |
| Mô hình chính | Pipeline graph tường minh, typed, YAML | Ecosystem rộng; `create_agent` high-level (graph tường minh nằm ở LangGraph) | Data framework thiên index/ingestion, 150+ connector |
| Mạnh nhất | Search/RAG service production, môi trường regulated | Breadth: agent, tool, workflow đủ loại | Đường ngắn nhất documents → answers |
| Yếu hơn | Mindshare agent, ít template/ecosystem | API churn, nhiều tầng abstraction | Ít kiểm soát luồng chạy chi tiết |

- Số liệu mindshare: LlamaIndex có lượng PyPI download hàng tháng gấp ~10 lần Haystack (~5M vs ~394k) (as of zenml.io blog, confidence: medium) — Haystack là "retrieval/production specialist" chứ không phải lựa chọn mặc định khi tìm agent framework.
- Bù lại: codebase ổn định, ít breaking change kiểu ecosystem trẻ; phù hợp team muốn build **[[agent-architecture-rag-agent]]** chạy production từ ngày đầu.

## Liên hệ tới các phần khác

- [[ai-engineer-roadmap]] — vị trí trong lộ trình: nhóm "Building with frameworks".
- [[agent-building-langchain]], [[agent-building-langgraph]], [[agent-building-llamaindex]] — ba framework cùng lớp để so sánh trực tiếp.
- [[agent-architecture-rag-agent]] — Haystack là hiện thân "RAG agent" thuần production: retriever + document store + agent loop trong cùng một graph.

### Áp dụng với Claude Code

- **Claude làm bộ não trong Haystack**: integration chính thức `anthropic-haystack` cho phép dùng `AnthropicChatGenerator` (Claude + tool calling + prompt caching) làm `chat_generator` của Agent.
- **MCP hai chiều là điểm giao rõ nhất**: (1) Hayhooks expose pipeline/agent Haystack thành **MCP Tool**, nên Claude Code (MCP client) gọi thẳng một pipeline RAG production như một tool — docs Haystack nêu đích danh kịch bản "called from any MCP-compatible client like Claude Desktop"; (2) ngược lại, `MCPToolset` cho agent Haystack tiêu thụ MCP server bất kỳ.
- **Khác triết lý với Claude Code/Agent SDK**: Agent SDK đóng gói sẵn agent loop model-driven (built-in tools, hooks, subagents, permissions) — developer không vẽ graph; Haystack bắt nối tường minh từng component. Pattern kết hợp thực dụng: dùng Haystack cho tầng retrieval/RAG (Agent SDK không có sẵn retriever/vector store), deploy qua Hayhooks, rồi để Claude Code gọi qua MCP như một knowledge tool.

## Giới hạn / open questions

- Số liệu stars/downloads thay đổi nhanh; các con số mindshare ở trên là snapshot 8/2026, độ tin trung bình.
- So sánh "gần LangGraph hơn create_agent" là nhận xét biên tập từ docs, không phải claim chính thức của deepset.
- Haystack 3.0 (7/2026) còn rất mới: Skills/hooks/budgets của agent loop mới chưa được kiểm chứng thực tế trong note này; nội dung phần Agent chủ yếu phản ánh 2.x.
- Chưa nghiên cứu sâu: hiệu năng thực tế của Hayhooks ở tải lớn, chất lượng evaluation components (so với Ragas standalone), và trải nghiệm deepset platform bản thương mại.
- Vì sao mindshare thấp dù codebase tốt (marketing? Berlin vs SF? định vị enterprise?) — câu hỏi mở, chưa có nguồn định lượng.
