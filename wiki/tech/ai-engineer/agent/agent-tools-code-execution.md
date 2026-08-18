---
status: current
updated: 2026-08
sources:
  - https://platform.claude.com/docs/en/agents-and-tools/tool-use/code-execution-tool
  - https://platform.claude.com/docs/en/agents-and-tools/tool-use/bash-tool
  - https://code.claude.com/docs/en/sandboxing
  - https://www.anthropic.com/engineering/advanced-tool-use
  - https://developers.openai.com/api/docs/guides/tools-code-interpreter
  - https://arxiv.org/abs/2211.10435
  - https://sj-langchain.readthedocs.io/en/latest/tools/langchain.tools.python.tool.PythonREPLTool.html
  - https://weaviate.io/blog/what-is-agentic-rag
roadmap: ai-engineer
stage: learning
---

# Code Execution / REPL Tool — tool cho agent chạy code thật và đọc lại kết quả thực thi

**TL;DR**: Code Execution / REPL là một tool cho phép agent **chạy code** (thường là Python, trong sandbox) và nhận lại `stdout`/`stderr`/`return value` thật vào context, thay vì chỉ sinh code dưới dạng text rồi "hy vọng nó đúng" — nhờ vậy phần tính toán/logic/xử lý dữ liệu được **xác minh tại runtime**, và model có thể tự sửa lỗi dựa trên lỗi thật thay vì đoán đúng ngay lần đầu.

## 1. Vấn đề nó giải quyết

- LLM sinh text bằng cách dự đoán token tiếp theo — kể cả khi sinh ra code hoặc phép tính, nó **không thực sự "chạy" phép tính đó**, chỉ mô phỏng bằng xác suất ngôn ngữ. Điều này khiến LLM hay sai số học/logic dù đã suy luận từng bước đúng hướng.
- Precedent học thuật: **PAL — Program-Aided Language Models** (2023) tách hai việc: LLM sinh **chương trình** làm reasoning trace, còn **phần tính toán thật sự được giao cho Python interpreter** thay vì tự "nhẩm" bằng token.

  > PAL + Codex đạt **72.0%** trên bộ benchmark toán **GSM8K** (Grade-School Math 8K — 8.500 bài toán đố cấp tiểu học dùng để đo khả năng suy luận số học), so với **65.6%** của chain-of-thought thuần (chỉ suy luận bằng text, không thực thi code) (as of arxiv.org/abs/2211.10435, confidence: high).

  Delta 6.4 điểm này là bằng chứng cụ thể: "execute" tốt hơn "generate-and-hope" với bài toán số học/logic.
- Code Execution tool là hiện thực hoá ý tưởng PAL ở tầng **tool trong agent loop**: thay vì chỉ có khả năng "viết code" (text), agent còn có khả năng **thực thi** nó và nhận **observation thật** — output này quay lại làm input cho bước [[agent-observation-reflection]] (bước "quan sát kết quả" trong vòng lặp agent) tiếp theo.
- **Khi nào nên dùng tool này** (thay vì tự viết code chạy tay, hoặc để model "nhẩm" bằng text):
  - Task có phần **tính toán/logic có thể sai nếu chỉ suy luận bằng ngôn ngữ** — số học, thống kê, xử lý dữ liệu, chạy test, parse output có cấu trúc.
  - Bạn cần agent **tự sửa lỗi dựa trên lỗi thật** (ví dụ: chạy `pytest` rồi tự sửa code cho tới khi test pass) thay vì bạn ngồi chạy tay từng bước.
  - Khi thiết kế tool riêng cho agent của mình: nếu tool trả về dữ liệu cần agent **tính toán thêm** trên đó (tổng hợp, lọc, transform), cân nhắc cho agent quyền chạy code thay vì bắt nó tự nhẩm kết quả.

## 2. Cơ chế hoạt động

- Model sinh ra một `tool_use` block chứa code cần chạy (không phải sinh code như câu trả lời cuối cùng).
- Runtime (sandbox container, bash session cục bộ, hoặc hạ tầng server-side của provider) **thực sự thực thi** code đó — đây chính là ranh giới đã nêu trong [[agent-acting-tool-invocation]]: model quyết định, runtime thực thi.
- Kết quả thực thi (`stdout`, `stderr`, `return_code`, file sinh ra...) được đóng gói thành `tool_result` và đưa lại vào context của model cho bước reasoning kế tiếp.
- Nếu code lỗi, model đọc được lỗi **thật** (traceback, exception message) — chứ không phải lỗi tưởng tượng — nên có thể sửa và chạy lại. OpenAI mô tả trực tiếp vòng lặp này: "a model that writes code that fails to run can keep rewriting and running that code until it succeeds"[^1].

### Ví dụ minh hoạ

Model được hỏi: "213 số nguyên tố đầu tiên có tổng bằng bao nhiêu?"

- **Không có code execution**: model tự "nhẩm" bằng token generation → dễ sai vì đây là phép tính dài, không có cơ chế kiểm tra.
- **Có code execution**: model sinh code, tool chạy thật, trả kết quả về:

```python
from sympy import primerange
print(sum(list(primerange(2, 2000))[:213]))
```

```
stdout: 168891
stderr: (rỗng)
return_code: 0
```

Model đọc `stdout: 168891` từ `tool_result` và dùng số đó — con số đến từ runtime thật, không phải model "đoán". Nếu code ném `NameError` hay `IndexError`, model thấy `stderr` thật và tự sửa code ở lượt tiếp theo, đúng vòng lặp act → observe → reason lại đã mô tả trong [[agent-loop]].

### Ví dụ "wire format" thật (Anthropic Messages API)

Để tự dựng, bạn cần 2 thứ: (1) khai báo tool `code_execution` trong request, (2) đọc `tool_result` trả về. Request tối thiểu:

```json
{
  "model": "claude-sonnet-4-5",
  "max_tokens": 1024,
  "tools": [
    { "type": "code_execution_20250825", "name": "code_execution" }
  ],
  "messages": [
    { "role": "user", "content": "213 số nguyên tố đầu tiên có tổng bằng bao nhiêu?" }
  ],
  "betas": ["code-execution-2025-08-25"]
}
```

Model trả về một `tool_use` block chứa code, rồi bạn (hoặc — với `code_execution` là **server-executed tool** — chính hạ tầng Anthropic) chạy code đó và model nhận lại `tool_result` dạng:

```json
{
  "type": "code_execution_tool_result",
  "tool_use_id": "srvtoolu_01ABC...",
  "content": {
    "type": "code_execution_result",
    "stdout": "168891\n",
    "stderr": "",
    "return_code": 0
  }
}
```

Vì đây là server-executed tool, bạn không tự chạy code — chỉ cần gửi request có khai báo tool, Anthropic tự thực thi và trả `tool_result` kèm theo response cuối cùng; bạn chỉ cần đọc `content.stdout`/`content.stderr` trong response.

## 3. Phân biệt với các khái niệm gần giống

- **Khác "khả năng viết code" đơn thuần**:
  - Viết code chỉ là sinh text.
  - Code execution tool bắt buộc phải có bước **thực thi + trả kết quả thật về context**.
  - Một agent "biết viết code" mà không có tool execution thì không tự xác minh được gì.
- **Khác RAG** (Retrieval-Augmented Generation — kỹ thuật bổ sung kiến thức cho model bằng cách retrieve tài liệu ngoài rồi nhét vào context, không phải chạy code):
  - RAG giúp model biết thêm **thông tin**, không giúp model kiểm chứng **tính toán/logic**.
  - Hai kỹ thuật bổ sung cho nhau chứ không thay thế nhau — thường kết hợp trong mô hình "agentic RAG"[^2].
- **Khác workflow tĩnh** (chuỗi bước cố định, chạy đúng thứ tự định sẵn, không đọc lại kết quả thật để đổi hướng):
  - Agent có code execution theo kiểu **ReAct** (Reasoning + Acting — mẫu hình agent xen kẽ giữa suy luận và hành động) thì lặp: reasoning → act → quan sát kết quả thật → reasoning tiếp.
  - Nhờ vậy agent có khả năng tự sửa lỗi mà workflow tĩnh không có.
- **Khác retry đơn thuần**:
  - Retry là thử lại đúng chiến lược cũ khi gặp lỗi tạm thời (network timeout...).
  - Self-correction từ code execution là model **đổi chiến lược** (sửa code, đổi cách tiếp cận) sau khi đọc lỗi/kết quả thật — đây là phân biệt Anthropic đưa ra giữa "retry" và "self-correction" trong tool use.

**Tóm lại**: cả 4 so sánh trên đều quy về một điểm — code execution là tool **duy nhất** trong nhóm này buộc phải có bước "chạy thật rồi đọc lại kết quả thật", còn viết-code-suông, RAG, workflow tĩnh và retry đơn thuần đều thiếu ít nhất một trong hai vế đó (chạy thật, hoặc đọc lại để đổi hướng).

## 4. Các implementation thực tế (không phải một tính năng riêng của một vendor)

| Vendor / dự án | Tên tool | Đặc điểm |
|---|---|---|
| Anthropic (Claude API) | **Code execution tool** (`code_execution_20250825`, `code_execution_20260120+`) | Sandbox container riêng: Python 3.11.12, 1GB RAM, 5GB storage, có sẵn pandas/numpy/matplotlib; **không có internet** nên chỉ dùng được thư viện cài sẵn; từ version `code_execution_20260120` có "REPL state persistence" — state giữ nguyên qua nhiều lần chạy trong cùng phiên[^3] |
| Anthropic (Claude API) | **Bash tool** (`bash_20250124`) | Client tool: ứng dụng gọi giữ 1 process bash sống xuyên suốt nhiều lượt gọi tool → working directory, biến môi trường, file đã tạo đều giữ nguyên giữa các lệnh, cho phép agent lặp "chạy – xem lỗi – sửa – chạy lại" |
| OpenAI (Responses/Assistants API) | **Code Interpreter** | Chạy Python trong container sandbox; kết quả (kể cả file sinh ra) trả về qua `container_file_citation` để model đọc tiếp |
| Microsoft Foundry / Agent Framework | **Code Interpreter** | Cùng pattern: chạy Python trong sandbox cho data analysis/math/file processing — xác nhận đây là category tool chuẩn trên nhiều platform lớn, không phải tính năng riêng của một hãng |
| LangChain (`langchain_experimental`) | **PythonREPLTool** | Đưa agent một Python shell sống; output của `print()` được trả về làm observation. **Cảnh báo thực tế** (đáng nhớ nhất trong bảng này): tool có thể thực thi code tuỳ ý (xoá file, gọi network) nên **bắt buộc phải sandbox riêng khi dùng production** — gói này hiện không còn được maintain tích cực, LangChain đang thay bằng lựa chọn sandbox mạnh hơn cho v1[^4] |

- Điểm chung: đều là **sandboxed REPL** — cô lập code khỏi hệ thống thật, và **trả kết quả thực thi thật** vào context model. Một số framework third-party (qua LiteLLM) còn cho phép đổi sandbox hosted của OpenAI sang self-hosted (E2B, Docker) khi cần giữ code/dữ liệu nội bộ — cho thấy pattern này portable qua vendor, không khoá vào 1 API cụ thể.

### Chọn cái nào trước? (starter recipe)

- **Đang dùng Claude Code (CLI)**: không cần setup gì — Bash tool cục bộ đã sẵn có, xem mục "Áp dụng với Claude Code" bên dưới.
- **Đang tự gọi Claude API để build agent riêng**: thêm khối `{"type": "code_execution_20250825", "name": "code_execution"}` vào mảng `tools` (xem ví dụ JSON ở mục 2) — không cần tự dựng sandbox, Anthropic chạy hộ.
- **Cần internet / cài thêm package trong lúc chạy** (mà cả 2 lựa chọn trên đều không cho phép, xem mục 5): tự dựng sandbox riêng bằng **E2B** hoặc **Docker self-hosted**, rồi bọc nó thành một custom tool (`tool_use` → gọi API sandbox của bạn → trả `tool_result`).
- **Đang prototype nhanh bằng LangChain**: cân nhắc kỹ trước khi dùng `PythonREPLTool` — xem cảnh báo "không sandbox" trong bảng trên.

## 5. Giới hạn thực tế đáng chú ý

- Sandbox **không có internet** (trường hợp Anthropic) → chỉ dùng được thư viện đã cài sẵn, không `pip install` gói mới giữa chừng.
- State **không** giữ nguyên giữa các container invocation khác nhau (khác lượt gọi tool riêng biệt) — chỉ giữ trong cùng 1 phiên/1 container đang chạy, đây là giới hạn "trí nhớ REPL" cần phân biệt với session Bash cục bộ dài hơi của Claude Code.
- Code execution tool miễn phí thêm chi phí khi dùng chung với `web_search`/`web_fetch` (vì nó cũng phục vụ lọc kết quả động bên trong các tool đó); ngoài trường hợp này áp dụng giá riêng cho code execution[^3].
- **Guardrail vận hành**: vòng lặp "viết → chạy → sửa" có thể lặp nhiều lượt nếu model không hội tụ (code sai liên tục) — mỗi lượt là một round-trip tốn token + phí sandbox. Khi tự build agent, nên đặt **giới hạn số lượt tự sửa** (ví dụ tối đa 3-5 lần retry) và **timeout tổng cho cả tác vụ**, tương tự guardrail cho vòng lặp agent nói chung ở [[llm-stopping-criteria]] — chưa thấy tài liệu vendor nêu con số mặc định cụ thể cho riêng code execution, nên đây là khuyến nghị chung chứ không phải trích dẫn từ nguồn.

## Nguồn & độ tin cậy

Các claim ít trọng yếu hơn (mô tả tính năng/giá/trạng thái maintain của chính vendor) được gom lại đây thay vì chèn inline, để giữ mạch đọc ở phần thân bài:

| # | Claim | Nguồn | Độ tin cậy |
|---|---|---|---|
| [^1] | OpenAI mô tả vòng lặp tự sửa code của Code Interpreter | developers.openai.com/api/docs/guides/tools-code-interpreter | high (tài liệu chính thức OpenAI) |
| [^2] | RAG và code execution bổ sung cho nhau trong "agentic RAG" | weaviate.io/blog/what-is-agentic-rag | medium (blog vendor, không phải paper) |
| [^3] | Chi tiết sandbox/giá của Anthropic Code execution tool | platform.claude.com/docs/en/agents-and-tools/tool-use/code-execution-tool | high (tài liệu chính thức Anthropic) |
| [^4] | `langchain_experimental.PythonREPLTool` không còn maintain tích cực | github.com/langchain-ai/langchain/issues/33800 | medium (GitHub issue, không phải release note chính thức) |

## Liên hệ tới các phần khác

- So với [[agent-what-are-tools]] (khái niệm tool nói chung trong agent) và [[agent-tool-definition]] (cách định nghĩa/khai báo một tool cho model): code execution là một **loại tool cụ thể** trong tập hợp tool nói chung, nhưng đặc biệt ở chỗ đầu ra của nó là **kết quả xác minh được bằng runtime thật** (không phải dữ liệu tra cứu tĩnh như search tool).
- So với [[agent-acting-tool-invocation]] (ranh giới giữa model quyết định gọi tool và runtime thực thi tool): code execution tuân theo đúng ranh giới đó; với Anthropic, code execution tool thuộc nhóm **server-executed tools** (chạy trên hạ tầng Anthropic, không phải code của bạn).
- So với [[agent-observation-reflection]] (bước agent đọc lại kết quả hành động để quyết định bước tiếp theo): `stdout`/`stderr`/`return_code` chính là dạng "observation" cụ thể nhất — có thể verify được bằng máy, không phụ thuộc model tự đánh giá đúng/sai.

### Áp dụng với Claude Code

- Claude Code (CLI) **không dùng** hosted code execution tool (container sandbox của Claude API) mà dùng cơ chế riêng: **Bash tool cục bộ**, chạy shell command (kể cả chạy Python script, test suite, build command) ngay trên máy người dùng, được cô lập bằng sandbox cấp hệ điều hành (macOS Seatbelt; Linux/WSL2 qua kernel packages) thay vì container từ xa (as of code.claude.com/docs/en/sandboxing, confidence: high).
- Vì sandbox OS-level tự enforce ranh giới filesystem/network đã khai báo, Claude Code có thể chạy Bash command **không cần hỏi xác nhận thủ công cho từng lệnh** — đây chính là cơ chế vận hành an toàn cho vòng lặp "viết code → chạy → đọc kết quả thật → tự sửa" mà không cần người duyệt từng bước.
- Nói cách khác: khái niệm "code execution / REPL" áp dụng cho Claude Code dưới hình thức **local process execution có sandbox OS**, không phải remote hosted container như Claude API — về mặt hành vi với model thì tương đương (model vẫn nhận `stdout`/`stderr` thật), chỉ khác nơi thực thi.

## Giới hạn / open questions

- Chưa rõ chi tiết cấu hình sandbox OS-level của Claude Code (Seatbelt profile cụ thể, danh sách syscall/network bị chặn) — tài liệu nguồn chỉ nêu ở mức khái quát.
- Chưa kiểm chứng độc lập con số hiệu năng PAL (72.0% vs 65.6% trên GSM8K) ngoài paper gốc — chỉ trích dẫn từ chính nguồn arXiv.
- Chưa rõ mức độ "REPL state persistence" của Anthropic (`code_execution_20260120+`) khác biệt cụ thể thế nào so với session Bash cục bộ về giới hạn thời gian sống, dung lượng, hay cơ chế dọn dẹp.
- Chưa có so sánh thực nghiệm trực tiếp về độ an toàn/hiệu năng giữa các cách tiếp cận sandbox khác nhau (container hosted vs OS-level local vs self-hosted E2B/Docker) trong cùng một benchmark.
