---
status: current
updated: 2026-08
sources:
  - https://arxiv.org/abs/2310.08560
  - https://docs.langchain.com/oss/python/langchain/long-term-memory
  - https://docs.langchain.com/oss/python/concepts/memory
  - https://arxiv.org/pdf/2504.19413
  - https://vectorize.io/articles/agent-memory-vs-rag
  - https://mem0.ai/blog/how-to-create-ai-agents-with-long-term-memory
  - https://openai.com/index/memory-and-new-controls-for-chatgpt/
  - https://platform.claude.com/docs/en/agents-and-tools/tool-use/memory-tool
  - https://code.claude.com/docs/en/memory
  - https://www.digitalocean.com/community/tutorials/langgraph-mem0-integration-long-term-ai-memory
roadmap: ai-engineer
stage: learning
---

# Long-term memory — bộ nhớ sống ngoài prompt, được ghi và truy hồi qua nhiều session

**TL;DR**: **Long-term memory** là thông tin được agent **ghi ra một kho lưu trữ bền vững** (vector DB, SQL, file...) thay vì chỉ tồn tại trong context window, rồi được **truy hồi chọn lọc** ở một session khác, sau này, và bơm ngược vào prompt. Về kiến trúc, bước truy hồi này chính là **RAG** (retrieve rồi inject — xem [[llm-rag-basics]]) áp dụng cho kho fact riêng của agent về user, thay vì một kho tài liệu tĩnh.

## 1. Phân biệt với short-term memory

- **Short-term memory** ([[agent-memory-short-term]]): sống trong context window hiện tại (system prompt, lịch sử hội thoại, core memory) — biến mất khi session kết thúc hoặc bị compact/rotate ra ngoài cửa sổ token.
- **Long-term memory**: ghi ra một store **bên ngoài** context window, tồn tại độc lập với vòng đời của session, và phải được **truy hồi chủ động** (query lại) mới quay vào prompt được.
- **Nguồn gốc thuật ngữ**: paper **MemGPT** (2023, coi context window như bộ nhớ hệ điều hành — dự án mã nguồn mở sau đổi tên thành **Letta**) chia bộ nhớ agent làm 2 tầng:
  - *Short-Term Memory* — nằm trong context: system prompt, core memory, chat history.
  - *Long-Term Memory* — nằm ngoài context, gồm **Archival Memory** (kho fact tổng quát, tìm bằng search) và **Recall Memory** (toàn bộ lịch sử hội thoại cũ, gọi lại theo yêu cầu) (as of arxiv.org/abs/2310.08560, confidence: high).

## 2. Ba câu hỏi thiết kế bắt buộc

Mọi hệ long-term memory đều phải trả lời 3 câu hỏi này: lưu cái gì, index bằng cách nào, và ghi lúc nào.

### 2.1. Lưu cái gì?

- **Raw transcript**: toàn văn hội thoại — đơn giản nhất nhưng tốn token, không ưu tiên hoá, khó scale.
- **Summary**: tóm tắt định kỳ — nén thông tin nhưng có thể mất chi tiết.
- **Extracted facts**: LLM trích xuất fact rời rạc kèm metadata (VD "user thích Kotlin hơn Java") — cách tiếp cận production phổ biến nhất hiện nay. Mem0 (2025) là ví dụ tiêu biểu: trích xuất, đánh giá, **hợp nhất** (consolidate — gộp fact mới với fact cũ, tránh trùng lặp/mâu thuẫn) rồi truy hồi lại fact quan trọng từ hội thoại; mặc định lưu fact/summary có metadata thay vì transcript thô, có flag `infer=False` để ép lưu nguyên văn khi cần (as of arxiv.org/pdf/2504.19413, confidence: medium).
- LangGraph phân loại theo khoa học nhận thức: **Semantic memory** (fact về user/thế giới), **Episodic memory** (sự kiện/hành động quá khứ, VD few-shot trajectory), **Procedural memory** (quy tắc hành vi — nằm trong weight/prompt/code chứ không phải store runtime).

**Ví dụ cụ thể — một fact được trích xuất và lưu (kiểu Mem0):**

```json
{
  "id": "fact_8f2c",
  "user_id": "leonard",
  "memory": "User prefers Kotlin over Java for backend services",
  "metadata": { "category": "preference", "source_session": "sess_204" },
  "created_at": "2026-08-10T09:12:00Z"
}
```

Và khi agent cần dùng lại fact này ở session sau, nó gọi truy hồi (không phải nạp toàn bộ transcript cũ):

```python
results = memory_store.search(
    query="ngôn ngữ backend user thích dùng là gì?",
    user_id="leonard",
    limit=5,
)
# results -> [{"memory": "User prefers Kotlin over Java...", "score": 0.87}, ...]
```

### 2.2. Index để truy hồi bằng cách nào?

- **Vector similarity search** (**semantic search** — tìm theo nghĩa gần chứ không phải khớp chữ): embedding + nearest-neighbor, phù hợp truy vấn mờ ("user từng nói gì về deadline?").
- **SQL / key-value lookup**: query chính xác theo key/namespace, phù hợp fact có cấu trúc rõ (VD `user.timezone = "Asia/Ho_Chi_Minh"`).
- **Kết hợp**: nhiều hệ production (Mem0, LangGraph Store) hỗ trợ cả hai trên cùng một store — ví dụ API dạng `store.get(namespace, key)` cho lookup chính xác và `store.search(query)` cho similarity search.
- Hạ tầng phổ biến: **PostgreSQL + pgvector** — xử lý tốt vector search tới hàng triệu vector, không cần thêm hạ tầng riêng, query chung được với dữ liệu quan hệ khác của app.

### 2.3. Khi nào ghi?

- **Hot path**: ghi ngay trong lượt hội thoại hiện tại (thường qua tool call) — minh bạch nhưng thêm latency.
- **Background/async**: ghi sau, ở cuối session hoặc theo job định kỳ (cron) — không chặn phản hồi nhưng phải tự quyết tần suất trigger.
- Chưa có rule cứng "mỗi lượt đều ghi": write quá nhiều làm nhiễu kết quả truy hồi, write quá ít làm mất context quan trọng — đây là bài toán cần tinh chỉnh theo domain. Một điểm khởi đầu hợp lý nếu chưa có dữ liệu riêng: mặc định ghi **async ở cuối session**, chỉ chuyển sang hot-path cho các fact có tính an toàn/quan trọng ngay lập tức (VD user vừa đổi thông tin thanh toán).

## 3. Vì sao gọi long-term memory là "RAG áp dụng cho lịch sử của chính agent"

| | RAG cổ điển | Agent long-term memory |
|---|---|---|
| Nguồn dữ liệu | Kho tài liệu tĩnh, index 1 lần | Fact/sự kiện agent tự ghi ra, cập nhật liên tục |
| Write path | Không có (read-only ở inference time) | Chủ động: extract, **identity resolution** (xác định fact mới nói về cùng một entity/user nào với fact cũ), merge/update |
| Truy hồi | Single-pass similarity search, top-k chunk | Có thể kết hợp semantic search + keyword + graph traversal + lọc theo thời gian, **reciprocal rank fusion** (gộp nhiều danh sách kết quả xếp hạng thành một) |
| Kết quả | Chunk rời rạc, không thứ tự | Có thể là output có cấu trúc: timeline, entity profile |
| Trạng thái | Stateless — quên sau mỗi phiên | Stateful — tồn tại xuyên session, "học" dần về user |

Về bản chất, cơ chế "retrieve rồi inject vào prompt" giống hệt RAG (xem [[llm-rag-basics]], [[vector-search]]); khác biệt nằm ở việc long-term memory còn có **write path chủ động** mà RAG cổ điển không có.

## 4. Ví dụ thực tế

- **ChatGPT (OpenAI)** có 2 cơ chế song song:
  - **Saved Memories** — fact tường minh do user yêu cầu nhớ, inject vào mọi chat tới khi xoá (giống key-value store).
  - **Chat History reference** — truy hồi mờ dựa trên hội thoại cũ liên quan (giống RAG-style similarity search).
  - User tắt được riêng từng cơ chế, hoặc dùng Temporary Chat để bỏ qua cả đọc lẫn ghi.
- **LangGraph + Mem0**: LangGraph xử lý state ngắn hạn trong 1 session (orchestration, checkpoint); Mem0 cung cấp lớp bộ nhớ ngữ nghĩa bền vững, scoped theo user, truy hồi xuyên session.
- **Anthropic memory tool** (`memory_20250818`, GA trên Messages API, Claude 4+):
  - Claude thao tác file trong thư mục `/memories` qua các lệnh kiểu filesystem (`view`, `create`, `str_replace`, `insert`, `delete`, `rename`).
  - Được mô tả là **"just-in-time context retrieval"** (ghi lại điều học được ra file, đọc lại theo nhu cầu — thay vì nạp hết vào context từ đầu).
  - Toàn bộ thao tác chạy **phía client**: Anthropic chỉ gửi `tool_use` request, app của developer tự thực thi trên storage họ chọn (đĩa cục bộ, DB, cloud) — Anthropic không áp đặt cách index (SQL/vector/key-value đều do dev tự quyết) (as of platform.claude.com/.../memory-tool, confidence: high).

## 5. Liên hệ tới các phần khác

- So với [[agent-memory-short-term]]: short-term nằm trong context window và mất khi session kết thúc; long-term sống ngoài context, cần bước retrieve tường minh để quay lại prompt.
- Bước retrieve của long-term memory dùng chung nguyên lý với [[llm-rag-basics]] và [[vector-search]] — chỉ khác nguồn corpus.
- Nằm trong bức tranh lớn hơn của agent loop — xem [[agent-loop]] và [[agent-reason-plan]] để hiểu bộ nhớ được đọc/ghi ở giai đoạn nào của một lượt xử lý.

### Áp dụng với Claude Code

Claude Code (CLI) **có** cơ chế long-term memory riêng, nhưng khác đáng kể so với kiến trúc "vector DB + embedding retrieval" mô tả ở trên:

- **CLAUDE.md**: file tĩnh do người dùng tự viết, được nạp **toàn bộ** vào mỗi session — không phải cơ chế tự động ghi.
- **Auto memory**: Claude tự viết ghi chú (build command, insight debug, preference) vào `~/.claude/projects/<project>/memory/`.
  - `MEMORY.md` (tối đa 200 dòng / 25KB) luôn được nạp tự động.
  - Các file chủ đề khác (VD `debugging.md`) chỉ được đọc **theo nhu cầu bằng tool đọc file thông thường** — **không phải semantic/vector search**, mà là index-then-read (as of code.claude.com/docs/en/memory, confidence: high).
- Claude tự quyết **ghi gì** một cách không tất định — không phải session nào cũng ghi, Claude tự đánh giá thông tin có hữu ích cho tương lai không — khác hẳn CLAUDE.md vốn 100% do người dùng kiểm soát.
- Auto memory **scoped theo máy + theo git repo** (không đồng bộ qua nhiều máy/cloud), khác mô hình store tập trung (Postgres/pgvector) mà kiến trúc long-term memory tổng quát thường giả định.
- Vì native mechanism không có embedding-based retrieval, hệ sinh thái bên thứ ba (Mem0, Supermemory, cognee) đã xây thêm lớp memory có vector index trên nền Claude Code / Claude Agent SDK để bù khoảng trống này.
- CLAUDE.md ở project root có đặc quyền: sống sót qua `/compact` vì được đọc lại từ đĩa và re-inject sau compaction; CLAUDE.md lồng nhau (nested) hoặc rule scoped theo path thì không tự động re-inject — chỉ nạp lại khi file khớp được đọc lần kế tiếp.

## 6. Giới hạn / open questions

- Paper khảo sát "Memory in the Age of AI Agents" (arXiv:2512.13564) được liệt kê như nguồn taxonomy hàn lâm nhưng chưa được đọc sâu trong ghi chú này (confidence: low) — cần review kỹ hơn ở lần cập nhật sau.
- Chưa có benchmark định lượng rõ ràng trong các nguồn đã đọc về ngưỡng "ghi bao nhiêu là đủ" hay chi phí latency thực tế của hot-path write so với background write — mới dừng ở mô tả định tính; đề xuất "async cuối session" ở §2.3 là suy luận cá nhân, chưa có số liệu kiểm chứng.
- Câu hỏi về governance (xoá memory cũ, tránh rò rỉ dữ liệu nhạy cảm giữa các session/user) mới được nêu như trách nhiệm của developer (Anthropic memory tool docs), chưa có pattern chuẩn hoá rộng rãi để dẫn chiếu.
- Bài Medium gốc (medium.com/@alozie_igbokwe) không fetch trực tiếp được trong phiên nghiên cứu này (lỗi socket) — các claim liên quan chỉ dựa trên summary do người yêu cầu cung cấp, cần verify lại nếu có dịp.

### Nguồn & độ tin cậy theo claim

| Claim | Nguồn | Độ tin cậy |
|---|---|---|
| Taxonomy MemGPT (Archival/Recall Memory) | arxiv.org/abs/2310.08560 | high |
| Cơ chế extract/consolidate của Mem0, flag `infer=False` | arxiv.org/pdf/2504.19413 | medium |
| Bảng so sánh RAG vs. agent memory (§3) | vectorize.io/articles/agent-memory-vs-rag | high |
| ChatGPT Saved Memories vs. Chat History reference | openai.com/index/memory-and-new-controls-for-chatgpt | high |
| Anthropic memory tool (`/memories`, client-side execution) | platform.claude.com/.../memory-tool | high |
| Claude Code auto memory (MEMORY.md, index-then-read) | code.claude.com/docs/en/memory | high |
| Bên thứ ba (Mem0/Supermemory/cognee) bù vector search cho Claude Code | mem0.ai/blog/claude-code-memory | medium |
