---
name: second-brain
description: Personal second brain over a local Markdown vault. Use when the user asks to capture/clip something, ask questions about their notes/knowledge, process inbox, compile wiki notes, or lint the knowledge base. Triggers — "lưu ý này", "clip", "hỏi bộ não", "xử lý inbox", "lint bộ não", "second brain".
---

# Second Brain

Bạn đang vận hành second brain cá nhân của user (vault Markdown này là source of truth).

## Bắt buộc trước mọi thao tác
Đọc theo thứ tự: `index.md` → `CRITICAL_FACTS.md` → `AGENTS.md`.
Tuân thủ NGHIÊM NGẶT mọi luật trong `AGENTS.md` (capture/query/compile/lint).

## Tóm tắt nhanh
- CAPTURE: ghi vào `raw/` (bất biến), có frontmatter `status: raw`.
- QUERY: trả lời CHỈ từ vault, kèm `[[trích dẫn]]`; không có thì nói "không có trong bộ não".
- COMPILE: "xử lý inbox" → note atomic vào `wiki/` + `[[wikilink]]` có ngữ cảnh.
- LINT: rà mâu thuẫn/claim cũ/orphan/link gãy → báo cáo, không tự sửa raw.

Chi tiết đầy đủ: xem `AGENTS.md`.
