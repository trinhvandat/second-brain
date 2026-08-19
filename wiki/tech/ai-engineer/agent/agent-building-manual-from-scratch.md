---
status: current
updated: 2026-08
sources:
  - https://platform.claude.com/docs/en/agents-and-tools/tool-use/implement-tool-use
  - https://platform.claude.com/docs/en/agents-and-tools/tool-use/how-tool-use-works
  - https://platform.claude.com/docs/en/agents-and-tools/tool-use/tool-runner
  - https://developers.openai.com/api/docs/guides/function-calling
  - https://help.openai.com/en/articles/8555517-function-calling-in-the-openai-api
  - https://www.anthropic.com/engineering/building-effective-agents
  - https://arxiv.org/abs/2210.03629
  - https://code.claude.com/docs/en/agent-sdk/agent-loop
  - https://claude.com/blog/building-agents-with-the-claude-agent-sdk
  - https://www.aibuilderclub.com/blog/how-to-build-ai-agent-from-scratch
  - https://www.neurond.com/blog/how-to-build-an-ai-agent
  - https://www.analyticsvidhya.com/blog/2025/10/ai-agents-vs-llms-vs-rag/
roadmap: ai-engineer
stage: learning
---

# Manual from scratch — tự viết toàn bộ agent loop bằng cách gọi thẳng LLM API, không dùng framework

TL;DR: Xây agent "from scratch" nghĩa là tự tay viết một vòng `while` gọi thẳng API chat/messages của provider (Anthropic/OpenAI), tự **parse** tool-call trong response, tự **execute** hàm tương ứng, tự **append** kết quả vào message history, rồi gọi lại API — lặp tới khi model không còn yêu cầu tool nào nữa. Đổi lại sự minh bạch và ít phụ thuộc, bạn phải tự làm lại những việc framework/SDK vốn cho miễn phí: retry, streaming, quản lý state/memory, và điều phối multi-agent.

## Vòng lặp thực tế trông như thế nào

Cấu trúc lặp gồm 5 bước, giống nhau dù dùng Anthropic hay OpenAI:

1. Gửi request tới API kèm danh sách `tools` đã định nghĩa và toàn bộ `messages` hiện có.
2. Kiểm tra response: nếu `stop_reason` (Anthropic) là `tool_use`, hoặc model trả về một tool-call object thay vì text thường (OpenAI) → có việc phải làm.
3. **Parse** thủ công các `tool_use` content block (id, name, JSON input) từ `response.content`.
4. **Execute** hàm tương ứng trong code của chính mình — model **không tự chạy tool**, nó chỉ quyết định gọi tool nào với tham số gì.
5. **Append** kết quả vào `messages`: thêm lượt `assistant` chứa `tool_use`, rồi thêm lượt `user` chứa `tool_result` (gắn đúng `tool_use_id`) — rồi gọi lại API. Lặp tới khi `stop_reason` là `end_turn` (không còn tool call nào).

Đây chính là cùng một chu trình mà [[agent-loop]] mô tả ở mức khái quát (perceive → reason/plan → act → observe), và là bản hiện thực hoá cụ thể của pattern [[agent-architecture-react]] (Thought → Action → Observation) khi làm việc trực tiếp với raw API — bước "Action" ở đây chính là [[agent-acting-tool-invocation]].

### Ví dụ minh hoạ (giả lập, ~theo Anthropic Messages API)

```python
messages = [{"role": "user", "content": "Thời tiết Hà Nội hôm nay?"}]

while True:
    response = client.messages.create(
        model="claude-...", messages=messages, tools=[weather_tool]
    )
    if response.stop_reason != "tool_use":
        break  # model đã trả lời cuối cùng, thoát vòng lặp

    messages.append({"role": "assistant", "content": response.content})
    tool_results = []
    for block in response.content:
        if block.type == "tool_use":
            result = call_local_function(block.name, block.input)  # tự execute
            tool_results.append({
                "type": "tool_result",
                "tool_use_id": block.id,
                "content": result,
            })
    messages.append({"role": "user", "content": tool_results})  # append lại history

print(response.content)  # câu trả lời cuối
```

Toàn bộ pattern này nằm gọn trong khoảng 60 dòng Python (as of aibuilderclub.com, confidence: medium) — không cần cài LangChain/LangGraph/CrewAI gì cả.

## Trade-off: được gì, mất gì

**Được (so với dùng framework):**
- **Minh bạch tuyệt đối** — thấy từng request/response thật, không có tầng abstraction "phép màu" nào che giấu prompt thực sự được gửi đi, dễ debug hơn.
- **Ít dependency, ít version churn** — không phải theo kịp breaking change của framework.
- Anthropic tự khuyến nghị hướng này trong bài "Building Effective Agents": *"many patterns can be implemented in a few lines of code"*, và cảnh báo framework *"often create extra layers of abstraction that can obscure the underlying prompts and responses, making them harder to debug"* (as of anthropic.com/engineering/building-effective-agents, confidence: high). Nếu vẫn dùng framework, họ khuyên phải "ensure you understand the underlying code" — vì hiểu sai những gì đang chạy bên dưới là nguồn lỗi phổ biến.

**Mất (phải tự làm lại):**
- **Retry/error handling** khi API lỗi hoặc rate-limit.
- **Streaming** response theo token.
- **Memory/state persistence** — tự quản lý lịch sử hội thoại dài, tự nén context khi gần vượt giới hạn (framework như Claude Agent SDK có compaction tự động).
- **Multi-agent coordination** — điều phối nhiều agent con, subagent với context/budget riêng.
- **Bookkeeping dễ sai**: phải append đúng cả lượt `assistant` (tool_use) lẫn lượt `user` (tool_result, đúng `tool_use_id`) vào history — quên hoặc sai thứ tự khiến model "mất dấu" ngữ cảnh (as of aibuilderclub.com, confidence: medium). Anthropic Messages API còn có ràng buộc: block `tool_result` phải đứng trước block text trong cùng lượt `user`, sai thứ tự sẽ bị lỗi 400.

## Khi nào hợp lý, khi nào không

- **Hợp lý**: agent đơn giản, một tác vụ, ít tool; mục đích học để hiểu cơ chế agent hoạt động thật sự bên dưới (nhiều tutorial 2026 dùng chính cách này để dạy — "building from scratch transfers this understanding directly to any framework you use later", as of leoniemonigatti.com, confidence: medium).
- **Kém hợp lý**: cần multi-agent orchestration, cần persistence/resume session qua nhiều lần chạy, cần retry/streaming phức tạp ở quy mô production — lúc này framework/SDK (vd. Claude Agent SDK, hoặc LangGraph) tiết kiệm công sức đáng kể hơn nhiều so với cái giá phải trả về minh bạch.
- Khung tham chiếu rộng hơn của Anthropic: augmented LLM (1 call + tool/memory) → workflow (pipeline cố định, code quyết định luồng) → agent (model tự quyết định luồng trong vòng lặp). Nguyên tắc chung: tìm giải pháp đơn giản nhất trước, chỉ leo thang độ phức tạp khi eval cho thấy giải pháp đơn giản không đủ (as of anthropic.com/engineering/building-effective-agents, confidence: high).

## Liên hệ tới các phần khác

- [[agent-loop]] — bản khái quát của vòng lặp mà note này mô tả cụ thể ở mức code.
- [[agent-architecture-react]] — nguồn gốc học thuật (ReAct, arXiv:2210.03629) của pattern Thought/Action/Observation mà vòng lặp manual này hiện thực hoá.
- [[agent-tool-definition]], [[agent-acting-tool-invocation]] — chi tiết về cách định nghĩa tool và bước "Action" trong vòng lặp.
- [[ai-engineer-roadmap]] — mục "Building AI Agents".

### Áp dụng với Claude Code

- **Claude Code (CLI) không phải là ví dụ của pattern "manual from scratch"** — nó là bản triển khai tham chiếu (reference implementation) của một vòng lặp đã được đóng gói sẵn, không phải thứ người dùng CLI tự viết bằng tay.
- Claude Agent SDK (nền tảng của Claude Code) mô tả chính nó là *"embed Claude Code's autonomous agent loop in your own applications"* — tức là một loop đã đóng gói, chạy cùng cơ chế fetch → parse tool_use → execute → append → repeat như note này mô tả, nhưng do SDK tự vận hành thay vì developer tự viết.
- SDK/Claude Code cho "miễn phí" đúng những thứ mà cách làm manual phải tự bù đắp: tool execution + lập lịch song song, permission modes, hooks (PreToolUse/PostToolUse/Stop...), tự động compact context khi gần đầy, session persistence/resume/fork, giới hạn `max_turns`/`max_budget_usd`, và subagent orchestration.
- Do đó nếu người dùng muốn tự tay viết agent loop kiểu "manual from scratch" để học, họ nên dùng thẳng Anthropic Messages API (gói `anthropic`) chứ không phải Claude Code/Claude Agent SDK — vì SDK chính là thứ thay thế cho việc viết tay đó.

## Giới hạn / open questions

- Chưa có benchmark định lượng đáng tin cậy so sánh chi phí vận hành thực tế (thời gian dev, tỷ lệ lỗi) giữa agent viết tay và agent dùng framework ở quy mô production — claim "production agents chạy trên hand-written loop" trong bài aibuilderclub.com chỉ là giai thoại, độ tin cậy thấp.
- Chưa rõ ranh giới cụ thể ("bao nhiêu tool", "bao nhiêu turn") để quyết định khi nào nên chuyển từ manual loop sang framework — các nguồn chỉ đưa nguyên tắc định tính (đơn giản trước, phức tạp sau).
- Chưa khảo sát sâu cách các provider khác (Gemini, Mistral) mô tả cùng pattern này — note này tập trung chủ yếu vào Anthropic và OpenAI.
