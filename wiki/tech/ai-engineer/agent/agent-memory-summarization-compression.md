---
status: current
updated: 2026-08
sources:
  - https://code.claude.com/docs/en/context-window
  - https://code.claude.com/docs/en/costs
  - https://code.claude.com/docs/en/model-config#set-the-auto-compact-window
  - https://code.claude.com/docs/en/how-claude-code-works
  - https://www.anthropic.com/engineering/effective-context-engineering-for-ai-agents
  - https://platform.claude.com/docs/en/build-with-claude/compaction
  - https://arxiv.org/abs/2310.08560
  - https://arxiv.org/abs/2308.15022
  - https://api.python.langchain.com/en/latest/langchain/memory/langchain.memory.summary.ConversationSummaryMemory.html
  - https://www.pinecone.io/learn/series/langchain/langchain-conversational-memory/
  - https://www.sei.cmu.edu/blog/evaluating-llms-for-text-summarization-introduction/
  - https://gist.github.com/badlogic/cd2ef65b0697c4dbe2d13fbecb0a0a5f
  - https://okhlopkov.com/claude-code-compaction-explained/
  - https://m.academy/lessons/compact-conversations-claude-code/
  - https://mem0.ai/blog/llm-chat-history-summarization-guide-2025
  - https://mem0.ai/blog/rag-vs-ai-memory
  - https://vectorize.io/articles/agent-memory-vs-rag
  - https://deepwiki.com/anthropics/claude-cookbooks/6.3-context-management-and-compaction
  - https://github.com/bgauryy/open-docs/blob/main/docs/claude-agent-sdk/memory-and-context.md
roadmap: ai-engineer
stage: learning
---

# Summarization / Compression — nén hội thoại cũ thành bản tóm tắt ngắn hơn để giữ context trong giới hạn

TL;DR: Khi hội thoại dài dần và sắp vượt context window, hệ thống định kỳ thay một khối message cũ bằng một **summary** do chính LLM sinh ra (giữ lại facts/decisions quan trọng, bỏ chi tiết dư thừa) — thay vì cắt cứng (**truncation**, mất thông tin âm thầm) hoặc cứ để prompt phình to mãi (tốn chi phí/latency, cuối cùng vẫn vỡ giới hạn).

## Hành động nhanh (áp dụng ngay trong Claude Code)

- Chủ động chạy `/compact` thủ công quanh mốc **~60% context usage**, đừng đợi auto-compact (~95%) — summary sẽ chất lượng hơn vì nén một context chưa quá tải.
- Đặt các rule/instruction bắt buộc phải giữ vào **CLAUDE.md**, không nên chỉ gõ ở đầu hội thoại — chi tiết nói sớm rất dễ bị compact bỏ qua.
- Dùng `/compact focus on X` khi muốn định hướng summary giữ lại đúng phần đang cần (vd một file, một bug cụ thể).
- Dùng `/context` để xem trước usage/buffer còn lại; dùng `/clear` khi muốn xóa sạch hẳn (khác `/compact` — không giữ gist gì cả).

Phần còn lại của note giải thích *vì sao* các thao tác trên hoạt động, cộng thêm bối cảnh học thuật/vendor cho ai muốn tự xây cơ chế memory riêng — có thể bỏ qua nếu chỉ cần dùng Claude Code hằng ngày.

## Vấn đề cần giải quyết

- **Short-term memory** ([[agent-memory-short-term]]) là toàn bộ lịch sử hội thoại được gửi lại kèm mỗi lần gọi model — nó không tự "quên" gì cả, chỉ có 2 số phận nếu không can thiệp:
  - Gửi lại **toàn bộ** lịch sử mỗi lượt → chi phí + latency tăng dần, cuối cùng vượt context window ([[llm-context-window]]).
  - **Truncation**: cắt bỏ các turn cũ nhất một cách máy móc → mất thông tin âm thầm, không kiểm soát được cái gì bị bỏ.
- **Summarization/Compression** là kỹ thuật thứ ba: định kỳ lấy một khối message cũ, cho LLM tóm tắt thành một đoạn ngắn hơn nhiều nhưng vẫn giữ được "gist" — ý định người dùng, quyết định kỹ thuật, lỗi đã sửa, việc đang dang dở — rồi thay khối cũ bằng bản tóm tắt đó trong context tiếp theo.
- Phân biệt với summarization của **long-term memory** ([[agent-memory-long-term]]): long-term memory trích xuất **facts bền vững** để lưu trữ *xuyên session* (vector DB, file, SQL); còn compression ở đây chỉ nhằm giữ *session hiện tại* nằm trong ngân sách context — dù cơ chế tóm tắt (một lời gọi LLM) thường được tái sử dụng cho cả hai mục đích.

## Cơ chế hoạt động chung

- **Trigger** (khi nào chạy): theo threshold token — vd ~95% context limit, hoặc một ngưỡng cấu hình được như 150k input token — hoặc theo lệnh thủ công của người dùng.
- **Quá trình**: gửi toàn bộ (hoặc phần cũ của) lịch sử hội thoại cho LLM, yêu cầu sinh một bản tóm tắt có cấu trúc theo một prompt cố định, đại loại:

  ```
  Tóm tắt hội thoại trên, giữ lại:
  - user requests/intent (mục tiêu ban đầu là gì)
  - technical concepts / decisions đã chốt
  - files đã đọc/sửa (kèm đoạn code quan trọng nếu có)
  - lỗi đã gặp và cách đã sửa
  - việc còn dang dở (pending tasks) và bước tiếp theo
  Bỏ qua: tool output đầy đủ, reasoning trung gian không còn cần thiết.
  ```

- **Thay thế**: bản tóm tắt trở thành điểm khởi đầu mới của context; nội dung gốc trước đó bị bỏ (một số hệ thống vẫn giữ bản đầy đủ ở nơi khác để tra cứu — xem phần MemGPT bên dưới).
- **Đánh đổi cố hữu**: bản thân lệnh tóm tắt cũng là một request tốn token (phải đọc lại toàn bộ context cũ để nén nó). Độ trung thực (**faithfulness** — summary có phản ánh đúng, không bịa thêm không) luôn thấp hơn 100%, luôn có rủi ro làm mất chi tiết quan trọng (một constraint đã quyết định, một file đang sửa dở...).
- Nguyên tắc điều chỉnh prompt tóm tắt theo Anthropic: tối ưu **recall trước, precision sau** — tức thà giữ dư còn hơn bỏ sót; nén quá tay (mất thông tin quan trọng) nguy hiểm hơn nén không đủ (as of anthropic.com, confidence: high).

## Ví dụ: trước và sau khi tóm tắt

Một đoạn hội thoại dài ~30 turn về việc sửa bug login có thể được nén như sau:

**Trước** (30 turns, ~18k token): toàn bộ log debug, các lần đọc file `auth.ts`, `session.ts`, vài lần thử sai, output đầy đủ của mỗi lệnh test.

**Sau** (1 đoạn summary, ~200 token):
```
State: Đang sửa bug "session hết hạn sớm" trong auth.ts.
Nguyên nhân: TTL token set nhầm đơn vị (giây thay vì mili-giây), dòng 42.
Đã sửa: đổi TTL sang mili-giây, thêm test session-expiry.test.ts (đã pass).
Còn dang dở: chưa cập nhật doc API nói rõ TTL tính bằng gì.
Next step: sửa docs/api/session.md, rồi chạy lại toàn bộ test suite auth.
```

Đây chính là dữ liệu mà `/compact` của Claude Code sinh ra và dùng làm điểm khởi đầu context mới — phần "trước" bị bỏ hẳn khỏi context, chỉ còn "sau".

## Ví dụ cụ thể: /compact trong Claude Code

- Lệnh `/compact` đọc toàn bộ hội thoại, cho Claude sinh summary (theo mẫu ở ví dụ trên), tạo một "compact boundary" và chèn summary đó làm context mới thay cho lịch sử gốc.
- Có thể định hướng nội dung giữ lại bằng `/compact focus on X` hoặc mục "Compact Instructions" trong CLAUDE.md.
- **Auto-compact**: tự động kích hoạt khi context đạt ngưỡng cấu hình được (`/autocompact <token-count>`). Cộng đồng ước tính ngưỡng mặc định rơi vào khoảng ~95% dung lượng context — Anthropic chưa công bố con số chính thức này (as of m.academy, confidence: medium).
- Vì auto-compact chờ đến gần giới hạn mới nén (context đã quá tải), best practice là chủ động chạy `/compact` thủ công sớm hơn, vd quanh ~60% utilization, để summary chất lượng hơn.
- `/context` cho xem breakdown usage theo category kèm buffer dành cho auto-compact; `/clear` xóa sạch về 0 token (khác hẳn `/compact` — xóa hoàn toàn, không giữ gist).
- Chi tiết bị mất khi compact: skill description nạp lúc khởi động sẽ **không** được tự động chèn lại sau `/compact` (chỉ skill nào thực sự được gọi trong session mới sống sót) — minh chứng compression là chọn lọc, không phải copy đầy đủ.
- Nếu context bị "refill" ngay sau một lần compact (thường do một tool output/file cực lớn), Claude Code sẽ ngừng auto-compact lặp vô hạn và báo lỗi thay vì loop mãi.

### Bảng so sánh nhanh các implementation

Tham khảo khi cần chọn/so sánh chiến lược compaction giữa các công cụ — không bắt buộc phải nhớ nếu chỉ dùng Claude Code:

| Công cụ | Trigger | Đặc điểm |
|---|---|---|
| Claude Code `/compact` | thủ công hoặc ~95% context | giữ file/decisions/state, bỏ tool output; có thể chỉnh hướng bằng CLAUDE.md |
| Claude API `compaction` (beta) | mặc định 150k input token (min 50k) | server-side, trả về content block `compaction`, client phải resend block này để giữ liên tục |
| OpenAI Codex CLI | vượt `model_auto_compact_token_limit` (~180k–244k tùy model, margin ~95%) | tái tạo state = initial context + ~20k token gần nhất + summary |
| OpenCode | thủ công hoặc `isOverflow()` | có thêm bước "**prune**" riêng (dọn bớt, không tóm tắt): bỏ tool output cũ > ~40k token, tách biệt summary chi tiết vs summary 2 câu để hiển thị UI |
| Sourcegraph Amp | không có auto-compaction | dùng "Handoff" thủ công — người dùng nêu mục tiêu, Amp trích riêng phần liên quan sang thread mới, chủ trương giữ hội thoại ngắn thay vì tự nén |

## Nguồn gốc học thuật và các implementation khác

> Phần này dành cho ai muốn tự xây cơ chế memory cho agent của mình; nếu chỉ dùng Claude Code có thể bỏ qua.

- **MemGPT** (Packer et al., arXiv:2310.08560, 2023): coi context window như "main memory" tốc độ cao trong mô hình phân cấp bộ nhớ kiểu OS. Khi cần "**evict**" (đẩy ra khỏi context) một message cũ, hệ thống sinh một **recursive summary**: `summary mới = summary cũ + các message bị evict`. Toàn bộ lịch sử gốc vẫn được lưu riêng ở "recall memory" ngoài context để tra cứu lại khi cần — đây là điểm khác `/compact` (vốn không giữ bản gốc). Pseudocode rút gọn:
  ```
  if tokens_in_context > threshold:
      evicted = pop_oldest_messages(context)
      summary = llm_summarize(prompt="giữ state/next-steps/learnings", 
                               input=summary + evicted)
      context = [summary] + remaining_messages
      recall_memory.append(evicted)  # vẫn lưu bản gốc để tra cứu
  ```
- **Recursively Summarizing Enables Long-Term Dialogue Memory** (Wang et al., arXiv:2308.15022, 8/2023): tóm tắt từng đoạn hội thoại nhỏ rồi đệ quy gộp với summary trước đó — một trong những bài sớm nhất đặt tên kỹ thuật này cho long-conversation memory, đi trước MemGPT khoảng 2 tháng.
- **LangChain `ConversationSummaryBufferMemory`**: kết hợp buffer thô cho các turn gần nhất với một running summary cho các turn cũ hơn, chuyển sang summary khi vượt ngưỡng token (không phải số turn cố định) — minh họa pattern phổ biến: **summarization + sliding window** đi cùng nhau, hiếm khi dùng summarization đơn độc.
- **Claude Agent SDK**: có tham số `compaction_control` để tự tóm tắt theo ngưỡng token. Tham số này đã bị **deprecated** ở SDK Python/TypeScript/Ruby; khuyến nghị hiện tại là chuyển sang dùng trực tiếp tính năng `compaction` server-side của Claude API (xem phần ví dụ số bên dưới). SDK còn có "**context editing**" (xóa `tool_result` cũ — một dạng eviction, khác summarization vì không sinh bản tóm tắt) và subagent (con trả về summary cho parent, không lộ toàn bộ transcript).

## Kỹ thuật liên quan nhưng không phải summarization

- **Sliding window**: chỉ giữ N turn gần nhất, bỏ hẳn phần còn lại — rẻ nhưng mất thông tin âm thầm giống truncation, không sinh ra bản tóm tắt.
- **RAG / retrieval-based memory**: về bản chất là read-only, stateless — index tài liệu một lần rồi truy vấn theo từng turn, không có write path và không cần nén hội thoại; phù hợp cho Q&A tri thức tĩnh, single-turn. Summarization/compression thì có write path chủ động (trích + cập nhật facts theo thời gian) và nhắm vào hội thoại nhiều turn, kéo dài — hai kỹ thuật thường được kết hợp chứ không thay thế nhau.
- **Vectorized memory**: embed các turn cũ, truy xuất theo similarity khi cần — khác summarization ở chỗ không nén nội dung, chỉ lọc/truy xuất theo nhu cầu.

## Đánh giá chất lượng summary

> Dành cho ai cần đo/so sánh chất lượng summary của một hệ thống tự xây; nếu chỉ dùng `/compact` có thể bỏ qua phần này.

Theo khung của SEI/CMU (viết gốc cho tóm tắt tài liệu, áp dụng được cho tóm tắt hội thoại) — 5 tiêu chí, mỗi tiêu chí trả lời một câu hỏi cụ thể:
- **Accuracy** — summary có bao nhiêu nội dung trùng với bản gốc? (đo bằng ROUGE/BLEU/BERTScore)
- **Faithfulness** — summary có bịa thêm chi tiết không có trong bản gốc không? (đo bằng SummaC, QAFactEval)
- **Compression ratio** — nén được bao nhiêu lần (vd 18k token → 200 token là ~90x)?
- **Extractiveness** — summary trích nguyên câu gốc hay viết lại hoàn toàn (**abstractive**)? Viết lại càng nhiều thì rủi ro sai lệch càng cao.
- **Efficiency** — chi phí tính toán để sinh summary.

Rủi ro thực tế được ghi nhận: chất lượng summary có thể **suy giảm dần qua nhiều lần compact liên tiếp** (lossy compression tích lũy), và nếu auto-compact kích hoạt giữa chừng một task phức tạp, agent có thể "đi lạc hướng" vì mất chi tiết quan trọng.

## Ví dụ minh họa bằng số

- Claude API `compaction` (beta): mặc định trigger ở **150,000 input token** (cấu hình được, tối thiểu 50,000). Khi vượt ngưỡng, API tự chèn một lượt tóm tắt, bọc kết quả trong content block `compaction`, và ở các request tiếp theo tự động drop toàn bộ nội dung *trước* block đó — client phải resend chính block `compaction` để giữ tính liên tục (as of platform.claude.com, confidence: high).
- Vendor benchmark (Mem0, tự công bố, chưa kiểm chứng độc lập): tuyên bố cải thiện ~26% chất lượng phản hồi kèm giảm >90% token usage so với gửi full history; một case study ứng dụng giáo dục báo cáo giảm ~40% chi phí token khi chuyển từ replay toàn bộ lịch sử sang summarization/selective-memory (as of mem0.ai, confidence: low — đây là số liệu marketing, nên đối chiếu thêm trước khi dùng để ra quyết định).

## Liên hệ tới các phần khác

- Liên quan trực tiếp tới [[agent-memory-short-term]] — summarization là kỹ thuật chính để giữ short-term memory trong giới hạn khi session kéo dài.
- Khác với [[agent-memory-long-term]] ở phạm vi (trong-session vs xuyên-session) dù cơ chế tóm tắt có thể tái dùng.
- Gắn liền với [[llm-context-window]] — đây chính là ràng buộc mà summarization cố gắng tôn trọng.

### Áp dụng với Claude Code

Có áp dụng trực tiếp và là một trong những implementation phổ biến nhất của kỹ thuật này:
- `/compact` (thủ công) và auto-compact (khi gần chạm giới hạn context, ước tính ~95%) đều dùng chính LLM để sinh summary thay cho lịch sử cũ.
- Có thể tùy chỉnh qua `/compact focus on X` hoặc mục "Compact Instructions" trong `CLAUDE.md`.
- `/context` cho xem usage; `/clear` là thao tác khác hẳn (xóa sạch, không tóm tắt).
- Các rule/instruction quan trọng nên đặt trong CLAUDE.md thay vì trông chờ chúng "sống sót" qua nhiều lần compact, vì compact có thể làm mất chi tiết instruction sớm trong hội thoại.
- Ngoài compact, Claude Code còn dùng subagent (bắt đầu context trống, chỉ trả summary về parent) như một chiến lược **cấu trúc** bổ sung để giữ context chính nhỏ — khác về bản chất so với compression (né việc nạp chi tiết vào context chính ngay từ đầu, thay vì nén sau).
- Summarization cũng được dùng cho `claude --resume` (tóm tắt session cũ ở background) — một use case tách biệt với `/compact` trong-session.

## Giới hạn / open questions

- Chưa có số liệu benchmark độc lập (ngoài vendor) đo faithfulness/compression ratio thực tế của `/compact` Claude Code hay compaction API trên các loại task khác nhau.
- Ngưỡng auto-compact chính xác (~95%) là ước tính từ reverse-engineering cộng đồng, chưa phải con số chính thức được Anthropic công bố rõ ràng cho mọi phiên bản.
- Chưa rõ mức độ ảnh hưởng của nhiều lần compact liên tiếp (cumulative lossy compression) tới hiệu năng agent trong các task dài thực tế — hiện chỉ có báo cáo giai thoại (anecdotal).
- Số liệu Mem0 (26% quality improvement, >90% token reduction, ~40% cost reduction) là tự công bố từ vendor, độ tin cậy thấp, cần đối chiếu thêm nguồn độc lập.
- Chưa khảo sát sâu cách các framework khác (LangGraph, LlamaIndex, AutoGen...) implement compression so với LangChain `ConversationSummaryBufferMemory`.

**Ghi chú độ tin cậy nguồn** (tổng hợp thay vì gắn tag ở từng đoạn):
- Guidance chính thức từ Anthropic (recall-trước-precision-sau, cơ chế `compaction` API): confidence cao.
- Các con số vận hành cụ thể của Claude Code (ngưỡng auto-compact ~95%, việc `compaction_control` bị deprecated) đến từ reverse-engineering cộng đồng (gist.github.com/badlogic, m.academy, deepwiki) chứ không phải doc chính thức: confidence trung bình.
- Số liệu benchmark của Mem0 là tự công bố từ vendor, chưa có đối chiếu độc lập: confidence thấp.
