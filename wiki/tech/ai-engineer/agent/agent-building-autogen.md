---
status: current
updated: 2026-08
sources:
  - https://arxiv.org/abs/2308.08155
  - https://www.microsoft.com/en-us/research/project/autogen/
  - https://microsoft.github.io/autogen/0.2/docs/Use-Cases/agent_chat/
  - https://www.microsoft.com/en-us/research/blog/autogen-v0-4-reimagining-the-foundation-of-agentic-ai-for-scale-extensibility-and-robustness/
  - https://microsoft.github.io/autogen/stable//user-guide/agentchat-user-guide/migration-guide.html
  - https://arxiv.org/abs/2408.15247
  - https://github.com/microsoft/autogen
  - https://devblogs.microsoft.com/agent-framework/microsofts-agentic-ai-frameworks-autogen-and-semantic-kernel/
  - https://visualstudiomagazine.com/articles/2025/10/01/semantic-kernel-autogen--open-source-microsoft-agent-framework.aspx
  - https://www.anthropic.com/engineering/multi-agent-research-system
  - https://code.claude.com/docs/en/agent-sdk/subagents
roadmap: ai-engineer
stage: learning
---

# AutoGen — framework multi-agent "hội thoại" tiên phong của Microsoft Research

**TL;DR:** **AutoGen** là framework mã nguồn mở của Microsoft Research đề xuất mô hình **conversation programming**: các agent giải quyết task bằng cách *nói chuyện với nhau* (trao đổi message, chạy code, hỏi người dùng khi cần). Nó là hiện thực kinh điển của mẫu **conversational orchestration**, nhưng từ 10/2025 đã hội tụ vào **Microsoft Agent Framework** và ở chế độ maintenance — nên học nó để hiểu pattern, không chọn làm default cho dự án mới. Lưu ý chi phí: multi-agent kiểu hội thoại tự do có thể tốn ~15x token so với một phiên chat đơn (số liệu Anthropic, xem phần Claude Code bên dưới).

## Mô hình lập trình cốt lõi: conversation programming

- Ý tưởng nền tảng từ paper *"AutoGen: Enabling Next-Gen LLM Applications via Multi-Agent Conversation"* (Wu, Bansal et al., arXiv 2308.08155, 8/2023): mọi ứng dụng LLM đều có thể mô hình hóa thành các **conversable agent** — thực thể biết gửi/nhận message, có thể được "chống lưng" bởi LLM, con người, tool, hoặc kết hợp cả ba.
- Luồng hội thoại được lập trình bằng cả **natural language** (system prompt) lẫn **code** (auto-reply, transition rules) — đó là nghĩa của "conversation programming".
- Ba abstraction chính thời v0.2:
  - **ConversableAgent**: lớp cơ sở — bất kỳ agent nào cũng send/receive message được.
  - **AssistantAgent**: agent chạy LLM, viết code (thường là Python) và tự sửa dựa trên feedback từ kết quả thực thi.
  - **UserProxyAgent**: "người đại diện" của con người — vừa là điểm **human-in-the-loop** (qua `human_input_mode`), vừa tự động **thực thi code block** tìm thấy trong message rồi trả kết quả về hội thoại.
- **Code execution** có executor cấu hình được, gồm sandbox **Docker**, và có thể tắt hẳn.
- **GroupChat + GroupChatManager**: mở rộng vượt quá hội thoại 2 agent — manager broadcast message cho mọi thành viên và **chọn speaker kế tiếp một cách động** (LLM-based hoặc theo transition rules đăng ký sẵn). Đây chính là mẫu group-chat orchestration kinh điển mà [[agent-architecture-multi-agent-orchestration]] mô tả ở nhánh dynamic orchestration.

## Vì sao nó khác một lần gọi LLM đơn / RAG / workflow cố định

- **Vs một lần gọi LLM:** vòng lặp 2 agent (AssistantAgent viết code → UserProxyAgent chạy → trả stderr/kết quả → Assistant sửa) tạo ra vòng **verify-and-fix lặp** mà một lần gọi stateless không làm được — đây là demo coding trung tâm của paper.
- **Vs RAG:** AutoGen hiện thực chính RAG như một *cuộc hội thoại* (retrieval-augmented chat): agent retrieval có thể **re-query lặp lại** khi câu trả lời chưa đủ, thay vì nhồi context một lần — tức multi-agent conversation bao trùm RAG như một pattern con (cách diễn giải này là suy luận từ paper — xem Giới hạn).
- **Vs workflow/graph cố định (kiểu [[agent-building-langchain]]/LangGraph):** GroupChat chọn speaker **tại runtime bằng LLM**, không đi theo DAG định nghĩa trước — đánh đổi tính dự đoán được lấy tính linh hoạt. Agent Framework sau này bổ sung graph-based workflow chính là để bù cho nhược điểm này.
- Paper minh họa qua các ứng dụng cụ thể: giải toán có human-in-the-loop, RAG chat, decision-making trong ALFWorld, tối ưu chuỗi cung ứng (OptiGuide), dynamic group chat, cờ vua hội thoại. Ví dụ áp dụng thực tế: Novo Nordisk dùng AutoGen xây framework phân tích dữ liệu nội bộ với yêu cầu compliance nghiêm ngặt (nguồn thứ cấp — xem Giới hạn).

### Ví dụ code (v0.2 style — API legacy, chỉ để hiểu pattern)

```python
# Chạy với package legacy: pip install "pyautogen<0.3" (API v0.2, nay deprecated).
# KHÔNG dùng cho dự án mới — xem snippet v0.4 AgentChat bên dưới.
from autogen import AssistantAgent, UserProxyAgent, GroupChat, GroupChatManager

assistant = AssistantAgent("coder", llm_config={"model": "gpt-4o"})
critic = AssistantAgent("critic", system_message="Review code, chỉ ra bug.")
user_proxy = UserProxyAgent(
    "user",
    human_input_mode="TERMINATE",       # chỉ hỏi người khi kết thúc
    code_execution_config={"executor": "docker"},  # sandbox
)

groupchat = GroupChat(agents=[user_proxy, assistant, critic], messages=[], max_round=12)
manager = GroupChatManager(groupchat=groupchat)  # chọn speaker động bằng LLM

user_proxy.initiate_chat(manager, message="Viết script phân tích CSV doanh thu và vẽ chart.")
# Vòng lặp: coder viết code -> user_proxy chạy trong Docker -> lỗi/kết quả quay lại
# -> critic góp ý -> coder sửa -> ... đến khi xong hoặc hết 12 round.
```

## v0.2 → v0.4: viết lại theo event-driven actor model

- **v0.4** (phát hành 01/2025) là bản **viết lại từ đầu**: kiến trúc **asynchronous, event-driven** dựa trên **actor model** — hiểu đơn giản: mỗi agent là một "hộp thư" độc lập, nhận và xử lý message bất đồng bộ thay vì mọi agent chờ nhau trong một vòng lặp chung. Lý do viết lại: v0.2 khó quan sát chuyện gì đang xảy ra bên trong (observability), khó ghép pattern cộng tác linh hoạt, và khó scale.
- Kiến trúc 3 tầng:
  - **autogen-core**: runtime mức thấp theo actor model — nền để chạy nhiều agent phân tán; hầu hết người dùng ứng dụng không đụng trực tiếp tầng này.
  - **AgentChat**: API mức cao theo task, giữ các abstraction quen thuộc của v0.2 (AssistantAgent, UserProxyAgent, group chat, code execution) — đường migrate khuyến nghị cho người dùng v0.2 và là tầng nên bắt đầu.
  - **Extensions (autogen-ext)**: package tích hợp bên ngoài (model client OpenAI/Azure, Docker executor, v.v.).
- GroupChat tách thành các Team type: **RoundRobinGroupChat** (nói lần lượt theo vòng), **SelectorGroupChat** (LLM chọn speaker kế tiếp), **Swarm** (agent tự "handoff" — chuyển quyền nói cho agent cụ thể), **MagenticOneGroupChat**, kèm **termination conditions** tường minh (điều kiện dừng: gặp từ khóa, hết số round...).
- Tính năng mới: messaging bất đồng bộ (cả event-driven lẫn request/response), observability qua **OpenTelemetry** (chuẩn tracing/metrics phổ biến, cùng loại dùng cho microservices), typing chặt, **cross-language** (agent Python và .NET nói chuyện được với nhau qua cùng runtime), **AutoGen Bench** để benchmark, và **Magentic-One** — hệ multi-agent tổng quát cho task web/file.

### Ví dụ code (v0.4 AgentChat — nếu muốn chạy thử hôm nay, bắt đầu từ đây)

```python
# pip install "autogen-agentchat" "autogen-ext[openai]"  (API v0.4+)
import asyncio
from autogen_agentchat.agents import AssistantAgent
from autogen_agentchat.teams import RoundRobinGroupChat
from autogen_agentchat.conditions import TextMentionTermination
from autogen_ext.models.openai import OpenAIChatCompletionClient

async def main():
    model = OpenAIChatCompletionClient(model="gpt-4o")
    coder = AssistantAgent("coder", model_client=model)
    critic = AssistantAgent(
        "critic", model_client=model,
        system_message="Review code, chỉ ra bug. Trả lời APPROVE khi đạt.",
    )
    # Cùng pattern coder/critic như ví dụ v0.2, nhưng team + điều kiện dừng tường minh
    team = RoundRobinGroupChat(
        [coder, critic],
        termination_condition=TextMentionTermination("APPROVE"),
    )
    await team.run(task="Viết script phân tích CSV doanh thu và vẽ chart.")

asyncio.run(main())
```

- Lưu ý: AutoGen vẫn ở maintenance mode — snippet trên hợp lệ để học/thử nghiệm; cho greenfield production, Microsoft khuyến nghị **Microsoft Agent Framework** (`pip install agent-framework`), API cùng triết lý AgentChat nên chuyển đổi khái niệm gần như 1-1.

## AutoGen Studio — prototyping no-code

- **AutoGen Studio** (arXiv 2408.15247) là web UI low-code/no-code để prototype, debug, đánh giá multi-agent workflow: đặc tả agent bằng **JSON declarative**, kéo-thả xây team, debug tương tác, gallery component tái sử dụng.
- README cảnh báo rõ: *"not meant to be a production-ready app"* — công cụ thí nghiệm, không phải nền tảng deploy.

## 2025+: hội tụ vào Microsoft Agent Framework — cách nên định vị AutoGen

- Từ 11/2024, Microsoft đã công khai định vị: **AutoGen = xe nghiên cứu/thử nghiệm** (Microsoft Research AI Frontiers Lab), **Semantic Kernel = SDK production**, và hai team align về một runtime chung.
- **01/10/2025**: Microsoft phát hành **Microsoft Agent Framework** (public preview) — hợp nhất AutoGen (dynamic multi-agent orchestration) với Semantic Kernel (nền tảng enterprise: state management, type safety, middleware, telemetry), thêm graph-based workflow, cho Python và .NET; hai team được sáp nhập tổ chức thành một (as of Visual Studio Magazine 10/2025, confidence: high).
- README của repo AutoGen hiện ghi rõ: **"AutoGen is now in maintenance mode"**, community-managed, và khuyến nghị dự án mới dùng Agent Framework kèm migration guide chính thức.
- Agent Framework 1.0 được đưa tin phát hành production-ready khoảng 04/2026, với hai kiểu orchestration: dynamic LLM-driven (dòng máu AutoGen) và deterministic workflow (dòng máu Semantic Kernel) (confidence: medium).
- **Kết luận định vị:** học AutoGen để hiểu *pattern* — group chat, conversational orchestration, human-in-the-loop proxy, actor runtime — vì các ý tưởng đó sống tiếp trong Agent Framework; đừng chọn AutoGen làm default cho greenfield.
- **Khi nào KHÔNG nên multi-agent:** trước khi chọn bất kỳ framework nào ở note này, nhớ rằng multi-agent tốn ~15x token so với chat đơn và kém hiệu quả cho task cần shared context dày (như coding) — chỉ đáng khi task song song hóa được và giá trị kết quả bù được chi phí.

## Liên hệ tới các phần khác

- [[agent-architecture-multi-agent-orchestration]] — AutoGen là **hiện thực kinh điển của conversational orchestration**: GroupChatManager chọn speaker động chính là nhánh dynamic-orchestration trong note đó.
- [[agent-building-langchain]] — đối trọng kiểu graph/chain: LangGraph định nghĩa luồng tường minh trước, AutoGen để LLM quyết luồng tại runtime.
- [[agent-architecture-self-critique]] — cặp AssistantAgent + critic agent trong group chat là một dạng self-critique liên-agent (generator/reviewer tách vai).
- [[ai-engineer-roadmap]] — vị trí trong lộ trình: mục "Building with frameworks".

### Áp dụng với Claude Code

- Claude Code / **Claude Agent SDK** *cố tình không* dùng mẫu hội thoại peer-to-peer của AutoGen: nó dùng **orchestrator-worker phân cấp** — subagent chạy trong context cô lập, chỉ nhận prompt từ Agent tool và chỉ trả về final message; không có transcript group-chat chung.
- Anthropic cũng ghi nhận chi phí của multi-agent: hệ research multi-agent tốn ~15x token so với chat thường và kém hiệu quả cho task cần shared context dày (như coding) — một phê phán ngầm với overhead của conversational orchestration tự do (as of Anthropic engineering blog, confidence: high).
- Ánh xạ khái niệm: **UserProxyAgent** (human-in-the-loop + chạy code) ≈ permission system (`canUseTool` — callback trong Agent SDK để duyệt/chặn từng lần gọi tool — và các permission mode) + **Bash** tool; **AssistantAgent** ≈ **AgentDefinition** (cấu hình khai báo một subagent: description/prompt/tools/model — xem [[agent-architecture-multi-agent-orchestration]]); AutoGen Studio thì không có tương đương trực tiếp trong CLI.
- Bản Claude Code gần đây thêm khả năng gần với AutoGen hơn ở dạng opt-in: tool **SendMessage** cho phép một agent nhắn trực tiếp agent khác (tính năng native "teams"), cùng giới hạn kiểm soát mà group chat v0.2 thiếu (spawn depth, số subagent chạy đồng thời, budget) — đúng loại control-plane mà v0.4 phải viết lại để có.

## Giới hạn / open questions

- Mốc "Agent Framework 1.0 production-ready, AutoGen và Semantic Kernel đều maintenance mode" mới dựa trên đưa tin thứ cấp (Visual Studio Magazine, blog cá nhân) — chưa đối chiếu changelog chính thức của Microsoft.
- Chưa nghiên cứu sâu **Magentic-One** và **AutoGen Bench** (kiến trúc orchestrator, kết quả benchmark cụ thể).
- Chi tiết migration AutoGen → Agent Framework (API nào map 1-1, cái gì mất) chưa được đào; note chỉ nêu tồn tại migration guide.
- So sánh định lượng conversational orchestration vs graph orchestration (token cost, độ tin cậy, latency) chưa có số liệu ngoài con số ~15x của Anthropic cho use case khác domain.
- Nhánh fork cộng đồng **AG2** (ag2.ai, từ nhóm tác giả gốc) tồn tại song song nhưng chưa được khảo sát trong note này.
- Hai claim ở mức confidence trung bình, chưa kiểm chứng độc lập: (1) cách đọc "RAG chỉ là pattern con của multi-agent conversation" là diễn giải của note từ paper gốc (arXiv 2308.08155), không phải phát biểu nguyên văn; (2) ví dụ Novo Nordisk lấy từ blog "What's new in AutoGen?" của Microsoft Research, chưa có case study chi tiết công khai.
- Snippet v0.4 và câu lệnh cài Agent Framework viết theo docs tại thời điểm 2026-08, chưa chạy thử trên môi trường thật — pin version trước khi dùng nghiêm túc.
