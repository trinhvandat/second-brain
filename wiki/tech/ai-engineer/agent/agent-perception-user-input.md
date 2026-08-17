---
status: current
updated: 2026-08
sources:
  - https://www.ibm.com/think/topics/ai-agent-perception
  - https://marktalks.com/perception-in-ai-understanding-its-types-and-importance/
  - https://www.anthropic.com/engineering/building-effective-agents
  - https://huggingface.co/learn/agents-course/en/unit1/agent-steps-and-structure
  - https://code.claude.com/docs/en/agent-sdk/agent-loop
  - https://code.claude.com/docs/en/agent-sdk/overview
  - https://www.anthropic.com/engineering/effective-harnesses-for-long-running-agents
  - https://github.com/anthropics/claude-code/issues/34566
  - https://github.com/anthropics/claude-code/issues/55040
roadmap: ai-engineer
stage: learning
---

# Perception / User Input — bước đầu tiên của agent loop

**TL;DR**: **Perception** (hay **user input**) là bước agent "nghe" và chuẩn hoá dữ liệu thô từ bên ngoài thành dạng model dùng được. Perception tốt nghĩa là agent bắt đầu [[agent-loop]] với **sự thật**, không phải phỏng đoán — input sai/mơ hồ ở bước này sẽ làm sai lệch mọi bước reason/act/observe phía sau (ví dụ thật ở mục "Áp dụng với Claude Code" ngay dưới đây).

## Áp dụng với Claude Code (đọc trước — phần thực hành nhất của note)

Claude Code (CLI/Agent SDK) hiện thực perception rất cụ thể, không chỉ ở mức khái niệm. Chia làm 3 nhóm:

**Nhóm 1 — input đầu vào (prompt & tool call)**

- **Bước "receive prompt"**: agent loop của Claude Agent SDK/Claude Code chính thức mô tả là *receive prompt (Claude nhận prompt + system prompt + tool definitions + conversation history) → evaluate và respond → execute tools → lặp lại → trả kết quả*. "Receive prompt" chính là bước perception/user input được hiện thực hoá.
- **Hook `UserPromptSubmit`**: fires mỗi khi user gửi prompt, dùng để tiêm thêm context/làm sạch input trước khi nó vào loop. Đăng ký trong `.claude/settings.json`, hook nhận input qua stdin (JSON có field `prompt`) và có thể chèn thêm context bằng cách in ra stdout:

  ```json
  // .claude/settings.json
  {
    "hooks": {
      "UserPromptSubmit": [
        {
          "hooks": [
            { "type": "command", "command": "$CLAUDE_PROJECT_DIR/.claude/hooks/clean-input.sh" }
          ]
        }
      ]
    }
  }
  ```

  ```bash
  #!/bin/bash
  # .claude/hooks/clean-input.sh — đọc JSON từ stdin, in thêm context ra stdout
  input=$(cat)
  prompt=$(echo "$input" | jq -r '.prompt')
  # ví dụ: chèn thêm ngày giờ hiện tại làm context trước khi prompt vào loop
  echo "Current date: $(date)"
  ```
- **`PreToolUse` hook**: cùng cơ chế command + stdin/stdout như trên nhưng fire trước mỗi tool call, dùng để validate/transform input của tool trước khi nó chạy — mở rộng perception ra mọi ranh giới tool call, không chỉ ranh giới prompt ban đầu.

**Nhóm 2 — tool result & ảnh (quan sát trong lúc chạy loop)**

- **Tool result cũng là kênh perception**: mỗi `tool_result` được đưa lại vào context như tín hiệu "world state" mới trước bước evaluate kế tiếp — perception không chỉ là input ban đầu mà là mọi lần "nghe" trong vòng lặp (chi tiết ở mục 1 bên dưới).
- **Resize ảnh là ví dụ thật**: Claude Code tự động resize/downscale screenshot trước khi đưa vào context model (nhắm khoảng ~2000px) — đúng ví dụ "agent resize ảnh" trong định nghĩa perception (as of github.com/anthropics/claude-code/issues/34566, confidence: high).
- **Khi perception hỏng, cả loop hỏng theo**: một bug thật đã ghi nhận — khi pipeline resize ảnh lỗi trên ảnh quá khổ, ảnh gốc chưa resize bị đưa thẳng vào context, khiến API báo lỗi vượt giới hạn kích thước ảnh (tối đa 2000px khi có nhiều ảnh) ở **mọi lượt sau đó**, làm session "bị khoá cứng" cho đến khi `/clear` hoặc restart — minh chứng trực tiếp cho luận điểm "input sai ở bước perception làm hỏng toàn bộ các bước sau" (as of github.com/anthropics/claude-code/issues/34566, confidence: high). Issue #55040 xác nhận đây vẫn là điểm chưa hoàn thiện, chưa giải quyết triệt để.

**Nhóm 3 — "grounding" phiên dài & Agent SDK**

- **"Grounding" nghĩa là gì**: trong ngữ cảnh này, grounding = agent chủ động đi xác minh lại trạng thái thật của môi trường (đọc git log, file tiến độ...) thay vì tin vào giả định/trí nhớ cũ — nói cách khác là "tự làm mới perception" trước khi làm việc tiếp, tránh reasoning dựa trên thông tin đã lỗi thời.
- **Grounding lại state ở đầu mỗi phiên**: với agent chạy dài, Anthropic khuyến nghị chủ động đọc lại git log, file tiến độ, danh sách feature ở đầu mỗi phiên làm việc thay vì giả định continuity — một dạng "perception chủ động" để agent bắt đầu vòng lặp mới bằng sự thật đã xác minh, đúng tinh thần TL;DR của note này.
- **Agent SDK thừa hưởng toàn bộ hành vi trên**: Agent SDK dùng chung "tools, agent loop, và context management" với Claude Code CLI, nên các cơ chế perception kể trên (resize ảnh, hook, context loading) áp dụng cho mọi agent tuỳ biến xây trên SDK, không riêng CLI.

## 1. Định nghĩa và vị trí trong agent loop

- IBM định nghĩa perception là khả năng agent thu thập, diễn giải và xử lý dữ liệu từ môi trường để hiểu trạng thái hiện tại, làm nền cho quyết định tiếp theo — thứ tự vận hành luôn là **perceive → process → act** (as of ibm.com/think/topics/ai-agent-perception, confidence: medium — trang trả 403 khi fetch trực tiếp, thông tin lấy qua search snippet).
- Trong [[agent-loop]] (4 bước: perceive → reason/plan → act/invoke tool → observe/reflect), perception chính là bước 1 — nhưng xảy ra ở **2 thời điểm khác nhau**:
  - **Vòng lặp đầu tiên**: perception = xử lý input gốc từ người dùng (task ban đầu) — đúng nghĩa đen "user input".
  - **Từ vòng lặp thứ 2 trở đi**: perception = đọc `tool_result`/observation của bước trước, cộng dồn vào context — Hugging Face Agents Course gọi chu trình này là **Think → Act → Observe**, trong đó Observe chuyển raw API response thành structured data rồi đưa ngược vào context cho vòng kế tiếp.
- Nói cách khác: user input là **trường hợp riêng** của perception; perception là khái niệm rộng hơn, bao trùm mọi tín hiệu agent "nghe" được dọc theo vòng lặp, không chỉ lúc khởi động. Claude Code hiện thực rõ cả hai thời điểm này (chi tiết ở mục "Áp dụng với Claude Code").

## 2. Vì sao perception phải "sạch" trước khi reasoning

- Anthropic (bài "Building Effective Agents") mô tả agent về bản chất là *"LLMs using tools based on environmental feedback, in a loop"* — nếu input/feedback sai, mọi reasoning dựa trên đó cũng lệch, vì agent lấy "ground truth" từ đó để tự đánh giá tiến độ.
- Nguyên lý **garbage in, garbage out (GIGO)** nặng hơn với agent so với 1 lệnh gọi LLM đơn, vì kết quả perception đi thẳng vào action tiếp theo trong loop: input sai không chỉ ra câu trả lời sai, mà còn có thể kích hoạt hành động sai trong thế giới thực (xoá nhầm dữ liệu, gửi nhầm tin nhắn). Claude Code có một bug thật minh hoạ đúng điều này — xem mục "Áp dụng với Claude Code".
- Ngoài text, agent nói chung còn "nghe" qua giọng nói (speech-to-text) hoặc sensor (LIDAR, radar) — nhưng Claude Code hiện chỉ xử lý **text + ảnh**, nên phần này chỉ mang tính bối cảnh, không có ví dụ CLI cụ thể để đối chiếu (xem "Giới hạn / open questions").

## 3. Ví dụ cụ thể: "sửa 1 test đang fail"

| Vòng lặp | Perception (input agent "nghe" được) |
|---|---|
| 1 | User gõ: "fix test X" — perception = đọc và tokenize câu lệnh |
| 2 | Kết quả `read_file(test_x.py)` — perception = đọc nội dung file, nhận diện assertion sai |
| 3 | Kết quả `bash(pytest test_x.py)` — perception = đọc log `AssertionError: expected 5, got 4` |
| 4 | Kết quả `bash(pytest test_x.py)` lần 2 — perception = đọc log `PASSED` → tín hiệu dừng |

Từ vòng 2 trở đi, "perception" không còn là user input gốc mà là quan sát môi trường (tool result) — đúng phân biệt ở mục 1.

## Liên hệ tới các phần khác

- [[agent-loop]] — perception chính là bước 1 (perceive) của vòng lặp 4 bước; note này đào sâu riêng bước đó.
- [[agent-what-are-ai-agents]] — mô tả vì sao agent cần liên tục perceive kết quả môi trường, không chỉ nhận input 1 lần như một LLM call đơn.
- [[ai-engineer-roadmap]] — vị trí perception trong lộ trình học agent (nhóm AI Agents 101).

## Giới hạn / open questions

- Nguồn IBM (định nghĩa perception nói chung) không fetch trực tiếp được (403) — thông tin lấy qua search snippet, cần verify lại nếu muốn trích dẫn chi tiết hơn.
- Chưa rõ Claude Code có cơ chế "lọc nhiễu" nào cho input dạng audio/sensor hay không (CLI hiện chủ yếu xử lý text + ảnh) — phần "giọng nói, sensor" ở mục 2 mang tính khái niệm chung của AI agent, chưa có ví dụ Claude Code cụ thể để đối chiếu.

