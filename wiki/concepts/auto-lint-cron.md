# Auto-lint định kỳ bằng cron

Ý tưởng: chạy bước LINT của vault tự động hằng tuần thay vì thủ công, dùng `cron`
để định kỳ nhờ Claude rà mâu thuẫn/claim cũ/orphan/link gãy. (as of 2026-06, raw/inbox)

Đây là một mở rộng của giai đoạn *lint* trong [[llm-wiki]] (raw → compile → lint) —
biến lint từ thao tác thủ công thành định kỳ. Thuộc danh mục "để dành (YAGNI)" của
MVP: chỉ làm khi vault đủ lớn để việc rà tay trở nên tốn công. (confidence: medium — mới là ý tưởng)
