---
status: current
updated: 2026-08
sources:
  - https://huggingface.co/learn/agents-course/en/unit1/tools
  - https://platform.claude.com/docs/en/agents-and-tools/tool-use/overview
  - https://platform.claude.com/docs/en/agents-and-tools/tool-use/define-tools
  - https://modelcontextprotocol.io/docs/concepts/tools
  - https://modelcontextprotocol.io/specification/2025-06-18/server/tools
  - https://developers.openai.com/api/docs/guides/function-calling
  - https://arxiv.org/pdf/2210.03629
  - https://arxiv.org/pdf/2302.04761
  - https://www.anthropic.com/engineering/writing-tools-for-agents
  - https://code.claude.com/docs/en/mcp
  - https://aimultiple.com/ai-agent-tools
roadmap: ai-engineer
stage: done
---

# What are Tools? — kỹ năng/tài nguyên bổ sung mà agent gọi tới khi ngôn ngữ tự nhiên không đủ

**TL;DR**: **Tool** là một đơn vị **callable** (function, API, DB query, file system access...) có **contract rõ ràng** (tên, mô tả, input/output schema) mà agent gọi tới để làm những việc LLM không tự làm được từ ngôn ngữ thuần — tính toán chính xác, lấy dữ liệu real-time, hay tạo side-effect (gửi email, ghi DB).

## 1. Vì sao agent cần tool

- Kiến thức của LLM bị **đóng băng** tại thời điểm huấn luyện (training cutoff) — không biết thông tin sau đó, không tự truy vấn được dữ liệu real-time.
- LLM giỏi **dự đoán token tiếp theo**, không giỏi **tính toán chính xác** — paper Toolformer chỉ ra nghịch lý: LLM "exhibit remarkable abilities... but paradoxically struggle with basic functionality, such as arithmetic or factual lookup" (as of arxiv.org/abs/2302.04761, confidence: high).
- LLM không có khả năng tạo **side-effect** thật ngoài việc sinh text — không tự gửi email, không tự ghi file, không tự gọi API thanh toán. Muốn làm những việc này, agent phải "mượn" một tool.
- Nói cách khác: model đảm nhiệm **reasoning/quyết định**, tool đảm nhiệm **act** lên hệ thống bên ngoài.

## 2. Tool là gì, chính xác

- Hugging Face Agents Course định nghĩa ngắn gọn: **"A Tool is a function given to the LLM"**, cần đáp ứng một mục tiêu rõ ràng (as of huggingface.co/learn/agents-course, confidence: high).
- Một tool đầy đủ thường có 4 thành phần:
  - **Tên** (name) — định danh, model dùng để gọi (Anthropic/OpenAI đều giới hạn dạng chuỗi ngắn, ví dụ khớp pattern `^[a-zA-Z0-9_-]{1,64}$`).
  - **Mô tả** (description) — văn bản giải thích chức năng và **khi nào nên/không nên dùng** — đây là phần model dựa vào để quyết định gọi tool nào.
  - **Input schema** — tham số đầu vào có kiểu rõ ràng (thường là JSON Schema).
  - **Output/output schema** (khuyến nghị, không luôn bắt buộc) — cấu trúc kết quả trả về.
- Model **không tự thực thi** tool — nó chỉ sinh ra một structured request (tên tool + input theo schema); runtime/harness bên ngoài mới là bên thực sự chạy code và trả kết quả lại cho model để tiếp tục suy luận. Cơ chế này là nền tảng của bước **Acting/Tool Invocation** — xem [[agent-acting-tool-invocation]].

## 3. Tool khác gì "skill" chung chung của model

| | Tool | Khả năng suy luận nội tại (skill/reasoning) |
|---|---|---|
| Bản chất | Một đơn vị **callable**, có contract tường minh (name/description/schema) | Năng lực sinh ngôn ngữ, suy luận, tổng hợp bên trong trọng số model |
| Thực thi | Chạy **ngoài** model — function thật, API thật, DB thật | Chạy hoàn toàn trong forward-pass của model, không cần hệ thống ngoài |
| Kiểm soát | Model chỉ **quyết định gọi hay không, gọi gì** — không tự chạy được | Model tự "làm" trực tiếp, không cần trung gian |
| Kết quả | Xác định bởi hệ thống ngoài (deterministic hoặc theo trạng thái thật) | Xác định bởi phân phối xác suất của model (probabilistic) |

- Anthropic mô tả tool như "một loại phần mềm mới phản ánh **hợp đồng (contract)** giữa hệ thống tất định (deterministic) và agent phi tất định (non-deterministic)" — khác API call truyền thống luôn cho cùng output, agent có thể gọi tool theo cách biến thiên hoặc không gọi, nên thiết kế tool đòi hỏi tư duy khác thiết kế API thông thường (as of anthropic.com/engineering/writing-tools-for-agents, confidence: high).

## 4. Ví dụ cụ thể: định nghĩa một tool `get_weather`

Theo chuẩn Anthropic (`input_schema` là JSON Schema), một tool điển hình trông như sau:

```json
{
  "name": "get_weather",
  "description": "Get the current weather in a given location. Use this whenever the user asks about weather, temperature, or forecast for a specific place.",
  "input_schema": {
    "type": "object",
    "properties": {
      "location": {
        "type": "string",
        "description": "City and country, e.g. 'Hanoi, Vietnam'"
      },
      "unit": {
        "type": "string",
        "enum": ["celsius", "fahrenheit"]
      }
    },
    "required": ["location"]
  }
}
```

- Khi user hỏi "Hôm nay Hà Nội bao nhiêu độ?", model không tự "biết" — nó trả về một khối `tool_use` với `name: "get_weather"` và `input: {"location": "Hanoi, Vietnam"}`. Ứng dụng (client) chạy API thời tiết thật, rồi gửi lại kết quả qua `tool_result` để model tổng hợp câu trả lời cuối.
- Cấu trúc "name + description + input_schema (+ output_schema)" này **hội tụ** giữa các nhà cung cấp: Anthropic (`input_schema`), OpenAI function calling (`parameters`), và MCP (`inputSchema`/`outputSchema`) — cho thấy đây là chuẩn thiết kế chung, không riêng một hãng nào.

## 5. Các loại tool phổ biến trong thực tế

- **APIs/integrations**: Slack, GitHub, Google Calendar, Salesforce...
- **Functions/structured commands**: chạy code, deploy hệ thống, tính toán.
- **Data sources**: vector DB, search engine, arXiv/PubMed, tài liệu nội bộ.
- **File system / document repositories**: đọc/ghi file, quản lý document.
- Một điểm hay bị nhầm: **RAG (retrieval)** không loại trừ khái niệm tool — trong mô hình "agentic RAG", retrieval được coi như **một tool** mà agent tự quyết định có gọi hay không, thay vì luôn tự động chạy trước mỗi lượt trả lời như RAG truyền thống.

## 6. Nguồn gốc học thuật

- Paper **ReAct** (Yao et al., 2022) định nghĩa vòng lặp Thought → Action → Observation, trong đó Action là một lời gọi tool tương tác với môi trường ngoài — đây được xem là nền tảng lý thuyết cho bước Acting/Tool Invocation trong agent loop hiện đại (as of arxiv.org/abs/2210.03629, confidence: high). Xem chi tiết ở [[agent-reason-plan]].
- Paper **Toolformer** (Schick et al., Meta AI, 2023) là bằng chứng thực nghiệm sớm cho việc dạy LLM tự học gọi tool (calculator, search engine, calendar...) để bù đắp hạn chế nội tại.

## 7. Liên hệ tới các phần khác

- [[agent-what-are-ai-agents]] — tool là một trong các thành phần giúp agent "hành động" (act) lên môi trường, không chỉ "cảm nhận" và "suy luận".
- [[agent-loop]] — tool được gọi ở bước act/invoke tool, ngay sau reason/plan.
- [[agent-acting-tool-invocation]] — mô tả chi tiết cơ chế thực thi tool (ai gọi, ai chạy, vòng lặp tool_use/tool_result).

### Áp dụng với Claude Code

- Claude Code có sẵn **built-in client tools** (Bash, Read, text_editor, v.v.) tuân theo đúng contract chuẩn (name + description + input_schema) của Claude API — model trả `tool_use`, Claude Code (harness) thực thi cục bộ trên máy người dùng rồi gửi lại `tool_result`.
- Ngoài built-in tools, Claude Code mở rộng nguồn tool qua **Model Context Protocol (MCP)** — một chuẩn mở cho phép kết nối tới hàng trăm external tool/database/API (JIRA, GitHub, PostgreSQL, Gmail...) mà không cần hard-code từng tool vào harness (as of code.claude.com/docs/mcp, confidence: high).
- Với Claude Agent SDK, dev có thể định nghĩa **custom tool** qua `SdkMcpTool` (name, description, input_schema, handler) — chạy in-process như một MCP server nội bộ, cùng cấu trúc contract với tool trong Messages API.

## 8. Giới hạn / open questions

- Ranh giới giữa "tool nên định nghĩa mô tả chi tiết cỡ nào là đủ" chưa có công thức chuẩn — Anthropic chỉ khuyến nghị định tính ("ít nhất 3-4 câu", viết như onboarding đồng nghiệp mới), chưa có benchmark định lượng rõ ràng để đánh giá chất lượng mô tả tool.
- Khi số lượng tool trong một agent tăng lên hàng nghìn (ví dụ MCP ecosystem lớn), cơ chế nhồi hết schema vào context không còn hiệu quả — Anthropic có "Tool Search Tool" để discover/load on-demand, nhưng đây là giải pháp còn khá mới và note này chưa đào sâu tradeoff của nó.
- Chưa rõ mức độ chuẩn hoá thực tế giữa các provider (Anthropic/OpenAI/Google) về `outputSchema` — phần lớn nguồn tập trung vào input schema, output schema thường được mô tả là "tuỳ chọn"/"khuyến nghị" chứ chưa phải bắt buộc phổ biến.
