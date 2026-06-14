# LLM Wiki

Mẫu kiến trúc second brain do Andrej Karpathy đề xuất (as of 2026-04, gist.github.com/karpathy):
bỏ vector DB cho corpus cỡ vừa (~400k từ), để LLM lập luận trực tiếp trên Markdown
qua 3 giai đoạn raw → compile → lint. File `.md` là nguồn chân lý truy vết được. (confidence: high)

Liên quan: [[zettelkasten]] (atomicity dùng cho note), và là nền của vault này — xem [[index]].
