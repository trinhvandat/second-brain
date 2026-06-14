# Design Spec — Personal Second Brain (LLM Wiki)

- **Date:** 2026-06-14
- **Status:** Approved design → ready for implementation planning
- **Author:** Leonard (+ Claude)
- **Project root:** `/Users/leonard/Workspace/code/personal/second-brain` (greenfield)

---

## 1. Mục tiêu (Objective)

Xây một **second brain cá nhân** dạng *LLM Wiki*: một vault Markdown local-first
làm **source of truth**, với Claude làm bộ não đọc/lập luận/duy trì. Hệ thống phục
vụ **4 use case trên cùng một substrate**:

1. **Hỏi-đáp tri thức cá nhân** — hỏi tự nhiên, nhận câu trả lời kèm trích dẫn nguồn.
2. **Trợ lý kỹ thuật / công việc** — snippet, ADR, lessons-learned cho lúc code.
3. **Capture & kết nối ý tưởng** — ghi nhanh, hệ thống tự liên kết note (Zettelkasten + AI).
4. **Bộ nhớ đời sống tổng hợp** — bài đọc web, meeting notes, PDF, journal.

**Vì sao (why):** Nút thắt của AI trong knowledge work không phải mô hình mà là
*ngữ cảnh cá nhân* được cấu trúc để LLM đọc được (Tiago Forte — "Personal Context
Management"). Mục tiêu là biến ghi chú rời rạc thành một "wiki biết trả lời" và
**tự duy trì**.

## 2. Cơ sở từ research (đã verify 3-0)

Dựa trên báo cáo deep-research ngày 2026-06-13 (21/25 claim confirmed):

- **LLM Wiki của Karpathy (4/2026):** bỏ vector DB cho corpus cỡ vừa (~100 bài /
  ~400k từ); LLM lập luận trực tiếp trên Markdown qua 3 giai đoạn raw → compile →
  lint; file `.md` là nguồn chân lý truy vết được, tránh hộp đen embedding.
  (gist Karpathy, VentureBeat)
- **obsidian-second-brain:** Claude Code skill biến vault Markdown thành KB
  **tự duy trì**; cấu trúc cho LLM đọc (`index.md` đọc trước, `CRITICAL_FACTS.md`
  luôn nạp, `raw/` bất biến, `wiki/` theo entities/concepts, `[[wikilinks]]` bắt
  buộc, marker confidence/recency). (github.com/eugeniughelbur/obsidian-second-brain)
- **Zettelkasten:** atomicity (1 note = 1 khối tri thức, địa chỉ duy nhất); liên
  kết phải CÓ NGỮ CẢNH mới tạo tri thức. (zettelkasten.de)
- **NotebookLM source-grounding:** chỉ trả lời từ nguồn đã có + trích dẫn xác minh
  được → mẫu chống bịa. (arXiv 2504.09720)

## 3. Quyết định thiết kế (từ brainstorming)

| Quyết định | Lựa chọn | Ghi chú |
|---|---|---|
| Mục đích | Cả 4 use case | Phục vụ trên cùng substrate Markdown |
| Triết lý build | Hybrid → vault sẵn + lớp custom mỏng | "Lớp custom" = Claude skill + script nhỏ, KHÔNG phải app |
| Stack | Không cần code nhiều | Claude Code làm ingest/query; chỉ viết shell script khi cần |
| Retrieval | **LLM-over-Markdown** (Karpathy) | Zero infra; RAG/pgvector để dành cho tương lai |
| Bề mặt | **Claude Code (chính) + Claude Desktop/MCP (phụ)** | Cả hai trỏ vào cùng vault |
| Luật vận hành | **Surface-agnostic** | Đặt trong `index.md` + `AGENTS.md`; SKILL.md chỉ là wrapper |

**Approaches đã loại:**
- *RAG + pgvector*: mâu thuẫn "không cần code nhiều"; YAGNI cho tới khi corpus vượt
  ngưỡng context window.
- *Obsidian + plugin RAG (Smart Connections)*: khoá vào Obsidian app; muốn Claude
  là tác nhân chính.
- *claude.ai Projects*: **không ghi ngược file local** → vault "sống" sẽ lệch dần.

## 4. Kiến trúc & cấu trúc vault

**Nguyên tắc nền:**
- File `.md` là source of truth — mọi câu trả lời truy về được một file cụ thể.
- Viết **cho Claude đọc trước, người đọc sau** (AI-first retrieval).
- Mỗi claim mang marker: `(as of YYYY-MM, source.com)` + độ tin cậy khi liên quan.
- `[[wikilinks]]` bắt buộc, có ngữ cảnh giải thích (Zettelkasten).

```
second-brain/
├── index.md              # Claude ĐỌC ĐẦU TIÊN — bản đồ vault + cách dùng
├── CRITICAL_FACTS.md     # ~150 token, facts luôn-đúng-về-tôi, luôn nạp
├── AGENTS.md             # Bộ luật vận hành surface-agnostic (capture/query/lint)
├── raw/                  # Nguồn BẤT BIẾN
│   ├── web/              # bài clip từ URL (Markdown)
│   ├── meetings/         # meeting notes thô
│   └── inbox/            # capture nhanh, chưa xử lý
├── wiki/                 # Tri thức đã compile — Claude tự viết & duy trì
│   ├── concepts/         # 1 file = 1 atomic concept
│   ├── entities/         # người, công ty, dự án, công cụ
│   ├── tech/             # use case trợ lý kỹ thuật: snippet, ADR, lessons
│   └── journal/          # use case bộ nhớ đời sống: theo ngày/tuần
├── .claude/
│   └── skills/second-brain/SKILL.md   # wrapper mỏng trỏ về AGENTS.md
├── scripts/              # shell script nhỏ: clip url, import file
└── docs/superpowers/specs/            # spec này
```

**Ánh xạ use case → substrate:**
- Hỏi-đáp tri thức → đọc `wiki/` + `raw/`, trả lời kèm trích dẫn.
- Trợ lý kỹ thuật → `wiki/tech/`.
- Capture & kết nối ý tưởng → `raw/inbox/` → compile thành `wiki/concepts/` + auto `[[links]]`.
- Bộ nhớ đời sống → `raw/` + `wiki/journal/`.

## 5. Các đơn vị (units) & ranh giới

| Unit | Làm gì | Phụ thuộc | Giao diện |
|---|---|---|---|
| `AGENTS.md` | Định nghĩa luật capture/query/maintain | — | Claude đọc khi vào vault |
| `index.md` | Bản đồ vault + thứ tự đọc | cấu trúc thư mục | Claude đọc đầu tiên |
| `CRITICAL_FACTS.md` | Facts cố định về user | — | luôn nạp vào context |
| SKILL.md (Claude Code) | Wrapper kích hoạt + trỏ về AGENTS.md | AGENTS.md | auto khi cd vào vault |
| MCP filesystem config | Cho Desktop đọc/ghi vault | Claude Desktop | chat surface |
| `scripts/clip.sh` | URL → Markdown vào raw/web/ | curl/markdown tool | CLI |
| `scripts/import.sh` | file → raw/inbox/ | — | CLI |

Mỗi unit hiểu được độc lập, test được riêng. Luật vận hành tách khỏi cơ chế kích
hoạt (AGENTS.md vs SKILL.md) để hai bề mặt dùng chung.

## 6. Ba luồng vận hành

### ① CAPTURE (nạp vào) — ma sát thấp
- Claude Code: `clip <url>` → `raw/web/`; "lưu ý này: ..." → `raw/inbox/`.
- Desktop: paste/nói → Claude ghi file qua MCP filesystem.
- **Nguyên tắc:** capture thô **bất biến**, không sửa; xử lý để sau.

### ② QUERY (hỏi-đáp) — 4 use case
- Claude đọc `index.md` + `CRITICAL_FACTS.md` trước → `grep`/đọc `wiki/` + `raw/`.
- Trả lời **kèm trích dẫn `[[file]]`** + độ tin cậy.
- Không có trong vault → nói rõ "không có trong bộ não" (source-grounding, chống bịa).

### ③ MAINTAIN (compile + lint)
- *Compile*: "xử lý inbox" → đọc `raw/inbox/`, viết/cập nhật note atomic vào `wiki/`,
  tự thêm `[[wikilinks]]` + gợi ý liên hệ.
- *Lint* (định kỳ): rà mâu thuẫn, claim cũ, orphan, link thiếu → báo cáo + đề xuất sửa.

## 7. Phạm vi MVP (vòng 1)

1. Khởi tạo cấu trúc vault + `index.md`, `CRITICAL_FACTS.md`, `AGENTS.md`.
2. Viết Claude Code skill `second-brain` (wrapper mỏng trỏ AGENTS.md).
3. Cấu hình MCP filesystem cho Claude Desktop trỏ vào vault.
4. 1-2 script capture (`clip.sh`, `import.sh`).
5. Seed vài note thật để test 3 luồng.

**Ngoài phạm vi (YAGNI — chỉ làm khi cần):** RAG/pgvector (khi corpus vượt ngưỡng
context), web clipper tự động, mobile capture, auto-lint theo lịch.

## 8. Kế hoạch test (verify MVP dùng được)

5 prompt thử:
- (a) capture 1 URL → file Markdown xuất hiện trong `raw/web/`.
- (b) capture 1 ý nhanh → file trong `raw/inbox/`.
- (c) hỏi 1 câu CÓ trong vault → câu trả lời **kèm trích dẫn `[[file]]`**.
- (d) hỏi 1 câu KHÔNG có → phải nói "không có trong bộ não", không bịa.
- (e) "xử lý inbox" → sinh note atomic trong `wiki/` có `[[link]]`.

Cả 5 phải pass trên **cả hai bề mặt** (Claude Code + Desktop/MCP) cho luồng tương ứng.

## 9. Rủi ro & câu hỏi mở

- **Ngưỡng quy mô:** khi corpus vượt context window, cần chuyển sang RAG. Karpathy
  nêu ~400k từ là "cỡ vừa"; ranh giới trên chưa định lượng → theo dõi, chưa build RAG.
- **Chi phí token:** "nạp wiki vào context" tốn token khi vault lớn → giảm bằng
  `index.md`/grep có chọn lọc thay vì đọc toàn bộ.
- **Tiếng Việt:** chất lượng xử lý note tiếng Việt của Claude tốt, nhưng chưa có
  benchmark embedding tiếng Việt (chỉ quan trọng nếu sau này thêm RAG).
- **Đồng bộ hai bề mặt:** cả hai ghi vào cùng file → tránh sửa đồng thời; vault
  không bật real-time sync nên xung đột thấp.

## 10. Bước tiếp theo

Sau khi user duyệt spec → invoke **writing-plans** để ra kế hoạch triển khai chi tiết
cho MVP (mục 7).
