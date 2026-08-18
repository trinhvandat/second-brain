---
status: current
updated: 2026-08
sources:
  - https://docs.langchain.com/oss/python/concepts/memory
  - https://langchain-ai.github.io/langmem/concepts/conceptual_guide/
  - https://arxiv.org/abs/2310.08560
  - https://docs.letta.com/guides/core-concepts/memory/memory-blocks
  - https://docs.letta.com/guides/legacy/memgpt_agents_legacy
  - https://openai.com/index/memory-and-new-controls-for-chatgpt/
  - https://embracethered.com/blog/posts/2025/chatgpt-how-does-chat-history-memory-preferences-work/
  - https://support.claude.com/en/articles/11817273-use-claude-s-chat-search-and-memory-to-build-on-previous-context
  - https://platform.claude.com/docs/en/agents-and-tools/tool-use/memory-tool
  - https://code.claude.com/docs/en/memory
  - https://mem0.ai/blog/persistent-memory-for-claude-agents-sdk
  - https://arxiv.org/pdf/2504.19413
  - https://arxiv.org/pdf/2605.06527
  - https://arxiv.org/pdf/2309.02427
  - https://arxiv.org/pdf/2510.07925
  - https://supermemory.ai/blog/building-user-profiles-ai-agents
  - https://medium.com/@visrow/rag-vs-agent-memory-vs-llm-wiki-a-practical-comparison-41a9a0dc4dec
roadmap: ai-engineer
stage: learning
---

# User Profile Storage — lưu trữ thông tin ổn định về một người dùng cụ thể, tái nạp vào mọi phiên làm việc mới

TL;DR: **User Profile Storage** là một ứng dụng cụ thể của **semantic memory**, nơi agent giữ một bản ghi đã được rút gọn, khử trùng lặp (deduplicated) về một người dùng nhất định (tên, sở thích, ràng buộc lặp lại, quyết định trước đó) và nạp lại bản ghi đó vào mọi phiên hội thoại mới với người đó — khác với **episodic memory** vốn là log các sự kiện/transcript cụ thể trong quá khứ.

Nói đơn giản: đây chính là cơ chế đứng sau tính năng "Memory" mà bạn thấy trong ChatGPT hay Claude.ai — một "tờ ghi chú các fact đã biết về bạn", được đọc lại mỗi lần bắt đầu chat mới, thay vì bạn phải gõ lại "tôi thích trả lời ngắn gọn" mỗi lần.

## Vấn đề nó giải quyết

- Không có memory: mỗi phiên hội thoại (LLM call trần) bắt đầu từ context rỗng, người dùng phải tự nhắc lại tên, phong cách giao tiếp, công cụ ưa thích, quyết định cũ mỗi lần — tốn effort và làm agent "quên" các ràng buộc quan trọng.
- **User Profile Storage** giải quyết vấn đề này bằng cách duy trì một bản ghi **current-state** (trạng thái hiện tại, không phải lịch sử đầy đủ) về người dùng, được cập nhật/hoà giải (reconcile) theo thời gian, rồi tự động re-inject vào system/context của phiên mới.

## Phân biệt với Episodic Memory

Theo taxonomy **CoALA** (Cognitive Architectures for Language Agents — một khung phân loại các loại memory của agent, dùng để so sánh các hệ thống với nhau) (as of arxiv.org/pdf/2309.02427, confidence: high):

| Loại memory | Nội dung | Ví dụ |
|---|---|---|
| Episodic | Log sự kiện/hành động cụ thể, gắn với instance | "Ngày 12/8 user hỏi cách deploy Kubernetes, agent trả lời X" |
| Semantic (bao gồm User Profile) | Facts đã trừu tượng hoá, tổng quát hoá về thế giới/user | "User thích câu trả lời ngắn gọn kèm code example" |
| Procedural | Kỹ năng, nằm trong weights hoặc code | Cách agent tự sửa lỗi build |

User Profile là **semantic memory** thu hẹp phạm vi về **một** user cụ thể (thay vì facts chung về thế giới), và khác episodic memory ở chỗ nó không phải "thêm dòng mới mỗi lần" mà là **overwrite/reconcile** khi fact cũ bị thay thế. Xem thêm [[agent-memory-episodic-semantic]].

## Hai pattern thiết kế chính: Profile vs Collection

LangChain phân biệt rõ hai cách triển khai semantic/user memory:

- **Profile pattern**: một JSON document duy nhất, được cập nhật liên tục — mỗi lần có fact mới, model phải **regenerate lại toàn bộ profile**. Ưu điểm: luôn gọn, không trùng lặp. Nhược điểm: dễ lỗi khi profile lớn dần (model có thể vô tình xoá/méo fact cũ khi viết lại).
- **Collection pattern**: nhiều document nhỏ, phạm vi hẹp, được **append** dần theo thời gian. Ưu điểm: ghi đơn giản, an toàn hơn khi thêm mới. Nhược điểm: đẩy độ phức tạp sang bước xoá/update và search (phải tìm và loại bỏ fact cũ bị mâu thuẫn khi truy vấn).

Đây chính là nguồn gốc của câu hỏi thiết kế "conflict resolution khi preference thay đổi" — hai pattern trên là hai cách khác nhau để trả lời câu hỏi đó.

## Giải quyết xung đột và staleness trong thực tế

- **Mem0** dùng pipeline 2 pha: extraction (rút fact ứng viên từ hội thoại) → update (so sánh fact mới với memory tương tự đã có, rồi phát lệnh ADD / UPDATE / DELETE / NOOP) — thiết kế rõ ràng để **merge/overwrite** thay vì chỉ append (as of arxiv.org/pdf/2504.19413, confidence: high).
- **Letta/MemGPT** (nguồn gốc khái niệm "core memory", Packer et al. 2023) lưu profile trong một **memory block** tên "human" — vùng có giới hạn kích thước, luôn nằm trong context (system prompt), tách biệt với block "persona" (agent tự mô tả bản thân) và với archival/recall memory (dùng cho episodic). Agent tự sửa block này qua hai tool call `core_memory_append` (thêm dòng mới) và `core_memory_replace` (ghi đè dòng cũ) — về bản chất là API "sửa file" mà agent tự gọi để cập nhật profile của chính nó.
- **Fact bị lỗi thời (staleness) vẫn là bài toán khó**: benchmark STALE (2026) — bộ test đo xem model có nhận ra một fact đã lưu từ trước còn đúng hay không — cho thấy ngay cả model tốt nhất được test cũng chỉ đạt khoảng **~55% độ chính xác** khi phải quyết định một fact profile đã lưu có còn hợp lệ hay không (as of arxiv.org/pdf/2605.06527, confidence: medium). Nói cách khác, "biết khi nào một fact đã cũ" chưa có lời giải chắc chắn ở thời điểm viết note này.
- Gợi ý thực dụng (mặc định nên dùng nếu chưa biết chọn gì): tách profile thành 2 lớp — **static facts** (vai trò, timezone, gói dịch vụ — ít đổi) và **dynamic/live facts** (hành vi gần đây, mục tiêu đang theo đuổi — cập nhật liên tục), áp policy refresh/access khác nhau cho mỗi lớp. Nếu vẫn phân vân giữa Profile và Collection pattern ở trên: bắt đầu với **Collection pattern + trường `last_seen`/TTL**, chỉ chuyển sang Profile pattern khi kích thước inject vào context thực sự trở thành vấn đề.

## Ví dụ triển khai trong sản phẩm thật

- **ChatGPT Memory**: lưu "Saved Memories" — facts về vai trò, ngành nghề, phong cách làm việc — được âm thầm tham chiếu vào mọi hội thoại tương lai; người dùng có thể xem/sửa/xoá từng memory riêng lẻ (Settings > Personalization > Memory) hoặc tắt hoàn toàn tính năng.
- **Claude.ai Memory** (rollout khoảng 3/2026): sau mỗi chat, Claude trích các chi tiết như vai trò, sở thích, phong cách format thành một bản tóm tắt đang chạy (running summary), đọc lại bản tóm tắt đó ở đầu mọi hội thoại mới. Mỗi Project có không gian memory riêng, tách biệt với memory chat chung; người dùng có thể bật/tắt trong Settings.
- **LangGraph Store**: lưu long-term memory theo namespace tuỳ chỉnh, ví dụ `("users", "user_id", "facts")`, cho phép scope chính xác từng user và persist/recall xuyên nhiều thread/session.

Ví dụ minh hoạ một profile document dạng "Profile pattern":

```json
{
  "user_id": "u_8823",
  "name": "Leonard",
  "communication_style": "ngắn gọn, có ví dụ code",
  "tool_preferences": ["Kotlin", "Spring Boot", "PostgreSQL"],
  "recurring_constraints": ["luôn giải thích trade-off trước khi implement"],
  "past_decisions": [
    {"topic": "ORM", "decision": "dùng Exposed thay vì JPA", "as_of": "2026-06"}
  ],
  "last_updated": "2026-08-15"
}
```
Khi user đổi quyết định (ví dụ chuyển từ Exposed sang JPA), hệ thống cần **overwrite** trường `decision` thay vì append thêm một bản ghi mâu thuẫn — đây chính là điểm khác biệt cốt lõi so với lưu transcript thô.

## Liên hệ tới các phần khác

- Là một trường hợp cụ thể của [[agent-memory-long-term]] và [[agent-memory-episodic-semantic]] — semantic memory scoped theo một user.
- Xem [[agent-memory-what-is-agent-memory]] để hiểu vị trí của User Profile Storage trong bức tranh tổng thể các loại memory.
- So với RAG (retrieval tĩnh trên corpus tài liệu) và workflow/procedural memory (quy trình tái sử dụng), User Profile Storage là nhánh "facts/preferences ghi tại thời điểm hội thoại, đọc tại thời điểm truy vấn" — production system hiện đại thường kết hợp cả ba.

### Áp dụng với Claude Code

- Claude Code (CLI) **không có** cấu trúc dữ liệu "user profile" chuyên biệt. Cơ chế gần nhất là hệ thống phân cấp **CLAUDE.md** (managed policy > `~/.claude/CLAUDE.md` > project `CLAUDE.md` > `CLAUDE.local.md`), toàn bộ được nối lại thành context ở mỗi lần khởi động phiên (as of code.claude.com/docs/en/memory, confidence: high). Đây là văn bản **instructions/rules** người dùng tự viết, không phải "facts về user" được agent tự trích xuất theo nghĩa semantic memory chuẩn.
- CLAUDE.md **không được** hệ thống tự động khử trùng lặp hay hoà giải xung đột — tài liệu chính thức khuyến nghị người dùng tự "xoá instruction lỗi thời/mâu thuẫn", và cảnh báo nếu hai rule mâu thuẫn nhau, Claude có thể chọn tuỳ ý. Conflict resolution ở đây là trách nhiệm thủ công của con người, không phải cơ chế built-in.
- Claude Code có cơ chế **Auto memory**: Claude tự ghi các learning trong phiên (bao gồm "preferences Claude phát hiện được") vào `MEMORY.md` + các file chủ đề tại `~/.claude/projects/<project>/memory/`, tự động nạp lại (200 dòng/25KB đầu) vào mọi phiên mới — đây là phần **gần nhất** với một "curated, current-state profile" built-in, vì Claude được hướng dẫn "merge hoặc drop entry cũ" khi index gần đầy. Entry có thể mang frontmatter `modified` (ISO-8601, từ Claude Code v2.1.214) để đánh giá độ cũ của fact, nhưng **không có** cơ chế tự động hết hạn/xoá fact stale.
- Subagent trong Claude Code **không tự động kế thừa** auto memory của main thread (trừ khi được fork) — nghĩa là thông tin "profile" lưu ở main thread không tự động re-inject vào context của subagent, một khoảng hở cần lưu ý khi thiết kế injection.
- Ở lớp SDK bên dưới (Claude Agent SDK), **không có** sẵn cơ chế xây dựng context riêng cho từng user và duy trì/tăng trưởng nó qua nhiều session — muốn có user-profile layer thật sự thì ứng dụng phải tự xây trên nền **memory tool** (`memory_20250818`, GA từ Claude 4+) hoặc một user store tuỳ biến. Memory tool cho phép Claude đọc/ghi file trong thư mục `/memories` (kể cả `str_replace`/xoá/đổi tên — đủ để hiện thực "overwrite" thay vì chỉ append), nhưng Anthropic **không** cung cấp sẵn logic dedup/conflict-resolution — việc phát hiện fact bị supersede, giới hạn kích thước, dọn file cũ là trách nhiệm của developer.

## Giới hạn / open questions

- Chưa có chuẩn công nghiệp thống nhất cho "conflict resolution": mỗi hệ thống (Mem0, Letta, ChatGPT, Claude.ai) tự chọn heuristic riêng, và nghiên cứu (STALE benchmark) cho thấy ngay cả LLM mạnh cũng chỉ đạt ~55% độ chính xác khi phán đoán một fact có còn hợp lệ hay không — đây vẫn là bài toán mở.
- Chưa rõ ngưỡng "bao nhiêu profile nên được inject" (toàn bộ vs chỉ phần liên quan đến câu hỏi hiện tại) có best practice định lượng cụ thể nào không — các nguồn mới dừng ở mức khuyến nghị định tính (tách static/dynamic).
- Cơ chế staleness/expiry (tự động hết hạn fact cũ) hầu như chưa được chuẩn hoá trong các sản phẩm khảo sát — phần lớn dựa vào timestamp thủ công hoặc dọn dẹp định kỳ do developer tự viết, chưa có ví dụ production nào công khai chi tiết thuật toán expiry.
- Nguồn seed ban đầu (ComputerWeekly, "AI and the data storage it needs") không fetch được (HTTP 403) và theo snippet tìm kiếm chỉ là bài giải thích hạ tầng lưu trữ nói chung, không đề cập cụ thể đến user-profile memory — mức liên quan thấp, cần thay bằng nguồn khác nếu muốn trích dẫn sâu hơn về khía cạnh storage-infrastructure.
