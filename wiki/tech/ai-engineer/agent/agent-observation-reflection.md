---
status: current
updated: 2026-08
sources:
  - https://arxiv.org/abs/2210.03629
  - https://arxiv.org/abs/2303.11366
  - https://www.anthropic.com/research/building-effective-agents
  - https://code.claude.com/docs/en/agent-sdk/agent-loop
  - https://developers.openai.com/api/docs/guides/prompt-engineering
  - https://langchain-doc.readthedocs.io/en/latest/modules/agents/examples/max_iterations.html
roadmap: ai-engineer
stage: done
---

# Observation & Reflection — bước 4, bước cuối cùng trong agent loop

**TL;DR**: Sau khi thực thi tool ở bước Acting, agent ghi nhận kết quả trả về (**Observation** — dữ liệu khách quan: output, error, side-effect), rồi đánh giá kết quả đó so với mục tiêu ban đầu (**Reflection** — phán đoán chủ quan hơn: đã đạt chưa, có cần đổi chiến lược không), từ đó quyết định 1 trong 3 hướng: loop lại về [[agent-reason-plan]] với thông tin mới, dừng vì đã hoàn thành, hoặc dừng vì chạm giới hạn/thất bại — đây chính là cơ chế "self-check" ngăn agent chạy vô tận hoặc dừng sai lúc, gắn chặt với [[llm-stopping-criteria]].

## 1. Vị trí trong agent loop

Trong [[agent-loop]], 4 bước là perceive → reason/plan → act/invoke tool → **observe/reflect**. Đây là bước khép vòng lặp:

- **Input**: kết quả trả về từ tool vừa gọi ở bước Act (return value, exception, side-effect quan sát được), cộng với toàn bộ context tích luỹ (goal gốc, lịch sử các vòng trước).
- **Output**: 1 trong 3 quyết định — (a) loop lại [[agent-reason-plan]] với observation mới làm input, (b) dừng vì đã đạt mục tiêu, (c) dừng vì thất bại/chạm giới hạn.
- Khác với Reason/Plan (chạy hoàn toàn ẩn bên trong model), bước này có phần **lộ ra ngoài model**: raw tool output luôn được append vào context một cách cơ học bởi harness, trước khi model được gọi lại để "đọc" và phản ứng với nó.

## 2. Observation vs. Reflection — 2 việc khác nhau, hay bị gộp làm một

Note này tách rõ 2 khái niệm mà nhiều tài liệu dùng lẫn lộn:

| | Observation | Reflection |
|---|---|---|
| Bản chất | Ghi nhận dữ liệu khách quan | Đánh giá chủ quan, có phán đoán |
| Câu hỏi trả lời | "Tool trả về gì?" | "Kết quả này có tốt không? Có đạt mục tiêu chưa? Có cần đổi chiến lược?" |
| Nguồn gốc trong literature | ReAct — `Observation` là output thô của Action, được append thẳng vào context | Reflexion — chuyển feedback (thường là tín hiệu nhị phân/thưa) thành **lời phê bình bằng ngôn ngữ tự nhiên**, lưu vào **episodic memory** để dùng ở lần thử sau |
| Ai làm | Harness/môi trường trả về (không cần model can thiệp) | Model tự sinh ra (một dạng suy luận, giống Reason/Plan nhưng nhìn về quá khứ thay vì tương lai) |

> **Episodic memory** là gì: một dạng "sổ tay" lưu lại bài học từ các lần thử trước (VD "lần trước sửa hàm `sum()` kiểu này đã sai vì quên xử lý số âm") — khác với context window (chỉ tồn tại trong 1 phiên chạy), episodic memory được đọc lại ở các lần thử/episode sau để agent không lặp lại sai lầm cũ.

- **ReAct** (Yao et al., Princeton/Google Brain, arXiv:2210.03629) là nguồn gốc của "Observation" như một bước riêng biệt trong loop: chu trình Thought → Action → Observation, trong đó Observation là giá trị trả về thô của tool call, được append vào context để làm input cho Thought kế tiếp (as of arxiv.org/abs/2210.03629, confidence: high).
- **Reflexion** (Shinn et al., NeurIPS 2023, arXiv:2303.11366) hình thức hoá "Reflection" như một bước tách biệt: agent nhận tín hiệu thưa (VD binary success/failure) từ môi trường, rồi tự sinh ra "verbal reflection" — một đoạn văn tự phê bình — lưu vào episodic memory, dùng để cải thiện quyết định ở các lần thử tiếp theo (as of arxiv.org/abs/2303.11366, confidence: high). Đây chính là gốc của "self-critique/reflection pattern".
- Điểm khác biệt kiến trúc quan trọng: Reflection trong Reflexion không chỉ tác động tới vòng lặp hiện tại (như Observation của ReAct) mà còn **tích luỹ qua nhiều episode/attempt** — nghĩa là ảnh hưởng tới cả những lần chạy sau, không riêng lần này.

## 3. Ví dụ cụ thể: "sửa 1 test đang fail" (nối tiếp ví dụ ở [[agent-reason-plan]] mục 7)

| Vòng lặp | Act (đã làm) | **Observation** (dữ liệu thô) | **Reflection** (đánh giá) | Quyết định |
|---|---|---|---|---|
| 3 | `edit_file(sum.py)` sửa hàm `sum()` | Tool trả về: file đã ghi thành công, diff hiển thị 1 dòng thay đổi | Sửa có vẻ đúng hướng nhưng **chưa có bằng chứng** — chưa chạy lại test | Loop lại: gọi `bash(pytest test_x.py)` |
| 4 | `bash(pytest test_x.py)` | stdout: `1 passed` | Kết quả khớp mục tiêu ban đầu ("fix test X") — không có test nào khác fail thêm | Dừng: hoàn thành |
| 4' (kịch bản khác) | `bash(pytest test_x.py)` | stdout: `1 failed: AssertionError: expected 5, got 3` | Sửa sai — logic thay đổi chưa đúng, cần quay lại đọc code kỹ hơn thay vì đoán tiếp | Loop lại: quay về [[agent-reason-plan]] với observation mới |
| 4'' (kịch bản thất bại) | Đã loop 3 lần sửa mà vẫn fail | stdout vẫn fail | Nhận ra pattern lặp lại không tiến triển (no-progress) | Dừng: báo lỗi, không loop tiếp — tránh chạy vô hạn |

Hàng 4 minh hoạ Observation thuần (`1 passed` là dữ liệu khách quan) dẫn tới Reflection đơn giản (khớp mục tiêu → dừng). Hàng 4'' minh hoạ Reflection phức tạp hơn: không chỉ nhìn 1 observation đơn lẻ mà so sánh nhiều observation qua các vòng để phát hiện **no-progress** — tức là kết quả của vòng lặp mới không khác gì (hoặc tệ hơn) vòng lặp trước, dấu hiệu agent đang "giậm chân tại chỗ" thay vì tiến gần tới mục tiêu. Đây là lúc [[llm-stopping-criteria]] (max iterations, no-progress detection) phải can thiệp thay vì để model tự quyết định vô thời hạn.

## 4. Cơ chế dừng: 3 kết cục sau Observation & Reflection

1. **Dừng sạch (natural completion)**: model tự nhận thấy goal đã đạt — trong các agent loop hiện đại (Claude Agent SDK, OpenAI Agents SDK), tín hiệu kỹ thuật là model trả về response **không kèm tool call nào** (`stop_reason: end_turn`), khác hẳn với việc có 1 nhãn "Reflection step" tường minh do SDK định danh.
2. **Loop lại (re-plan)**: observation cho thấy chưa xong hoặc sai hướng → model quay lại [[agent-reason-plan]] với thông tin mới, có thể điều chỉnh chiến lược thay vì lặp lại hành động cũ.
3. **Dừng cưỡng bức (hard stop)**: chạm giới hạn cấu hình từ bên ngoài, không phải do model tự quyết — đây là phần cơ chế kỹ thuật, không phải "self-check" thuần tuý:
   - Claude Agent SDK: `max_turns` (đếm số turn có tool-call) hoặc `max_budget_usd`; khi chạm giới hạn, SDK trả về `ResultMessage` với subtype `error_max_turns` / `error_max_budget_usd` thay vì `success` (as of code.claude.com/docs/en/agent-sdk/agent-loop, confidence: high).
   - LangChain `AgentExecutor`: `max_iterations` cộng với `early_stopping_method` (`"force"` trả 1 chuỗi dừng có sẵn ngay lập tức; `"generate"` chạy thêm 1 lượt LLM để tổng hợp câu trả lời từ các cặp action/observation đã tích luỹ) khi chạm giới hạn (as of langchain-doc.readthedocs.io, confidence: medium).
   - Anthropic khuyến nghị rõ: luôn implement stopping condition kiểu max iterations để tránh agent loop chạy vô hạn/tốn chi phí không kiểm soát.

Xem [[llm-stopping-criteria]] để biết chi tiết các loại giới hạn (turn budget, wall-clock time, token ceiling, no-progress detection).

## 5. Reflection trong thực hành: hướng dẫn cấp prompt (OpenAI) và cấp kiến trúc (Anthropic)

- **OpenAI prompt engineering guide** khuyến nghị model "reflect extensively on the outcomes [of] each function call" và "only terminate your turn when you are sure the problem is solved" — đây là hướng dẫn hành vi ở cấp prompt, chỉ tác động tới cách model tự phản ánh trong quá trình sinh text, không phải cơ chế cứng như `max_turns`. Guide này còn khuyến nghị dùng TODO-list để track tiến độ, nhằm tránh agent dừng sớm khi sub-task chưa hoàn thành hết.
- **Anthropic "Building Effective Agents"** nhấn mạnh: trong lúc thực thi, agent cần lấy **"ground truth"** từ môi trường ở mỗi bước (kết quả test, output tool) để đánh giá tiến độ thật, thay vì tự tin giả định đã đúng — đây chính là lý do Observation phải là dữ liệu khách quan trước khi Reflection diễn ra, chứ không thể Reflection dựa trên suy đoán không kiểm chứng.
- **Reflexion** đi xa hơn 1 lượt reflect đơn giản: nó có 3 vai trò tách biệt — Actor (hành động), Evaluator (chấm điểm quỹ đạo), Self-Reflection (ghi bài học bằng ngôn ngữ vào episodic memory cho lần thử sau). Ví dụ áp dụng: 1 agent code thử fix bug 3 lần liên tiếp đều fail theo cùng 1 kiểu — Evaluator chấm "vẫn fail", Self-Reflection sinh ra câu như "cách sửa ở hướng A không hiệu quả, lần sau nên đọc kỹ stack trace trước khi sửa thay vì đoán" và lưu lại để agent tham khảo ở episode kế tiếp. Đây là kiến trúc reflection nhiều lớp, khác hẳn với 1 lượt reflect-rồi-quyết-định đơn giản trong ReAct loop thông thường.

## Liên hệ tới các phần khác

- [[agent-loop]] — Observation & Reflection là bước 4, bước khép vòng của loop 4 bước; note này mở rộng chi tiết, đối xứng với cách [[agent-reason-plan]] mở rộng bước 2.
- [[agent-reason-plan]] — quyết định "loop lại" ở Reflection dẫn thẳng trở về bước Reason/Plan với observation mới làm input; 2 bước này tạo thành nhịp reason ↔ observe lặp lại của ReAct.
- [[llm-stopping-criteria]] — chi tiết các loại giới hạn (max iterations, turn budget, token ceiling, no-progress detection) quyết định khi nào Reflection phải nhường quyền cho 1 hard stop từ bên ngoài.
- [[agent-perception-user-input]] — Observation ở bước 4 và Perception ở bước 1 đều là "ghi nhận dữ liệu từ bên ngoài", khác nhau ở thời điểm: Perception nhận input ban đầu, Observation nhận feedback sau hành động.
- [[ai-engineer-roadmap]] — vị trí bước Observation & Reflection trong nhóm AI Agents 101 của lộ trình.

### Áp dụng với Claude Code

- Claude Code / Claude Agent SDK **không có một "Reflection module" tách biệt về mặt kỹ thuật** — loop chính thức được tài liệu hoá chỉ có 5 bước cơ học: (1) receive prompt, (2) evaluate & respond, (3) execute tools, (4) repeat, (5) return result. "Verify"/reflect nằm ẩn bên trong bước (2) của turn kế tiếp, khi model đọc `tool_result` vừa nhận (được harness tự động feed vào context) và tự quyết định bước tiếp theo — không phải một bước riêng có nhãn tường minh.
- Cơ chế dừng thực tế dựa trên tín hiệu kỹ thuật do SDK quản lý bên ngoài model: `stop_reason` trên `ResultMessage` (`end_turn` = dừng sạch, `max_tokens`/`refusal` = dừng bất thường), cộng với giới hạn cấu hình cứng `max_turns` / `max_budget_usd` khi chạm ngưỡng thì trả `error_max_turns` / `error_max_budget_usd` thay vì `success`.
- Những cơ chế gần nhất với "Observation & Reflection" theo đúng nghĩa self-check trong thực hành Claude Code: chạy test/linter/type-checker qua Bash tool và đọc kết quả (Observation khách quan), dùng `TodoWrite`/Task tools để tự cập nhật tiến độ so với mục tiêu ban đầu (gần giống Reflection nhưng là checklist thủ công, không phải module đánh giá chất lượng độc lập kiểu Reflexion), và hooks `PostToolUse`/`Stop` chạy validate/audit output ngoài context window của model trước khi coi vòng lặp hoàn tất.
- Nói cách khác: Claude Code hiện thực hoá "Observation" rất rõ (raw tool result luôn được append vào context), nhưng "Reflection" theo nghĩa Reflexion (self-critique tích luỹ qua nhiều episode, lưu vào bộ nhớ episodic) **không được SDK cung cấp sẵn** — nếu cần, phải tự xây bằng skill/hook/prompt engineering (VD skill `/verify`, hoặc yêu cầu model "reflect" tường minh trong system prompt).

## Giới hạn / open questions

- Chưa kiểm chứng trực tiếp việc Claude Agent SDK có expose thinking/reflection block riêng ở bước "evaluate" hay không (khác với `extended thinking` ở bước reasoning trước khi act) — cần đối chiếu sâu hơn với `code.claude.com/docs/en/agent-sdk/agent-loop` và ví dụ response thực tế.
- Threshold "1 lượt reflect có lợi, 2 lượt hết lợi, 3 lượt là dấu hiệu vấn đề thiết kế" (từ scalable.dk) chỉ có confidence thấp, chưa có benchmark định lượng cụ thể đi kèm — cần nguồn academic hoặc case study xác nhận trước khi coi là nguyên tắc chung.
- Chưa có note riêng cho Reflexion pattern (Actor/Evaluator/Self-Reflection 3 vai trò) — hiện chỉ nhắc gọn ở mục 5; nếu cần đào sâu multi-agent critique pattern thì nên tách note riêng, tương tự cách [[agent-reason-plan]] tách riêng deliberative planning.
- Chưa nghiên cứu cách LangGraph hoặc framework khác (ngoài LangChain AgentExecutor cổ điển) triển khai stopping criteria/reflection — mới chỉ có 1 nguồn medium-confidence cho phần LangChain.
</content>
