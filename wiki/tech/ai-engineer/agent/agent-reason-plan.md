---
status: current
updated: 2026-08
sources:
  - https://react-lm.github.io/
  - https://learnprompting.org/docs/agents/react
  - https://www.anthropic.com/engineering/building-effective-agents
  - https://code.claude.com/docs/en/agent-sdk/agent-loop
roadmap: ai-engineer
stage: learning
---

# Reason and Plan — bước 2 của agent loop

**TL;DR**: Reason and Plan là khoảnh khắc agent **suy nghĩ trước khi hành động**. Agent xuất phát từ một mục tiêu (goal) và những sự kiện nó đã biết (từ [[agent-perception-user-input]]), tự hỏi "cần làm gì tiếp theo để đạt mục tiêu?", chia goal thành các bước nhỏ hơn, kiểm tra từng bước có hợp lý không, sắp chúng theo một trình tự rõ ràng, đôi khi còn đoán trước điều gì có thể sai và chuẩn bị phương án dự phòng. Khi kế hoạch đã ổn, agent mới chuyển sang hành động (act/invoke tool). Đây là bước **duy nhất do LLM tự đảm nhiệm** trong 4 bước của [[agent-loop]] — 3 bước còn lại (perceive, act, observe) đều do harness (code bao quanh) thực thi.

## 1. Vị trí trong agent loop

Trong [[agent-loop]] mục 1, 4 bước là perceive → **reason/plan** → act/invoke tool → observe/reflect. Reason/plan là bước 2 — điểm chuyển giao giữa "agent đã biết gì" (perception) và "agent sẽ làm gì" (action):

- **Input của bước này**: toàn bộ ngữ cảnh tích luỹ tới thời điểm hiện tại — task gốc, lịch sử hội thoại, và (từ vòng lặp thứ 2 trở đi) observation/tool result vừa nhận được ở vòng trước.
- **Output của bước này**: một quyết định — trả lời luôn, hỏi thêm thông tin, hoặc gọi tool nào với tham số gì (xem [[agent-loop]] mục 1).
- Bước này chạy **bên trong model**, không thấy được từ bên ngoài trừ khi model được yêu cầu show reasoning (extended thinking) hoặc in ra một dòng `Thought:` tường minh (xem mục 3 bên dưới).

## 2. 4 việc mà reasoning/planning thực sự làm

Đối chiếu định nghĩa bước này với những gì diễn ra bên trong model:

1. **Chia nhỏ mục tiêu (decompose)**: một goal lớn ("fix bug X", "viết báo cáo Y") thường không thể giải quyết trong 1 hành động — model tách nó thành các bước con nhỏ hơn, mỗi bước đủ cụ thể để map sang 1 tool call hoặc 1 câu trả lời.
2. **Kiểm tra tính hợp lý (sanity-check) từng bước**: model đối chiếu bước dự định với facts đã biết — VD nếu chưa đọc file thì chưa nên sửa file, vì chưa biết nội dung hiện tại.
3. **Sắp thứ tự (sequence)**: các bước con cần thứ tự phụ thuộc rõ ràng (đọc trước khi sửa, sửa trước khi test) — đây là phần "plan" theo đúng nghĩa: một đường đi có thứ tự, không phải danh sách rời rạc.
4. **Đoán trước rủi ro (anticipate failure)**: model có thể dự đoán điều gì có thể sai (test có thể vẫn fail sau khi sửa, file có thể không tồn tại) và chuẩn bị bước dự phòng — tuy nhiên phần này **không phải lúc nào cũng tường minh**; nhiều agent loop hiện đại không planning-ahead nhiều bước mà chỉ quyết định 1 hành động tiếp theo rồi để observe ở vòng sau điều chỉnh (xem mục 5 "reactive vs. deliberative planning").

## 3. Gốc học thuật: ReAct — reasoning traces induce/track/update action plans

Paper **ReAct: Synergizing Reasoning and Acting in Language Models** (Yao et al., ICLR 2023, xem [[agent-loop]] mục 3) là nguồn gốc trực tiếp của cụm "reason and plan" trong agent loop hiện đại:

- ReAct cho model sinh ra chuỗi xen kẽ **Thought → Action → Observation**. `Thought` chính là bước reason/plan — một câu suy luận ngắn, viết bằng ngôn ngữ tự nhiên, có nhiệm vụ **"induce, track, and update action plans as well as handle exceptions"** (khởi tạo, theo dõi, và cập nhật kế hoạch hành động, đồng thời xử lý ngoại lệ) (as of react-lm.github.io, confidence: high).
- Điểm mấu chốt: reasoning trace không chỉ là "giải thích" — nó là cơ chế agent dùng để **giữ vững kế hoạch qua nhiều vòng lặp**. Vì mỗi `Thought` được ghi lại vào context, model ở vòng sau đọc lại được lý do vì sao nó chọn hành động ở vòng trước, từ đó biết nên tiếp tục kế hoạch cũ hay điều chỉnh.
- ReAct khắc phục 2 vấn đề của cách tiếp cận thuần reasoning (chain-of-thought không tool) hoặc thuần acting (không suy luận): **hallucination và error propagation** — vì mọi bước reasoning đều được "neo" (grounded) vào observation thật lấy từ môi trường ngoài (VD Wikipedia API), không chỉ dựa vào tri thức nội tại có thể sai của model (as of react-lm.github.io, confidence: high).
- Kết quả benchmark: trên ALFWorld và WebShop (2 benchmark ra quyết định tuần tự), ReAct vượt trội các phương pháp trước đó **34% và 10% absolute success rate** tương ứng, chỉ với vài in-context example; model nhỏ được finetune theo format ReAct còn vượt qua model lớn hơn chỉ dùng prompting (as of react-lm.github.io, confidence: high).
- Đánh giá trên 4 benchmark: HotpotQA, Fever (QA/fact-verification — cần reasoning nhiều), ALFWorld, WebShop (decision-making — cần acting nhiều) — ReAct thắng ở cả 2 nhóm vì kết hợp cả hai.

## 4. Ví dụ cụ thể từ paper gốc

Câu hỏi: "Ngoài Apple, Steve Jobs còn đồng sáng lập công ty nào khác?"

```
Thought 1: Tôi cần tìm thêm về Steve Jobs, cụ thể là các công ty ông đồng sáng lập.
Action 1: Search[Steve Jobs]
Observation 1: Steven Paul Jobs là doanh nhân người Mỹ, đồng sáng lập Apple Inc...
Thought 2: Đoạn này không liệt kê các công ty khác ông đồng sáng lập. Tôi cần tìm thêm.
Action 2: Lookup[co-founded]
Observation 2: Ông đồng sáng lập NeXT và Pixar.
Thought 3: Vậy Steve Jobs còn đồng sáng lập NeXT và Pixar. Trả lời.
Action 3: Finish[NeXT, Pixar]
```

Đối chiếu với 4 việc ở mục 2: `Thought 1` = decompose (goal lớn → cần search trước) + sequence (search trước khi trả lời); `Thought 2` = sanity-check (nhận ra observation chưa đủ) + điều chỉnh kế hoạch (đoán cần lookup thêm thay vì search lại từ đầu); `Thought 3` = tổng hợp và xác nhận điều kiện dừng đã đạt.

## 5. Reasoning tường minh vs. ngầm định trong agent hiện đại

Agent loop production (Claude tool-use loop, OpenAI Agents SDK) hiện thực hoá đúng pattern Thought→Action→Observation của ReAct nhưng **thường không in ra chữ `Thought:` tường minh nữa** — xem [[agent-loop]] mục 3: model trả về `stop_reason: "tool_use"` kèm `tool_use` block, phần reasoning nằm ẩn bên trong quá trình model sinh ra block đó.

Có 2 chế độ, khác nhau ở việc reasoning có **hiển thị được** hay không:

| | Reasoning ngầm định (mặc định) | Extended thinking / reasoning models |
|---|---|---|
| Reasoning có hiển thị? | Không — chỉ thấy `tool_use` block cuối cùng | Có — model sinh riêng 1 khối `thinking` trước khi hành động, xem được nội dung suy luận |
| Khi nào dùng | Task đơn giản, đường đi rõ ràng | Task cần lập kế hoạch nhiều bước, nhiều ràng buộc, dễ sai nếu vội |
| Trade-off | Nhanh hơn, rẻ hơn | Chậm hơn, tốn token hơn, nhưng giảm sai sót ở các bước lập kế hoạch phức tạp |

(xem [[llm-reasoning-vs-standard-models]] để biết chi tiết cơ chế reasoning model)

Ngoài ra còn một phân biệt khác về **độ sâu** của planning, độc lập với việc nó có hiển thị hay không:

- **Reactive (1 bước 1 lần)**: model chỉ quyết định hành động tiếp theo, không cố lập kế hoạch nhiều bước trước — dựa vào việc observe ở vòng sau để tự điều chỉnh. Đây là cách hầu hết agent loop hiện đại vận hành mặc định (đơn giản, ít lỗi tích luỹ từ một kế hoạch sai ngay từ đầu).
- **Deliberative (lập kế hoạch trước nhiều bước)**: model (hoặc 1 sub-agent riêng, gọi là "planner") vạch ra toàn bộ chuỗi bước trước khi hành động bước đầu tiên — phù hợp task phức tạp, nhiều phụ thuộc, nơi việc đi sai hướng ngay từ đầu tốn kém để sửa. Đây chính là ý tưởng của kiến trúc **Planner–Executor**, một agent architecture riêng (xem bảng roadmap "Agent Architectures", hiện `planned`).

## 6. Vì sao reasoning/planning quan trọng

- **Giảm hallucination**: reasoning được neo vào observation thật (ReAct), không phải model bịa ra hành động dựa trên "cảm giác" — khác với chain-of-thought thuần không tool, dễ trôi dạt khỏi facts.
- **Theo dõi tiến độ**: mỗi `Thought`/reasoning step được ghi lại vào context giúp model (và cả người quan sát) biết agent đang ở đâu trong kế hoạch, tránh lặp lại hành động đã làm hoặc quên bước cần làm.
- **Xử lý ngoại lệ**: khi observation không như kỳ vọng (VD tool trả lỗi, test vẫn fail), reasoning ở vòng tiếp theo là nơi model **điều chỉnh kế hoạch** thay vì mù quáng lặp lại hành động cũ.
- **Input sai ở perception → reasoning sai theo**: vì reasoning luôn dựa trên perception tích luỹ tới thời điểm đó (xem [[agent-perception-user-input]] TL;DR), một input mơ hồ hoặc thiếu ở bước 1 sẽ khiến kế hoạch ở bước 2 xây trên nền sai ngay từ đầu.

## 7. Ví dụ cụ thể: "sửa 1 test đang fail" (đối chiếu với [[agent-loop]] mục 5)

| Vòng lặp | Perceive | **Reason/plan** |
|---|---|---|
| 1 | Task: "fix test X" | Chưa biết test viết gì hay sai chỗ nào → cần đọc code trước khi đoán mò cách sửa. Quyết định: gọi `read_file(test_x.py)`. |
| 2 | Đã có nội dung test | Đọc thấy assertion, nhưng chưa biết implementation thật đang trả về gì → cần chạy test để có bằng chứng cụ thể thay vì đoán. Quyết định: gọi `bash(pytest test_x.py)`. |
| 3 | Đã có log lỗi `AssertionError: expected 5, got 4` | Log chỉ đích danh hàm nào, dòng nào sai — kế hoạch sửa đã đủ cụ thể để hành động. Quyết định: gọi `edit_file(sum.py)`. |
| 4 | Đã sửa code | Không thể chắc chắn fix đúng nếu không chạy lại test — đây là bước "đoán trước rủi ro": fix có thể sai hoặc gây regression khác. Quyết định: gọi `bash(pytest test_x.py)` lần nữa để xác nhận trước khi kết luận xong. |

Mỗi hàng minh hoạ: reasoning không phải là suy luận trừu tượng một lần — nó **lặp lại mỗi vòng**, luôn dựa trên perception mới nhất, và luôn kết thúc bằng 1 quyết định hành động cụ thể (hoặc quyết định dừng).

## Liên hệ tới các phần khác

- [[agent-loop]] — reason/plan là bước 2 của vòng lặp 4 bước; note này mở rộng chi tiết riêng cho bước đó, đối xứng với cách [[agent-perception-user-input]] mở rộng bước 1.
- [[agent-perception-user-input]] — input của reasoning luôn là perception tích luỹ tới thời điểm hiện tại; perception sai/thiếu → reasoning sai theo (xem mục 6).
- [[llm-reasoning-vs-standard-models]] — cơ chế kỹ thuật của reasoning model / extended thinking, khi reasoning được hiển thị tường minh thay vì ẩn bên trong quá trình sinh tool call.
- [[ai-engineer-roadmap]] — vị trí reason/plan trong lộ trình học agent (nhóm AI Agents 101); mục "Agent Architectures" (Planner–Executor, ReAct — hiện `planned`) sẽ mở rộng sâu hơn các biến thể deliberative planning nhắc ở mục 5.

## Giới hạn / open questions

- Nguồn learnprompting.org được cung cấp không thực sự đi sâu vào cơ chế "chia nhỏ goal / kiểm tra hợp lý / đoán rủi ro" như mô tả trong yêu cầu gốc — phần lớn nội dung mục 2 và 5 ở trên được tổng hợp từ hiểu biết chung về agent loop + đối chiếu với ReAct paper, không trích trực tiếp 1-1 từ learnprompting.org. Cần tìm nguồn khác (VD paper Planner–Executor, hoặc tài liệu LangChain/AutoGen về multi-step planning) nếu muốn có trích dẫn xác thực riêng cho phần "đoán trước rủi ro và chuẩn bị backup plan".
- Chưa có note riêng cho Planner–Executor architecture (hiện `planned` trong roadmap) — đây là nơi phù hợp để đào sâu deliberative planning (lập kế hoạch nhiều bước trước khi hành động) nhắc ở mục 5, tách biệt hẳn khỏi reasoning-per-step kiểu ReAct.
- Chưa kiểm chứng riêng cách Claude Agent SDK hiển thị/ẩn reasoning step trong thực tế triển khai (extended thinking block cụ thể trông thế nào trong response) — mục 5 dựa trên hiểu biết chung về khái niệm, chưa đối chiếu trực tiếp với `code.claude.com/docs/en/agent-sdk/agent-loop`.
</content>
