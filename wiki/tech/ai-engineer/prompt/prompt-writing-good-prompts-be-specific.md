---
status: current
updated: 2026-08
sources:
  - https://platform.claude.com/docs/en/build-with-claude/prompt-engineering/claude-prompting-best-practices
  - https://developers.openai.com/api/docs/guides/prompt-engineering
  - https://www.promptingguide.ai/introduction/tips
  - https://code.claude.com/docs/en/best-practices
  - https://www.anthropic.com/engineering/building-effective-agents
roadmap: ai-engineer
stage: done
---

# Writing Good Prompts — Be Specific — nói rõ chính xác bạn muốn gì thay vì để model tự đoán

TL;DR: Prompt mơ hồ buộc model phải tự suy diễn ý định từ context nghèo nàn nên output không thể đoán trước; prompt càng cụ thể (role, task, constraint, tiêu chí thành công) càng thu hẹp không gian output và tăng xác suất đúng ngay lần đầu.

## Vì sao "be specific" quan trọng

- LLM không đọc được suy nghĩ của bạn — nó chỉ có thể bám vào những gì xuất hiện trong context. Thiếu chi tiết = model phải "đoán", và càng đoán thì variance càng cao.
- Anthropic mô tả Claude như "**một nhân viên mới rất giỏi nhưng chưa có ngữ cảnh** về chuẩn mực/quy trình của bạn" — càng giải thích chính xác muốn gì, kết quả càng tốt (as of platform.claude.com/prompt-engineering, confidence: high).
- **Golden rule** của Anthropic: đưa prompt cho một đồng nghiệp ít ngữ cảnh đọc thử — nếu họ bối rối, Claude cũng sẽ bối rối.
- Claude Code best-practices dùng cùng nguyên tắc cho coding agent: "Claude có thể suy luận ý định, nhưng không đọc được suy nghĩ của bạn. Instruction càng chính xác thì càng ít lần phải sửa lại."

## Các thành phần làm prompt trở nên cụ thể

- **Role/persona** — đặt vai trò cho model trong system prompt. Chỉ 1 câu cũng tạo khác biệt rõ rệt, VD: "You are a helpful coding assistant specializing in Python."
- **Task** — động từ lệnh rõ ràng (Write, Classify, Summarize, Fix), không dùng từ chung chung như "làm tốt hơn".
- **Constraints** — giới hạn cụ thể thay vì sở thích mơ hồ. VD thay "keep it professional" bằng "avoid jargon, không dùng cụm từ 'dive into' hay 'game-changer', không quá 100 từ" — model xử lý ranh giới rõ ràng như hard constraint, không suy luận tốt ý ngầm.
- **Context/motivation** — giải thích *lý do* đằng sau constraint giúp model generalize đúng, thay vì chỉ làm theo nghĩa đen. VD: thay vì chỉ nói "NEVER dùng dấu ba chấm", giải thích "vì output sẽ được đọc bởi text-to-speech engine".
- **Tiêu chí thành công rõ ràng** — định nghĩa trước "thế nào là đúng" thay vì để model tự quyết định. Claude Code gọi đây là "cho Claude cách tự verify công việc".
- **Định dạng output** — nếu cần JSON, bảng, số câu cụ thể... phải nói rõ từ đầu.

## Ví dụ: mơ hồ vs. cụ thể

| Mục tiêu | Prompt mơ hồ | Prompt cụ thể |
|---|---|---|
| Giải thích khái niệm | "Explain prompt engineering. Keep it short." | "Use 2-3 sentences to explain prompt engineering to a high school student." |
| Sinh dashboard | "Create an analytics dashboard" | "Create an analytics dashboard. Include as many relevant features and interactions as possible. Go beyond the basics to create a fully-featured implementation." |
| Sửa bug (Claude Code) | "fix the login bug" | "Users report login fails after session timeout. Check the auth flow in src/auth/, especially token refresh. Write a failing test that reproduces the issue, then fix it." |
| Viết test | "add tests for foo.py" | "Write a test for foo.py covering the edge case where the user is logged out. Avoid mocks." |
| Validate email (verification criteria) | "implement a function that validates email addresses" | "Write a validateEmail function. Example test cases: user@example.com is true, invalid is false, user@.com is false. Run the tests after implementing." |

Prompt "cụ thể" ở cột phải luôn nắm rõ: **đối tượng**, **số lượng/giới hạn**, và **cách kiểm tra kết quả** — đây chính là ba trục chính của nguyên tắc be-specific.

## Lưu ý: specificity là default, không phải luật tuyệt đối

- Với các task **khám phá** (chưa rõ yêu cầu, còn đang tìm ý tưởng), prompt mơ hồ lại có ích — VD "bạn sẽ cải thiện gì trong file này?" có thể gợi ra những góc nhìn mà mình không nghĩ đến để hỏi cụ thể.
- Với instruction **bền vững** (VD file CLAUDE.md), specificity phải đi kèm **súc tích**: chỉ giữ những điều không hiển nhiên / đặc thù project; loại bỏ advice chung chung ("write clean code") vì model đã biết sẵn. CLAUDE.md quá dài làm tín hiệu bị loãng, khiến Claude bỏ qua instruction — nên "cụ thể" không đồng nghĩa với "càng dài càng tốt" (as of code.claude.com/best-practices, confidence: medium).
- Không có paper học thuật gốc nào đặt tên chính thức cho kỹ thuật "specificity" (khác với Chain-of-Thought có paper gốc Wei et al. 2022) — đây là best practice đúc kết từ thực hành của các vendor (Anthropic, OpenAI) và cộng đồng (promptingguide.ai), không phải từ một nghiên cứu đơn lẻ (confidence: medium).

## Liên hệ tới các phần khác

- [[prompt-engineering]] — be-specific là nguyên tắc nền tảng, áp dụng xuyên suốt mọi kỹ thuật prompt engineering khác (zero-shot, few-shot, CoT đều cần prompt cụ thể ở từng bước).
- Khác với **RAG** — RAG giải quyết vấn đề cung cấp đúng **dữ liệu/context** bên ngoài cho model, còn be-specific tập trung vào cách **diễn đạt instruction**. Hai kỹ thuật bổ trợ nhau: prompt cụ thể + context đúng đều thu hẹp không gian output.
- Khác với **agent** (theo định nghĩa Anthropic trong "Building Effective Agents") — agent để model tự định hướng nhiều bước/tool call, nên constraint và success-criteria trong system prompt càng quan trọng hơn để giới hạn không gian hành động tự trị, tránh drift qua nhiều vòng lặp.

### Áp dụng với Claude Code

- Claude Code không expose một "specificity setting" riêng qua CLI — nguyên tắc này áp dụng trực tiếp vào **cách viết prompt/task cho Claude Code**, không phải một config flag.
- Áp dụng rõ nhất qua hai cơ chế:
  - **Prompt tức thì**: mô tả scope (file nào, edge case nào), triệu chứng cụ thể (không chỉ "fix bug"), và tiêu chí verify (chạy test nào, expect gì) — xem bảng ví dụ ở trên.
  - **CLAUDE.md** (system-level, bền vững): chỉ nên chứa instruction cụ thể-nhưng-không-hiển-nhiên, tránh loãng tín hiệu bằng advice chung chung.
- Claude Agent SDK cho phép tune mức độ "cụ thể" của system prompt qua 3 cơ chế: mặc định minimal (chỉ tool instruction thiết yếu), preset `claude_code` (đầy đủ hành vi Claude Code), và `append` (chồng thêm instruction cụ thể lên trên preset mà không phải viết lại toàn bộ) (confidence: medium, tài liệu SDK).
- Adversarial review step trong Claude Code cũng áp dụng nguyên tắc này cho subagent: thay vì "review code này", nói rõ "review diff X so với PLAN.md, kiểm tra từng requirement có được implement, edge case có test, report gap chứ không phải style preference" — mở rộng be-specific từ prompt đơn sang orchestration nhiều agent.

## Giới hạn / open questions

- Chưa có số liệu định lượng (VD % giảm variance, % tăng accuracy) từ nguồn chính thống nào đo "specificity" mang lại — các ví dụ đều là qualitative, chưa thấy benchmark A/B công khai so sánh trực tiếp prompt mơ hồ vs. cụ thể trên cùng một task.
- Ranh giới giữa "cụ thể vừa đủ" và "over-specified gây nhiễu/mất flexibility" chưa được định lượng rõ — CLAUDE.md guidance cảnh báo về bloat nhưng không đưa threshold cụ thể.
- Chưa rõ nguyên tắc này khác biệt thế nào giữa reasoning model (o1-class) và non-reasoning model — OpenAI gợi ý reasoning model cần ít instruction chi tiết hơn (giao "mục tiêu cao" thay vì bước cụ thể), nhưng chưa có so sánh sâu với Claude/extended thinking trong nguồn đã đọc.
