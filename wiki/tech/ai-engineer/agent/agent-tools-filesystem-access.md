---
status: current
updated: 2026-08
sources:
  - https://github.com/modelcontextprotocol/servers/tree/main/src/filesystem
  - https://www.npmjs.com/package/@modelcontextprotocol/server-filesystem
  - https://github.com/modelcontextprotocol/servers/issues/3752
  - https://code.claude.com/docs/en/sandboxing
  - https://code.claude.com/docs/en/permissions
  - https://code.claude.com/docs/en/agent-sdk/secure-deployment
  - https://github.com/anthropics/claude-code/issues/23960
  - https://github.com/anthropics/claude-code/issues/32757
  - https://arxiv.org/abs/2405.15793
  - https://portswigger.net/web-security/file-path-traversal
  - https://www.llamaindex.ai/blog/files-are-all-you-need
roadmap: ai-engineer
stage: learning
---

# File System Access — tool cho phép agent đọc/ghi/liệt kê file trên một thư mục được cấp phép

TL;DR:
- **File system access** là nhóm **tool** cho agent thao tác với storage bền vững: mở file, ghi output, duyệt cây thư mục — đây là nền tảng của các coding agent như Claude Code.
- Điều cần nhớ nhất: **scoping/sandboxing** — luôn giới hạn agent vào một workspace root cụ thể, đừng cấp full-filesystem access.
- Rủi ro cần nhớ nhất: **path traversal** (ví dụ `../../etc/passwd`) — agent bị dụ (qua prompt injection hoặc lỗi logic) truyền path thoát khỏi workspace root đã cấp phép.

> Trước khi đọc tiếp, nên đã nắm khái niệm **tool** nói chung ở [[agent-what-are-tools]] — note này giả định bạn đã biết agent "gọi tool" nghĩa là gì.

## Phân biệt với Code Execution tool

- **File system access**: nhắm vào persistent storage/paths cụ thể — `open`, `read`, `write`, `list_directory`, `move_file`, `search_files`. Không tự chạy code.
- **Code Execution / REPL tool** (xem [[agent-tools-code-execution]]): chạy code tùy ý trong sandbox tính toán (Python interpreter...); có thể *gián tiếp* đụng tới file nhưng mục đích chính là compute, không phải quản lý path.
- Trong thực tế hai loại hay đi cùng nhau ở coding agent, nhưng taxonomy phổ biến vẫn tách riêng "code execution" khỏi "filesystem/file tools" và "RAG/retrieval tools" vì rủi ro và cách kiểm soát khác nhau.
- Vì sao tách riêng thay vì để agent tự mở file bằng raw shell: nghiên cứu SWE-agent (Yang et al., NeurIPS 2024) cho thấy việc thiết kế một **Agent-Computer Interface (ACI)** riêng — tức bộ tool có cấu trúc như `open`/`edit`/`search`/`navigate file`, scoped theo repo, thay vì raw shell access — cải thiện hiệu năng agent trên benchmark SWE-bench rõ rệt (confidence: high). Đây là lý do các coding agent hiện đại (kể cả Claude Code) ưu tiên tool file có cấu trúc thay vì chỉ dựa vào `bash`.

## Các implementation tiêu biểu

### MCP Filesystem Server (reference implementation)
- Gói chính thức `@modelcontextprotocol/server-filesystem` (nguồn: github.com/modelcontextprotocol/servers/tree/main/src/filesystem).
- Chỉ truy cập được các thư mục truyền vào lúc khởi động qua CLI argument:
  ```
  npx -y @modelcontextprotocol/server-filesystem /path/to/allowed/files
  ```
- Client hỗ trợ giao thức **Roots** (MCP: cơ chế client báo cho server biết những thư mục/URI nào nó được phép truy cập) có thể thay thế động danh sách thư mục cho phép tại runtime thay vì (hoặc cùng với) CLI args cố định.
- Nếu server khởi động không có CLI args và client không cung cấp Roots hợp lệ → server báo lỗi khởi tạo, **không** fallback về full-filesystem access (fail-closed by design).
- Tool bề mặt: `read_file`, `write_file`, `list_directory`, `directory_tree`, `move_file`, `search_files`, `get_file_metadata`.
- Mọi thao tác đi qua hàm `validatePath()`: kiểm tra path so với `allowedDirectories`, **resolve symlink trước** để chặn symlink-traversal — đây là defense-in-depth chống lại path traversal.
- Rủi ro thực tế đã được ghi nhận: 11 tool của server này nhận path parameter dưới dạng string không giới hạn, không có schema-level validation — dưới prompt injection, LLM có thể bị dụ truyền path chứa `../` để đọc/ghi ngoài thư mục cho phép (nguồn: github.com/modelcontextprotocol/servers/issues/3752). Đây là minh chứng trực tiếp cho việc "sandboxing ở tầng config" không đủ nếu thiếu validation ở tầng input.

### Claude Code (coding agent tiêu biểu)
- 5 tool file chính trước khi Bash được gọi: **Read**, **Write**, **Edit**, **Glob**, **Grep** — Read đọc nội dung (có xử lý token budget), Write tạo/ghi đè, Edit sửa dựa trên diff, Glob tìm file theo pattern (mặc định giới hạn ~100 kết quả).
- Sandbox OS-level: trên macOS dùng **Seatbelt** (cơ chế sandbox process gốc của macOS, giới hạn syscall/file access ở tầng kernel), trên Linux/WSL2 dùng **bubblewrap** (namespace-based sandbox tương tự trên Linux). Mặc định: đọc gần như toàn bộ filesystem được phép (trừ thư mục bị deny tường minh), nhưng **ghi ngoài working directory bị chặn** trừ khi cấu hình `sandbox.filesystem.allowWrite`.
- Có thể mở rộng phạm vi truy cập qua `permissions.additionalDirectories` trong settings, flag `--add-dir`, hoặc lệnh `/add-dir` trong session — đây là tương đương trực tiếp của "workspace root allowlist". Lưu ý: `additionalDirectories` chỉ cấp quyền file, **không** load CLAUDE.md/config từ thư mục đó (khác với `--add-dir`).

## Ví dụ cấu hình scoping (workspace root allowlist)

```jsonc
// Khởi động MCP filesystem server, chỉ cho phép 1 workspace root
// npx -y @modelcontextprotocol/server-filesystem /Users/leonard/projects/my-repo

// Claude Code settings.json — mở rộng quyền ghi ra thêm 1 path cụ thể (sandbox OS-level)
{
  "sandbox": {
    "filesystem": {
      "allowWrite": ["~/.kube", "/tmp/build"]
    }
  }
}
```

Bên cạnh sandbox OS-level ở trên, Claude Code còn có **permission rule** ở tầng request (áp dụng riêng cho tool `Read`/`Edit`, không phải OS boundary):

```jsonc
// settings.json — permission rule tầng request, KHÔNG thay thế được sandbox OS-level
{
  "permissions": {
    "allow": ["Read(./src/**)", "Edit(./src/**)"],
    "deny": ["Read(~/.ssh/**)", "Edit(~/.ssh/**)"]
  }
}
```

Path traversal minh họa — before/after:

```
# TRƯỚC (dễ bị khai thác): validate bằng string-prefix, không canonical hoá
def read_file(path):
    if path.startswith(ALLOWED_ROOT):   # "/workspace-evil" cũng "match" prefix "/workspace"
        return open(path).read()

# request độc hại từ LLM bị prompt injection:
read_file({"path": "../../etc/passwd"})   # thoát khỏi ALLOWED_ROOT

# SAU (an toàn hơn): resolve canonical path rồi mới so với boundary
def read_file(path):
    real = os.path.realpath(os.path.join(ALLOWED_ROOT, path))
    if real == ALLOWED_ROOT or real.startswith(ALLOWED_ROOT + os.sep):
        return open(real).read()
    raise PermissionError("path escapes allowed root")
```

Đây đúng theo pattern OWASP "Broken Access Control" (xem PortSwigger trong `sources`).

## Cơ chế phòng thủ chính chống path traversal / vượt sandbox

| Cơ chế | Chặn cái gì | Enforce ở đâu |
|---|---|---|
| **Allowlist tường minh** (workspace root, không phải blocklist) | Truy cập ngoài danh sách thư mục được phép; mặc định từ chối mọi thứ khác | Application / MCP server |
| **Canonical path resolution trước khi so sánh** (resolve `..`, symlink, rồi mới so với allowlist) | String-prefix match giả (vd. `/workspace-evil` "match" nhầm prefix `/workspace`) — lỗi này từng được ghi nhận thật trong local filesystem "memory" tool của Anthropic TypeScript SDK | Application / MCP server |
| **Enforcement ở tầng OS** (Seatbelt/bubblewrap) thay vì chỉ tầng application/prompt | Subprocess tự mở file (script Python/Node do Bash gọi) — permission rule (`Read(path)`/`Edit(path)`) chỉ áp dụng cho tool có sẵn của Claude, không áp dụng cho subprocess | OS / kernel |
| **Deny > Ask > Allow** | Deny rule luôn thắng allow rule bất kể độ cụ thể → dựng "hard boundary" quanh workspace root + deny tường minh cho subpath nhạy cảm bên trong | Permission layer (Claude Code) |
| **Symlink asymmetry**: allow rule cần match cả symlink path lẫn resolved target; deny rule chỉ cần match một trong hai | Tấn công tạo symlink trong thư mục được phép trỏ ra `~/.ssh` | Permission layer (Claude Code) |
| **Mount tối thiểu, ưu tiên read-only, dùng tmpfs cho scratch ghi tạm** (tmpfs = filesystem tạm nằm trong RAM, mất dữ liệu khi unmount) | Rò rỉ credential từ thư mục nhạy cảm (`~/.ssh`, `~/.aws`, `~/.config`, `.env`) dù chỉ mount read-only | Deployment / infra (khuyến nghị Anthropic secure-deployment guide) |

## Bug thực tế minh hoạ giới hạn của sandboxing (case study)

| Bug | Nguyên nhân | Bài học |
|---|---|---|
| Claude Code allowlist reject symlink hợp lệ | Không resolve symlink trước khi check allowlist → path thật bị coi là "Operation not permitted" | Canonicalize trước khi so khớp, nhưng cẩn thận false-negative |
| `sandbox.filesystem.allowWrite` vô hiệu | Absolute path bị tự động prefix nhầm với `~/.claude/` | Cấu hình allowlist path cần test kỹ, một lỗi nhỏ khiến toàn bộ rule vô nghĩa |
| MCP filesystem server bị prompt injection dẫn path traversal | Tool nhận string path không có schema validation | Sandboxing ở tầng process/CLI-args không thay thế được input validation ở tầng tool schema |

(nguồn: github.com/anthropics/claude-code/issues/23960, /issues/32757, /modelcontextprotocol/servers/issues/3752 — confidence: medium/high tuỳ mục)

## Liên hệ tới các phần khác

- Xem [[agent-what-are-tools]] và [[agent-tool-definition]] cho khái niệm tool nói chung.
- Xem [[agent-tools-code-execution]] để so sánh với nhóm tool chạy code.
- File system access là một hạng mục trong "Examples of Tools" của [[ai-engineer-roadmap]].
- Có quan điểm rộng hơn cho rằng "files/filesystem" đang nổi lên như abstraction cốt lõi để agent quản lý context vượt ngoài context window, chứ không chỉ là một utility tool đơn thuần (nguồn: llamaindex.ai/blog/files-are-all-you-need — quan điểm blog, chưa phải kết quả benchmark).

### Áp dụng với Claude Code

- Claude Code **có** file system access tool built-in (Read/Write/Edit/Glob/Grep) — đây chính là category tool được mô tả trong note này, không phải một plugin/MCP tách rời.
- Scoping mặc định là working directory khi khởi động CLI; mở rộng qua `--add-dir`, `/add-dir`, hoặc `permissions.additionalDirectories` trong settings.json.
- Ranh giới cứng (OS-level) chỉ có khi bật **sandbox mode** (`/sandbox`, Seatbelt/bubblewrap) — permission rule (`Read(path)`/`Edit(path)`) chỉ là gate ở tầng request mà chính Claude phải tự tuân theo, không phải OS boundary; muốn chặn cả subprocess tuỳ ý (script Python/Node do Bash gọi) bắt buộc phải dùng sandbox, không dùng permission rule đơn thuần.
- Một điểm dễ nhầm: permission path rule chỉ cover `Read`/`Edit` (Write/NotebookEdit/Glob/MultiEdit không được enforce qua rule cùng tên — Claude Code chỉ cảnh báo lúc khởi động chứ không tự sửa).

## Giới hạn / open questions

- URL seed `playbooks.com/mcp/mateicanavra-filesystem` trả về 404 khi fetch trực tiếp — nội dung liên quan tới server `mateicanavra/mcp-filesystem` trong note này chỉ dựa trên search snippet, chưa verify được trực tiếp (confidence: low), nên roadmap hub vẫn giữ nguyên link cũ đó làm reference, không dùng làm nguồn chính cho note.
- Chưa có benchmark định lượng so sánh hiệu năng agent khi dùng ACI có cấu trúc (kiểu SWE-agent) so với dùng file tool tổng quát (kiểu Claude Code Read/Edit) trên cùng một task set.
- Chưa rõ mức độ Roots protocol (MCP) được các client ngoài Claude hỗ trợ rộng rãi tới đâu trong thực tế (tính đến 2026-08).
- ReAct (Yao et al. 2022) chỉ được liên hệ như "tổ tiên kiến trúc" của agent dùng tool nói chung — claim này có confidence thấp và chưa verify trực tiếp trong bài gốc, cần đọc lại paper nếu cần trích dẫn chính xác hơn.
