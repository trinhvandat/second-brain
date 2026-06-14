# Second Brain — Index

> Claude: đọc file này ĐẦU TIÊN, rồi `CRITICAL_FACTS.md`, rồi `AGENTS.md`.

## Bản đồ vault
- `raw/` — nguồn bất biến đã capture
  - `web/` bài clip · `meetings/` họp · `inbox/` capture nhanh chưa xử lý
- `wiki/` — tri thức đã compile (atomic + wikilink)
  - `concepts/` khái niệm · `entities/` người/cty/dự án/tool · `tech/` kỹ thuật · `journal/` nhật ký
- `AGENTS.md` — luật vận hành (đọc trước khi thao tác)

## 4 use case → đường đi
- Hỏi-đáp tri thức → `wiki/` + `raw/`, trả lời kèm `[[trích dẫn]]`.
- Trợ lý kỹ thuật → `wiki/tech/`.
- Capture & kết nối ý tưởng → `raw/inbox/` → (compile) → `wiki/concepts/`.
- Bộ nhớ đời sống → `raw/` + `wiki/journal/`.

## Lệnh quen dùng
- Capture URL: `./scripts/clip.sh <url>`
- Capture file: `./scripts/import.sh <path>`
- Trong Claude: "lưu ý này: ..." / "xử lý inbox" / "lint bộ não".

## Trạng thái
- Khởi tạo: 2026-06-14. Retrieval: LLM-over-Markdown (chưa dùng RAG).
