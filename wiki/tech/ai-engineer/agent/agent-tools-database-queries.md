---
status: current
updated: 2026-08
sources:
  - https://www.deeplearning.ai/short-courses/building-your-own-database-agent/
  - https://reference.langchain.com/python/langchain-community/agent_toolkits/sql/toolkit/SQLDatabaseToolkit
  - https://docs.langchain.com/oss/python/integrations/tools/sql_database
  - https://github.com/anthropics/anthropic-tools/blob/main/tool_use_package/EXAMPLES.md
  - https://platform.claude.com/docs/en/agents-and-tools/tool-use/how-tool-use-works
  - https://arxiv.org/abs/2308.01990
  - https://dl.acm.org/doi/10.1109/ICSE55347.2025.00007
  - https://docs.cloud.google.com/sql/docs/postgres/secure-agent-interactions-mcp
  - https://goteleport.com/use-cases/secure-model-context-protocol/
  - https://learn.microsoft.com/en-us/sql/relational-databases/security/row-level-security?view=sql-server-ver17
  - https://rietta.com/blog/ai-sql-database-data-protection-read-replica/
  - https://dev.to/kowshik_jallipalli_a7e0a5/safe-text-to-sql-giving-an-agent-database-access-without-dropping-tables-or-leaking-pii-i47
  - https://docs.snowflake.com/en/user-guide/snowflake-cortex/cortex-analyst
  - https://www.snowflake.com/en/blog/ai-data-agents-snowflake-cortex/
  - https://reference.langchain.com/python/langchain-community/agent_toolkits/sql/base/create_sql_agent
  - https://code.claude.com/docs/en/agent-sdk/custom-tools
  - https://code.claude.com/docs/en/agent-sdk/permissions
  - https://mcpservers.org/servers/cuevacelis/mcp_postgres
  - https://github.com/hovecapital/read-only-local-postgres-mcp-server
roadmap: ai-engineer
stage: learning
---

# Database Query Tool — tool cho agent đọc (và đôi khi ghi) dữ liệu có cấu trúc bằng cách chạy query thật lên database

**TL;DR**: Database Query tool cho agent **sinh và chạy query thật** (SQL hoặc NoSQL) lên một database, rồi đọc kết quả vào context để trả lời — thay vì chỉ dựa vào dữ liệu đã nhét sẵn trong prompt. Rủi ro chính: model **tự viết câu query từ ngôn ngữ tự nhiên**, mà input từ người dùng thì không đáng tin. Vì vậy đây là một trong những tool có rủi ro production cao nhất — gồm injection, ghi/xoá nhầm dữ liệu, và rò rỉ dữ liệu ngoài phạm vi cho phép.

> Ghi chú cho người mới: note này giả định bạn đã biết khái niệm "tool" của agent (xem [[agent-what-are-tools]] trước nếu chưa). Các thuật ngữ SDK/thư viện cụ thể (LangChain, MCP, Claude Agent SDK) sẽ được giải thích ngắn gọn ngay lần đầu xuất hiện bên dưới, nhưng để tự triển khai thật, bạn vẫn cần đọc thêm doc chính thức của từng SDK.

## 0. Ví dụ nhanh: trông nó như thế nào

- Người dùng hỏi tự nhiên: "Nhân viên nào có lương cao nhất phòng Kỹ thuật?"
- Model tự sinh SQL: `SELECT name, salary FROM employee_data WHERE department = 'Engineering' ORDER BY salary DESC LIMIT 1;`
- **Runtime** (không phải model) chạy câu này trên DB thật, trả về 1 hàng kết quả vào context.
- Model đọc hàng đó và diễn giải lại thành câu trả lời tự nhiên.

Đây chính là pattern cốt lõi của cả note này: **model sinh query → runtime thực thi → model đọc kết quả thật**. Mục 1-4 đi sâu vào cơ chế và rủi ro; mục "Áp dụng với Claude Code" ở cuối có một skeleton code TypeScript đầy đủ minh hoạ cách làm điều này trong thực tế.

## 1. Vấn đề nó giải quyết

- Dữ liệu có cấu trúc (bảng khách hàng, đơn hàng, log...) thường **quá lớn để nhét hết vào context window**, và thường xuyên thay đổi (không thể "nhúng sẵn" như static text).
- Thay vì RAG (truy hồi đoạn văn bản/semantic chunk từ vector store), Database Query tool trả về **hàng dữ liệu chính xác, tươi (fresh), có cấu trúc** ngay tại thời điểm hỏi — ví dụ "doanh thu tháng 7 theo từng vùng" cần một phép `SUM ... GROUP BY` thật, không phải một đoạn text gần giống nghĩa.
- Cơ chế chung: model được cấp (1) mô tả schema/table (tên bảng, cột, kiểu dữ liệu, đôi khi cả business-term mapping) và (2) một tool để **thực thi query** — model tự quyết định query gì dựa trên yêu cầu người dùng, tool runtime chạy query đó, kết quả quay lại context để model đọc và trả lời (đúng theo ranh giới model-quyết-định / runtime-thực-thi đã mô tả ở [[agent-acting-tool-invocation]]).
- Có hai biến thể phổ biến:
  - **NL-to-SQL trực tiếp**: model tự viết chuỗi SQL từ ngôn ngữ tự nhiên rồi gọi một tool `execute_sql` chung.
  - **Function-calling / pre-built query functions**: model chỉ được chọn giữa một tập hàm đã định nghĩa sẵn (ví dụ `get_revenue_by_region(month, region)`), không tự viết SQL thô — khoá học "Building Your Own Database Agent" của DeepLearning.AI/Azure OpenAI nhấn mạnh cách tiếp cận này cải thiện cả **hiệu năng lẫn bảo mật** so với để model tự do sinh SQL (as of deeplearning.ai, confidence: medium).

## 2. Cơ chế hoạt động (pattern LangChain SQL agent)

- **LangChain** là một framework Python/TypeScript phổ biến để build agent; `SQLDatabaseToolkit` là bộ tool có sẵn của nó để agent thao tác SQL database, còn `create_sql_agent` là hàm dựng sẵn một agent hoàn chỉnh dùng bộ tool đó (không cần tự viết vòng lặp tool-calling từ đầu).
- Bước điển hình của một SQL agent như vậy: liệt kê bảng có sẵn → lấy schema của bảng liên quan → sinh câu SQL → **tự kiểm tra lại câu SQL** bằng `QuerySQLCheckerTool` (một LLM call phụ để rà lỗi cú pháp trước khi chạy) → thực thi → nếu lỗi, đọc traceback thật và tự sửa, lặp lại.
- Ví dụ cụ thể: người dùng hỏi "Nhân viên nào có lương cao nhất phòng Kỹ thuật?" → model đọc schema bảng `employee_data(name, department, salary)` (ví dụ trong repo mẫu `anthropic-tools`) → sinh `SELECT name, salary FROM employee_data WHERE department = 'Engineering' ORDER BY salary DESC LIMIT 1;` → tool chạy câu này trên SQLite/Postgres → trả về 1 hàng → model diễn giải lại thành câu trả lời tự nhiên.
- Anthropic mô tả cơ chế nền tảng: model chỉ trả về một `tool_use` block (tên tool + JSON arguments là câu query), **client application mới là bên thực sự chạy query** và trả `tool_result` — nghĩa là việc *thực thi, permission, và an toàn dữ liệu là trách nhiệm của tầng ứng dụng, không phải của model*.

## 3. Ba mối lo sản xuất đặc trưng của tool này

### 3.1 Read-only vs read-write permissioning

- Best practice phổ biến: cấp cho agent một **DB role chỉ có `SELECT`** (không `INSERT`/`UPDATE`/`DELETE`), và nếu có thể, khoá luôn ở tầng driver/connection là read-only — kể cả khi model "lỡ" sinh ra câu ghi, nó vẫn bị DB engine từ chối (defense in depth, không dựa vào prompt).
- Với các use case phân tích/khám phá dữ liệu, nên trỏ agent vào **read replica** (bản sao chỉ-đọc của database chính), không phải primary DB — cô lập **blast radius** (phạm vi thiệt hại nếu có sự cố) nếu agent chạy query nặng hoặc sai.
- Ví dụ community MCP Postgres server: có 2 lớp enforce read-only — (a) validate chuỗi query chỉ cho phép bắt đầu bằng `SELECT`, và (b) chạy trong read-only transaction hoặc bật cờ `--read-only` ở tầng Postgres. Lớp (b) mới là guarantee thật vì (a) — kiểm tra chuỗi text — có thể bị lách bằng SQL "khéo" (ví dụ CTE ẩn lệnh ghi).
- Với Claude Agent SDK: một MCP server có thể expose hai tool tách biệt, ví dụ `mcp__db__run_readonly_query` (được pre-approve trong `allowedTools`) và `mcp__db__write_query` (bị chặn cứng qua `disallowedTools`, hoặc gắn `_meta["anthropic/requiresUserInteraction"]` để luôn cần con người duyệt) — tách quyền đọc/ghi ở cấp *tool name* thay vì chỉ dựa vào system prompt.

### 3.2 SQL-injection-style risk khi model tự sinh query từ input chưa tin cậy

- Đây **không phải** SQL injection cổ điển (kiểu người dùng gõ trực tiếp `' OR 1=1--` vào một ô input).
- Đây là **Prompt-to-SQL (P2SQL) injection**: người dùng viết một câu hỏi/prompt "khéo léo" để dụ model tự sinh ra câu SQL độc hại thay cho attacker.
- Điểm khác biệt mấu chốt: payload không do attacker gõ trực tiếp vào ô SQL, mà do **chính model tạo ra** từ ngôn ngữ tự nhiên.
- **WAF/sanitizer truyền thống** là công cụ lọc request ở tầng network, hoạt động bằng cách chỉ scan chuỗi SQL thô cuối cùng trước khi nó chạm DB.
- Hệ quả: WAF/sanitizer kiểu đó thường **bỏ sót P2SQL injection**, vì nó không "hiểu" được ý đồ ẩn trong prompt gốc — nó chỉ thấy câu SQL cuối cùng đã trông "hợp lệ" (as of arxiv.org/abs/2308.01990, confidence: high).
- Một nghiên cứu tiếp nối tại ICSE 2025 hình thức hoá các lớp P2SQL injection trên agent LangChain/LlamaIndex và đề xuất phòng thủ tên **LangShield** — xác nhận đây là rủi ro đã được giới học thuật/công nghiệp công nhận, không chỉ lý thuyết.
- **Checklist giảm thiểu** (áp dụng được ngay, không cần đợi tool riêng):
  - Coi **mọi SQL do LLM sinh ra là input chưa tin cậy** — dùng parameterized query/bound variable cho giá trị do người dùng cung cấp, validate cấu trúc query trước khi chạy, và **chặn mọi statement không phải SELECT** ở một lớp validation đứng trước DB.
  - Áp pattern **"action-selector"** (giới hạn model chỉ được chọn trong một tập hàm query an toàn định nghĩa sẵn, như mục 1 đã nói) thay vì cho tự do sinh SQL thô — Google Cloud khuyến nghị pattern này cho agent dùng MCP kết nối Cloud SQL.
  - Với multi-tenant: identity/tenant dùng để lọc `WHERE tenant_id = ...` phải được **tầng ứng dụng inject**, không lấy từ output của model — tránh trường hợp model bị dẫn dụ bỏ qua điều kiện lọc tenant.
  - Ghi log đầy đủ (audit) mọi tool call và câu query thực tế đã chạy, để phát hiện/điều tra sau sự cố.
  - Dùng DB role read-only + read replica (xem mục 3.1) làm lớp phòng thủ cuối cùng, độc lập với mọi validation ở tầng ứng dụng.

### 3.3 Row/column-level access control

- MCP (Model Context Protocol) **không tự enforce authentication/authorization** — một MCP database server "an toàn tuỳ theo đội build nó", nghĩa là row/column-level access control phải được implement ở tầng server hoặc DB engine, không được giả định là có sẵn từ protocol.
- Cơ chế chuẩn để áp row-level access control là dùng tính năng **native của DB** — ví dụ SQL Server hoặc Postgres **Row-Level Security (RLS)**.
- **RLS** là một rule ở tầng database, tự động lọc bớt hàng dữ liệu tuỳ theo user/role đang chạy query (gọi là "security predicate theo principal") — thay vì để agent "tự phán đoán" hàng nào được xem.
- Google Cloud khuyến nghị mô hình phòng thủ nhiều lớp: **service account riêng cho từng agent**, gắn **IAM role tối thiểu** (ví dụ `viewer`, không phải `admin`).
- Lớp IAM đó **kết hợp** với grant row/column-level ở tầng DB — để dù token của agent bị lộ/lạm dụng, DB engine vẫn là ranh giới cuối cùng chặn truy cập vượt phạm vi.
- Schema đưa vào context nên là **tập con đã lọc** (chỉ bảng/cột liên quan), không phải toàn bộ schema — vừa giảm kích thước prompt, vừa giảm bề mặt exfiltrate dữ liệu chéo bảng ngoài ý muốn.

## 4. Ví dụ minh hoạ: 2 kiến trúc production thật

| Kiến trúc | Cách agent "truy vấn DB" | Điểm kiểm soát chính |
|---|---|---|
| LangChain `create_sql_agent` (mặc định) | Model tự sinh SQL bất kỳ, `SQLDatabaseToolkit` chạy trực tiếp trên connection đã cấp | LangChain tự cảnh báo: rủi ro query chậm/quét lớn/lock/ghi ngoài ý muốn tuỳ theo quyền của connection — **cần scope quyền DB càng hẹp càng tốt** |
| Snowflake Cortex Analyst | Dùng **semantic model** — một file cấu hình ánh xạ thuật ngữ nghiệp vụ (ví dụ "doanh thu") sang đúng bảng/cột/công thức trong schema thật — thay vì để model tự đoán pattern-matching thuần; có JOIN validation để giảm hallucination JOIN/đếm trùng | Agent chạy trong môi trường Snowflake được governance sẵn, không có "SQL tự do" chạm thẳng warehouse |

## Liên hệ tới các phần khác

- Đây là một ví dụ cụ thể của khái niệm chung [[agent-what-are-tools]] và [[agent-tool-definition]] (tool = tên + input schema + hàm thực thi được model gọi).
- So với [[agent-tools-code-execution]]: Database Query tool cũng theo mô hình "model sinh lệnh → runtime thực thi → đọc kết quả thật", nhưng khác ở chỗ lệnh sinh ra (SQL) chạm trực tiếp vào **dữ liệu sản xuất/nhạy cảm** thay vì một sandbox cô lập — nên bề mặt rủi ro (injection, exfiltration, ghi nhầm) cao hơn hẳn.
- Trong kiến trúc agent lớn hơn, SQL agent thường là **một node/tool trong workflow đa tool** (ví dụ kết hợp với RAG cho dữ liệu phi cấu trúc), do một orchestrator/router quyết định khi nào gọi tool nào — không phải kỹ thuật đứng độc lập (xem thêm ghi chú confidence ở mục "Giới hạn / open questions" bên dưới).

### Áp dụng với Claude Code

- Claude Code (CLI) **không có built-in database-query tool** sẵn trong hộp — đây không phải một trong các tool mặc định (Read/Bash/Edit...) của CLI.
- Cách khả dụng để có tool này trong Claude Code/Claude Agent SDK là qua **custom in-process MCP server** (một MCP server bạn tự viết, chạy trong cùng process với agent thay vì là một process/service riêng biệt): định nghĩa tool bằng `@tool` (Python)/`tool()` (TypeScript), khai báo input schema (chuỗi SQL/params), viết handler async thực thi query, rồi đăng ký qua `create_sdk_mcp_server`/`createSdkMcpServer` và truyền vào `mcpServers` khi gọi `query()`.
- Skeleton tối thiểu (TypeScript, minh hoạ ý tưởng — không phải code production-ready):

```ts
import { tool, createSdkMcpServer, query } from "@anthropic-ai/claude-agent-sdk";
import { z } from "zod";

const runReadonlyQuery = tool(
  "run_readonly_query",
  "Chạy một câu SELECT trên database phân tích (read-only)",
  { sql: z.string() },
  async ({ sql }) => {
    if (!/^\s*select\b/i.test(sql)) {
      throw new Error("Chỉ cho phép câu SELECT");
    }
    const rows = await readonlyDbClient.query(sql); // client trỏ vào read replica, role chỉ có SELECT
    return { content: [{ type: "text", text: JSON.stringify(rows) }] };
  }
);

const dbServer = createSdkMcpServer({ name: "db", tools: [runReadonlyQuery] });

await query({
  prompt: "Doanh thu tháng 7 theo từng vùng là bao nhiêu?",
  options: {
    mcpServers: { db: dbServer },
    allowedTools: ["mcp__db__run_readonly_query"], // pre-approve tool đọc
  },
});
```

- Việc phân quyền đọc/ghi và bắt buộc human-approval cho thao tác ghi thực hiện qua **permission system** của SDK: tên tool đủ điều kiện dạng `mcp__{server}__{tool}`, deny rule luôn thắng kể cả ở chế độ `bypassPermissions`, và có thể gắn cờ `requiresUserInteraction` để ép mọi lời gọi tool ghi phải qua `canUseTool` callback.
- Quan trọng: permission system của SDK chỉ gate **việc tool có được gọi hay không** — nó **không** validate hay sanitize nội dung câu SQL bên trong. Việc parameterize query, chặn injection, giới hạn quyền DB vẫn là trách nhiệm của người viết handler, giống hệt nguyên tắc "runtime chịu trách nhiệm thực thi an toàn" đã nêu ở mục 2.
- Với MCP connector trên Claude.ai/Team/Enterprise (khác với custom tool của Agent SDK): dùng OAuth uỷ quyền theo từng user, tool kế thừa đúng quyền của người dùng đang kết nối, không có service-account quyền cao hơn — một cách kiến trúc khác để đạt least-privilege mà không cần tự xây row/column ACL riêng (xem thêm ghi chú confidence ở mục "Giới hạn / open questions" bên dưới).

## Giới hạn / open questions

- Chưa có nguồn xác nhận Claude Code CLI (bản thân binary, không qua SDK) có roadmap tích hợp sẵn một database tool "chính chủ" hay không — hiện tại toàn bộ đều phải tự build qua MCP.
- Mức độ hiệu quả thực tế của các kỹ thuật P2SQL defense (như LangShield) ngoài phòng lab chưa được kiểm chứng rộng rãi trong production.
- Chưa rõ NoSQL (MongoDB, DynamoDB...) có các pattern phòng thủ tương đương RLS/column masking phổ biến như SQL hay không — phần lớn nguồn tham khảo được ở đây tập trung vào SQL/quan hệ.
- Case bypass permission (chained subcommand > 50, đã fix ở Claude Code v2.1.90) là ví dụ về lỗ hổng tầng permission nói chung, không riêng cho DB tool — cần theo dõi thêm các bypass tương tự có thể ảnh hưởng tool DB trong tương lai (confidence: low).
- Nhận định "SQL agent thường chỉ là một node trong workflow đa tool, không đứng độc lập" (mục "Liên hệ tới các phần khác") dựa trên suy luận từ cách các framework hiện tại (LangChain, Cortex Analyst) mô tả kiến trúc, chưa có khảo sát định lượng riêng để xác nhận tỉ lệ thực tế (confidence: low, nguồn chưa mạnh).
- Nhận định "MCP connector trên Claude.ai/Team/Enterprise kế thừa đúng quyền OAuth của user, không có service-account quyền cao hơn" (mục "Áp dụng với Claude Code") mới dựa trên một nguồn duy nhất, chưa đối chiếu chéo với tài liệu chính thức khác (confidence: low, một nguồn).
