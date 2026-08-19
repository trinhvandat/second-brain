---
status: current
updated: 2026-08
sources:
  - https://aws.amazon.com/what-is/retrieval-augmented-generation/
  - https://arxiv.org/abs/2310.11511
  - https://arxiv.org/pdf/2210.03629
  - https://arxiv.org/abs/2501.09136
  - https://docs.langchain.com/oss/python/langchain/retrieval
  - https://docs.langchain.com/oss/python/langgraph/agentic-rag
  - https://developer.nvidia.com/blog/traditional-rag-vs-agentic-rag-why-ai-agents-need-dynamic-knowledge-to-get-smarter/
  - https://www.buildmvpfast.com/blog/rag-architecture-patterns-naive-advanced-agentic-2026
  - https://www.digitalapplied.com/blog/agentic-rag-patterns-multi-step-reasoning-guide
  - https://www.uber.com/en-IN/blog/enhanced-agentic-rag/
  - https://www.zenml.io/llmops-database/enhanced-agentic-rag-for-internal-on-call-support-copilot
  - https://arxiv.org/abs/2603.07379
  - https://dust.tt/blog/rag-use-cases-real-business-problems
  - https://weaviate.io/blog/what-is-agentic-rag
  - https://vadim.blog/claude-code-no-indexing/
  - https://www.anthropic.com/engineering/effective-context-engineering-for-ai-agents
  - https://www.anthropic.com/engineering/multi-agent-research-system
  - https://support.claude.com/en/articles/11473015-retrieval-augmented-generation-rag-for-projects
  - https://simonwillison.net/2025/Nov/4/code-execution-with-mcp/
roadmap: ai-engineer
stage: learning
---

# RAG Agent — retrieval như một tool trong agent loop, không phải một bước cố định

**TL;DR**: RAG Agent (hay "agentic RAG") biến retrieval từ một bước pipeline cố định thành **một tool mà model tự quyết định khi nào gọi, gọi lại bao nhiêu lần, và kết hợp với tool nào khác** — khác với naive/classic RAG vốn luôn retrieve-rồi-generate một lượt duy nhất, không có suy luận hay điều chỉnh giữa chừng.

## 1. Naive RAG vs RAG Agent — điểm khác biệt cốt lõi

- **Naive/classic RAG**: pipeline tuyến tính cố định — query → embed → top-k retrieve → generate. Không có bước biến đổi query, không đánh giá chất lượng kết quả, không fallback nếu retrieval kém. Đây cũng là mô hình mà bài "What is RAG?" của AWS mô tả: tạo embedding → retrieve → augment prompt → generate, không hề nhắc tới agentic hay retrieval lặp lại.
- **RAG Agent / Agentic RAG**: retrieval trở thành **một control loop** — LLM (đóng vai agent) tự quyết định: có cần retrieve không, retrieve cái gì, kết quả đã đủ tốt chưa, và nếu chưa thì reformulate query rồi retrieve lại. Agent có thể bỏ qua retrieval hoàn toàn nếu câu hỏi không cần tra cứu, hoặc gọi nhiều lần nếu câu hỏi phức tạp (multi-hop).
- Nói cách khác: naive RAG trả lời câu hỏi "*retrieve cái gì?*"; RAG Agent trả lời cả 3 câu hỏi "*có nên retrieve không? retrieve cái gì? khi nào dừng?*".
- So sánh với 3 baseline liền kề để định vị rõ RAG Agent nằm ở đâu:
  - **LLM thuần**: trả lời hoàn toàn từ parametric knowledge (kiến thức đã học trong lúc train), không có grounding ngoài.
  - **Workflow tất định (deterministic)**: chuỗi bước cố định không rẽ nhánh runtime (vd: luôn retrieve → luôn summarize).
  - **Naive RAG**: một bước retrieve cố định chèn vào giữa.
  - **RAG Agent**: retrieval là 1 tool trong agent loop (xem [[agent-loop]]), có thể kết hợp với web search, calculator, v.v., và lặp lại dựa trên tự đánh giá kết quả trung gian.

## 2. Gốc học thuật

- **ReAct** (Yao et al., ICLR 2023) là nền móng chung cho pattern "agent loop có tool" mà RAG Agent áp dụng riêng cho retrieval: model xen kẽ **Thought** (suy luận) và **Action** (gọi tool, kể cả gọi API tra cứu Wikipedia), cập nhật kế hoạch dựa trên **Observation** nhận về — xem chi tiết ở [[agent-architecture-react]].
- **Self-RAG** (Asai et al., ICLR 2024 oral) là paper nền tảng riêng cho *agentic retrieval*: model được huấn luyện để sinh ra "reflection tokens" đặc biệt, tự quyết định on-demand có cần retrieve hay không, có thể retrieve nhiều lần hoặc bỏ qua hoàn toàn, đồng thời tự phê bình (critique) cả đoạn văn bản retrieve được lẫn câu trả lời mình sinh ra — điểm khác biệt tường minh so với RAG chuẩn vốn luôn retrieve một số lượng passage cố định bất kể câu hỏi (arxiv.org/abs/2310.11511, confidence: high).
- **"Agentic Retrieval-Augmented Generation: A Survey"** (Singh et al., arXiv 2501.09136, Jan 2025) tổng hợp định nghĩa: Agentic RAG là việc nhúng autonomous agent (reflection, planning, tool use, multi-agent collaboration) vào pipeline RAG để quản lý động chiến lược retrieval, tinh chỉnh context lặp lại, và thích ứng workflow — trái ngược với RAG truyền thống vốn cố định, tuần tự, không thích ứng. Bài đề xuất taxonomy theo agent cardinality (single vs multi-agent) và control structure (hierarchical, corrective, adaptive, graph-based).
- **"SoK: Agentic Retrieval-Augmented Generation"** (arXiv 2603.07379) hình thức hoá vòng lặp retrieval-generation như một finite-horizon **POMDP** (partially observable Markov decision process). Nói đơn giản: ở mỗi bước, agent chỉ thấy một phần thông tin (kết quả retrieve hiện tại) và phải quyết định "dừng ở đây hay retrieve thêm" mà không có cách nào chắc chắn tuyệt đối là đã đủ — đây chính là lý do RAG Agent cần một tiêu chí dừng (stopping criteria) rõ ràng, thay vì chạy đúng 1 lượt cố định như naive RAG.

## 3. Cách các framework hiện thực hoá

- **LangChain**: phân biệt tường minh "2-step RAG" (classic: luôn retrieve rồi generate, dễ đoán, hợp FAQ) vs. Agentic RAG (agent tự lý luận từng bước, quyết định khi nào và cách nào retrieve). Điều kiện duy nhất để có hành vi agentic là gắn cho agent một hoặc nhiều tool truy vấn kiến thức ngoài (vd `create_retriever_tool()`) — agent sẽ tự đánh giá có cần gọi không, gọi có điều kiện, và lặp lại nếu lần retrieve đầu chưa đủ.
- **LangGraph agentic-RAG pattern**: retrieval không tự động chạy — chỉ chạy khi model chọn gọi nó như một tool. Sau khi nhận document, agent đánh giá độ liên quan; nếu document bị coi là không liên quan/không đủ, workflow rẽ nhánh quay lại rewrite query rồi retrieve lại trước khi generate câu trả lời cuối.
- **NVIDIA**: mô tả agentic RAG là hệ thống tự suy luận, hành động, tương tác với môi trường để đạt mục tiêu — quyết định khi nào/cách nào dùng tool ngoài (search engine, retrieval engine) và điều chỉnh chiến lược theo feedback, khác với model thụ động chỉ phản hồi một prompt/retrieval cố định.

### Ví dụ tối thiểu (pseudocode dựa theo API LangChain/LangGraph)

```python
from langchain.tools.retriever import create_retriever_tool

# 1. Biến retriever có sẵn thành 1 tool — đây là bước duy nhất cần để "agentic hoá" RAG
retriever_tool = create_retriever_tool(
    retriever,                      # vector store retriever đã setup sẵn
    name="search_knowledge_base",
    description="Tra cứu tài liệu nội bộ khi câu hỏi cần thông tin cụ thể, không có trong parametric knowledge.",
)

# 2. Gắn tool vào agent — model tự quyết định có gọi hay không, gọi bao nhiêu lần
agent = create_agent(model="claude-...", tools=[retriever_tool])

# 3. Vòng lặp bên trong agent (LangGraph) đại khái là:
#    while not model.thinks_answer_is_ready():
#        action = model.decide_next_step()      # "retrieve(query)" | "answer" | tool khác
#        if action == "retrieve":
#            docs = retriever_tool.invoke(query)
#            model.observe(docs)                 # tự đánh giá: đủ liên quan chưa?
#    return model.generate_final_answer()

result = agent.invoke({"messages": [{"role": "user", "content": "Chính sách nghỉ phép 2026 là gì?"}]})
```

- Điểm mấu chốt: **không có code retrieval "đặc biệt"** — khác biệt duy nhất so với gọi tool thông thường là retriever được bọc thành 1 tool, và loop dừng do model tự quyết định, không phải do lập trình viên hardcode "chạy đúng 1 lần".
- Lưu ý: đoạn code trên minh hoạ **cấu trúc**, chưa được chạy thử end-to-end trong note này — mục đích là cho thấy hình dạng thực tế của code, không phải một implementation đầy đủ đã kiểm chứng.

## 4. Ví dụ minh hoạ: pipeline khác biệt cụ thể

| Bước | Naive RAG | RAG Agent |
|---|---|---|
| 1 | Nhận câu hỏi | Nhận câu hỏi |
| 2 | Luôn embed + retrieve top-k | Model tự hỏi: "câu này có cần tra cứu ngoài không?" |
| 3 | Nhét toàn bộ top-k vào prompt | Nếu cần → gọi tool `retrieve(query)`; nếu không → trả lời thẳng từ parametric knowledge |
| 4 | Generate câu trả lời | Đọc kết quả, tự đánh giá: đủ liên quan/đủ chứng cứ chưa? |
| 5 | — | Nếu chưa đủ → reformulate query, `retrieve()` lại (hoặc gọi thêm tool khác: web search, calculator) |
| 6 | Trả lời | Lặp bước 4-5 tới khi đủ, rồi mới generate câu trả lời cuối |

- **Chi phí/độ trễ đánh đổi**: naive RAG ước tính ~$0.001/query, latency 200-500ms; agentic RAG cho cùng tác vụ có thể tốn gấp ~10 lần chi phí và cộng thêm vài giây latency (thường 2-10s+) (buildmvpfast.com, confidence: low — số liệu blog, chưa kiểm chứng độc lập). Vì vậy một pattern thực tế là dùng classifier phân loại độ phức tạp câu hỏi: câu đơn giản → naive/advanced RAG, câu multi-hop/phức tạp → mới route sang agentic RAG.
- **Case thực tế — Uber "Genie"**: trợ lý on-call kỹ thuật nội bộ trên Slack. Sau khi RAG truyền thống cho kết quả không đủ chính xác ở domain security/privacy, Uber chuyển sang kiến trúc "Enhanced Agentic RAG" (EAg-RAG) dùng các agent pre-/post-processing để tối ưu query, xác định nguồn, tinh chỉnh context (xây trên LangGraph + service nội bộ Langfx trong Michelangelo). Kết quả: tăng 27% tỷ lệ câu trả lời chấp nhận được, giảm 60% tỷ lệ lời khuyên sai — đủ tin cậy để triển khai vào kênh security/privacy (uber.com + zenml.io, confidence: high).

## 5. Liên hệ tới các phần khác

- Naive/classic RAG (retrieve-rồi-generate một lượt) đã được giới thiệu ở [[llm-rag-basics]] — note này chỉ nói về biến thể **agentic** của nó.
- Cơ chế agent loop tổng quát (perceive → reason/plan → act → observe) mà RAG Agent áp dụng riêng cho retrieval nằm ở [[agent-loop]].
- Pattern gốc "xen kẽ suy luận và hành động" nằm ở [[agent-architecture-react]] — RAG Agent có thể coi là ReAct áp dụng chuyên biệt cho tool retrieval.
- Cơ chế vector search/embedding phía sau retrieval nằm ở [[vector-search]].

### Áp dụng với Claude Code

**Điểm chính cần nhớ**: Claude Code (CLI) **không dùng RAG/vector-embedding pipeline theo mặc định** để tìm code trong repo.

- Thay vào đó, nó dùng **"agentic search"**: model tự phát ra chuỗi tool call (Glob, Grep, Read, LSP) từng bước, thu hẹp dần phạm vi giống cách một kỹ sư người thật explore repo, đọc trực tiếp file sống trên đĩa thay vì một index đã build sẵn (vadim.blog, confidence: medium — corroborated bởi 2 nguồn khác trong danh sách sources).
- Anthropic gọi chiến lược này là **"just-in-time" retrieval**: agent giữ các reference nhẹ (đường dẫn file, query đã lưu, link) và load dữ liệu vào context động lúc runtime qua tool, thay vì pre-embed mọi thứ trước — cho phép "progressive disclosure" (agent khám phá dần cái nó cần). Đánh đổi: explore lúc runtime chậm hơn retrieval đã tính toán sẵn, nên Anthropic khuyến nghị chiến lược hybrid cho một số trường hợp (anthropic.com/engineering/effective-context-engineering-for-ai-agents, confidence: high).

Các ví dụ phụ khác — cùng tinh thần "chỉ agentic hoá retrieval khi cần", nguồn/độ tin cậy chi tiết ở bảng phụ lục cuối note:

- Hệ thống multi-agent research của Claude: subagent coi web/internal search là 1 tool trong nhiều tool, reformulate query lặp lại (bắt đầu rộng, thu hẹp dần), tự đánh giá kết quả sau mỗi lần gọi thay vì retrieve tĩnh một-lượt.
- RAG built-in trong Claude Projects (tìm trên tài liệu đã upload) cũng agentic: model tự quyết định khi nào gọi search thay vì luôn nhét toàn bộ tài liệu vào context.
- Pattern "Code execution with MCP" (11/2025) áp dụng cùng triết lý "chỉ lấy cái cần, khi cần" nhưng cho việc discover tool (biến MCP tool definitions thành file code trên đĩa để agent load theo nhu cầu), không phải cho document retrieval.
- Claude Agent SDK không có sẵn primitive vector-store/RAG built-in — agentic search qua filesystem tool (grep/find/glob) hoạt động không cần RAG pipeline; muốn retrieval trên knowledge base ngoài repo/filesystem thì phải tự gắn thêm qua MCP server.

## Phụ lục: nguồn & độ tin cậy cho các nhận định không trích inline

Để giữ phần thân note dễ đọc, các claim ít gây tranh cãi hơn được gom vào bảng này thay vì chèn `(nguồn, confidence: ...)` sau mỗi câu:

| Nhận định | Nguồn | Độ tin cậy |
|---|---|---|
| Naive RAG là pipeline tuyến tính, không đánh giá lại kết quả retrieve | buildmvpfast.com | medium |
| Mô tả retrieve → augment → generate, không có bước agentic | aws.amazon.com | high |
| Khung so sánh LLM thuần / workflow tất định / naive RAG / RAG Agent | blog (dev.to) | low |
| Định nghĩa Agentic RAG + taxonomy theo agent cardinality & control structure | arXiv 2501.09136 (survey) | high |
| Agentic RAG hình thức hoá như finite-horizon POMDP | arXiv 2603.07379 (SoK) | medium |
| LangChain: agentic hoá qua gắn retriever tool (`create_retriever_tool()`) | docs.langchain.com | high |
| LangGraph agentic-RAG pattern: đánh giá relevance, rewrite query nếu cần | docs.langchain.com/langgraph | high |
| Agentic RAG là hệ thống tự suy luận + hành động + thích ứng theo feedback | developer.nvidia.com | medium |
| Multi-agent research system dùng search như 1 tool, reformulate lặp lại | anthropic.com/engineering/multi-agent-research-system | high |
| RAG built-in trong Claude Projects là agentic (model tự quyết định gọi search) | support.claude.com | medium |
| "Code execution with MCP" áp dụng triết lý "lấy khi cần" cho tool discovery | simonwillison.net | medium |
| Claude Agent SDK không có sẵn primitive RAG/vector-store built-in | nguồn blog bên thứ ba | low |

## Giới hạn / open questions

- Ranh giới giữa "agentic RAG" và "agent có tool retrieval" khá mờ trong nhiều bài blog — chưa có định nghĩa formal thống nhất trong cộng đồng ngoài các paper học thuật (Self-RAG, survey 2501.09136).
- Số liệu chi phí/latency (~10x, 2-10s+) chỉ từ 1 nguồn blog (buildmvpfast.com), chưa kiểm chứng chéo với benchmark độc lập — nên coi là ước lượng tham khảo, không phải con số chuẩn.
- Chưa research sâu về cách đánh giá (evaluation) chất lượng RAG Agent — vd làm sao đo được liệu vòng lặp "retrieve lại" có thực sự cải thiện answer hay chỉ tốn thêm latency mà không thêm giá trị.
- Đoạn pseudocode ở mục 3 minh hoạ cấu trúc API, nhưng **chưa được chạy thử end-to-end** — vẫn cần tự verify khi áp dụng vào project thật.
- Paper gốc Lewis et al. 2020 (RAG gốc) chỉ được trích dẫn gián tiếp qua survey 2501.09136, chưa fetch trực tiếp để xác nhận nội dung.
