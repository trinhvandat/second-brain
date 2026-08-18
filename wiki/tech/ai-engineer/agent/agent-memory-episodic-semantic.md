---
status: current
updated: 2026-08
sources:
  - https://www.sciencedirect.com/science/article/abs/pii/S0028393220300373
  - https://arxiv.org/abs/2309.02427
  - https://docs.langchain.com/oss/python/concepts/memory
  - https://langchain-ai.github.io/langmem/guides/extract_semantic_memories/
  - https://atlan.com/know/types-of-ai-agent-memory/
  - https://www.letta.com/blog/rag-vs-agent-memory/
  - https://platform.claude.com/docs/en/agents-and-tools/tool-use/memory-tool
  - https://code.claude.com/docs/en/memory
  - https://alexop.dev/posts/four-types-memory-coding-agents-claude-code/
  - https://informationmatters.org/2025/10/memgpt-engineering-semantic-memory-through-adaptive-retention-and-context-summarization/
roadmap: ai-engineer
stage: learning
---

# Episodic vs Semantic Memory — "chuyện gì đã xảy ra" so với "giờ tôi biết gì"

**TL;DR**: **Episodic memory** lưu các sự kiện/tương tác cụ thể, gắn mốc thời gian (VD "ngày 10/8/2026 user nhờ sửa bug X, mình đã sửa file Y"); **semantic memory** lưu fact/kiến thức tổng quát, phi thời gian, được **chưng cất** từ nhiều episode (VD "user này luôn thích TypeScript hơn JavaScript"). Đây là 2 trong số các phân nhóm con của [[agent-memory-long-term]] — episodic trả lời "chuyện gì đã xảy ra", semantic trả lời "giờ tôi biết gì".

## 1. Nguồn gốc: tâm lý học nhận thức

- Phân biệt này bắt nguồn từ nhà tâm lý học nhận thức **Endel Tulving**, trong chương sách năm 1972 "Episodic and Semantic Memory": **semantic memory** là một "mental thesaurus" — kho kiến thức tổng quát cần thiết để dùng ngôn ngữ; **episodic memory** là trí nhớ về "các episode/sự kiện có mốc thời gian" và quan hệ thời gian-không gian giữa chúng.
- Paper này trở thành khung tham chiếu kinh điển trong tâm lý học nhận thức, xác lập episodic + semantic là 2 hệ thống con chính trong **long-term memory** của con người — cùng với procedural memory (kỹ năng/thói quen, không thuộc phạm vi note này).
- Năm 2023, paper **CoALA — Cognitive Architectures for Language Agents** là công trình then chốt mang taxonomy này từ tâm lý học vào thiết kế agent LLM, đề xuất 4 loại bộ nhớ cho agent: working, episodic, semantic, procedural (as of arxiv.org/abs/2309.02427, confidence: high). Phần lớn framework agent memory hiện nay (LangMem, Letta/MemGPT, Claude Code — xem mục 3 và 5) đều tham chiếu trực tiếp hoặc gián tiếp về taxonomy này.

## 2. Định nghĩa áp dụng cho agent

| | Episodic memory | Semantic memory |
|---|---|---|
| Trả lời câu hỏi | "Chuyện gì đã xảy ra?" | "Giờ tôi biết gì?" |
| Nội dung | Sự kiện/tương tác cụ thể, có mốc thời gian | Fact/khái niệm tổng quát, phi thời gian |
| Cách lưu | Raw hoặc lightly-processed transcript, index theo thời gian/session | Output của bước **consolidation/extraction** (thường là 1 LLM call tóm tắt pattern qua nhiều episode) |
| Ví dụ | "Agent từng query metric `revenue_mrr`, phát hiện metric này đã bị deprecated 3 tháng trước" | "`net_revenue_q4 v3.2` là định nghĩa đã được Finance duyệt" |
| Cách agent dùng lại | Nạp làm few-shot example (trajectory quá khứ) | Nạp thẳng như fact đã biết, không cần suy luận lại |

- LangChain định nghĩa tương tự (và trích dẫn thẳng CoALA làm nguồn): **semantic memory** = "giữ lại fact và concept cụ thể" (dùng để cá nhân hoá, lưu dạng profile/document); **episodic memory** = "nhớ lại sự kiện/hành động quá khứ" (thường triển khai bằng few-shot example của trajectory cũ).
- Ví dụ enterprise cụ thể hoá khác biệt: episodic = agent nhớ nó từng gặp sự cố data-quality khi truy vấn 1 metric; semantic = agent lấy ra định nghĩa metric đã chuẩn hoá, versioned để trả lời câu hỏi cấp board.

## 3. Semantic memory là output của một bước consolidation

Điểm khác biệt vận hành quan trọng nhất: **episodic memory được ghi gần như trực tiếp** (transcript, event log), còn **semantic memory hầu như luôn cần một bước xử lý riêng** biến episode thô thành fact bền vững.

- **LangMem SDK** (LangChain) minh hoạ rõ pattern này: một component gọi là **Memory Manager** phân tích dữ liệu hội thoại/episode bằng LLM prompting với schema-based extraction + parallel tool calling, để create/update/delete các fact semantic có cấu trúc; đồng thời chạy **consolidation** định kỳ (gộp memory liên quan, giải quyết mâu thuẫn) để tránh phình kho nhớ vô hạn.
- LangMem cũng cung cấp 2 đường ghi: **hot path** (agent chủ động gọi tool ghi memory trước khi trả lời — thêm latency) và **background path** (một tiến trình riêng trích xuất/consolidate sau hội thoại — không tốn latency nhưng cần logic trigger). Chính background path là cơ chế biến transcript episodic thô thành fact semantic đã hợp nhất.
- **MemGPT/Letta**: episodic memory (gắn với 1 thời điểm/ngữ cảnh cụ thể) chuyển hoá thành semantic memory (kiến thức chung, tách khỏi ngữ cảnh gốc) khi thông tin đó lặp lại qua nhiều ngữ cảnh khác nhau — song song trực tiếp với quá trình consolidation episodic→semantic ở người; Letta hiện thực bằng mô hình 3 tầng core/archival/recall memory. Claim này dựa trên 1 bài blog thứ cấp, chưa đối chiếu trực tiếp với docs gốc của Letta (as of informationmatters.org/.../memgpt-engineering-semantic-memory, confidence: medium).

**Ví dụ minh hoạ luồng consolidation** (kiểu LangMem/Mem0):

```
Episode 1 (2026-08-10): "User: sửa bug X trong file Y bằng cách dùng interface thay vì type."
Episode 2 (2026-08-14): "User: viết component mới, yêu cầu dùng TypeScript interface."
Episode 3 (2026-08-16): "User: từ chối PR vì dùng `any`, yêu cầu type rõ ràng."
        │
        │  LLM consolidation pass (định kỳ hoặc cuối session)
        ▼
Semantic fact: { "fact": "User luôn ưu tiên TypeScript interface tường minh, tránh `any`",
                  "category": "coding_preference", "derived_from": ["ep1","ep2","ep3"] }
```

Episode gốc vẫn có thể giữ lại (để trace lại "vì sao mình biết điều này"), nhưng fact semantic mới là thứ được inject thẳng vào prompt ở các lượt sau — không cần đọc lại cả 3 episode.

## 4. So sánh nhanh với RAG

- Cả episodic và semantic memory đều là external store, chỉ vào prompt khi được **truy hồi chủ động** — về cơ chế đọc, giống [[llm-rag-basics]] (retrieve rồi inject).
- Khác biệt: episodic/semantic memory có **write path chủ động** trong lúc hội thoại (extract fact, entity resolution — nhận ra "Alice" ở hội thoại này là cùng một Alice từng nhắc trong ticket tuần trước), trong khi RAG cổ điển mặc định stateless, chỉ grounding vào corpus tĩnh tại query time. RAG trả lời "tài liệu nói gì?", agent memory trả lời "user này cần gì?".

## 5. Liên hệ tới các phần khác

- Đây là 2 sub-category cụ thể trong bức tranh lớn hơn của [[agent-memory-long-term]] — xem note đó để hiểu 3 câu hỏi thiết kế chung (lưu cái gì / index sao / ghi lúc nào) áp dụng thế nào cho cả episodic lẫn semantic.
- Phân biệt với [[agent-memory-short-term]]: cả episodic lẫn semantic ở đây đều nói về bộ nhớ **ngoài** context window (persist xuyên session); short-term memory sống trong context hiện tại và biến mất khi session kết thúc.
- Xem [[agent-memory-what-is-agent-memory]] cho định nghĩa tổng quát về agent memory trước khi đi vào chi tiết taxonomy này.

### Áp dụng với Claude Code

Claude Code (CLI) **không** expose 2 store riêng biệt tên gọi "episodic" và "semantic" qua API/setting nào cả. Nhưng nó có 2 cơ chế memory cross-session (sống sót qua nhiều session, khác với context window của 1 phiên) có thể ánh xạ gần đúng vào 2 khái niệm này:

| Cơ chế Claude Code | Vai trò gần nhất | Ai/cái gì tạo ra nó |
|---|---|---|
| `CLAUDE.md` (người dùng tự viết) | **semantic memory** — kiến thức bền vững, đã curate | Con người viết tay |
| Auto memory: `MEMORY.md` + file chủ đề dưới `~/.claude/projects/<project>/memory/` | gần **episodic memory**, nhưng đã qua chưng cất | Claude tự viết trong lúc làm việc |

- Điểm cần lưu ý: khác với định nghĩa sách vở (episodic = log thô, semantic = fact đã chưng cất *từ* episodic), ở Claude Code layer "gần-episodic" (auto memory) đã là ghi chú tóm tắt sẵn (build command, insight debug, architecture note...) — không phải transcript nguyên bản; còn layer "semantic-like" (CLAUDE.md) lại do người viết tay trực tiếp, không phải output của một bước extraction tự động. Nói cách khác, thứ tự "ai tạo ra ai" bị đảo so với khung CoALA — một phân tích bên thứ ba áp CoALA vào Claude Code cũng ghi nhận cùng quan sát này (as of alexop.dev/.../four-types-memory-coding-agents-claude-code, confidence: medium).
- Claude Code **không giữ raw session transcript** như một kho "episodic memory" mà agent tự đọc lại được: transcript hội thoại chỉ là lịch sử tạm thời, bị xoá sau `cleanupPeriodDays` (cấu hình được); chỉ riêng thư mục `memory/` (MEMORY.md + topic files) được loại trừ khỏi việc dọn dẹp này. Tức là Claude Code chủ động không lưu episodic log thô dài hạn — chỉ có bản đã consolidate.
- Về "consolidation": Claude Code không chạy một LLM consolidation job định kỳ như LangMem. Cơ chế đơn giản hơn nhiều — khi `MEMORY.md` gần chạm giới hạn đọc (200 dòng/25KB), hệ thống trả về reminder tự động yêu cầu Claude rút gọn (gộp/bỏ entry cũ, chuyển chi tiết sang topic file). Đây là **prune cơ học, nhẹ** (dọn theo ngưỡng dung lượng), khác về bản chất với một pass tóm tắt-bằng-LLM chạy trên toàn bộ transcript.
- Có tin đồn/dự án cộng đồng (không chính thức) về một tính năng tên "Auto Dream" (4 pha: Orient, Gather Signal, Consolidate, Prune) khớp khá sát với ý tưởng "semantic là output của 1 LLM consolidation call trên episode" — nhưng tính năng này **không xuất hiện trong docs chính thức** của Anthropic tại thời điểm viết note, nên KHÔNG được trình bày như hành vi chính thức của Claude Code (as of github.com/grandamenium/dream-skill, confidence: low).

## 6. Giới hạn / open questions

- Chưa có benchmark định lượng trong các nguồn đã đọc về ngưỡng "bao nhiêu episode thì nên trigger 1 lần consolidation" hay chi phí latency/cost thực tế của bước LLM consolidation này ở quy mô lớn — các nguồn (LangMem, MemGPT) mới mô tả định tính.
- Claim về Letta/MemGPT dùng đúng mô hình "episodic transforms into semantic khi lặp lại qua nhiều context" dựa trên 1 bài blog thứ cấp (informationmatters.org), chưa đối chiếu trực tiếp với source code hay docs gốc của Letta — cần verify thêm.
- "Auto Dream" của Claude Code chỉ là tin đồn/dự án cộng đồng, chưa xác nhận chính thức — nếu Anthropic công bố chính thức trong tương lai, cần cập nhật lại phần "Áp dụng với Claude Code".
- Chưa rõ trong thực tế production, ranh giới giữa "episodic đã lightly-processed" và "semantic đã fully-extracted" có thực sự tách bạch được hay là một dải liên tục (spectrum) — nhiều hệ thống (Claude Code auto memory, Mem0) dường như nằm ở đâu đó giữa 2 cực này chứ không thuần một trong hai.
