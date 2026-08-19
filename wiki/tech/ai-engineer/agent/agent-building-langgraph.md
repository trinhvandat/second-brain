---
status: current
updated: 2026-08
sources:
  - https://docs.langchain.com/oss/python/langgraph/overview
  - https://langchain-ai.github.io/langgraph/concepts/low_level/
  - https://docs.langchain.com/oss/python/langgraph/persistence
  - https://www.langchain.com/blog/langchain-langgraph-1dot0
  - https://langchain-ai.github.io/langgraph/concepts/human_in_the_loop/
  - https://www.langchain.com/built-with-langgraph
  - https://www.anthropic.com/research/building-effective-agents
  - https://docs.langchain.com/langgraph-platform
roadmap: ai-engineer
stage: learning
---

# LangGraph — orchestration runtime dạng graph để xây agent stateful, kiểm soát từng bước

**TL;DR**: **LangGraph** mô hình hoá agent thành một **state machine** dạng graph: mỗi **node** là một hàm nhận/trả state, mỗi **edge** quyết định bước tiếp theo (cố định hoặc conditional). Đổi lại việc phải tự vẽ graph thay vì gọi một hàm `create_agent` dựng sẵn, bạn được thứ mà tầng LangChain high-level giấu đi: kiểm soát tường minh flow, **persistence/checkpointing** (dừng và resume giữa chừng), **human-in-the-loop**, và **time-travel** debug — vì thế nó là tầng mà các production agent lớn (Klarna, Uber, LinkedIn) thực sự chạy trên, chứ không phải LangChain high-level (as of langchain.com/built-with-langgraph, confidence: high).

## LangGraph là gì và vị trí trong stack

- Là **runtime orchestration low-level** của hệ sinh thái LangChain, open-source từ đầu 2024, đạt **v1.0 ngày 22/10/2025** cùng lúc với LangChain 1.0 (Python + JS).
- Vị trí trong ladder abstraction (xem bảng đầy đủ ở [[agent-building-langchain]]): nằm **dưới** LangChain `create_agent` và **trên** manual loop ([[agent-building-manual-from-scratch]]). Từ 1.0, chính `create_agent` của LangChain cũng **chạy trên runtime LangGraph** — "drop down to LangGraph" là đường thoát chính thức khi cần control.
- Khác biệt tư duy so với chain/agent-harness:
  - **Chain (LCEL)**: pipeline một chiều, không loop.
  - **Agent harness (`create_agent`)**: vòng lặp tool-calling dựng sẵn, bạn không đụng vào flow.
  - **LangGraph**: bạn tự khai báo graph — trộn được bước **deterministic** (luôn chạy, theo thứ tự) với bước **agentic** (model quyết định rẽ nhánh), điều mà hai tầng trên không cho phép.
- **Không phụ thuộc LangChain**: dùng được với raw SDK bất kỳ; nhưng thực tế đa số dùng kèm model interface của LangChain cho tiện.

## Ba khái niệm lõi: State, Node, Edge

- **State**: một schema (thường là `TypedDict` hoặc Pydantic model) mô tả dữ liệu chảy qua graph — ví dụ `messages`, `retry_count`, kết quả trung gian. Mỗi node trả về **partial update**, runtime merge vào state theo **reducer** (ví dụ `add_messages` để append thay vì ghi đè) — hợp triết lý immutability: node không mutate state cũ mà trả về delta.
- **Node**: hàm Python thường `(state) -> dict` — gọi LLM, chạy tool, hay logic thuần tuý đều được.
- **Edge**:
  - **Normal edge**: node A xong luôn chạy node B.
  - **Conditional edge**: một hàm nhìn vào state và trả về tên node kế tiếp — đây là chỗ "agentic" nằm (model gọi tool tiếp hay kết thúc?).
- Vòng lặp agent = **cycle trong graph** (agent → tools → agent...) — thứ mà DAG thuần không biểu diễn được (so sánh ở [[agent-architecture-dag]]).

## Ví dụ tối thiểu: ReAct agent tự dựng bằng graph

```python
from typing import Annotated, TypedDict
from langgraph.graph import StateGraph, START, END
from langgraph.graph.message import add_messages
from langgraph.prebuilt import ToolNode
from langchain.chat_models import init_chat_model

def get_weather(city: str) -> str:
    """Lấy thời tiết hiện tại của một thành phố."""
    return f"Trời nắng ở {city}, 32°C"

class State(TypedDict):
    messages: Annotated[list, add_messages]   # reducer: append, không ghi đè

model = init_chat_model("claude-sonnet-4-5").bind_tools([get_weather])

def agent_node(state: State):
    return {"messages": [model.invoke(state["messages"])]}

def route(state: State):                      # conditional edge: model muốn gọi tool?
    last = state["messages"][-1]
    return "tools" if last.tool_calls else END

builder = StateGraph(State)
builder.add_node("agent", agent_node)
builder.add_node("tools", ToolNode([get_weather]))
builder.add_edge(START, "agent")
builder.add_conditional_edges("agent", route)
builder.add_edge("tools", "agent")            # cycle: tool xong quay về agent

graph = builder.compile()
result = graph.invoke({"messages": [{"role": "user", "content": "Thời tiết Hà Nội?"}]})
```

- So với `create_agent` (một dòng), bạn viết ~25 dòng — nhưng giờ flow là **của bạn**: chèn thêm node validate trước `tools`, node summarize sau N vòng, hay nhánh escalate sang human đều chỉ là thêm node/edge.
- So với manual loop: cấu trúc tương đương `while True: gọi model → chạy tool`, nhưng được "reify" thành data structure — nhờ đó runtime mới chèn được checkpointing/streaming/interrupt vào giữa các bước.

## Persistence & Human-in-the-loop — lý do thật sự để chọn LangGraph

- **Checkpointer**: khi compile graph với một checkpointer (`InMemorySaver`, SQLite, Postgres), runtime **lưu state sau mỗi node (superstep)** theo `thread_id`. Hệ quả:
  - **Multi-turn memory**: gọi lại cùng `thread_id` là hội thoại tiếp tục — short-term memory không phải tự quản ([[agent-memory-short-term]]).
  - **Durable execution / fault tolerance**: process chết giữa chừng → resume từ checkpoint cuối, không chạy lại từ đầu — quan trọng với agent chạy dài, tool đắt tiền.
  - **Time-travel**: tua lại checkpoint bất kỳ, sửa state, chạy lại từ đó — debug agent theo cách mà manual loop không có.
- **Human-in-the-loop qua `interrupt()`**: node gọi `interrupt(payload)` → graph **dừng hẳn và lưu state** (không phải chờ blocking); người duyệt xong thì resume bằng `Command(resume=...)` — có thể sau vài giây hoặc vài ngày. Đây là cách chuẩn để bắt approve trước tool nhạy cảm (xoá DB, gửi tiền).
- **Streaming**: stream theo nhiều mode — token-by-token, hoặc từng bước state update — cần cho UX agent chạy lâu.
- Multi-agent: pattern **supervisor/subgraph** — mỗi agent là một graph con, graph cha điều phối ([[agent-architecture-multi-agent-orchestration]]).

## Khi nào nên / không nên dùng

| Tình huống | Lựa chọn hợp lý |
|---|---|
| Prototype nhanh, loop tool-calling chuẩn | LangChain `create_agent` (chạy trên LangGraph sẵn) |
| Workflow trộn bước cố định + bước agentic, cần branch/retry tường minh | **LangGraph** |
| Agent chạy dài cần resume, hoặc bắt buộc human approval giữa flow | **LangGraph** (checkpointer + `interrupt`) |
| 1 provider, loop đơn giản, muốn ít dependency và dễ debug nhất | Manual loop ([[agent-building-manual-from-scratch]]) |
| Cần deploy managed (scale, task queue, API) | **LangGraph Platform** — nhưng đây là sản phẩm thương mại, tách khỏi OSS |

- Lưu ý ngược chiều: Anthropic khuyên bắt đầu bằng LLM API trực tiếp và chỉ thêm framework khi thấy cần — LangGraph ít "ma thuật" hơn LangChain high-level (graph là code bạn viết), nhưng vẫn là một dependency có learning curve riêng (state/reducer/checkpoint semantics) (as of anthropic.com/research/building-effective-agents, confidence: high).
- Cam kết stability: v1.0 hứa không breaking change đến 2.0 — đáng giá vì track record churn của hệ LangChain trước đó (as of blog LangChain 10/2025, confidence: medium).

## Liên hệ tới các phần khác

- [[agent-building-langchain]] — tầng high-level bên trên; note này là "drop down" tầng dưới của cùng hệ sinh thái.
- [[agent-building-manual-from-scratch]] — tầng dưới nữa: hiểu manual loop rồi mới thấy graph reification mua được gì (checkpoint, interrupt) với giá nào (dependency, learning curve).
- [[agent-architecture-react]] — pattern mà ví dụ graph ở trên implement; [[agent-architecture-dag]] — vì sao agent cần cycle chứ không chỉ DAG.
- [[agent-architecture-planner-executor]] và [[agent-architecture-multi-agent-orchestration]] — các pattern dựng tự nhiên bằng subgraph/supervisor trên LangGraph.

### Áp dụng với Claude Code

- **Claude Code không dùng và không expose LangGraph** — nó ship một agent loop opinionated (gather context → act → verify → repeat) thay vì cho bạn tự vẽ graph. Nhưng nhiều bài toán LangGraph giải có "đối trọng" trong Claude Code: human-in-the-loop ≈ **permission prompts** trước tool nhạy cảm; multi-agent supervisor ≈ **subagents**; chèn logic giữa các bước ≈ **hooks** tại lifecycle points; resume hội thoại ≈ `--resume`/session transcripts.
- Khác biệt bản chất: với LangGraph bạn **sở hữu control flow** (tự định nghĩa node/edge/state); với Claude Code bạn **cấu hình một flow có sẵn**. Muốn control kiểu LangGraph trong hệ Anthropic thì dùng **Claude Agent SDK** và tự viết orchestration quanh nó.
- Dùng chéo được: một node trong LangGraph hoàn toàn có thể gọi Claude (qua `langchain-anthropic` hoặc raw SDK) — LangGraph không ràng buộc provider.

## Giới hạn / open questions

- Chưa benchmark định lượng overhead (latency/token/độ phức tạp code) của LangGraph vs manual loop — nhận định "ít ma thuật hơn LangChain" là định tính.
- Ranh giới OSS vs thương mại (**LangGraph Platform**, LangSmith) thay đổi theo thời gian — pricing và feature gating chưa nghiên cứu kỹ.
- Note thiên Python; LangGraph JS/TS có API tương đương nhưng chưa kiểm chứng chi tiết.
- Chưa đào sâu: **Functional API** (`@entrypoint`/`@task` — cách viết không cần khai báo graph), semantics chính xác của **Send API** (fan-out động/map-reduce), và long-term memory **Store** cross-thread.
- Các case production (Klarna, Uber, LinkedIn) lấy từ trang marketing của LangChain — quy mô và mức độ "chạy trên LangGraph" thực tế chưa kiểm chứng độc lập.
- Chưa so trực tiếp với các graph/workflow engine khác (Temporal, Prefect + LLM, Mastra, Pydantic AI Graph) — mới chỉ định vị trong nội bộ hệ LangChain.
