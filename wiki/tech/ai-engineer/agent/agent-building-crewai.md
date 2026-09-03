---
status: current
updated: 2026-08
sources:
  - https://github.com/crewAIInc/crewAI
  - https://docs.crewai.com/en/introduction
  - https://docs.crewai.com/en/concepts/agents
  - https://docs.crewai.com/en/concepts/processes
  - https://docs.crewai.com/en/concepts/flows
  - https://docs.crewai.com/en/guides/advanced/customizing-prompts
  - https://x.com/joaomdmoura/status/1867585281177637073
  - https://www.deeplearning.ai/courses/multi-ai-agent-systems-with-crewai
  - https://techcrunch.com/2024/10/22/crewai-uses-third-party-models-to-automate-business-tasks
  - https://www.zenml.io/blog/langgraph-vs-crewai
  - https://www.truefoundry.com/blog/crewai-vs-langgraph
  - https://python.plainenglish.io/autogen-vs-langgraph-vs-crewai-a-production-engineers-honest-comparison-d557b3b9262c
  - https://pickaxe.co/post/crewai-vs-langgraph-vs-autogen
  - https://crewai.com/
  - https://code.claude.com/docs/en/sub-agents
  - https://claude.com/blog/building-agents-with-the-claude-agent-sdk
roadmap: ai-engineer
stage: learning
---

# CrewAI — framework multi-agent theo mô hình "đội nhóm nhập vai"

> **TL;DR**: **CrewAI** là framework Python cho phép mô hình hóa một "crew" gồm nhiều **Agent** — mỗi agent có **role**, **goal**, **backstory** — cùng cộng tác qua các **Task** theo **Process** định sẵn (**sequential** hoặc **hierarchical**). Phép ẩn dụ "đội nhóm con người" khiến nó trở thành framework multi-agent dễ tiếp cận nhất cho người mới, nhưng đánh đổi bằng ít quyền kiểm soát low-level hơn [[agent-building-langgraph]] và một số lo ngại về độ chín production.

## Bối cảnh ra đời

- Được tạo bởi **João Moura** (cựu AI engineering lead tại Clearbit/HubSpot), open-source trên GitHub tháng 11/2023; khởi nguồn từ một thử nghiệm cá nhân (agent viết bài LinkedIn) khiến Moura nhận ra rào cản xây agent đang cao một cách không cần thiết.
- Không có paper học thuật đứng sau — thiết kế role/goal/backstory là lựa chọn **product design** lấy cảm hứng từ ẩn dụ đội nhóm con người, không phải phương pháp nghiên cứu được công bố (as of tổng hợp search 2026, confidence: medium).
- Tagline chính thức trên GitHub: *"Framework for orchestrating role-playing, autonomous AI agents"* — MIT license, ~57k stars (as of GitHub Aug 2026, confidence: high).

## Bốn khái niệm cốt lõi: Agent, Task, Crew, Process

- **Agent**: thực thể LLM được định nghĩa bởi ba trường:
  - **role** — chức năng/chuyên môn ("Senior Research Analyst"),
  - **goal** — mục tiêu dẫn dắt quyết định,
  - **backstory** — ngữ cảnh/tính cách.
  - Các thuộc tính quan trọng khác: `llm` (và `function_calling_llm` riêng), `tools`, `allow_delegation` (agent có thể ủy quyền cho nhau), `max_iter` (mặc định 20 vòng lặp trước khi buộc trả lời).
- **Task**: đơn vị công việc rời rạc, gán cho một agent, có `description` và `expected_output`.
- **Crew**: nhóm agent cộng tác trên danh sách task — "đội làm việc nặng" cho bài toán cần sáng tạo và cộng tác.
- **Process**: cách crew thực thi task, hiện chỉ có 2 loại (enum):
  - **sequential** — task chạy tuần tự, output của task trước làm context cho task sau;
  - **hierarchical** — framework tự tạo một **manager agent** (chỉ định qua `manager_llm` hoặc `manager_agent`) để lập kế hoạch, phân công task cho worker agent theo năng lực, và kiểm tra kết quả. Đây thực chất là pattern **orchestrator-workers** được "đóng gói thành sản phẩm".

## Flows — tầng orchestration deterministic bổ sung sau

- **Flows** (thêm khoảng giữa 2024, mở rộng qua 2025): tầng orchestration **event-driven, deterministic** — một Python class dùng decorator `@start`, `@listen`, `@router` để kiểm soát thứ tự thực thi, rẽ nhánh, vòng lặp, và **state management** (dict tự do hoặc **Pydantic** có cấu trúc, kèm persistence).
- Định vị chính thức: **Crews = autonomy** (việc mở, cần sáng tạo/cộng tác), **Flows = deterministic control** (production cần audit được). Khuyến nghị production: bắt đầu với một Flow làm xương sống, ủy quyền các bài toán con "mờ/sáng tạo" cho Crew — hai thứ bổ trợ, không cạnh tranh.
- Việc CrewAI phải thêm Flows cũng là lời thừa nhận ngầm: nhiều use case production thực ra chỉ cần workflow deterministic, không cần cả một crew tự trị.

## Ví dụ cụ thể: content pipeline researcher → writer

Đây là hình mẫu kinh điển được dạy trong các course (research-and-write, lead enrichment, support triage, trip planning… — các quy trình map tự nhiên vào vai trò nghề nghiệp):

```python
from crewai import Agent, Task, Crew, Process

researcher = Agent(
    role="Senior Research Analyst",
    goal="Tìm và tổng hợp thông tin mới nhất về {topic}",
    backstory="Chuyên gia phân tích với 10 năm kinh nghiệm...",
    tools=[search_tool],
)
writer = Agent(
    role="Tech Content Writer",
    goal="Viết bài blog dễ hiểu từ kết quả nghiên cứu",
    backstory="Cây viết công nghệ chuyên giải thích khái niệm phức tạp...",
)

research_task = Task(
    description="Nghiên cứu {topic}, liệt kê 5 insight chính",
    expected_output="Bullet list 5 insight kèm nguồn",
    agent=researcher,
)
write_task = Task(
    description="Viết bài blog ~800 từ từ kết quả nghiên cứu",
    expected_output="Bài blog markdown hoàn chỉnh",
    agent=writer,
)

crew = Crew(
    agents=[researcher, writer],
    tasks=[research_task, write_task],
    process=Process.sequential,  # output research_task tự chảy vào write_task
)
result = crew.kickoff(inputs={"topic": "AI agents"})
```

- Workflow đơn giản kiểu này CrewAI viết trong ~20 dòng, trong khi wiring graph tương đương ở LangGraph cần 50+ dòng — đây chính là điểm bán hàng "approachable" (as of TrueFoundry/ZenML comparisons, confidence: medium).

## Vì sao CrewAI phổ biến đến vậy

- **Ẩn dụ nhập vai dễ hiểu**: định nghĩa agent như tuyển nhân sự — "role gì, mục tiêu gì, xuất thân ra sao" — map thẳng vào cách con người nghĩ về ủy quyền công việc, nên là on-ramp multi-agent số một cho người mới.
- **Hệ sinh thái đào tạo khổng lồ**: ít nhất 3 short course chính thức trên **DeepLearning.AI** do chính Moura dạy (course đầu rated 4.8/5 trên Coursera); công ty tuyên bố 100.000+ developer được certify qua community courses; **Andrew Ng** là nhà đầu tư.
- **Thương mại hóa mạnh**: raise ~$18M (seed + Series A 10/2024), hiện định vị là "Enterprise Agent Build & Runtime" (AMP Suite) với các con số như 65% Fortune 500, 450M+ agentic workflows/tháng, khách hàng DocuSign/PepsiCo/IBM — **đều là số liệu vendor tự công bố, chưa kiểm chứng độc lập** (as of crewai.com 2026, confidence: medium).

## Cuộc "ly hôn" LangChain

- CrewAI ban đầu build trên primitives của **LangChain**, sau đó được viết lại hoàn toàn standalone. Moura tuyên bố tháng 12/2024 (quanh v0.86.0): *"LangChain is completely removed from CrewAI"*; lớp LLM riêng dựa trên **LiteLLM**.
- Lợi ích: import nhẹ/nhanh hơn, ít xung đột version; marketing hiện tại nhấn "built entirely from scratch, independent of LangChain". Con số "5.76x faster than LangGraph" là benchmark của vendor, nên đọc với sự hoài nghi (confidence: low-medium).

## Trade-offs thẳng thắn

- **Role/backstory = prompt engineering trá hình**: ba trường role/goal/backstory cuối cùng chỉ được nội suy vào prompt template (`system_template`, `prompt_template`); CrewAI còn **âm thầm chèn thêm default system instructions** mà người dùng có thể không biết — docs phải có hẳn guide "Customizing Prompts" vì production team cần minh bạch prompt. Một prompt bạn không trace được là một prompt bạn không debug được.
- **Logic điều kiện đánh nhau với paradigm Crew**: "nếu X thì chạy agent B, không thì C" khó biểu diễn trong Crew, thường bị nhét vào prompt của agent → giòn. Flows sinh ra một phần chính để vá điểm này.
- **Ít kiểm soát low-level hơn LangGraph**: CrewAI giấu orchestration sau các role; LangGraph phơi bày nó thành graph tường minh. Các khoảng trống production hay bị nêu: checkpoint/recovery yếu hơn cho agent chạy dài, observability nông hơn LangGraph+LangSmith, rẽ nhánh điều kiện phức tạp hạn chế, memory không nhất quán giữa các run — tóm gọn: *"shines in demos, cracks under complex logic"* (as of practitioner comparisons 2025-2026, confidence: medium).
- **Không validate sự thật**: hệ thống fail không phải vì backstory chưa đủ "sống động", mà vì agent A hallucinate và agent B tin mù quáng → lỗi khuếch đại dây chuyền (error compounding).
- **Pattern hybrid phổ biến**: dùng LangGraph làm orchestrator ngoài, nhúng CrewAI crews làm worker role-based bên trong.

## So sánh nhanh với các framework khác

| Tiêu chí | CrewAI | [[agent-building-autogen]] | [[agent-building-langgraph]] |
|---|---|---|---|
| Mô hình điều phối | Role-based: role/goal/backstory + Process định sẵn | Conversation-driven: agent phối hợp qua chat tự do | Graph tường minh: node/edge/state |
| Độ dễ tiếp cận | Cao nhất (ẩn dụ đội nhóm) | Trung bình | Thấp (nhiều boilerplate) |
| Kiểm soát low-level | Thấp → trung bình (Flows) | Trung bình | Cao nhất |
| Deterministic control | Flows (thêm sau, ít battle-tested hơn) | Yếu (emergent qua hội thoại) | Native (checkpointing, LangSmith) |
| Phù hợp | Pipeline map vào vai trò nghề nghiệp; prototype nhanh | Use case bản chất là hội thoại (classic AutoGen đã vào maintenance phía Microsoft) | Production cần state/retry/observability |

- Trong taxonomy của [[agent-architecture-multi-agent-orchestration]], CrewAI là hiện thân cụ thể của pattern **role-based orchestration**; hierarchical process của nó tương ứng pattern **orchestrator-workers** trong guidance "Building effective agents" của Anthropic.

## Liên hệ tới các phần khác

- [[agent-architecture-multi-agent-orchestration]] — CrewAI = pattern role-based orchestration được đóng gói thành framework; hierarchical process = orchestrator-workers.
- [[agent-building-autogen]] — trục so sánh chuẩn: role/task-driven (CrewAI) vs conversation-driven (AutoGen).
- [[agent-building-langgraph]] — đối trọng "control vs convenience"; cũng là framework CrewAI từng phụ thuộc (qua LangChain) rồi tách ra.
- [[ai-engineer-roadmap]] — node "Building with frameworks — CrewAI" trong nhánh Agent.

### Áp dụng với Claude Code

- **Claude Code subagents** là analogue gần nhất của CrewAI Agent: file Markdown với YAML frontmatter (`name`, `description`, `tools`, `model`…) và body là **system prompt** tự do — Anthropic **cố tình không có schema role/goal/backstory**; một system prompt duy nhất thay cho persona 3 trường.
- Không có tương đương Crew/Process: không có object workflow sequential/hierarchical khai báo trước. Delegation là **động** — orchestrator Claude tự quyết lúc runtime dựa trên `description` của từng subagent; subagent chạy trong context window cô lập, trả kết quả một chiều. Tức là **emergent hierarchy** (Claude Code) vs **declared hierarchy** (manager agent của CrewAI).
- Triết lý Agent SDK là **tool-centric** chứ không persona-centric: vòng lặp "gather context → take action → verify → repeat"; subagent tồn tại chủ yếu để parallelize và cô lập context. Mapping thực dụng: CrewAI role ≈ system prompt + description của subagent; CrewAI Process ≈ orchestration prompt / Agent Teams / script tự viết; CrewAI Flows ≈ code thường gọi Agent SDK (SDK cố ý để orchestration deterministic cho code thường thay vì DSL decorator). Setup OMC của chính vault này (planner/executor/code-reviewer trong `~/.claude/agents/`) là ví dụ sống của chuyên môn hóa theo vai trò mà không cần abstraction "crew".

## Giới hạn / open questions

- Các con số adoption (65% Fortune 500, 450M workflows/tháng, case study Gelato/DocuSign/Konecta…) đều là vendor-reported — chưa có audit độc lập.
- Timeline chính xác của Flows (mốc release, mức độ ổn định API qua các version 0.x) chưa được xác minh chi tiết; CrewAI vẫn ở versioning 0.x với API thay đổi nhanh.
- Benchmark "5.76x faster than LangGraph" chưa được tái lập độc lập.
- Chưa nghiên cứu sâu: memory system của CrewAI (short-term/long-term/entity memory), CrewAI Enterprise/AMP Suite thực tế vận hành ra sao, và mức độ battle-tested của Flows so với LangGraph checkpointing trong long-running workloads.
- Câu hỏi mở: khi Flows ngày càng giống "graph framework", giá trị khác biệt còn lại của CrewAI so với LangGraph là gì ngoài DX và ẩn dụ role?
