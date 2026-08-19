---
status: current
updated: 2026-08
sources:
  - https://react-lm.github.io/
  - https://arxiv.org/abs/2210.03629
  - https://arxiv.org/pdf/2210.03629
  - https://github.com/ysymyth/ReAct
  - https://www.promptingguide.ai/techniques/react
  - https://reference.langchain.com/python/langchain-classic/agents/react/agent/create_react_agent
  - https://weaviate.io/blog/what-is-agentic-rag
  - https://code.claude.com/docs/en/agent-sdk/agent-loop
  - https://code.claude.com/docs/en/how-claude-code-works
  - https://platform.claude.com/docs/en/build-with-claude/extended-thinking
roadmap: ai-engineer
stage: learning
---

# ReAct (Reason + Act) — kiến trúc agent xen kẽ suy luận tường minh với hành động gọi tool

TL;DR: ReAct là pattern cho LLM lặp vòng **Thought → Action → Observation** — model tự nói ra lý do trước khi gọi tool, dùng kết quả tool để cập nhật bước suy luận tiếp theo, lặp lại tới khi đủ dữ kiện để trả lời. Đây là paper học thuật (ICLR 2023) đã hình thức hoá cái mà roadmap này gọi chung là "agent loop" (perceive → reason/plan → act → observe).

## Bối cảnh & nguồn gốc

- Paper: "ReAct: Synergizing Reasoning and Acting in Language Models" — Shunyu Yao, Jeffrey Zhao, Dian Yu, Nan Du, Izhak Shafran, Karthik Narasimhan, Yuan Cao (Princeton + Google Research/Brain).
- Đăng arXiv:2210.03629 tháng 10/2022, sau đó được accept chính thức tại **ICLR 2023**.
- Trang chủ dự án/paper: react-lm.github.io; code gốc do tác giả chính (ysymyth) maintain tại github.com/ysymyth/ReAct.

## Vấn đề mà ReAct giải quyết

Trước ReAct có hai hướng tách biệt, mỗi hướng thiếu một nửa:

- **Chain-of-Thought (CoT) thuần suy luận**: model chỉ "nghĩ thầm" bằng **parametric knowledge** (kiến thức đã học sẵn trong trọng số model, không tra cứu gì thêm), không có cách xác minh hay cập nhật thông tin với thế giới thực → dễ hallucination, và một khi suy luận đi lệch hướng thì sai sót cứ dồn tích qua các bước tiếp theo (**error propagation**) vì không có gì để "phanh" lại.
- **Agent chỉ hành động (action-only)**: các agent RL/imitation-learning trước đó có thể gọi tool/tương tác môi trường nhưng không có bước suy luận tường minh nào để lập kế hoạch, theo dõi tiến độ sub-goal, hay xử lý ngoại lệ khi kết quả không như mong đợi.

ReAct kết hợp cả hai: reasoning trace giúp model tự lập, theo dõi và cập nhật kế hoạch hành động cũng như xử lý ngoại lệ; action giúp model lấy thêm thông tin thật từ bên ngoài thay vì chỉ dựa vào kiến thức nội tại — hai phần bổ trợ lẫn nhau trong cùng một vòng lặp.

## Vòng lặp ReAct

Cấu trúc lặp, mỗi vòng gồm 3 phần:

1. **Thought** — model tự giải thích bằng ngôn ngữ tự nhiên: tại sao cần làm bước tiếp theo, đang thiếu thông tin gì.
2. **Action** — model gọi một tool cụ thể (vd. `Search[query]`, API tra cứu, database query...).
3. **Observation** — kết quả trả về từ tool, được đưa lại vào context để làm input cho Thought kế tiếp.

Lặp lại chu trình này cho tới khi model tự quyết định đã đủ dữ kiện và phát ra hành động cuối (thường là `Finish[answer]`).

### Ví dụ minh hoạ (HotpotQA-style, theo promptingguide.ai)

```
Thought 1: Tôi cần tìm hiểu về Colorado orogeny và "eastern sector" của nó.
Action 1: Search[Colorado orogeny]
Observation 1: Colorado orogeny là một giai đoạn tạo núi ở Colorado và vùng lân cận...

Thought 2: Kết quả chưa nói rõ "eastern sector" mở rộng tới đâu, cần tìm thêm.
Action 2: Search[eastern sector]
Observation 2: Eastern sector mở rộng vào vùng High Plains.

Thought 3: Cần biết cao độ (elevation) của High Plains.
Action 3: Search[High Plains (United States)]
Observation 3: High Plains có cao độ dao động từ khoảng 1,800 đến 7,000 ft.

Thought 4: Đã đủ dữ kiện để trả lời.
Action 4: Finish[1,800 to 7,000 ft]
```

Mỗi Observation trực tiếp định hình Thought kế tiếp — đây chính là điểm khác biệt so với CoT (không có Observation, không có Action) và so với action-only (không có Thought hiển thị).

### Vòng lặp tối giản viết bằng code (pseudocode)

Ý tưởng cốt lõi có thể viết lại thành một vòng `for` gọi LLM lặp đi lặp lại, parse output để tách Thought/Action, chạy tool tương ứng, rồi nối Observation vào lại prompt cho lượt sau:

```python
def react_loop(question: str, tools: dict, max_steps: int = 6) -> str:
    scratchpad = ""  # tích luỹ Thought/Action/Observation qua các vòng
    for step in range(max_steps):
        prompt = build_prompt(question, tools, scratchpad)
        completion = llm.generate(prompt, stop=["Observation"])
        thought, action, action_input = parse_react_output(completion)

        if action == "Finish":
            return action_input  # model tự quyết định đã đủ dữ kiện

        if action not in tools:
            observation = f"Lỗi: không có tool tên '{action}'"
        else:
            observation = tools[action](action_input)  # thực thi tool thật

        scratchpad += f"Thought: {thought}\nAction: {action}[{action_input}]\n"
        scratchpad += f"Observation: {observation}\n"

    return "Không hoàn thành trong giới hạn số bước."
```

Vài điểm cần lưu ý khi tự viết loop này trong production:
- **Parse lỗi**: nếu model không sinh đúng format `Action: X[input]`, cần fallback (retry với instruction rõ hơn, hoặc trả lỗi có kiểm soát) thay vì crash.
- **Giới hạn số bước** (`max_steps`): bắt buộc phải có, nếu không loop có thể chạy vô hạn khi model liên tục quyết định "cần tìm thêm".
- Cách viết trên mô phỏng đúng ý tưởng gốc của paper (parse action dạng text tự do), nhưng hệ thống hiện đại thường thay `parse_react_output` bằng **native tool-calling** của LLM API (OpenAI function calling, Anthropic tool_use) — model trả về structured JSON cho tool call thay vì text cần parse, giảm hẳn lỗi parse ở trên.

## Kết quả benchmark chính (paper gốc)

| Benchmark | Loại task | Kết quả ReAct |
|---|---|---|
| HotpotQA (multi-hop QA) | Hỏi đáp | Giảm hallucination/error-propagation so với CoT thuần, nhờ grounding qua Wikipedia API đơn giản |
| FEVER | Fact verification | Tương tự — grounded bằng tra cứu thực tế thay vì suy luận nội tại |
| ALFWorld | Ra quyết định tương tác | Vượt baseline imitation/RL learning **+34% absolute success rate** |
| WebShop | Ra quyết định tương tác | Vượt baseline imitation/RL learning **+10% absolute success rate** |

Các kết quả trên đạt được chỉ với 1-2 ví dụ **few-shot** (vài ví dụ mẫu chèn thẳng vào prompt, không cần huấn luyện lại model) trong prompt, không cần finetune. Paper cũng báo cáo một model nhỏ được **finetune** theo lối ReAct có thể vượt qua model lớn hơn nhiều chỉ dùng prompting thuần (as of arxiv.org/abs/2210.03629, confidence: medium).

## So sánh với các pattern liên quan

- **Plain LLM call**: một lượt sinh câu trả lời duy nhất từ context/training data, không có retrieval, không có vòng lặp refine.
- **RAG cổ điển (naive)**: retrieve tài liệu một lần rồi generate — cũng là "single-shot", không có reasoning loop hay validate chất lượng retrieval (**grounding** — tức bám vào dữ liệu thật thay vì chỉ suy luận nội tại). "Agentic RAG" mới là dạng thêm ReAct-style planning/looping lên trên RAG (as of weaviate.io, confidence: medium).
- **Workflow tĩnh (predefined pipeline)**: chuỗi bước hard-code cố định, không thích nghi — model không tự quyết định bước tiếp theo dựa trên observation.
- **ReAct agent**: có thể điều phối nhiều tool (API, database, web search), thích nghi theo từng Observation thay vì đi theo đường cố định.

## Trade-off thực tế khi dùng ReAct trong production

Đây là điểm hay bị bỏ qua trong các bài giới thiệu lý thuyết nhưng lại là thứ hay gây sự cố khi chạy thật:

- **Latency & chi phí token tăng**: mỗi vòng Thought/Action/Observation là một lượt gọi model riêng — một câu hỏi cần 4 vòng như ví dụ trên nghĩa là 4 lượt inference thay vì 1.
- **Loop có thể bị kẹt**: nếu một tool call thất bại (vd. API tra cứu trả lỗi) và không có gì "nhớ" là hành động đó đã thử và fail, model có thể lặp lại đúng Action y hệt ở vòng kế tiếp — vì lỗi vẫn nằm trong scratchpad nhưng model không được huấn luyện/prompt để tránh lặp lại hành động đã thất bại. Cách giảm thiểu phổ biến: giới hạn số lần retry cùng một action, hoặc chèn instruction rõ ràng "đừng lặp lại action đã thất bại" vào prompt.
- Đây là quan sát tổng hợp từ nhiều nguồn thứ cấp, chưa có số liệu benchmark chính thức đo riêng tần suất loop bị kẹt (confidence: low).

## Triển khai thực tế

- **LangChain** có `create_react_agent` — bám sát paper gốc: vòng lặp Thought → Action (tool call) → Observation, dùng prompt template với biến `tools`, `tool_names`, `agent_scratchpad` (chuỗi Thought/Action/Observation tích luỹ, tương đương biến `scratchpad` trong pseudocode ở trên). LangChain hiện coi đây là API legacy, khuyến nghị dùng `create_agent` (dựa trên native tool-calling API của LLM, không parse text tự do) cho production (as of reference.langchain.com, confidence: medium).
- Ví dụ ứng dụng thường được nhắc tới (nguồn blog tổng hợp, chưa verify sâu, chỉ nêu để hình dung): agent sửa code kiểu SWE-agent (đọc file, chạy shell, sửa code theo vòng ReAct-style), agent customer-support phải tra cứu CRM/order trước khi quyết định hành động (vd. refund).

## Liên hệ tới các phần khác

- ReAct là dạng cụ thể hoá của [[agent-loop]] — vòng perceive/reason → act → observe generic được academic hoá thành Thought/Action/Observation.
- Liên hệ trực tiếp tới [[agent-reason-plan]] (bước "reason" trong loop chính là Thought của ReAct) và [[agent-observation-reflection]] (Observation feed ngược vào Thought kế tiếp).
- Khác với CoT thuần (xem phần Prompt Engineering / [[prompt-engineering]]) ở chỗ ReAct có Action/Observation thật, không chỉ suy luận nội tại.

### Áp dụng với Claude Code

**Có áp dụng, ở mức cấu trúc vòng lặp** — Claude Code (qua Claude Agent SDK) chạy đúng nhịp Action → Observation của ReAct: model đánh giá state hiện tại, có thể trả lời text và/hoặc yêu cầu gọi tool, SDK thực thi tool rồi đưa kết quả trở lại vào context — lặp lại (mỗi vòng gọi là một "turn") tới khi Claude trả lời không kèm tool call nữa (as of code.claude.com/docs/en/agent-sdk/agent-loop, confidence: high). Docs "How Claude Code works" diễn đạt cùng ý bằng 3 giai đoạn gather context → take action → verify results, và nói rõ mỗi tool call cho Claude thông tin mới để định hình bước kế — đúng tinh thần "Observation định hình Thought kế tiếp" của ReAct.

**Khác biệt: phần "Thought" là tuỳ chọn, không bắt buộc.** Paper ReAct luôn có Thought hiển thị vì đó là kết quả trực tiếp của việc prompt model theo few-shot. Claude Code thì khác — không bắt buộc phải "nói ra suy nghĩ" trước mỗi tool call. Phần gần nhất với Thought tường minh là tính năng riêng của Anthropic gọi là **interleaved thinking**: Claude sinh một khối "thinking" hiển thị, gọi tool, nhận kết quả, rồi sinh tiếp khối thinking khác để suy luận về kết quả đó — trong cùng một turn, trước khi quyết định hành động kế tiếp.

Vài điểm cần biết nếu định dựa vào interleaved thinking để có Thought tường minh như ReAct:
- Nó là một **block dữ liệu có cấu trúc** riêng trong response (loại "thinking", có thể bị encrypt/rút gọn), khác với free-text reasoning mà ReAct sinh ra qua prompting thường.
- Nó **không phải mặc định trên mọi model** — ví dụ bị giới hạn/không hỗ trợ trên một số model nhỏ hơn, và quy tắc bật/tắt khác nhau giữa các model — nên không thể coi là một đảm bảo kiến trúc cố định giống ReAct học thuật (as of platform.claude.com/docs/en/build-with-claude/extended-thinking, confidence: high).
- Agent SDK cũng có tham số `effort` (low/medium/high/xhigh/max) điều chỉnh model "suy nghĩ" nhiều hay ít mỗi turn — đây là một tham số điều khiển mức reasoning, tách biệt với việc reasoning đó có hiển thị ra như một khối Thought hay không; paper ReAct gốc không có khái niệm tương đương.

**Tóm lại**: Claude Code áp dụng đúng cấu trúc vòng lặp ReAct hình thức hoá, nhưng "Thought hiển thị tường minh" là tính năng tuỳ chọn (interleaved/adaptive thinking) chứ không phải mặc định bắt buộc như trong paper gốc.

## Giới hạn / open questions

- Chưa có tài liệu chính chủ nào của Anthropic trích dẫn trực tiếp paper ReAct 2022 khi mô tả agent loop của Claude Code/Agent SDK — mối liên hệ ở trên là suy luận cấu trúc, không phải tuyên bố chính thức.
- Các ví dụ ứng dụng thực tế (SWE-agent, customer-support agent) trong note này dựa trên nguồn tổng hợp có confidence thấp, chưa verify trực tiếp từ paper/case study gốc.
- Chưa đào sâu: hiệu năng ReAct so với tool-calling agent hiện đại (native function calling của OpenAI/Anthropic) trên benchmark mới hơn 2022; paper gốc dùng few-shot prompting kiểu text-parsing hành động, khác với cách LLM hiện tại gọi tool qua structured API.
- Chưa rõ mức độ "interleaved thinking" của Anthropic có thực sự implement đúng ý tưởng ReAct hay là một cơ chế độc lập được thiết kế song song — cần đọc kỹ hơn phần kỹ thuật (encrypted thinking blocks, tokenization) để so sánh chính xác.
