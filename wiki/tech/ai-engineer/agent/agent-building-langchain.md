---
status: current
updated: 2026-08
sources:
  - https://docs.langchain.com/oss/python/langchain/overview
  - https://www.langchain.com/blog/langchain-langgraph-1dot0
  - https://docs.langchain.com/oss/python/migrate/langchain-v1
  - https://python.langchain.com/docs/concepts/lcel/
  - https://octomind.dev/blog/why-we-no-longer-use-langchain-for-building-our-ai-agents
  - https://www.anthropic.com/research/building-effective-agents
  - https://code.claude.com/docs/en/agent-sdk/overview
  - https://docs.langchain.com/oss/python/deepagents/comparison
  - https://en.wikipedia.org/wiki/LangChain
roadmap: ai-engineer
stage: learning
---

# LangChain — framework open-source phổ biến nhất để xây LLM app, một tầng abstraction trên raw provider SDK

**TL;DR**: **LangChain** cung cấp một interface thống nhất cho model của mọi provider (đổi **OpenAI** ↔ **Anthropic** ↔ **Gemini** gần như chỉ đổi một dòng code) cùng các building block ghép được với nhau (prompt, tool, retriever, memory) và hàm **create_agent** — một "agent harness": bộ khung dựng sẵn tự chạy vòng lặp gọi tool thay cho bạn. Đổi lại, bạn trả giá bằng nhiều lớp abstraction chồng lên nhau (lỗi xảy ra trong code framework nên khó debug) và API thay đổi liên tục qua các phiên bản (**version churn**) — nhiều team production cuối cùng quay về manual loop ([[agent-building-manual-from-scratch]]) hoặc chuyển xuống **LangGraph**.

## LangChain là gì và vì sao ra đời

- Do **Harrison Chase** tạo ra, open-source từ tháng 10/2022 — trước cả khi các provider có **function calling** chuẩn hoá. Giá trị cốt lõi ban đầu: **composability** — ghép LLM với prompt, retriever, memory thành "chains". Không có paper học thuật gốc; framework được định nghĩa qua docs/blog, thiết kế agent lấy cảm hứng từ **ReAct** ([[agent-architecture-react]]).
- Là framework LLM open-source được adopt rộng nhất: hệ sinh thái đạt khoảng ~90M downloads/tháng (số liệu tự công bố — xem Giới hạn), dùng production tại Uber, LinkedIn, Klarna, JP Morgan, BlackRock.
- Vị trí trong ladder: nằm **một tầng abstraction trên** raw provider SDK. Thay vì tự viết vòng lặp function-calling ([[agent-building-function-calling-overview]]), bạn khai báo model + tools + prompt và framework chạy loop hộ.

## LangChain thực sự cung cấp gì

- **Unified model interface**: một API duy nhất cho chat model, embedding... của mọi provider. Đổi provider thường chỉ là đổi model string (`init_chat_model("claude-sonnet-4-5")` → `init_chat_model("gpt-5")`), giữ nguyên phần còn lại của app.
- **Building blocks composable**: prompt templates, output parsers (ép output thành JSON/Pydantic), **Tool** abstraction, **retrievers** + hàng trăm vector-store integrations (mảng RAG vẫn là giá trị mạnh nhất còn lại), memory.
- **Agent abstraction — `create_agent`**: docs 1.0 mô tả là "a minimal, highly configurable agent harness" = **Model + Tools + Prompt + Middleware**. Bản chất vẫn là vòng lặp tool-calling (model chọn tool → thực thi → trả kết quả về model → lặp), nhưng framework lo phần plumbing.
- **Middleware system** (mới ở 1.0): các "trạm chặn" cho phép chèn logic trước/sau mỗi bước trong agent loop — built-in có **human-in-the-loop** (dừng lại chờ người duyệt trước khi chạy tool nhạy cảm), tóm tắt hội thoại khi context dài, PII redaction (che thông tin cá nhân).
- **Hệ sinh thái package**: `langchain-core` (abstractions/Runnable), các package provider (`langchain-openai`, `langchain-anthropic`...), `langchain` (framework high-level), `langgraph` (runtime low-level), cùng **LangSmith** (SaaS thương mại cho tracing/evals, dùng được cả ngoài LangChain).

### Ví dụ tối thiểu với `create_agent` (đường chính thức từ 1.0)

```python
from langchain.agents import create_agent

def get_weather(city: str) -> str:
    """Lấy thời tiết hiện tại của một thành phố."""  # docstring = mô tả tool cho model
    return f"Trời nắng ở {city}, 32°C"

agent = create_agent(
    model="claude-sonnet-4-5",          # đổi provider = đổi string này
    tools=[get_weather],                # hàm Python thường, framework tự convert thành tool schema
    system_prompt="Bạn là trợ lý thời tiết, trả lời ngắn gọn.",
)
result = agent.invoke({"messages": [{"role": "user", "content": "Thời tiết Hà Nội thế nào?"}]})
print(result["messages"][-1].content)
```

- Toàn bộ vòng lặp (model chọn tool → framework thực thi `get_weather` → trả kết quả về model → model viết câu trả lời cuối) diễn ra bên trong `invoke` — đây chính là phần plumbing mà ở manual loop bạn phải tự viết.

## LCEL — LangChain Expression Language

- Cơ chế chaining "chữ ký" của thời 0.x: mọi component (prompt, model, parser, retriever, function) đều tuân theo một interface chung tên **Runnable**, nên nối được với nhau bằng toán tử pipe `|` — giống pipe trong shell: output của bước trước thành input của bước sau. Chuỗi thu được (**RunnableSequence**) tự có sẵn `invoke`/`stream`/`batch`/async và tracing LangSmith.
- Ví dụ RAG chain kinh điển (minh hoạ cấu trúc — cần một `vector_store` đã index tài liệu từ trước thì mới chạy được):

```python
from langchain_core.prompts import ChatPromptTemplate
from langchain_core.output_parsers import StrOutputParser
from langchain.chat_models import init_chat_model

retriever = vector_store.as_retriever()        # vector_store: đã index tài liệu sẵn
prompt = ChatPromptTemplate.from_template(
    "Trả lời dựa trên context:\n{context}\n\nCâu hỏi: {question}"
)
model = init_chat_model("claude-sonnet-4-5")   # đổi provider = đổi string này

chain = {"context": retriever, "question": lambda x: x} | prompt | model | StrOutputParser()
chain.invoke("LangChain là gì?")
```

- **Trạng thái hiện tại**: từ 1.0, LCEL bị de-emphasize cho agent building — hướng dẫn chính thức xoay quanh `create_agent`; LCEL còn dùng cho composition đơn giản, còn pattern LCEL-heavy cũ nằm trong `langchain-classic`. Kinh nghiệm cộng đồng: chain quá ~4 pipe hoặc cần loop/branch → chuyển sang LangGraph.

## Ladder abstraction (đặt LangChain vào bối cảnh)

| Mức | Là gì | Công cụ |
|---|---|---|
| Plain LLM call | 1 request SDK, không tool/state | Raw SDK |
| Manual loop | Tự viết vòng lặp function-calling | Raw SDK ([[agent-building-manual-from-scratch]]) |
| RAG chain / workflow cố định | retriever + prompt + model + parser | LCEL |
| Tool-calling agent | Model tự chọn tool trong loop | LangChain `create_agent` |
| Stateful graph orchestration | Điều khiển từng node/edge, durable state | LangGraph |
| Batteries-included harness | Planning, sub-agents, filesystem sẵn | Deep Agents |

## LangChain vs LangGraph (cùng công ty, hai tầng)

- **LangChain** = tầng cao: đường nhanh với các agent pattern chuẩn (`create_agent`). **LangGraph** = tầng thấp: orchestration stateful dạng graph, kiểm soát chi tiết workflow phức tạp trộn deterministic + agentic.
- Từ 1.0, agent của LangChain **chạy trên runtime LangGraph** — nên kế thừa sẵn **durable execution** (agent bị dừng giữa chừng có thể resume từ checkpoint đã lưu), persistence, streaming, **human-in-the-loop** (chèn bước người duyệt vào giữa flow), và bạn có thể "start simple rồi drop down xuống LangGraph khi cần control".
- Cả hai đạt **v1.0 ngày 22/10/2025** (Python + JS), cam kết không breaking change đến 2.0.
- Đáng chú ý: các case production nổi tiếng (Klarna assistant 85M user, Uber test-generation, LinkedIn recruiter agents, Replit) chạy trên **LangGraph**, không phải LangChain high-level (as of langchain.com/built-with-langgraph, confidence: high).

## Trade-off thẳng thắn

- **Abstraction overhead**: wrapper có giá trị năm 2022 khi API các provider còn lộn xộn; nay các vendor đã hội tụ về tool-calling tương tự nhau, nên 3-4 lớp class/Runnable phải xuyên qua để làm custom retry/routing trở thành chi phí thuần (nhận định tổng hợp từ practitioner posts — xem Giới hạn).
- **Debugging opacity**: case kinh điển — **Octomind** dùng LangChain production ~12 tháng rồi gỡ bỏ, vì abstraction cứng nhắc khiến code low-level khó viết, stack trace lồng sâu buộc "debug framework code mình không viết"; thay bằng manual loop trên raw SDK thì codebase đơn giản hẳn. LangSmith là câu trả lời của LangChain cho vấn đề này (tracing từng bước), nhưng là SaaS thương mại.
- **Version churn** — lịch sử API thay đổi qua từng bản:
  - 0.1 (01/2024): deprecate `LLMChain`, chuyển sang LCEL.
  - 0.2: deprecate `AgentExecutor`.
  - 0.3: bắt buộc Pydantic v2.
  - 1.0 (10/2025): đẩy toàn bộ legacy (`LLMChain`, `AgentExecutor`, `ConversationBufferMemory`...) sang package riêng `langchain-classic`; `create_react_agent` bị thay bằng `create_agent`; drop Python 3.9.
  - Hệ quả: tutorial/code mẫu cũ lỗi thời rất nhanh — ngay cả URL docs gốc (`python.langchain.com`) giờ cũng 308-redirect sang `docs.langchain.com`.
- **Anthropic khuyến cáo ngược chiều**: guide "Building effective agents" cảnh báo framework "tạo thêm các lớp abstraction che mất prompt/response thực, khó debug", khuyên bắt đầu bằng LLM API trực tiếp và giảm lớp abstraction khi lên production (as of anthropic.com/research/building-effective-agents, confidence: high).
- **Pattern thoát phổ biến**: team outgrow LangChain thì hoặc (a) về manual loop trên raw SDK, hoặc (b) xuống LangGraph — chính LangChain cũng thừa nhận qua framing "drop down to LangGraph".

## Khi nào nên / không nên dùng

- **Nên**: prototype nhanh; cần multi-provider thật sự (Claude cho reasoning, model rẻ cho classification, embeddings cho RAG); tận dụng kho integrations (700+ được trích dẫn phổ biến); team muốn pattern chuẩn thay vì tự thiết kế loop.
- **Không nên**: agent chỉ dùng 1 provider với yêu cầu custom sâu (manual loop ngắn hơn và dễ debug hơn); workflow phức tạp cần state control chi tiết (đi thẳng LangGraph); team dị ứng breaking change.

## Liên hệ tới các phần khác

- [[agent-building-manual-from-scratch]] và [[agent-building-function-calling-overview]] — tầng bên dưới mà LangChain wrap lại; hiểu manual loop trước thì mới thấy `create_agent` đang giấu gì.
- [[agent-architecture-react]] — pattern gốc truyền cảm hứng cho agent design của LangChain (tên cũ `create_react_agent`).
- [[ai-engineer-roadmap]] — node kế tiếp trong nhánh framework là LangGraph và LlamaIndex.

### Áp dụng với Claude Code

- **Claude Code không dùng và không expose LangChain** — nó là harness Claude-only theo triết lý ngược lại: thay vì provider-agnostic chains, **Claude Agent SDK** ship sẵn một agent loop opinionated (gather context → act → verify → repeat) với tool file/bash/web built-in, hooks, subagents, permissions, và giải bài toán tool integration bằng **MCP** (**Model Context Protocol** — chuẩn mở để cắm tool/data source ngoài vào LLM app) thay vì Tool abstraction của LangChain.
- Quan hệ hai chiều: Claude dùng được **bên trong** LangChain (package `langchain-anthropic` sau `init_chat_model`), nhưng stack của Anthropic không bao giờ wrap provider khác. Muốn tự viết loop thì dùng Client SDK (chính là hướng manual-from-scratch).
- LangChain có bảng so sánh chính thức Deep Agents vs Claude Agent SDK: Deep Agents chạy mọi model (100+ providers), Claude Agent SDK chỉ Claude — trade-off điển hình: Claude-only thì SDK build nhanh hơn, debug dễ hơn; multi-provider thì LangChain thắng.
- Đối trọng của LangSmith trong Claude Code không phải tracing SaaS mà là các primitive minh bạch built-in: hooks tại lifecycle points, permission prompts, session transcripts.

## Giới hạn / open questions

- Số liệu adoption (90M downloads/tháng, ~99-134k stars) do LangChain tự công bố hoặc từ nguồn thứ cấp — chưa kiểm chứng độc lập.
- Mức độ LCEL "bị bỏ" sau 1.0 là suy luận từ cấu trúc docs mới, chưa có tuyên bố deprecate chính thức cho LCEL core.
- Nhận định "abstraction overhead là chi phí thuần" tổng hợp từ nhiều practitioner post độc lập (Octomind và các bài tương tự), chưa có benchmark định lượng đối chứng.
- Chưa nghiên cứu sâu: LangChain JS/TS (note này thiên Python); chi tiết middleware API 1.0; so sánh định lượng overhead (latency/token) của LangChain vs manual loop.
- Chưa so trực tiếp với LlamaIndex/DSPy/CrewAI — mới chỉ ghi nhận positioning tổng quát (LlamaIndex retrieval-first, DSPy prompt optimization, CrewAI/AutoGen multi-agent).
- Cam kết "không breaking change đến 2.0" mới từ 10/2025 — chưa đủ thời gian kiểm chứng với track record churn trước đó.
