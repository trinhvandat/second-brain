---
status: current
updated: 2026-08
sources:
  - https://python.langchain.com/docs/how_to/chatbots_memory/
  - https://docs.langchain.com/oss/python/langchain/long-term-memory
  - https://langchain-ai.github.io/langgraph/how-tos/ttl/configure_ttl/
  - https://ar5iv.labs.arxiv.org/html/2304.03442
  - https://arxiv.org/pdf/2310.08560
  - https://www.letta.com/blog/agent-memory/
  - https://mem0.ai/blog/introducing-memory-decay-in-mem0
  - https://mem0.ai/blog/memory-eviction-and-forgetting-in-ai-agents
  - https://arxiv.org/html/2603.07670v1
  - https://www.memorybase.app/blog/chatgpt-memory-full-fix
  - https://arxiv.org/html/2606.10677v1
  - https://platform.claude.com/docs/en/agents-and-tools/tool-use/memory-tool
  - https://platform.claude.com/docs/en/build-with-claude/context-editing
  - https://www.anthropic.com/engineering/effective-context-engineering-for-ai-agents
  - https://www.anthropic.com/news/context-management
  - https://code.claude.com/docs/en/memory
  - https://hidekazu-konishi.com/entry/ai_agent_memory_design_guide.html
roadmap: ai-engineer
stage: learning
---

# Forgetting / Aging Strategies — chủ động loại bỏ memory cũ/ít giá trị để giữ context gọn và hữu ích

TL;DR:
- **Vấn đề**: kho **long-term memory** ([[agent-memory-long-term]]) chỉ tăng theo thời gian nếu không ai chủ động dọn — retrieval bị nhiễu (fact cũ lấn chỗ fact mới), chi phí lưu trữ tăng, và fact lỗi thời có thể bị agent coi là đúng rồi trả lời sai.
- **4 cách fix**: **TTL/expiry** (xoá theo tuổi), **recency-weighted scoring** (ưu tiên bản ghi mới khi ranking), **usage-based decay** (bản ghi ít dùng bị dìm điểm, giống LRU cache), **explicit supersession** (fact mới ghi đè fact cũ cùng chủ đề).
- **Khi nào cần**: chỉ khi kho retrieval là một log agent tự ghi, lớn dần theo turn/session — không cần cho một lệnh gọi LLM đơn lẻ hay RAG trên corpus tĩnh.
- **Đọc trước nếu chưa quen**: note này giả định bạn đã biết khái niệm **long-term memory** ([[agent-memory-long-term]]) và **summarization/compression** ([[agent-memory-summarization-compression]]) — nếu chưa, đọc hai note đó trước vì phần "Vấn đề" bên dưới dựa trên chúng.

## Vấn đề: vì sao memory cần "già đi"

- Kho memory dài hạn (episodic log, user facts) được ghi liên tục qua nhiều session — nếu không xóa/giảm ưu tiên, nó chỉ tăng theo thời gian.
- Hệ quả cụ thể:
  - **Retrieval noise**: càng nhiều candidate, càng nhiều memory cạnh tranh cùng top-K slot, dễ kéo nhầm bản ghi cũ vào context.
  - **Chi phí**: lưu trữ + embedding (vector số hoá text dùng để so khớp ngữ nghĩa) tăng tuyến tính theo số lượng bản ghi.
  - **Sai lệch chủ động (không chỉ trung tính)**: một fact cũ ("user đang làm ở e-commerce", "issue X đang mở") nếu bị retrieve và agent coi là hiện tại, sẽ khiến câu trả lời sai — ví dụ này được nêu rõ trong tài liệu memory của ChatGPT.
- Phân biệt quan trọng với **summarization/compression** ([[agent-memory-summarization-compression]]): summarization **rút gọn nhưng cố giữ thông tin**; forgetting **chủ động loại bỏ thông tin** vì bị đánh giá là không còn giá trị. MemGPT hay bị nhầm là "forgetting" nhưng thực ra gần compression hơn: khi context đầy, nó evict ~50% message cũ khỏi cửa sổ active nhưng vẫn lưu nguyên trong "recall storage" và sinh summary đệ quy (as of arXiv 2310.08560, confidence: high).

## Chọn chiến lược nào trước

Quy tắc thực dụng để bắt đầu — map tình huống của bạn vào một chiến lược:
- Cần một giới hạn cứng, đơn giản (compliance/PII retention, bound dung lượng store) → bắt đầu với **TTL**.
- Memory đã có similarity search và muốn bản ghi mới "thắng" khi ranking → **Recency-weighted scoring**.
- Muốn giữ mọi thứ nhưng để bản ghi ít dùng tự chìm xuống (không xoá cứng) → **Usage-based decay**.
- Dữ liệu dạng preference/trạng thái ("tôi thích X" → "tôi thích Y") hay bị mâu thuẫn nếu giữ cả hai bản → **Explicit supersession**.
- Hệ thống production thường **kết hợp cả 3-4 chiến lược** thay vì chọn một (xem phần "Thực hành" bên dưới).
- Chưa có công thức chung để chọn con số TTL/ngưỡng cụ thể (ví dụ 7 ngày hay 30 ngày, threshold 0.85 hay 0.9) — các ví dụ số trong note này (7 ngày, ngưỡng 0.85...) chỉ là điểm khởi đầu hợp lý để thử nghiệm rồi tinh chỉnh theo domain, không phải giá trị "đúng" sẵn.

## Bắt tay vào code: 3 mẫu tối thiểu

Ba đoạn dưới đây là điểm khởi đầu copy-paste được cho từng chiến lược — đọc phần lý thuyết ở "Bốn chiến lược cốt lõi" bên dưới nếu cần hiểu sâu hơn.

**1. TTL (LangGraph Store)** — xoá cứng theo tuổi:

```python
from langgraph.store.memory import InMemoryStore

store = InMemoryStore(
    ttl={
        "default_ttl": 10080,       # 7 ngày, tính bằng phút
        "refresh_on_read": True,     # đọc/search cũng reset đồng hồ
        "sweep_interval_minutes": 60 # quét xoá bản ghi hết hạn mỗi giờ
    }
)
```

Nếu một fact được `put()` lần đầu rồi không ai `get()`/`search()` lại trong 7 ngày, nó bị sweep xoá. Nếu `refresh_on_read=True` và có truy vấn retrieve trúng nó ở ngày thứ 6, đồng hồ 7 ngày reset lại — TTL kiểu này tự động ngả sang hành vi giống usage-based decay khi bật `refresh_on_read`.

**2. Usage-based decay (kiểu Mem0)** — không xoá, chỉ dìm điểm ranking:

```python
def decayed_score(base_score, access_timestamps, now):
    recent_uses = count_uses_within(access_timestamps, window_days=7)
    if recent_uses > 0:
        multiplier = min(1.5, 1.0 + 0.1 * recent_uses)   # boost, trần 1.5x
    else:
        days_idle = days_since_last_use(access_timestamps, now)
        multiplier = max(0.3, 1.0 - 0.05 * days_idle)    # dìm dần, sàn 0.3x
    return base_score * multiplier
```

**3. Explicit supersession** — fact mới ghi đè fact cũ cùng chủ đề:

```python
def write_fact(new_fact, existing_facts, similarity_threshold=0.85):
    for old in existing_facts:
        if embedding_similarity(new_fact, old) > similarity_threshold:
            mark_superseded(old, by=new_fact)   # đánh dấu cũ, không xoá vật lý ngay
            break
    store(new_fact)
```

Ví dụ số cho **recency-weighted scoring** (chiến lược thứ 4, không xoá mà chỉ ưu tiên khi ranking): một memory 48h tuổi có `recency ≈ 0.995^48 ≈ 0.79` (decay hàm mũ, hệ số 0.995/giờ); nếu `relevance = 0.9` (cosine similarity embedding) và `importance = 0.6` (điểm LLM tự chấm 1-10, đã normalize về [0,1]), với trọng số bằng nhau thì:

```
score ≈ (0.79 + 0.9 + 0.6) / 3 ≈ 0.76
```

→ một memory mới hơn nhưng kém liên quan vẫn có thể thua một memory cũ hơn nhưng match tốt.

## Bốn chiến lược cốt lõi (chi tiết)

- **TTL / Expiry** — tự động xóa sau N ngày/phút.
  - LangGraph Store là ví dụ chuẩn hoá tốt: cấu hình `default_ttl`, `refresh_on_read` (true = mỗi lần đọc/search sẽ reset đồng hồ hết hạn; false = chỉ `put()` mới refresh), và `sweep_interval_minutes` (tần suất quét xoá bản ghi hết hạn) — xem code mẫu ở phần trên.
  - Mem0 phân loại đây là "age-based" — tốt cho compliance/PII retention window, nhưng rủi ro xoá nhầm fact bền vững hiếm khi được nhắc tới (dị ứng thuốc, cấu trúc billing) dù vẫn quan trọng.
- **Recency-weighted scoring** — trộn similarity với độ "mới" của memory khi ranking, thay vì xoá hẳn bản ghi cũ.
  - Nguồn gốc học thuật: paper *Generative Agents* (Park et al., 2023, arXiv:2304.03442). Công thức retrieval: `score = α_recency·recency + α_importance·importance + α_relevance·relevance`, cả 3 thành phần được min-max normalize (co giãn về khoảng [0,1] để so sánh công bằng), trong paper gốc `α` bằng nhau.
  - `recency` = decay hàm mũ theo số giờ (sandbox time) kể từ lần truy cập gần nhất; `relevance` = cosine similarity embedding (độ tương đồng ngữ nghĩa giữa 2 vector, 1 = giống hệt); `importance` = điểm do LLM chấm (khoảng 1-10, gọi là "poignancy" — mức độ đáng nhớ của sự kiện).
- **Usage-based decay** — memory ít/không bao giờ được retrieve thì bị giảm ưu tiên khi ranking, giống LRU cache eviction (Least Recently Used — cache đẩy phần tử lâu không dùng ra ngoài trước).
  - Không có một paper học thuật "chuẩn" cho nhánh này (khác với recency-weighting hay TTL) — nó chủ yếu xuất hiện trong tài liệu vendor/blog kỹ thuật (Letta, Mem0) và bắt nguồn khái niệm từ LRU cache trong hệ điều hành.
  - Mem0 "Memory Decay" là implementation cụ thể phía sau đoạn code mẫu ở trên: đây là **re-ranking tại thời điểm search, không phải xoá**. Mỗi memory giữ tối đa 20 timestamp truy cập gần nhất; multiplier dao động trong biên độ 5x (0.3x–1.5x), không bao giờ về 0 — nên fact cũ vẫn có thể trồi lên nếu nó thực sự match tốt nhất.
- **Explicit supersession** — fact mới về cùng chủ đề ghi đè/vô hiệu hoá fact cũ thay vì để cả hai cùng tồn tại.
  - Hiệu quả nhất với dữ liệu dạng preference ("tôi thích X" → sau đổi thành "tôi thích Y"); thách thức lớn nhất là *phát hiện* "cùng chủ đề" — trong thực tế thường dùng embedding similarity vượt ngưỡng (như code mẫu ở trên), hoặc một LLM classifier so sánh fact mới với fact cũ đã lưu; cả hai cách đều không hoàn hảo và cần tinh chỉnh theo domain.

## Thực hành: layer nhiều chiến lược cùng lúc

Mem0 đề xuất một heuristic sản xuất: kết hợp **TTL** cho các entry hiếm khi chạm tới (bound storage) + **usage decay kiểu LRU** trên điểm retrieval (bound nhiễu/interference) + **supersession chủ động** ở mỗi lần ghi (không để mâu thuẫn tích tụ) — hệ thống thực tế hiếm khi chỉ chọn một chiến lược.

## Liên hệ tới các phần khác

- So với [[agent-memory-long-term]]: forgetting/aging là cơ chế vòng đời áp dụng *lên trên* store dài hạn đó — không phải một loại memory riêng.
- So với [[agent-memory-summarization-compression]]: hai kỹ thuật song song nhưng mục tiêu trái ngược (giữ gist vs. loại bỏ hẳn); nhiều hệ thống dùng cả hai (vd Claude context editing dùng cả compaction lẫn clearing).
- So với [[agent-memory-user-profile-storage]]: supersession là cơ chế chính để user profile không bị "đóng băng" theo fact cũ khi user thay đổi preference/thông tin.
- Không áp dụng cho một lệnh gọi LLM đơn lẻ (không có state để già đi) hay một workflow tuyến tính đơn giản (state chỉ tồn tại trong một lần chạy); cũng thường không cần cho RAG trên corpus tài liệu tĩnh (corpus được coi là knowledge base bảo trì, không phải log tích luỹ) — forgetting/aging chỉ thực sự cần khi kho retrieval là một log agent tự ghi, lớn dần theo turn/session.

### Áp dụng với Claude Code

- **Memory tool** (`memory_20250818`, dùng qua Agent SDK, chưa phải tính năng CLI mặc định): hoàn toàn client-side, không có forgetting tự động phía server. Docs khuyến nghị pattern TTL thủ công: "Periodically delete memory files that haven't been accessed in a long time" — nhưng việc này do hạ tầng của developer tự làm, Anthropic không cung cấp sẵn.
- **Context editing** (`clear_tool_uses_20250919`, beta): đây là forgetting thật (xoá hẳn, thay bằng placeholder), khác compaction (tóm tắt giữ thông tin). Xoá cặp tool_use/tool_result **cũ nhất trước** (FIFO theo tuổi) khi vượt ngưỡng token/số lượng tool call. Có 2 tham số chỉnh: `keep` (giữ N lượt gần nhất) và `exclude_tools` (loại trừ tool nào đó, vd memory tool, khỏi việc bị xoá). Kết hợp memory tool + context editing đo được cải thiện 39% trên agentic search eval, và giảm 84% token trong eval web search 100 lượt.
- **Claude Code CLI cụ thể** — có hai hệ memory persistent:
  - `CLAUDE.md`: load toàn bộ mỗi session, không có decay/aging gì cả.
  - "Auto memory" (`MEMORY.md` + topic files, Claude tự ghi): **không có TTL, không có recency-weighted retrieval, không có usage-based decay tự động** ở tầng platform. Dọn fact cũ hoàn toàn dựa vào phán đoán của Claude cộng chỉnh sửa thủ công qua `/memory`.
- Điểm gần nhất với "aging" trong auto memory là một forcing function theo **dung lượng, không theo tuổi**: chỉ 200 dòng/25KB đầu của `MEMORY.md` được load mỗi session. Khi gần/vượt ngưỡng, Claude được nhắc giữ mỗi entry một dòng, dồn chi tiết vào topic file, merge hoặc bỏ entry đã lỗi thời — pruning bị kích hoạt bởi áp lực kích thước, không phải tuổi bản ghi.
- Từ v2.1.214, file memory có YAML frontmatter được ghi thêm timestamp `modified` (ISO 8601) — chỉ là tín hiệu thụ động để Claude/user tự đánh giá độ mới, platform không tự dùng nó để xếp hạng hay tự xoá. File auto memory cũng bị **loại trừ** khỏi cơ chế dọn session transcript cũ (`cleanupPeriodDays`), nên mặc định nó tồn tại vô thời hạn trừ khi ai đó chủ động sửa/xoá.
- Kết luận: Anthropic cung cấp cơ chế (file, timestamp, prompt pruning theo dung lượng) nhưng **không** có policy TTL/decay tự động — với project sống lâu, giữ `MEMORY.md` gọn là việc thủ công liên tục (as of code.claude.com/docs/en/memory, confidence: medium).

## Giới hạn / open questions

- Chưa có một paper học thuật "chuẩn" duy nhất cho usage-based decay/LRU và explicit supersession như đã có cho recency-weighting (Generative Agents) hay TTL (LangGraph) — phần này chủ yếu dựa trên tài liệu vendor (Mem0, Letta), độ tin cậy thấp hơn.
- Các con số hiệu năng từ paper "Infini Memory" (arxiv 2606.10677: +12.5% Accurate Retrieval, +4.4% TTL, +25.4% LRU, +26.5% Selective Forgetting) chỉ đến từ một preprint gần đây, chưa được kiểm chứng độc lập.
- Chưa rõ threshold/tham số mặc định cụ thể mà các sản phẩm production lớn (ChatGPT memory, các agent framework thương mại khác ngoài LangGraph/Mem0) thực sự dùng cho TTL hay decay — phần lớn thông tin công khai chỉ dừng ở mức "có tính năng forget/delete theo yêu cầu người dùng", không công bố công thức nội bộ.
- Chưa kiểm chứng thực nghiệm trong vault này việc kết hợp nhiều chiến lược (TTL + usage decay + supersession) ảnh hưởng thế nào đến chất lượng retrieval trong một hệ thống cụ thể — phần "thực hành layer nhiều chiến lược" hiện chỉ là khuyến nghị từ một nguồn (Mem0), chưa đối chiếu chéo.
- Chưa có rule of thumb cụ thể cho cách chọn con số TTL/ngưỡng similarity ban đầu theo từng loại domain (support bot, coding agent, personal assistant...) — các giá trị trong note này chỉ là ví dụ minh hoạ, không phải khuyến nghị đã kiểm chứng.

<details>
<summary>Phụ lục: phân loại học thuật đối chiếu + bảng nguồn/độ tin cậy chi tiết (mở rộng nếu cần đào sâu)</summary>

### Phân loại học thuật đối chiếu

Một khung phân loại lấy cảm hứng từ khoa học nhận thức gộp forgetting agent memory thành 3 nhóm tương ứng gần khớp với 4 chiến lược trên (Mem0 research / khảo sát liên quan):

| Nhóm | Khoá theo | Tương ứng |
|---|---|---|
| Time-based forgetting | thời điểm tạo | TTL |
| Frequency-based forgetting | hoạt động truy cập | Usage-based decay / LRU |
| Importance-driven forgetting | điểm salience tổng hợp | (gần với recency-weighted scoring, cộng thêm supersession khi salience = 0) |

### Bảng nguồn & độ tin cậy các claim gây tranh cãi

| Claim | Nguồn | Confidence |
|---|---|---|
| MemGPT evict gần với compression/archival hơn forgetting thật | arXiv 2310.08560 | high |
| Công thức retrieval Generative Agents (`α_recency/importance/relevance`) | Park et al., 2023, arXiv:2304.03442 | high |
| Mem0 Memory Decay: boost 1.5x / floor 0.3x, giữ tối đa 20 timestamp | Mem0 blog | high |
| Anthropic memory tool + context editing: +39% agentic search, -84% token web search | Anthropic engineering blog | high |
| Usage-based decay/LRU thiếu paper học thuật chuẩn, chỉ có tài liệu vendor | Mem0, Letta blog | low |
| Số liệu hiệu năng "Infini Memory" | arXiv 2606.10677 (preprint chưa kiểm chứng độc lập) | low |
| Claude Code CLI thiếu native staleness management cho auto memory | quan sát độc lập từ practitioner, đối chiếu docs code.claude.com | medium |

</details>
