---
status: current
updated: 2026-08
sources:
  - https://www.anthropic.com/engineering/multi-agent-research-system
  - https://claude.com/blog/building-multi-agent-systems-when-and-how-to-use-them
  - https://cloud.google.com/discover/what-is-a-multi-agent-system
  - https://arxiv.org/abs/2305.14325
  - https://docs.claude.com/en/docs/agent-sdk/subagents
  - https://cognition.com/blog/dont-build-multi-agents
  - https://dev.to/jose_gurusup_dev/agent-orchestration-patterns-swarm-vs-mesh-vs-hierarchical-vs-pipeline-b40
roadmap: ai-engineer
stage: learning
---

# Multi-agent orchestration — nhiều instance agent tự trị phối hợp để hoàn thành một mục tiêu chung

TL;DR: Multi-agent orchestration là cách **nhiều instance LLM agent** (không phải một agent với vòng lặp nội bộ) phối hợp với nhau qua bốn topology chính — **hub-and-spoke**, **pipeline**, **peer-to-peer**, **debate/critic** — đánh đổi tốc độ/song song lấy chi phí token cao hơn và các failure mode mới (context isolation, trùng việc, lỗi lan truyền).

## Phân biệt với kiến trúc agent đơn lẻ

- **ReAct** (agent tự lặp reasoning → action → observation trong một context), **Planner-Executor** (một bước lập kế hoạch, một bước thực thi kế hoạch đó), **DAG** (task được chia thành đồ thị các bước có phụ thuộc, chạy theo thứ tự) — xem chi tiết ở [[agent-architecture-react]], [[agent-architecture-planner-executor]], [[agent-architecture-dag]] — đều mô tả **bên trong một agent** suy nghĩ/hành động thế nào.
- Multi-agent orchestration mô tả **giữa nhiều agent instance** — mỗi agent có context window, prompt, và có thể cả model riêng — giao tiếp/phối hợp ra sao.
- Định nghĩa gốc (Google Cloud): một multi-agent system gồm nhiều **autonomous, interacting agent** trong cùng môi trường, hợp tác/cạnh tranh/thương lượng để đạt mục tiêu cá nhân hoặc tập thể.
- Ghi chú lịch sử: khái niệm MAS có từ thập niên 1980, bắt nguồn từ Distributed Artificial Intelligence (DAI, giữa thập niên 1970) — không phải khái niệm mới sinh ra cùng LLM.

## Bốn topology chính

### 1. Hub-and-spoke / orchestrator-worker

- Một **lead agent** (orchestrator) phân tích task, lập chiến lược, spawn các **subagent** chuyên biệt chạy song song, mỗi subagent có context window riêng; lead agent tổng hợp kết quả cuối.
- Đây là kiến trúc production của Anthropic's multi-agent research system.
- Subagent không giao tiếp trực tiếp với nhau — cách ly lỗi tốt (một subagent lỗi không kéo cả hệ thống sập) nhưng tạo **bottleneck**: mọi thứ phải đi qua lead agent, nên lead agent chậm/quá tải thì cả hệ thống chậm theo.
- Điều kiện thành công: mỗi subagent cần **objective rõ ràng, output format, tool/source guidance, ranh giới task cụ thể** — thiếu chi tiết này agent sẽ trùng việc, bỏ sót, hoặc lạc đề.
- Được khuyến nghị là pattern mặc định để bắt đầu vì có một luồng điều khiển duy nhất, dễ trace/debug.

### 2. Sequential / pipeline handoff

- Output của agent A trở thành input của agent B, theo thứ tự cố định (ví dụ: content pipeline nghiên cứu → viết → biên tập).
- Rủi ro: hiệu ứng "telephone game" — thông tin suy giảm độ trung thực (fidelity) qua mỗi lần handoff nếu chia agent theo loại vấn đề thay vì theo ranh giới context.
- Khuyến nghị: giữ các giai đoạn tuần tự trong cùng một agent nếu chúng chia sẻ context, chỉ tách agent khi ranh giới context thực sự khác nhau.

### 3. Peer-to-peer / agent teams (network / mesh)

- Các agent giao tiếp trực tiếp với nhau, chia sẻ một task list, không có hierarchy chặt.
- Bất kỳ agent nào cũng có thể khởi tạo giao tiếp với bất kỳ peer nào mà không qua central coordinator; state có thể chuyển giao trực tiếp khi handoff.
- Ưu điểm: chống chịu tốt hơn với single point of failure (một agent hỏng không sập cả hệ thống).
- Nhược điểm: khó trace/debug hơn hub-and-spoke, overhead phối hợp tăng nhanh theo số lượng agent.

### 4. Debate / critic

- Nhiều instance LLM độc lập đề xuất câu trả lời, sau đó **phản biện lẫn nhau** qua nhiều vòng để hội tụ về một câu trả lời chung — cải thiện factuality và giảm hallucination so với một agent trả lời một lần.
- Nguồn gốc: paper "Improving Factuality and Reasoning in Language Models through Multiagent Debate" (Du et al., arXiv:2305.14325, ICML 2024).
- Giới hạn quan trọng: debate có thể **khuếch đại bias chung** thay vì sửa nó, đặc biệt khi tất cả agent debate là instance của cùng một model nền — thiếu đa dạng góc nhìn thật sự làm mất đi lợi ích lý thuyết của pattern này.
- Biến thể generator/critic (ví dụ REFINER): một model sinh reasoning, một critic riêng cho feedback lặp lại đến khi đúng hoặc hết feedback — khác debate toàn phần nhưng cùng họ pattern.

## Bảng so sánh nhanh

| Topology | Giao tiếp | Ưu điểm chính | Rủi ro chính | Dùng khi |
|---|---|---|---|---|
| Hub-and-spoke | qua lead agent, subagent không nói chuyện trực tiếp | dễ debug, cách ly lỗi | orchestrator là bottleneck | **Mặc định**: task chia được thành sub-task độc lập, cần trace/debug dễ (bắt đầu ở đây trừ khi có lý do rõ ràng dùng pattern khác) |
| Pipeline | tuyến tính A→B→C | đơn giản, dễ trace | fidelity suy giảm qua handoff ("telephone game") | Các bước có thứ tự cố định, ranh giới context giữa các bước thực sự khác nhau (vd: research → write → edit) |
| Peer-to-peer / mesh | agent nói chuyện trực tiếp với nhau | chống chịu single-point-of-failure | khó debug, overhead phối hợp tăng theo n agent | Cần agent tự điều phối linh hoạt, chấp nhận đánh đổi khó trace (hiếm khi cần — cân nhắc kỹ trước khi chọn) |
| Debate/critic | nhiều vòng phản biện lẫn nhau | tăng factuality, giảm hallucination | khuếch đại bias chung nếu cùng model nền | Câu trả lời cần độ chính xác cao, có ngân sách token để đổi lấy factuality (vd: fact-check, reasoning phức tạp) |

## Đánh đổi (trade-offs)

- **Chi phí token** — cùng một task, chi phí tăng dần theo kiến trúc (số liệu từ hai nguồn khác nhau, không cộng dồn được với nhau vì đo trên baseline khác nhau):

  | Kiến trúc | Token so với baseline | Nguồn |
  |---|---|---|
  | Chat 1-lượt | 1x (baseline) | Anthropic |
  | Single agent | ~4x | Anthropic |
  | Multi-agent system | ~15x | Anthropic |
  | Multi-agent vs. single-agent (ước tính riêng) | 3–10x | Claude engineering blog |

  Token usage một mình giải thích tới **80% variance hiệu năng** trong eval nội bộ của Anthropic (confidence: high) — nghĩa là nếu ngân sách token bị giới hạn chặt, hiệu năng multi-agent gần như tỷ lệ thuận với số token được phép dùng.
- **Tốc độ**: parallel research cắt giảm tới **90% thời gian** cho các query breadth-first phức tạp — đây là lý do chính để chấp nhận chi phí token cao hơn.
- **Failure mode riêng của multi-agent** (không tồn tại ở single agent):
  - **Error/behavior propagation**: một bước lỗi có thể khiến agent đi theo trajectory hoàn toàn khác, kết quả không dự đoán được; thay đổi nhỏ ở lead agent có thể làm subagent hành xử khác đi khó lường.
  - **Context isolation**: subagent có context riêng (lợi ích: context sạch, không nhiễu) nhưng cũng khiến chúng thiếu nhận thức chung → dễ trùng việc hoặc bỏ lỡ phối hợp nếu orchestrator không mô tả task đủ rõ.
  - **Coordination bottleneck (đồng bộ)**: trong kiến trúc chạy đồng bộ, lead agent không thể "chỉnh lái" subagent giữa chừng, subagent không phối hợp được với nhau, và cả hệ thống có thể bị block chờ một subagent hoàn thành.

> **Kết quả thực tế (case study)**: multi-agent Claude Opus 4 (lead) + Claude Sonnet 4 (subagent) vượt single-agent Claude Opus 4 baseline **90.2%** trên eval nghiên cứu nội bộ của Anthropic — con số ấn tượng nhưng đến từ **1 benchmark nội bộ**, chưa có replication độc lập (confidence: high nhưng phạm vi hẹp).

## Khi nào nên dùng multi-agent (và khi nào không)

Theo hướng dẫn chính thức của Claude ("Building multi-agent systems: when and how to use them"), chỉ nên đi multi-agent khi có ít nhất một trong ba lý do:

1. **Context protection** — cô lập lượng thông tin lớn, không liên quan đến task chính, tránh làm ô nhiễm context chính.
2. **Parallelization** — các sub-task độc lập, có thể chạy đồng thời (nghiên cứu, tìm kiếm song song).
3. **Specialization** — mỗi agent có toolset/prompt tập trung, giảm lỗi chọn sai tool so với một agent phải quản lý 20+ tool lẫn lộn.

Ngược lại: "một agent đơn lẻ được thiết kế tốt với tool phù hợp có thể làm được nhiều hơn phần lớn developer nghĩ" — nên bắt đầu với single agent, chỉ chuyển sang multi-agent khi một trong ba điều kiện trên rõ ràng đúng.

**Phản biện gay gắt nhất** đến từ Cognition (Devin): parallel subagent không đáng tin cậy cho coding production vì các subagent hành động dựa trên giả định xung đột nhau mà không chia sẻ context; Cognition khuyến nghị **single-threaded linear agent** với context liên tục thay vì multi-agent song song cho code-editing (xem chi tiết ở [[graph-engineering]] mục 7).

## Ví dụ cụ thể: Claude Agent SDK / Claude Code Task tool

- Trong Claude Agent SDK, một subagent bắt đầu với **context window mới, cô lập**; chỉ **message kết luận cuối cùng** của subagent — không phải quá trình làm ra nó — được trả về orchestrator (giống một tech lead nhận PR description từ người được giao việc, không thấy toàn bộ lịch sử commit).
- Subagent có thể định nghĩa theo hai cách: programmatic (tham số `agents` trong `query()`) hoặc filesystem-based (markdown + YAML frontmatter dưới `.claude/agents/`). Cả hai đều là cách khai báo hub-and-spoke — lead agent (main Claude Code session) gọi Task tool, subagent chạy cô lập rồi trả kết luận về.

**Ví dụ 1 — filesystem-based** (`.claude/agents/code-reviewer.md`):

```markdown
---
name: code-reviewer
description: Review code changes for bugs, style, security issues
tools: Read, Grep, Glob
---

Bạn là subagent chuyên review code. Với mỗi task được giao:
- Objective: tìm bug/vấn đề bảo mật trong diff được cung cấp, không refactor.
- Output format: danh sách finding, mỗi finding có file, dòng, mức độ nghiêm trọng.
- Ranh giới: chỉ đọc code trong phạm vi diff, không sửa file.
```

**Ví dụ 2 — programmatic** (tham số `agents` trong `query()`, TypeScript):

```typescript
const result = await query({
  prompt: "Review pull request #42 for security issues",
  options: {
    agents: {
      "security-reviewer": {
        description: "Phân tích lỗ hổng bảo mật trong code diff",
        tools: ["Read", "Grep"],
        prompt: "Objective: tìm SQL injection, XSS, secret hardcode. Output: JSON list finding.",
      },
    },
  },
});
```

Cả hai ví dụ đều thể hiện đúng 4 thành phần bắt buộc nêu ở mục 1 (objective rõ ràng, output format, tool guidance, ranh giới task) — thiếu một trong bốn, subagent dễ trùng việc hoặc lạc đề.

- Claude Code hỗ trợ tối đa khoảng 10 concurrent subagent task, vượt ngưỡng sẽ bị queue.

## Liên hệ tới các phần khác

### Áp dụng với Claude Code

- Claude Code hiện tại triển khai **native đúng một topology**: hub-and-spoke qua **Task tool** — main agent (orchestrator) delegate cho specialist subagent chạy trong context cô lập, chỉ trả về kết luận cuối.
- Claude Code / Claude Agent SDK **không có primitive built-in** cho peer-to-peer agent-to-agent messaging hay debate/critic loop — muốn dùng các pattern này phải tự xây harness bên ngoài (ví dụ: spawn 2 subagent rồi tự route output của chúng qua lại nhau, hoặc viết control loop riêng ở tầng harness). Đây khớp với điểm "coordination overhead do harness tự quản" đã ghi ở [[graph-engineering]] mục 8.
- Pipeline pattern có thể mô phỏng thủ công bằng cách gọi Task tool tuần tự và truyền output của subagent trước làm input prompt cho lần gọi sau — không có cơ chế "pipeline" chuyên dụng.

## Giới hạn / open questions

**Ghi chú confidence/sourcing** (gom từ các claim trong bài, thay vì chèn tag rải rác trong câu):
- Lịch sử MAS bắt nguồn từ DAI thập niên 1970-1980: confidence medium.
- Debate/critic khuếch đại bias chung nếu cùng model nền: confidence medium — dựa trên lập luận lý thuyết trong paper gốc, chưa có số liệu định lượng cụ thể mức khuếch đại.
- Con số "tối đa ~10 concurrent subagent task" của Claude Code: confidence medium, chỉ đến từ một bài viết thứ cấp (dev.to), chưa verify trực tiếp với docs chính thức của Anthropic — cần kiểm tra lại nếu số này quan trọng cho quyết định thiết kế.
- Chưa có benchmark định lượng so sánh trực tiếp 4 topology (hub-and-spoke vs pipeline vs peer-to-peer vs debate) trên cùng một task để biết mức trade-off tốc độ/chi phí cụ thể ngoài case study nghiên cứu của Anthropic.
- Debate/critic pattern: chưa rõ ngưỡng số vòng debate tối ưu ngoài quan sát "≤3 vòng thường hội tụ" trong benchmark cụ thể — có thể không tổng quát hóa cho mọi loại task.
- Async/non-blocking orchestrator-worker (thay vì đồng bộ hiện tại của Anthropic) được nhắc tới như hướng cải tiến nhưng chưa có triển khai production công khai để tham chiếu.
- Chưa rõ Agent-to-Agent (A2A) protocol của roadmap.sh có phải là chuẩn thực tế được áp dụng rộng hay chỉ là đề xuất — nguồn gốc claim này confidence thấp, cần verify lại trực tiếp trên trang roadmap.sh.
