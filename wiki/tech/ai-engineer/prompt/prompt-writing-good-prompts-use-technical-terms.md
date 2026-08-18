---
status: current
updated: 2026-08
sources:
  - https://platform.claude.com/docs/en/build-with-claude/prompt-engineering/claude-prompting-best-practices
  - https://docs.anthropic.com/en/docs/build-with-claude/prompt-engineering/system-prompts
  - https://developers.openai.com/api/docs/guides/prompt-engineering
  - https://www.moveworks.com/us/en/resources/ai-terms-glossary
  - https://www.refontelearning.com/blog/crafting-domain-specific-prompts-for-better-llm-outputs
  - https://arxiv.org/abs/2505.17037
  - https://arxiv.org/abs/2410.19792
  - https://www.qodo.ai/blog/rag-vs-fine-tuning-vs-rag-prompt-engineering/
  - https://code.claude.com/docs/en/agent-sdk/modifying-system-prompts
roadmap: ai-engineer
stage: learning
---

# Writing Good Prompts — Dùng đúng thuật ngữ kỹ thuật (technical terms) của domain

TL;DR: Khi prompt thuộc một domain chuyên môn (legal, medical, finance, software engineering...), hãy dùng đúng thuật ngữ chuẩn của ngành đó (VD "idempotent" thay vì "gọi lại API mà không lỗi") — nó giúp model khóa đúng vào đúng "kiến thức chuyên gia" thay vì phải tự đoán domain từ câu mô tả chung chung. Nhưng dùng sai jargon hoặc nhồi nhét thuật ngữ quá hiếm sẽ phản tác dụng, nên chỉ dùng từ mà mình chắc chắn là chuẩn ngành.

**Nếu chỉ nhớ 1 điều:**
- **Đổi từ lóng sang thuật ngữ chuẩn ngành** mà mình chắc chắn đúng (VD "idempotent" thay vì "gọi lại không lỗi") — nhưng vẫn giữ đầy đủ chi tiết/ràng buộc, không chỉ đổi từ suông.
- **Kiểm tra thuật ngữ có "chuẩn" không** trước khi dùng: nó có xuất hiện trong textbook/tài liệu chính thức/RFC của ngành đó không? Nếu không chắc, ưu tiên mô tả chi tiết hơn là đoán jargon.
- **Không tự chế hoặc dịch máy móc thuật ngữ** — model sẽ hiểu sai thay vì hiểu đúng hơn.
- **Với Claude Code**: đưa jargon/quy ước dự án vào CLAUDE.md một lần, thay vì gõ lại mỗi prompt.

## Checklist nhanh: nên / không nên

- **Nên**: gọi đúng tên khái niệm/kỹ thuật chuẩn của ngành (idempotent, 3NF, differential diagnosis...) thay vì diễn giải vòng vo.
- **Nên**: nếu không chắc thuật ngữ có chuẩn không, ưu tiên độ chi tiết/đầy đủ thông tin (context, ràng buộc, ví dụ) hơn là cố nhồi jargon cho "nghe chuyên nghiệp".
- **Nên**: với Claude Code, đưa jargon/quy ước dự án vào CLAUDE.md một lần, thay vì gõ lại mỗi prompt (xem phần "Áp dụng với Claude Code" bên dưới).
- **Không nên**: tự chế thuật ngữ hoặc dịch máy móc từ tiếng Việt sang tiếng Anh — nếu model không nhận ra từ, nó sẽ hiểu sai thay vì hiểu đúng hơn.
- **Không nên**: đánh giá một prompt là "tốt" chỉ vì có nhiều jargon — theo một khảo sát, độ đầy đủ thông tin của prompt dự đoán thành công tốt hơn là mật độ jargon đúng (xem mục "Rủi ro" bên dưới).

## Vì sao thuật ngữ kỹ thuật giúp model "neo" đúng context

- Trong lúc huấn luyện, model học cách "mã hóa" mỗi từ/cụm từ thành một dạng biểu diễn nội bộ gọi là **representation** (hiểu đơn giản: một "vị trí" trong không gian kiến thức nội bộ của model, sao cho các khái niệm liên quan nằm gần nhau) — thuật ngữ chuyên ngành thường nằm gần cụm với kiến thức/văn phong/mức độ chi tiết riêng của domain đó. Gọi tên đúng thuật ngữ ≈ trỏ thẳng tới đúng "vị trí" đó, thay vì buộc model phải suy đoán domain từ mô tả chung chung.
- Ví dụ minh họa: từ "Maui" thông thường nghĩa là một hòn đảo, nhưng từ góc nhìn developer nó có nghĩa là **.NET MAUI** (một framework của Microsoft) — nếu prompt chỉ nói "help me with Maui" model có thể hiểu sai domain; gọi đúng tên "**.NET MAUI**" loại bỏ hoàn toàn sự nhập nhằng này.
- Về mặt cơ chế, đặt tên chính xác scenario/ngành giúp model "thu hẹp phạm vi tri thức khổng lồ của nó về phần liên quan", giảm ambiguity và cho phép model rút ra đúng tập con của kiến thức đã học thay vì trả lời generic.
- Đây là một trường hợp cụ thể của nguyên tắc "be specific/explicit" của Anthropic (xem [[prompt-writing-good-prompts-be-specific]]) — nhưng khác ở chỗ: thay vì cụ thể hóa *yêu cầu/ranh giới*, ta cụ thể hóa *từ vựng/khung tri thức chuyên môn*.
- **Role-prompting** của Anthropic là cơ chế tài liệu chính thức gần nhất với ý tưởng này: gán Claude một vai trò chuyên gia trong system prompt (VD "You are a senior data scientist") được mô tả là "**anchors its word choice, confidence level, and depth of response**", giúp tăng độ chính xác rõ rệt cho các task phức tạp như phân tích pháp lý hay mô hình tài chính (as of docs.anthropic.com/system-prompts, confidence: high). Đặt tên đúng thuật ngữ domain trong nội dung prompt là một cách bổ trợ cho cơ chế này — cả hai đều neo model vào đúng "expert framing".

## Trái ngược: mô tả bằng ngôn ngữ phổ thông (lay language)

- Mô tả task bằng từ ngữ thông thường buộc model phải tự đoán domain framing từ ngữ cảnh mơ hồ, dẫn đến câu trả lời mang tính "generalist" — đúng nhưng không sâu, không đúng độ chi tiết mà người trong ngành cần.
- VD đối lập:
  - Lóng: "check if this database design is good" → Kỹ thuật: "check xem schema này có đạt **3NF** (third normal form) không — verify mọi non-key attribute có functional dependency đầy đủ vào primary key."
  - Lóng: "what could be wrong with this patient?" → Kỹ thuật: "generate a **differential diagnosis** list dựa trên các triệu chứng sau, xếp theo xác suất."
  - Lóng: "make this API call safe to retry" → Kỹ thuật: "make this API endpoint **idempotent** — dùng idempotency key để tránh duplicate side-effect khi retry."
- Anthropic và OpenAI không có tài liệu chính thức nào đặt tên riêng cho kỹ thuật "dùng domain jargon" — đây là suy luận/tổng hợp từ nguyên tắc chung "be specific/explicit" của cả hai vendor, không phải một claim được trích dẫn trực tiếp từ tài liệu gốc.

## Ví dụ: bảng đối chiếu thuật ngữ domain

Cột cuối giải thích ngắn gọn từng thuật ngữ, dành cho người chưa quen domain đó:

| Domain | Mô tả lóng (mơ hồ) | Thuật ngữ kỹ thuật (neo đúng context) | Giải thích ngắn |
|---|---|---|---|
| Software engineering | "làm sao để gọi lại API này nhiều lần mà không bị lỗi" | "make the endpoint **idempotent**" | idempotent = gọi lại nhiều lần cho kết quả như gọi 1 lần, không tạo side-effect trùng lặp |
| Database | "sắp xếp lại bảng cho gọn" | "**normalize to 3NF**, loại bỏ functional dependency thừa" | 3NF (third normal form) = chuẩn thiết kế bảng để mỗi cột phụ thuộc đúng vào khóa chính, tránh dư thừa dữ liệu; functional dependency = quan hệ "cột A luôn xác định giá trị cột B" |
| Medical | "bệnh nhân bị gì vậy" | "generate a **differential diagnosis**" | differential diagnosis = danh sách các bệnh có thể gây ra triệu chứng, xếp theo xác suất |
| Legal | "kiểm tra xem hợp đồng này có vấn đề gì không" | "review for **indemnification clause** gaps và **force majeure** coverage" | indemnification clause = điều khoản bồi thường khi một bên gây thiệt hại; force majeure = điều khoản miễn trách nhiệm do sự kiện bất khả kháng (thiên tai, chiến tranh...) |
| Finance | "tính xem khoản đầu tư này có lời không" | "compute **NPV** và **IRR** cho cash flow này" | NPV (net present value) = giá trị hiện tại của dòng tiền tương lai; IRR (internal rate of return) = tỷ lệ sinh lời nội bộ của khoản đầu tư |

### Ví dụ prompt đầy đủ (trước / sau)

- **Trước (lay language)**: "Can you look at this endpoint and make sure calling it twice doesn't break anything?"
- **Sau (dùng thuật ngữ)**: "Review this endpoint and make it **idempotent**: if the client retries the same request (e.g. due to a network timeout), the result must be identical to a single successful call — no duplicate rows, no double charge. Use an idempotency key if needed."
- Bản "sau" không chỉ đổi từ — nó còn giữ đủ chi tiết/ràng buộc cụ thể (idempotency key, kết quả tương đương 1 lần gọi). Đây chính là điểm được nhấn mạnh ở mục "Rủi ro" bên dưới: jargon đúng mà thiếu context vẫn không đủ.

## Rủi ro: lạm dụng hoặc dùng sai thuật ngữ

- Nghiên cứu "Prompt Engineering: How Prompt Vocabulary affects Domain Knowledge" cho thấy có một **specificity range** ở đó model đạt hiệu suất tốt nhất, nhất quán trên nhiều model khác nhau — nghĩa là độ đặc thù của từ vựng có điểm tối ưu, vượt qua điểm đó (dùng từ quá hiếm/quá sâu) có thể làm giảm hiệu suất thay vì tăng (as of arxiv.org/abs/2505.17037, confidence: medium). Nghiên cứu này không định lượng rõ ngưỡng "quá hiếm" nằm ở đâu, nên trong thực tế chưa có con số cụ thể để dựa vào.
- Nguyên nhân: nếu model không "nhận ra" thuật ngữ (từ hiếm, từ tự người dùng tự chế, hoặc dùng sai nghĩa chuyên ngành), nó không neo được vào đúng vùng tri thức — tương tự như prompt mơ hồ, model lại phải đoán, nhưng lần này đoán từ một tín hiệu gây nhiễu thay vì thiếu tín hiệu.
- Ví dụ về từ "quá hiếm": một thuật ngữ tự chế (VD viết tắt nội bộ của team, không ai ngoài team biết) hoặc một từ chỉ xuất hiện trong 1-2 paper hẹp sẽ không có trong dữ liệu huấn luyện của model — dùng nó cũng tương đương với dùng một từ vô nghĩa. Ngược lại, "idempotent", "3NF", "NPV" đều là từ xuất hiện phổ biến trong textbook/tài liệu chuẩn ngành nên an toàn để dùng.
- Một nghiên cứu đối lập đáng chú ý: khảo sát sinh viên lập trình mới học cho thấy **độ chính xác của từ vựng kỹ thuật chỉ tương quan yếu** với thành công của prompt — yếu tố dự đoán thành công mạnh hơn là **độ đầy đủ thông tin** (information completeness) của prompt, không phải sự có mặt của jargon đúng (as of arxiv.org/abs/2410.19792, confidence: medium). Kết luận thực tiễn: thuật ngữ đúng giúp neo context, nhưng không thay thế được việc cung cấp đủ chi tiết task — xem thêm [[prompt-writing-good-prompts-be-specific]] và [[prompt-writing-good-prompts-provide-context]].
- Cách giảm rủi ro trong thực tế: chỉ dùng thuật ngữ mà mình tin chắc là standard/well-attested trong domain đó, không tự chế từ riêng hay dịch máy móc; và nên duy trì một danh sách thuật ngữ/từ viết tắt đặc thù cho từng dự án để đưa vào prompt một cách nhất quán (đây là khuyến nghị thực tế từ cả hai nguồn trên, không phải claim chính thức từ Anthropic/OpenAI).
- **Test nhanh để kiểm tra một thuật ngữ có "đủ chuẩn" không** (không có benchmark chính thức, đây là heuristic thực tế): từ đó có xuất hiện trong (a) sách giáo khoa/tài liệu nhập môn của ngành, (b) tiêu chuẩn/RFC chính thức (VD RFC của IETF, chuẩn ISO), hoặc (c) tài liệu chính thức của framework/công cụ liên quan (VD docs của Postgres cho "3NF") không? Nếu có ít nhất 1 trong 3 nguồn này và từ đó không phải viết tắt nội bộ/từ team tự chế, có thể coi là đủ chuẩn để dùng. Nếu chỉ thấy từ đó trong 1-2 bài blog/paper hẹp, nên ưu tiên mô tả chi tiết thay vì dùng jargon.

## So sánh với RAG khi cần domain knowledge

- Dùng đúng thuật ngữ domain là cách tận dụng tốt hơn tri thức **đã có sẵn** trong trọng số pretrained của model — nhanh, stateless, hoạt động tốt cho các vấn đề phổ biến/được đại diện tốt trong training data.
- **RAG** khác về bản chất: nó bơm thêm tri thức **model chưa có** (VD tài liệu nội bộ, pháp lý cập nhật, hồ sơ bệnh án riêng) bằng cách retrieve từ knowledge base ngoại tại ở query-time — RAG thường được khuyên dùng cho domain cần dữ kiện xác thực/cập nhật (legal, healthcare, research), còn prompt engineering (bao gồm dùng đúng thuật ngữ) phù hợp hơn cho summarization, Q&A, formatting — những task mà tri thức pretrained của model nhiều khả năng đã đủ.
- Nói cách khác: thuật ngữ đúng giúp **truy xuất** đúng phần tri thức model đã học; RAG giải quyết trường hợp model **chưa từng học** phần tri thức đó.

## Liên hệ tới các phần khác

- [[prompt-writing-good-prompts-be-specific]] — dùng thuật ngữ domain là một dạng cụ thể hóa đặc biệt: cụ thể hóa về *từ vựng/khung tri thức* thay vì về *yêu cầu/định dạng*.
- [[prompt-writing-good-prompts-provide-context]] — cung cấp context và dùng đúng thuật ngữ bổ trợ nhau: context giải thích "tại sao", thuật ngữ giải thích "domain nào"; cả hai cùng giảm nhập nhằng.
- [[prompt-engineering]] — đây là một kỹ thuật con trong nhóm nguyên tắc "prompt clarity/specificity" nói chung của prompt engineering.

### Áp dụng với Claude Code

- Claude Code không có một flag/setting riêng cho "domain vocabulary injection" qua CLI — nguyên tắc này áp dụng trực tiếp vào cách viết task/prompt cho nó, giống như với mọi model khác.
- Cơ chế chính thức gần nhất của Claude Code/Claude Agent SDK là **CLAUDE.md** (project memory) và pattern **append** lên system prompt preset `claude_code`: thay vì phải nhắc lại thuật ngữ/quy ước domain trong từng prompt, team có thể codify một lần (tên framework nội bộ, quy ước đặt tên, thuật ngữ nghiệp vụ) và nó được inject vào mọi session, chia sẻ qua git — đây chính là cách chính thức để thêm "**product-specific rules like coding standards, output format, or domain context**" (as of code.claude.com/agent-sdk/modifying-system-prompts, confidence: high).
- Nói tóm lại: với Claude Code, "dùng đúng thuật ngữ domain" được thực hiện tốt nhất ở cấp **dự án** (CLAUDE.md/system-prompt append) hơn là phải nhờ người dùng nhắc lại jargon ở mỗi lần gọi lệnh riêng lẻ.

## Giới hạn / open questions

- Toàn bộ note này là suy luận/tổng hợp từ nguyên tắc "be specific" của Anthropic/OpenAI cộng với tài liệu bên thứ ba (blog, arXiv) — chưa tìm thấy tài liệu chính thức nào đặt tên riêng cho kỹ thuật "dùng domain jargon" như một mục độc lập trong prompt-engineering guide, nên phần lớn claim ở đây nên được coi là confidence trung bình/thấp thay vì đã được vendor xác nhận trực tiếp.
- Chưa có benchmark định lượng so sánh trực tiếp "prompt dùng jargon đúng" vs "prompt lay language" trên cùng một bộ task/domain để đo chênh lệch accuracy cụ thể; cũng chưa rõ có sự khác biệt đáng kể giữa các model (Claude vs GPT vs open-weight) về mức độ nhạy cảm với domain jargon — các nguồn đã đọc chỉ nói chung về "LLM".
- **[Nâng cao / có thể bỏ qua nếu chỉ cần áp dụng thực tế]** Cơ chế "gọi đúng thuật ngữ sẽ trỏ tới đúng vùng representation" (giải thích ở mục "Vì sao" phía trên) hiện mới là suy luận gián tiếp, chưa có bằng chứng đo đạc trực tiếp trên model production. Các hướng nghiên cứu liên quan (chỉ để tham khảo, không cần hiểu sâu để áp dụng note này):
  - **MoE (Mixture-of-Experts)**: một kiến trúc model trong đó có nhiều "mạng con" (experts) chuyên biệt, và model chỉ kích hoạt một vài expert phù hợp cho mỗi input — lý thuyết về cơ chế chọn expert (expert routing) của kiến trúc này có liên quan gián tiếp tới ý tưởng "từ khóa đúng sẽ kích hoạt đúng vùng kiến thức chuyên biệt".
  - **Domain embeddings**: cách biểu diễn một văn bản/domain thành một vector số, dùng để đo độ "gần/xa" về mặt ngữ nghĩa giữa các khái niệm — có liên quan gián tiếp tới ý tưởng "thuật ngữ đúng ngành nằm gần nhau trong không gian biểu diễn".
  - **Probing / activation patching**: các kỹ thuật interpretability (nghiên cứu "bên trong" model đang nghĩ gì) dùng để kiểm chứng trực tiếp xem một vùng neuron/activation cụ thể có thực sự tương ứng với một khái niệm hay không — đây là loại bằng chứng còn thiếu để xác nhận chắc chắn cơ chế nêu trên.
  - Tóm lại: chưa có nghiên cứu nào dùng các kỹ thuật này để chứng minh trực tiếp hiện tượng "domain jargon kích hoạt đúng vùng kiến thức" trong các model production hiện nay.
