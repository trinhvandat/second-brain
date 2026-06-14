# AGENTS.md — Luật vận hành Second Brain

> Đây là bộ luật chung cho MỌI bề mặt (Claude Code & Claude Desktop/MCP).
> Đọc file này trước khi thao tác với vault.

## 0. Thứ tự đọc (BẮT BUỘC)
1. `index.md` — bản đồ vault.
2. `CRITICAL_FACTS.md` — facts cố định về user (luôn nạp).
3. Sau đó mới `grep`/đọc file liên quan trong `wiki/` và `raw/`.

## 1. CAPTURE (nạp vào)
- Mọi thứ vào `raw/` là **BẤT BIẾN** — không sửa nội dung gốc, chỉ thêm file mới.
- URL → `raw/web/YYYY-MM-DD-<slug>.md` (dùng `scripts/clip.sh` hoặc WebFetch).
- Ý/note nhanh → `raw/inbox/YYYY-MM-DD-HHMM-<slug>.md`.
- Meeting → `raw/meetings/YYYY-MM-DD-<slug>.md`.
- Mỗi file raw có YAML frontmatter: `source`, `captured_at`, `status: raw`.

## 2. QUERY (hỏi-đáp)
- Trả lời CHỈ từ nội dung trong vault.
- Mọi khẳng định kèm trích dẫn `[[file]]` (wikilink tới file nguồn).
- Nếu KHÔNG có trong vault: nói rõ "Không có trong bộ não" — KHÔNG bịa, KHÔNG dùng kiến thức ngoài trừ khi user yêu cầu rõ.
- Khi thông tin cũ/mâu thuẫn, nêu marker thời điểm `(as of YYYY-MM, source)`.

## 3. COMPILE (raw → wiki)
- Khi user nói "xử lý inbox": đọc `raw/inbox/`, chắt lọc thành note ATOMIC.
- Atomicity: 1 file = 1 khái niệm/thực thể. Đặt vào đúng `wiki/concepts|entities|tech|journal`.
- Mỗi wiki note PHẢI có ≥1 `[[wikilink]]` CÓ NGỮ CẢNH (giải thích vì sao liên kết).
- Giữ URL nguồn verbatim + marker confidence `(high|medium|low)` cho claim quan trọng.
- Sau khi compile, đánh dấu file raw đã xử lý: đổi frontmatter `status: processed`.

## 4. LINT (rà soát định kỳ)
- Khi user nói "lint" hoặc "kiểm tra bộ não": rà toàn `wiki/` tìm:
  - mâu thuẫn giữa các note;
  - claim cũ (marker thời điểm đã lâu);
  - orphan (note không ai link tới);
  - wikilink trỏ tới file không tồn tại.
- Xuất báo cáo + ĐỀ XUẤT sửa; KHÔNG tự sửa nội dung raw.

## 5. Văn phong note
- Viết cho future-Claude đọc & lập luận, không phải prose cho người.
- Ngắn, atomic, nhiều liên kết. Tiếng Việt hoặc Anh đều được, nhất quán trong 1 note.
