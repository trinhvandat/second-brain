---
status: current
updated: 2026-08
sources:
  - https://arxiv.org/abs/2310.08560
  - https://arxiv.org/abs/2309.02427
  - https://arxiv.org/abs/2502.12110
  - https://docs.langchain.com/oss/python/concepts/memory
  - https://www.letta.com/blog/agent-memory/
  - https://developers.openai.com/api/docs/guides/conversation-state
  - https://platform.claude.com/docs/en/agents-and-tools/tool-use/memory-tool
  - https://www.anthropic.com/news/context-management
  - https://code.claude.com/docs/en/memory
  - https://www.anthropic.com/engineering/building-effective-agents
  - https://help.openai.com/en/collections/8471548-memory
roadmap: ai-engineer
stage: learning
---

# Agent Memory — lớp kỹ thuật lưu và tái nạp lại thông tin đã xảy ra vào context của một LLM vốn stateless

**TL;DR**: LLM mặc định **stateless** — mỗi lần gọi API không hề "nhớ" các lần gọi trước, trừ khi phía gọi tự gửi lại ngữ cảnh cũ. **Agent memory** là lớp kỹ thuật bao quanh model để giải quyết đúng vấn đề đó: lưu trữ (store), truy xuất (retrieve), và tái nạp (re-inject) đúng phần thông tin quá khứ liên quan vào context window ở mỗi lượt gọi — đây là khái niệm ô dù bao trùm short-term memory, long-term memory, episodic/semantic memory, user profile, summarization/compression, và forgetting strategies.

## 1. Vì sao cần agent memory: LLM là stateless

- Theo tài liệu chính thức của OpenAI, mỗi request tới Chat Completions API độc lập hoàn toàn — model **không tự giữ lại** lịch sử hội thoại (confidence: high).
  - Muốn model "nhớ" lượt trước, caller phải tự gửi lại toàn bộ `messages` array ở mỗi request, HOẶC dùng API stateful (Conversations/Responses) để server tự lưu trạng thái hộ.
- Nói cách khác: "trí nhớ" của một agent không nằm trong trọng số model — nó nằm trong **harness** (code bao quanh model): thứ quyết định cái gì được lưu, cái gì được lấy ra, và cái gì được nhét vào prompt tiếp theo.
- Vì context window có giới hạn kích thước (xem [[llm-context-window]]) và giá tăng theo token, agent memory không chỉ là "lưu tất cả" — nó luôn đi kèm bài toán **chọn lọc**: lưu gì, quên gì, nén gì, và khi nào lấy lại.

## 2. Đây là khái niệm ô dù — sơ đồ phân loại

Paper nền tảng **CoALA — Cognitive Architectures for Language Agents** (tạm dịch: kiến trúc nhận thức cho agent dùng ngôn ngữ; Sumers, Yao, Narasimhan, Griffiths, arXiv:2309.02427, đăng trên tạp chí học thuật TMLR) đưa ra một **sơ đồ phân loại (taxonomy)** mà phần lớn framework hiện nay (LangChain/LangGraph) trực tiếp trích dẫn:

- **Working / short-term memory**: ngữ cảnh đang hoạt động trong 1 phiên (thread) — lịch sử tin nhắn, kết quả tool vừa gọi, bị giới hạn bởi kích thước context window.
- **Long-term memory**: thông tin sống ngoài context window, được lưu bền vững và truy xuất lại theo yêu cầu; CoALA chia tiếp thành 3 loại:
  - **Episodic memory**: các sự kiện/trải nghiệm cụ thể đã xảy ra (VD: "lần trước user yêu cầu X, agent đã làm Y").
  - **Semantic memory**: tri thức/sự kiện tổng quát (VD: "user tên gì, thích ngôn ngữ gì") — LangChain map loại này gần với "fact về user".
  - **Procedural memory**: quy tắc/kỹ năng — có thể nằm trong trọng số model, hoặc tường minh hơn là code/system prompt/guideline.

LangChain/LangGraph áp dụng taxonomy này gần như nguyên bản:

- **Short-term memory** = thread-scoped (chỉ tồn tại trong 1 phiên hội thoại) — lưu qua *Checkpointer*, persist toàn bộ message log của phiên đó.
- **Long-term memory** = cross-thread (dùng chung được giữa nhiều phiên khác nhau) — lưu trong *Store*, tổ chức theo *namespace* (hiểu đơn giản: một "ngăn" đặt tên để nhóm dữ liệu liên quan, ví dụ 1 namespace riêng cho mỗi user) (confidence: high).

## 3. Ví dụ tối thiểu: lưu một fact rồi tái nạp ở lượt sau

Bài toán nhỏ nhất minh hoạ agent memory: user nói "tôi thích Python", agent phải "nhớ" điều này ở lượt hội thoại kế tiếp — dù đó là 1 request API hoàn toàn mới (vì LLM stateless, xem mục 1).

```
# Lượt 1: user gõ "tôi thích Python"
fact = extract_fact(user_message)                # "user thích Python"
memory_store.write(key="lang_pref", value=fact)   # (1) WRITE: ghi vào long-term store

# --- Lượt 2, một request API MỚI, không liên quan gì tới lượt 1 ---
relevant = memory_store.read(key="lang_pref")     # (2) READ: truy xuất lại
prompt = system_prompt \
    + f"\n\nĐiều đã biết về user: {relevant}"     # (3) RE-INJECT: nạp vào context
    + user_message
response = llm.call(prompt)
```

- Bước (1) — **write**: quyết định "cái gì đáng lưu" (ở đây đơn giản hoá; thực tế bước này có thể do 1 LLM call riêng làm nhiệm vụ tóm tắt/trích fact).
- Bước (2)-(3) — **read + re-inject**: lấy đúng phần liên quan (không phải toàn bộ lịch sử) rồi ghép vào prompt của lượt tiếp theo.
- `memory_store` có thể là 1 file JSON, 1 dòng trong Postgres, hay 1 LangGraph `Store` — bản chất là bất kỳ nơi lưu trữ nào sống ngoài vòng đời của 1 request.
- Mọi kiến trúc phức tạp hơn ở các mục dưới đây (MemGPT, A-MEM, Claude memory tool) đều lặp lại đúng 3 bước này — chỉ khác nhau ở **ai quyết định** write/read (code cứng hay để model tự issue function-call) và **tổ chức dữ liệu** ra sao (phẳng, phân tầng, hay dạng đồ thị liên kết).

## 4. Hai kiến trúc tham chiếu cụ thể

### MemGPT / Letta — "LLM như một Operating System"

Paper **MemGPT: Towards LLMs as Operating Systems** (Packer et al., 2023, arXiv:2310.08560) là công trình phổ biến hoá framing "agent memory" hiện đại, dùng ẩn dụ OS:

- **Main context** (trong prompt) ≈ RAM — nhanh nhưng nhỏ.
- **Archival storage** (ngoài prompt, được truy vấn) ≈ đĩa cứng — lớn nhưng chậm hơn.
- Điểm mấu chốt: chính **model tự issue function-call** (tự gọi tool) để quyết định đưa gì vào RAM, đẩy gì ra đĩa — gọi là "virtual context management" (quản lý context ảo), lấy cảm hứng từ cơ chế **paging** của OS (kỹ thuật hệ điều hành tự động hoán đổi dữ liệu giữa RAM và đĩa khi RAM đầy).

Letta (framework kế thừa MemGPT) hiện thực hoá thành 3 tầng cụ thể hơn:

| Tầng | Vai trò | Ẩn dụ | Cách agent thao tác |
|---|---|---|---|
| Core Memory | Luôn nằm trong context, được ghim | RAM | `core_memory_append` / `core_memory_replace` |
| Recall Memory | Lịch sử hội thoại cũ, tìm kiếm được | Disk cache | truy vấn theo yêu cầu |
| Archival Memory | Kho lưu trữ ngoài, dài hạn | Cold storage | `archival_memory_insert` / `archival_memory_search` |

### Anthropic memory tool + context editing

Claude Platform cung cấp `memory_20250818` (memory tool, phát hành 29/9/2025) — cho phép Claude đọc/ghi file trong thư mục `/memories`, tồn tại bền vững qua nhiều phiên (hỗ trợ create, read, update, delete).

- Đây là tool **client-side**: bản thân model **không lưu gì** — Claude chỉ *yêu cầu* thao tác file, còn ứng dụng của bạn (harness) mới thực sự đọc/ghi đĩa. Theo Anthropic: "Claude requests file operations, and your application executes them... memory lives entirely in your application" (confidence: high).

- Đi kèm là **context editing**: tự động dọn các tool-result/nội dung cũ đã hết giá trị khỏi context window.
- Trên benchmark web-search 100 lượt, kết hợp memory tool + context editing giúp tiết kiệm **84% token** và cải thiện **39% hiệu năng** so với baseline không có 2 cơ chế này (confidence: high, số liệu từ Anthropic).
- Đây là ví dụ cụ thể cho việc "long-term memory (persist)" và "forgetting/compression (context editing)" là 2 cơ chế bổ trợ nhau, không phải 1 cơ chế duy nhất.

## 5. Memory khác RAG ở đâu

Cả hai đều dùng kỹ thuật truy xuất tương tự (embedding + similarity search), nhưng khác mục đích và vòng đời dữ liệu:

- **RAG** (retrieval-augmented generation) thường build index trên tài liệu **tĩnh**, ingest offline, ít cần cập nhật (VD: toàn bộ docs sản phẩm).
- **Agent/dialog memory** liên tục index thông tin trích ra từ tương tác **sống** (mỗi lượt hội thoại mới), đòi hỏi cập nhật index thường xuyên, gần real-time (confidence: medium).

Semantic long-term memory trong LangChain thực chất thường triển khai bằng chính cơ chế RAG (lưu vector, truy xuất theo similarity) — nghĩa là RAG là một *cách hiện thực hoá* semantic memory, không phải khái niệm tách biệt.

## 6. Các hướng tổ chức memory mới hơn: A-MEM

Paper **A-MEM: Agentic Memory for LLM Agents** (Xu et al., 2025, arXiv:2502.12110) không dùng taxonomy short-term/long-term/episodic/semantic kể trên, mà đề xuất một cách tổ chức khác: mỗi memory mới được lưu thành 1 "note" kiểu **Zettelkasten** (một phương pháp ghi chú liên kết chéo giữa các note, giống một wiki cá nhân — note mới có thể tự trỏ tới note cũ liên quan) — có mô tả ngữ cảnh, keyword, tag — và có thể tự động kích hoạt cập nhật/liên kết tới các memory cũ liên quan, tạo thành mạng lưới tri thức tiến hoá dần thay vì lưu trữ phẳng cố định. Nên coi đây là **một cách kiến trúc hoá bộ nhớ** (memory organization pattern), không phải định nghĩa gốc của khái niệm agent memory.

## 7. Ví dụ cụ thể: ChatGPT memory

ChatGPT (OpenAI) minh hoạ rõ ranh giới short-term/long-term ở mức sản phẩm:

- **Saved Memories**: fact/preference tường minh, user có thể xem/xoá — tương đương semantic memory được ghi thủ công hoặc do model đề xuất ghi.
- **Chat History reference** (từ 4/2025): model có thể tham chiếu lại *toàn bộ* các cuộc hội thoại cũ để trả lời liên quan hơn — tương đương episodic memory ở quy mô toàn tài khoản.
- Cả hai đều opt-in và người dùng kiểm soát được (bật/tắt/xoá).

## 8. Liên hệ tới các phần khác

- Agent memory là điều kiện để [[agent-loop]] có thể chạy nhiều vòng lặp mà vẫn "nhớ" bước trước — nếu không có memory, mỗi vòng perceive→reason→act→observe sẽ mất hết ngữ cảnh của vòng trước.
- Kích thước context window (xem [[llm-context-window]]) chính là giới hạn vật lý buộc phải có compression/forgetting strategy — không thể nhét mọi thứ đã lưu vào 1 prompt.
- Xem [[ai-engineer-roadmap]] để biết vị trí của agent memory trong lộ trình tổng thể (mục "Agent Memory").

### Áp dụng với Claude Code

Claude Code (CLI) là một hệ thống thực tế minh hoạ gần như trọn vẹn các khái niệm ở trên:

- Mỗi phiên Claude Code bắt đầu với context window **trống hoàn toàn** — đúng với giả định "LLM stateless" ở mục 1; không có gì tự động tồn tại giữa các phiên trừ khi được ghi vào file (confidence: high).
- **CLAUDE.md**: đóng vai trò semantic/procedural memory được **người curate thủ công** — nạp toàn bộ nội dung (theo thứ tự ưu tiên managed policy > user > project > local) vào đầu mỗi phiên dưới dạng user message (không nằm trong system prompt, nên mức tuân thủ mang tính xác suất, không phải ràng buộc cứng).
- **Auto memory**: là long-term memory **do Claude tự quyết định ghi** (build command, insight khi debug, sở thích user...) — lưu tại `~/.claude/projects/<project>/memory/`, có file index `MEMORY.md` (giới hạn 200 dòng / 25KB, luôn nạp) và các file chủ đề riêng (chỉ nạp khi cần) — đây là ví dụ sản phẩm cụ thể cho pattern "summarization/compression + tái nạp có chọn lọc" ở mức định nghĩa gốc.
- Auto memory **không đồng bộ cloud**, chỉ tồn tại local theo máy, và scope theo git repo (dùng chung giữa các worktree của cùng repo) — tức đây là external store do harness quản lý, không phải năng lực của bản thân model.
- **Subagent** mặc định **không kế thừa** auto memory của phiên chính (context isolation) — trừ khi được "fork" từ phiên hiện tại, hoặc được cấu hình một thư mục memory riêng qua field `memory`.
- **Compaction (`/compact`)**: CLAUDE.md ở root project **sống sót** qua compaction (được đọc lại từ đĩa và tái nạp); nhưng CLAUDE.md lồng nhau (nested) hoặc path-scoped rule thì **không** tự tái nạp — chỉ nạp lại khi file tương ứng được đọc lần kế tiếp. Đây là ví dụ thực tế cho việc memory và forgetting/compaction tương tác với nhau không hoàn toàn đối xứng.
- Claude Code **không dùng** memory tool API chính thức (`memory_20250818`) — nó có logic đọc/ghi memory riêng (bespoke) trong harness, dù về khái niệm tương đồng với memory tool ("just-in-time context retrieval").

**Nếu tự xây memory cho agent của riêng bạn**, có thể rút ra template 3 bước từ chính Claude Code (khớp với ví dụ ở mục 3):

1. **Chọn nơi lưu (store)** — Claude Code chọn file phẳng trên đĩa; bạn có thể chọn file, một bảng Postgres, hay một vector store, tuỳ quy mô.
2. **Định nghĩa rõ điều kiện ghi** — Claude Code để chính model tự quyết định khi nào đáng ghi (auto memory); cách đơn giản hơn để bắt đầu là dùng rule cứng (VD: ghi mỗi khi user nói "nhớ giúp tôi...").
3. **Định nghĩa rõ điều kiện đọc** — Claude Code phân tầng: `MEMORY.md` luôn nạp (như Core Memory ở mục 4), các file chủ đề riêng chỉ nạp khi cần (như Recall/Archival Memory) — đây là đánh đổi kinh điển giữa "luôn có sẵn, tốn context window" và "tiết kiệm context, phải truy xuất đúng lúc".

## 9. Giới hạn / open questions

- Chưa có số liệu định lượng rõ ràng về hiệu quả của A-MEM (Zettelkasten-style) so với kiến trúc tầng đơn giản (MemGPT/Letta) trên benchmark chung — cần đọc kỹ phần evaluation của paper để so sánh trực tiếp.
- Ranh giới giữa "agent memory" và "RAG" trong thực tế triển khai còn khá mờ khi semantic memory được hiện thực bằng chính pipeline RAG — cần thêm ví dụ code cụ thể để phân biệt rạch ròi hơn.
- Chưa rõ chi tiết thuật toán mà Claude Code auto-memory dùng để quyết định "cái gì đáng nhớ" (heuristic gì, có dùng LLM riêng để tóm tắt không) — tài liệu chính thức mới mô tả hành vi bề ngoài, chưa mô tả cơ chế nội bộ.
- Chưa khảo sát sâu forgetting strategies (TTL, xoá theo độ liên quan, xoá thủ công) ngoài ví dụ context-editing của Anthropic — đây có thể là 1 sub-topic riêng cần note khác.
