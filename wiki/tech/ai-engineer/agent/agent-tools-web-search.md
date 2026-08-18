---
status: current
updated: 2026-08
sources:
  - https://platform.claude.com/docs/en/agents-and-tools/tool-use/web-search-tool
  - https://claude.com/blog/web-search-api
  - https://developers.openai.com/api/docs/guides/tools-web-search
  - https://arxiv.org/abs/2112.09332
  - https://arxiv.org/abs/2210.03629
  - https://usefulai.com/tools/ai-search-engines
  - https://parallel.ai/articles/the-honest-2026-comparison-web-search-apis-for-ai-agents
  - https://coldiq.com/blog/tavily-vs-exa
  - https://mastra.ai/articles/best-ai-agent-search-tools
  - https://blog.n8n.io/agentic-rag/
  - https://learn.microsoft.com/en-us/azure/foundry/agents/how-to/tools/web-overview
  - https://developer.nvidia.com/blog/traditional-rag-vs-agentic-rag-why-ai-agents-need-dynamic-knowledge-to-get-smarter/
  - https://mikhail.io/2025/10/claude-code-web-tools/
  - https://help.apiyi.com/en/claude-code-web-search-websearch-mcp-guide-en.html
  - https://code.claude.com/docs/en/agent-sdk/overview
roadmap: ai-engineer
stage: learning
---

# Web Search Tool — tool giúp agent truy vấn internet trực tiếp thay vì chỉ dựa vào kiến thức đóng băng lúc train

**TL;DR**: **Web Search** là một **agent tool** cho phép LLM tự quyết định gọi một search engine API (hoặc hosted web-search capability của provider) để lấy kết quả/nội dung trang web **tại thời điểm hỏi**, từ đó vượt qua giới hạn **knowledge cutoff** và trả lời có **citation** — khác với [[llm-rag-basics]] vốn truy hồi từ một corpus riêng/nội bộ đã được index sẵn. Nói đơn giản: giống như đưa cho model một nút "tìm kiếm Google" mà nó có thể tự bấm giữa chừng khi trả lời, thay vì chỉ dựa vào những gì nó "nhớ" từ lúc train.

## 1. Vấn đề mà tool này giải quyết

- Một LLM call thuần (không tool) chỉ có kiến thức đóng băng tại thời điểm huấn luyện — không thể xác minh hay cập nhật sự kiện mới (giá cả hiện tại, tin tức, tài liệu vừa thay đổi).
- Gắn thêm web-search tool biến model từ "trả lời theo trí nhớ" thành một **agent step** có thể **grounding** câu trả lời vào thông tin sống động, kèm nguồn trích dẫn để người dùng tự kiểm chứng.
- Đây là một trong những tool phổ biến nhất trong hệ sinh thái agent vì nó giải quyết trực tiếp và đơn giản nhất bài toán "model không biết chuyện vừa xảy ra hôm qua".
- Về mặt kiến trúc, khác một **workflow cố định** (developer hardcode bước search + tham số từ trước): trong agentic use, chính model quyết định có search hay không, search câu gì, và có cần đọc full nội dung trang hay lặp lại search hay không, dựa trên ngữ cảnh hội thoại.

## 2. Cơ chế hoạt động chung

- Web search thường được cung cấp dưới dạng **server tool** (hosted bởi provider) chứ không phải function do developer tự viết:
  - Đưa `web_search` (hoặc tên tương đương) vào mảng `tools` của request.
  - Model tự quyết định khi nào cần search (ví dụ khi câu hỏi liên quan sự kiện gần đây, giá cả, thông tin có thể đã thay đổi).
  - Backend của provider thực thi search, trả kết quả về model dưới dạng observation.
  - Model có thể lặp lại nhiều vòng search trong cùng một turn trước khi đưa ra câu trả lời cuối kèm citation.
- Hình dung nhanh một lượt (chi tiết + ví dụ code đầy đủ ở §3): user hỏi "giá Bitcoin hôm nay bao nhiêu?" → model tự quyết "cần search" (Thought) → gọi tool `web_search` với query "giá Bitcoin hôm nay" (Action) → provider trả về vài kết quả web kèm URL/title (Observation) → model đọc observation và trả lời kèm trích dẫn nguồn.

> Phần dưới đây (nguồn gốc nghiên cứu ReAct/WebGPT) là bối cảnh lịch sử — có thể bỏ qua nếu chỉ cần biết cách dùng tool, xem thẳng §3.

- Nguồn gốc kiến trúc: **ReAct** (Yao et al., ICLR 2023) là framework nền tảng cho vòng lặp Thought → Action → Observation ở trên, trong đó Action có thể là gọi một search API (paper dùng Wikipedia search/lookup trên HotpotQA/FEVER). Xem thêm [[agent-reason-plan]] và [[agent-acting-tool-invocation]].
- Tiền thân nghiên cứu sớm: **WebGPT** (OpenAI, Nakano/Hilton et al., 2021) fine-tune GPT-3 để trả lời câu hỏi dài bằng một môi trường duyệt web dạng text (lệnh search/click/quote), huấn luyện bằng behavior cloning + reward model từ human preference, đánh giá trên ELI5 — câu trả lời được người đánh giá ưa thích hơn cả human demonstrator (56%) lẫn câu trả lời Reddit top-vote (69%). WebGPT cũng là nơi đặt nền cho pattern "câu trả lời có căn cứ + trích dẫn" (grounded answer with citations) mà các web-search tool sản xuất ngày nay vẫn giữ.

## 3. Ví dụ triển khai thực tế: Anthropic Claude API

- `web_search` là **server tool** trong Messages API — khi Claude thấy request cần thông tin cập nhật, nó tự invoke tool, API thực thi search và đưa kết quả về context.
- Tham số hỗ trợ: `max_uses` (giới hạn số lần search/request), `allowed_domains`/`blocked_domains` (loại trừ nhau), `user_location` (localize kết quả).
- Kết quả trả về gồm `url`, `title`, `page_age`, `encrypted_content` (phải echo lại ở các turn sau).
- **Citation luôn bật**: mỗi `web_search_result_location` gồm `url`, `title`, `encrypted_index`, và tối đa 150 ký tự `cited_text`; các field citation này **không** tính vào token usage.
- Giá: **$10/1.000 lần search** + chi phí token tiêu chuẩn cho nội dung do search sinh ra; có trên Claude API, Claude Platform trên AWS/Microsoft Foundry; **không có trên Amazon Bedrock**.
- Ra mắt tháng 5/2025 cho Claude 3.7 Sonnet, 3.5 Sonnet (bản nâng cấp), 3.5 Haiku, kèm admin controls (domain allow/block list, org-level usage controls).
- *(Nâng cao)* Phiên bản tool mới hơn (`web_search_20260209+`) thêm **dynamic filtering**: Claude tự viết và chạy code để lọc bớt kết quả search trước khi đưa vào context, giảm chi phí token cho các tác vụ agentic nặng search.

### Ví dụ tool definition (rút gọn theo tinh thần Anthropic)

```json
{
  "type": "web_search_20250305",
  "name": "web_search",
  "max_uses": 3,
  "allowed_domains": ["docs.example.com"],
  "user_location": { "type": "approximate", "country": "VN" }
}
```

### Ví dụ end-to-end: một lượt request → response tối giản

**Request** (rút gọn, chỉ giữ phần liên quan tới tool):

```json
{
  "model": "claude-sonnet-4-5",
  "messages": [
    { "role": "user", "content": "Giá Bitcoin hôm nay bao nhiêu?" }
  ],
  "tools": [
    { "type": "web_search_20250305", "name": "web_search", "max_uses": 3 }
  ]
}
```

**Response** (Claude tự invoke tool — không cần developer gọi lại API lần hai, provider xử lý search nội bộ rồi trả thẳng câu trả lời cuối):

```json
{
  "content": [
    { "type": "server_tool_use", "name": "web_search", "input": { "query": "giá Bitcoin hôm nay" } },
    { "type": "web_search_tool_result", "content": [
        { "type": "web_search_result", "url": "https://coinmarketcap.com/currencies/bitcoin/",
          "title": "Bitcoin Price Today", "page_age": "2026-08-17" }
    ]},
    { "type": "text", "text": "Theo CoinMarketCap, giá Bitcoin hiện khoảng $... (nguồn dưới đây).",
      "citations": [
        { "url": "https://coinmarketcap.com/currencies/bitcoin/", "title": "Bitcoin Price Today",
          "cited_text": "Bitcoin price today is $..." }
      ]}
  ]
}
```

- Điểm khác biệt so với tool tự viết (custom `function` tool): developer **không** phải nhận `tool_use`, tự chạy search, rồi gửi lại `tool_result` ở một request riêng — toàn bộ vòng search diễn ra phía server của provider trong cùng một API call.
- Nếu muốn Claude search nhiều vòng (ví dụ đọc kết quả đầu rồi search tiếp để làm rõ), chỉ cần tăng `max_uses`; model tự quyết định có cần thêm vòng search hay không.

## 4. Ví dụ triển khai thực tế: OpenAI

- Responses API expose hosted tool `web_search` (tên `web_search_preview` chỉ giữ lại cho tích hợp cũ).
- Khi bật, model tự quyết định search; API trả về một item `web_search_call` ghi lại query, cùng response có annotation `url_citation` (URL, title, vị trí trích dẫn).
- Có nhiều **mode**: "non-reasoning" (trả kết quả search engine nhanh cho lookup đơn giản), agentic/reasoning-model mode (tự lên kế hoạch search), và "deep research" mode (duyệt nhiều trang, tổng hợp report có cấu trúc). Context window cho web search bị giới hạn ở **128k** bất kể model gốc lớn hơn (as of developers.openai.com, confidence: medium).
- Field `sources` liệt kê toàn bộ URL đã tham khảo — thường nhiều hơn tập URL thực sự được trích dẫn inline trong câu trả lời.
- Giá theo nguồn thứ ba (parallel.ai), **chưa đối chiếu với trang pricing chính thức**: **$25/1.000 search** trên non-reasoning models (GPT-4o, GPT-4.1), **$10/1.000** trên reasoning models (GPT-5), cộng chi phí token (confidence: medium — xem "Giới hạn / open questions").

## 5. Các nhà cung cấp / công cụ khác

| Loại | Ví dụ | Đặc điểm chính |
|---|---|---|
| Hosted server tool (LLM provider) | Anthropic `web_search`, OpenAI `web_search` | Tích hợp sẵn trong API, model tự quyết định gọi, có citation |
| Search API tối ưu cho agent | **Tavily** | Keyword-based, trả kết quả đã chunk/clean sẵn cho LLM, giảm hallucination, ~$7.5–8/1.000 search, có free tier |
| Search API dạng semantic | **Exa** | Neural/embedding-based search trên index riêng (có cả keyword mode), ~$7/1.000 request, hợp cho research agent cần discovery ngữ nghĩa |
| Sản phẩm consumer/agent-facing | Perplexity, ChatGPT Search, Google AI Mode, Claude Search, Gemini Search, Brave Search, Microsoft Copilot Search | Đóng gói web search + LLM thành trải nghiệm hỏi-đáp có nguồn, một số có "deep research mode" |

- Các "AI search engine" hiện đại kết hợp index web truyền thống với LLM để trả về câu trả lời tổng hợp có nguồn thay vì danh sách link — nhưng cảnh báo quan trọng: summary do AI sinh ra có thể diễn giải sai nguồn, thiếu ngữ cảnh, hoặc **hallucinate**, nên vẫn cần đối chiếu nguồn gốc.

## 6. Phân biệt Web Search vs RAG

| | Web Search tool | RAG trên corpus riêng |
|---|---|---|
| Nguồn dữ liệu | Toàn bộ internet mở, tại thời điểm query | Corpus nội bộ/private đã được index trước (docs công ty, DB, file) |
| Ai kiểm soát retrieval | Search provider (ranking, nguồn) | Developer (pipeline embedding, vector DB, chunking) |
| Khi nào chạy | Model tự quyết định gọi tool giữa chừng | Thường là bước cố định trong pipeline trước khi vào context, dù agentic RAG cũng cho model tự quyết định retrieve |
| Phạm vi | Không chạm được vào internal KB, CRM, hợp đồng riêng | Chính là domain của RAG — kiến thức riêng, không cần retrain |
| Chi phí | Tính phí theo mỗi lần search (search API call) | Chi phí embedding/vector store, không trả phí "mỗi query" cho bên thứ ba |

- Hai kỹ thuật này **bổ sung nhau**: nhiều hệ RAG dùng một bước search để xác định tài liệu liên quan trước khi retrieve vào context. Xem thêm [[llm-rag-basics]].
- Anthropic còn tách riêng một **web fetch tool** (đọc nội dung một URL cụ thể) khỏi `web_search` (tìm kiếm mở) — hai tool phục vụ hai bước khác nhau: "tìm" và "đọc".

## Liên hệ tới các phần khác

### Áp dụng với Claude Code

- Claude Code (CLI) có sẵn tool **WebSearch** built-in, gọi vào web search phía server của Anthropic (cùng capability dùng cho claude.ai), nhưng chỉ trả về **title và URL** — cố tình bỏ các field phong phú hơn như `page_age`, `encrypted_content` mà API thường trả, để giữ context gọn.
- WebSearch được ghép cặp với tool **WebFetch** riêng để đọc nội dung đầy đủ: WebFetch cần một `prompt` mô tả cần trích gì, convert HTML sang Markdown, chạy qua một model nhỏ/rẻ hơn để trả lời prompt đó, **không bao giờ** trả nguyên văn trang (giới hạn quote, kiểm tra domain deny-list, cache 15 phút). Cơ chế tách "search = discovery" / "fetch = đọc" này chính là hiện thực hoá cụ thể ý "query rồi tuỳ chọn đọc full content" trong định nghĩa gốc của tool.
- Tool schema của WebSearch (quan sát trực tiếp trong harness) ghi rõ: search tự động thực thi trong một API call, trả về block kết quả kèm markdown hyperlink, mục đích "for accessing information beyond Claude's knowledge cutoff", và **giới hạn khu vực (chỉ khả dụng ở US)**.
- WebSearch **không khả dụng** khi Claude Code được cấu hình chạy qua backend Bedrock hoặc Vertex AI — Claude Code ẩn hẳn tool này trong các cấu hình đó, vì search capability hosted của Anthropic không có trên hai platform này (as of help.apiyi.com, cross-checked platform.claude.com, confidence: medium).
- Ở tầng Claude API (nền tảng cho cả Claude Code lẫn Agent SDK), `web_search` là tool type chính thức (`web_search_20250305` trở lên) — Claude Code chỉ là một lớp UX/harness gọi lại capability này với output đã được tối giản.
- **Claude Agent SDK** (thư viện chạy "cùng agent loop, tool set, context management với Claude Code") liệt kê "search the web" là một trong các khả năng built-in sẵn có cho agent tự xây, không cần developer tự nối dây — dù vẫn có thể thêm search engine khác qua MCP nếu muốn.

## Giới hạn / open questions

- Giá $25/1.000 search (OpenAI, non-reasoning) và $10/1.000 (reasoning) chỉ đến từ một nguồn thứ ba (parallel.ai), chưa đối chiếu trực tiếp với trang pricing chính thức của OpenAI — cần verify lại trước khi dùng số liệu này để quyết định kiến trúc.
- Chưa rõ giới hạn khu vực "chỉ khả dụng ở US" của WebSearch trong Claude Code có áp dụng cho mọi plan/API key hay chỉ một số cấu hình — cần kiểm chứng thêm với doc chính thức của Claude Code.
- Chưa có số liệu định lượng so sánh chất lượng/độ chính xác giữa các search API (Tavily, Exa, Anthropic, OpenAI) trên cùng một benchmark — các nhận định "tối ưu cho agent" hiện dựa vào mô tả marketing của từng bên hơn là benchmark độc lập.
- Cơ chế "dynamic filtering" (Claude viết code lọc kết quả search) trong `web_search_20260209+` mới chỉ ghi nhận từ doc, chưa có ví dụ thực tế hoặc số liệu tiết kiệm token cụ thể.
- Chưa rõ hành vi chi tiết khi web search trả kết quả mâu thuẫn nhau (nhiều nguồn nói khác nhau) — model xử lý conflict resolution ra sao chưa được tài liệu hoá rõ trong các nguồn đã thu thập.
