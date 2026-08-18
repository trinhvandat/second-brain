---
status: current
updated: 2026-08
sources:
  - https://platform.claude.com/docs/en/build-with-claude/working-with-messages
  - https://developers.openai.com/api/docs/guides/conversation-state
  - https://docs.langchain.com/oss/python/langchain/short-term-memory
  - https://arxiv.org/abs/2310.08560
  - https://mem0.ai/blog/context-window-is-ram-not-storage-why-most-agent-failures-happen-how-to-fix-them-in-2026
  - https://www.letta.com/blog/rag-vs-agent-memory/
  - https://code.claude.com/docs/en/how-claude-code-works
  - https://code.claude.com/docs/en/context-window
  - https://code.claude.com/docs/en/memory
  - https://platform.claude.com/docs/en/build-with-claude/compaction
  - https://www.anthropic.com/engineering/effective-harnesses-for-long-running-agents
  - https://platform.claude.com/docs/en/agents-and-tools/tool-use/memory-tool
roadmap: ai-engineer
stage: learning
---

# Short-term memory — dữ liệu sống trong context window, mất đi khi session kết thúc

**TL;DR**: Model không tự nhớ gì cả — mỗi lần gọi API, code của bạn phải gửi lại toàn bộ đoạn hội thoại từ đầu, và phần "bộ nhớ" đó chỉ sống được trong giới hạn token của **context window**. **Short-term memory** = chính đoạn hội thoại (+ tool result) đang được gửi đi gửi lại đó; khi nó đầy, hệ thống phải cắt bớt (**trimming**) hoặc tóm tắt (**summarization**) để tiếp tục fit, và toàn bộ biến mất khi session kết thúc trừ khi được ghi chủ động ra bộ nhớ dài hạn.

**Vì sao quan trọng**: Nếu bạn tự build agent (LangChain, Claude Agent SDK, hay tự viết loop gọi API), bạn — không phải model — chịu trách nhiệm quản lý phần này. Không hiểu cơ chế này thì rất dễ gặp 2 lỗi kinh điển: (1) agent "quên" thông tin vài lượt trước vì bạn quên gửi lại, hoặc (2) chi phí token tăng phi mã vì gửi lại nguyên văn lịch sử ngày càng dài mà không cắt/tóm tắt.

## 1. Cơ chế: không có "bộ nhớ" thật, chỉ có gửi lại toàn bộ lịch sử

- **Claude Messages API là stateless**: tài liệu chính thức nói thẳng "The Messages API is stateless, which means that you always send the full conversational history to the API" — server không nhớ gì giữa các request, multi-turn chỉ tồn tại vì client tự gửi lại toàn bộ mảng `messages` mỗi lần gọi.
- **OpenAI Responses API cùng pattern**: "each text generation request is independent and stateless" — ứng dụng phải tự thêm các output item trước đó (kể cả reasoning item) vào history gửi kèm request mới.
- Hệ quả: short-term memory KHÔNG phải database, cache, hay session store riêng — nó chỉ là **payload request** được lắp lại từ đầu mỗi lượt gọi. Bất kỳ framework nào (LangChain, LangGraph, Agent SDK) tự nhận "quản lý memory" ở tầng ngắn hạn thực chất chỉ đang giữ và tái-inject list message này.
- LangChain gọi đơn vị chứa các lượt hội thoại này là **thread** (nghĩ đơn giản: 1 thread = 1 cuộc hội thoại/1 phiên làm việc, giống 1 email thread gom các reply lại). Thread được lưu tạm qua một cơ chế gọi là **checkpointer** (nghĩ đơn giản: nơi lưu trạng thái thread giữa các lượt gọi, để có thể resume đúng chỗ đang dừng) — checkpointer chỉ phục vụ khả năng resume trong phiên đó, không phải kho lưu trữ lâu dài.

## 2. Bị giới hạn bởi context window, và cách xử lý khi đầy

- **Context window** = tổng số token tối đa 1 request có thể dùng (input + output, có nơi tính cả reasoning token). Toàn bộ short-term memory phải nằm gọn trong con số này.
- Ví dụ cụ thể (2026): Claude Haiku 4.5 giới hạn 200K token; Claude Opus 4.8 / Sonnet 5 hỗ trợ tới 1M token (500K qua chat UI, 1M qua Claude Code/API). Khi window đầy, nội dung cũ nhất bị loại bỏ trước.
- Trong agent loop (không phải chat đơn thuần), vấn đề trầm trọng hơn: mỗi tool call mới phải gửi kèm lại toàn bộ tool result trước đó, nên token tiêu thụ tăng gần như bậc hai theo số vòng lặp — khoảng 50 lần gọi tool có thể đủ để lấp đầy một context window 200K token (confidence: low, nguồn thứ cấp — chưa kiểm chứng độc lập).
- Hai chiến lược ứng phó chuẩn (LangChain đặt tên rõ ràng) — chọn cái nào tuỳ tình huống:
  - **Trimming/deletion**: xoá message cũ nhất, chỉ giữ N lượt gần nhất. Dùng khi chi tiết cũ không còn quan trọng (ví dụ: chat hỗ trợ khách hàng, mỗi câu hỏi độc lập).
  - **Summarization**: dùng chính 1 lời gọi LLM để nén lịch sử cũ thành bản tóm tắt, giữ lại thông tin quan trọng thay vì mất trắng. Dùng khi cần giữ ngữ cảnh xuyên suốt (ví dụ: agent làm 1 task dài nhiều bước, coding agent).
- Pseudocode minh hoạ 2 chiến lược (tương ứng `trim_messages` và summarization node trong LangChain):

```python
# Trimming: chỉ giữ N message gần nhất (đơn giản, mất chi tiết cũ)
def trim_history(messages, max_tokens=100_000):
    kept = []
    total = 0
    for m in reversed(messages):  # từ mới nhất lùi về cũ
        total += count_tokens(m)
        if total > max_tokens:
            break
        kept.insert(0, m)
    return kept

# Summarization: khi vượt ngưỡng, gọi thêm 1 lần LLM để nén phần cũ
def summarize_if_needed(messages, threshold=100_000):
    if count_tokens(messages) < threshold:
        return messages
    old, recent = messages[:-10], messages[-10:]  # giữ 10 lượt gần nhất nguyên văn
    summary = llm_call(f"Tóm tắt hội thoại sau: {old}")
    return [{"role": "system", "content": summary}] + recent
```

## 3. Phân biệt với long-term memory

| | Short-term memory | Long-term memory |
|---|---|---|
| Nơi sống | Trong context window, gửi lại mỗi request | Ngoài context window — DB, vector store, file |
| Phạm vi | 1 session/thread | Xuyên nhiều session, nhiều thread |
| Cách lấy lại | Luôn có mặt (vì được gửi lại nguyên vẹn) | Phải retrieval chọn lọc rồi mới inject vào context |
| Khi session kết thúc | Mất hoàn toàn nếu không ghi ra ngoài | Vẫn còn |

- LangChain nêu rõ: "Need to remember information across conversations? Use long-term memory to store and recall user-specific or application-level data across different threads and sessions."
- Ẩn dụ hay dùng trong ngành: context window ≈ **RAM** (nhanh, dễ truy cập nhưng hữu hạn và mất khi tắt máy), long-term storage ≈ **disk** (chậm hơn nhưng bền, gần như không giới hạn).
- **RAG không phải là "memory"**: RAG là truy vấn phản ứng (reactive), 1-lần-1-query dựa trên cosine similarity vào 1 corpus tĩnh, không có khái niệm "đã từng nhớ điều gì trước đó" — khác cả short-term memory (trạng thái hội thoại đang chạy) lẫn long-term memory thật (chủ động tổ chức và gợi nhớ thông tin xuyên session). Ví dụ: nếu user nói thích màu xanh và phim X ở lượt trước, RAG semantic search cho câu hỏi không liên quan "lên kế hoạch sinh nhật" sẽ không kéo được 2 fact đó ra vì embedding không đủ gần nghĩa.

## 4. Bối cảnh nghiên cứu/nguồn gốc

- Không có 1 paper định nghĩa "short-term memory" cho LLM agent, nhưng hình thức hoá có ảnh hưởng nhất là **MemGPT** (Packer et al., arXiv:2310.08560, 2023): coi context window như RAM/"main context" (FIFO cố định kích thước — luôn chứa full lịch sử gần nhất) đối lập với 2 tầng lưu trữ ngoài — "**recall memory**" (log đầy đủ, tìm lại được bằng search) và "**archival memory**" (kho lưu trữ dài hạn, có cấu trúc hơn) — được "paged in" (nạp lại vào context khi cần) giống cơ chế virtual memory của hệ điều hành.
- Framing này (main context = ngắn hạn, external context = dài hạn) sau đó được các vendor như Mem0, LangChain dùng lại gần như nguyên vẹn.

## 5. Ví dụ cụ thể

Một cuộc hội thoại 3 lượt với 1 model stateless — mỗi API call phải gửi lại TOÀN BỘ history trước đó, không chỉ tin nhắn mới nhất:

```
Call 1: messages = [ {user: "Tên tôi là An"} ]
        → response: {assistant: "Chào An!"}

Call 2: messages = [
          {user: "Tên tôi là An"},
          {assistant: "Chào An!"},
          {user: "Tôi thích cà phê"}
        ]
        → response: {assistant: "Ghi nhận, An thích cà phê."}

Call 3: messages = [ ...toàn bộ 4 message trên..., {user: "Tôi tên gì?"} ]
        → response: {assistant: "Bạn tên An."}
```

Nếu ứng dụng KHÔNG lưu và gửi lại 2 message đầu ở Call 3, model sẽ không biết "An" là ai — vì bản thân model không giữ trạng thái gì giữa các lần gọi. Đây chính là "short-term memory" trong thực tế: dữ liệu do client quản lý và tái-inject, không phải do model tự nhớ.

## Liên hệ tới các phần khác

- [[agent-memory-what-is-agent-memory]] — bức tranh tổng quan về agent memory, trong đó short-term chỉ là 1 trong các loại.
- [[llm-context-window]] — giới hạn kỹ thuật (số token) quyết định short-term memory chứa được bao nhiêu.
- [[agent-loop]] — mỗi vòng lặp perceive→reason→act→observe đều đọc/ghi vào chính short-term memory này qua bước observe.
- [[ai-engineer-roadmap]] — vị trí của khái niệm này trong lộ trình học agent.

### Áp dụng với Claude Code

- Mỗi session Claude Code bắt đầu với context window hoàn toàn trống — lịch sử từ session trước KHÔNG tự động được nạp lại; các session độc lập với nhau theo thiết kế, trừ khi user chủ động chạy `--continue`/`--resume`.
- Short-term memory ở đây không chỉ là chat turn: nó gồm cả lịch sử hội thoại, nội dung file đã đọc, kết quả tool/command, CLAUDE.md, auto memory đã nạp, skill đã load — tất cả tính chung vào 1 context window.
- Khi context đầy: Claude Code trước tiên dọn bớt tool output cũ, sau đó nếu vẫn cần thì **compact** (tóm tắt) toàn bộ hội thoại — đúng cơ chế trimming-hoặc-summarization ở §2. Lệnh `/compact` thay hội thoại bằng 1 bản tóm tắt có cấu trúc, chỉ hiện 1 dòng "Conversation compacted" — quá trình tóm tắt diễn ra "âm thầm" phía sau.
- Long-term memory tương ứng trong Claude Code là CLAUDE.md + auto memory (MEMORY.md dưới `~/.claude/projects/<project>/memory/`) — được đọc từ disk và nạp lại vào short-term context mỗi khi session mới bắt đầu, đúng pattern "lưu ngoài + retrieval chọn lọc". Chỉ 200 dòng/25KB đầu của MEMORY.md được auto-load, phần còn lại phải đọc theo yêu cầu qua tool `Read`.
- Ở tầng API/Agent SDK (khác Claude Code sản phẩm), Anthropic có tính năng beta gọi là `context_management` (nghĩ đơn giản: cấu hình tự-động-compact ở mức code, thay vì gõ lệnh `/compact` thủ công), phiên bản cụ thể `compact_20260112` — tự động tóm tắt khi input token vượt ngưỡng cấu hình (mặc định 150K). Đây là bản tổng quát hoá ở mức SDK của chính cơ chế Claude Code làm trong sản phẩm. Anthropic cũng khuyến nghị kết hợp compaction (giữ context ngắn hạn gọn) với memory tool/file riêng (giữ thông tin cần sống sót qua nhiều lần tóm tắt) — tức là dùng cả 2 tầng short-term và long-term song song, không phải chọn 1.

## Giới hạn / open questions

- Chưa có số liệu benchmark rõ ràng cho biết chính xác tại ngưỡng token nào chất lượng model bắt đầu suy giảm ("lost in the middle") trước khi chạm giới hạn cứng của context window.
- Con số "~50 lần gọi tool đủ lấp đầy 200K token" (§2) và heuristic "60-70% token trong transcript thực tế là small talk/lặp lại" (Mem0) đều chỉ đến từ nguồn thứ cấp, chưa kiểm chứng độc lập — coi như ước lượng thô, không phải số đo chuẩn.
- Ranh giới giữa "sensory memory" và "working memory" trong short-term memory (cách chia của một số blog vendor) chưa có định nghĩa chuẩn hoá, khác nhau giữa các nguồn.
- Chưa rõ hành vi chi tiết của `context_management`/`compact_20260112` ở production scale (độ trễ, chi phí token của chính bước tóm tắt) ngoài mô tả trong docs beta.
