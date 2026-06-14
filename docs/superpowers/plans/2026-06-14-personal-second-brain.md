# Personal Second Brain — Implementation Plan

> **For agentic workers:** REQUIRED SUB-SKILL: Use superpowers:subagent-driven-development (recommended) or superpowers:executing-plans to implement this plan task-by-task. Steps use checkbox (`- [ ]`) syntax for tracking.

**Goal:** Dựng một second brain cá nhân dạng LLM Wiki — vault Markdown local-first làm source of truth, Claude (Code + Desktop/MCP) làm bộ não đọc/ghi/duy trì, phục vụ hỏi-đáp + trợ lý kỹ thuật + capture ý tưởng + bộ nhớ đời sống.

**Architecture:** File `.md` là nguồn chân lý; không vector DB, Claude lập luận trực tiếp trên Markdown (mẫu Karpathy LLM Wiki). Luật vận hành đặt trong `AGENTS.md` (surface-agnostic) để cả Claude Code và Claude Desktop/MCP đọc chung; SKILL.md chỉ là wrapper mỏng. Ba luồng: capture (raw bất biến) → compile (wiki atomic + wikilinks) → lint.

**Tech Stack:** Markdown, Bash (clip/import scripts), Claude Code skill, MCP filesystem server (Claude Desktop), git.

**Spec:** `docs/superpowers/specs/2026-06-14-personal-second-brain-design.md`

---

## File Structure

| File | Trách nhiệm |
|---|---|
| `index.md` | Bản đồ vault + thứ tự đọc; Claude đọc đầu tiên |
| `CRITICAL_FACTS.md` | Facts cố định về user (~150 token), luôn nạp |
| `AGENTS.md` | Bộ luật vận hành capture/query/maintain (surface-agnostic) |
| `raw/web/`, `raw/meetings/`, `raw/inbox/` | Nguồn bất biến |
| `wiki/concepts/`, `wiki/entities/`, `wiki/tech/`, `wiki/journal/` | Tri thức compiled |
| `.claude/skills/second-brain/SKILL.md` | Wrapper kích hoạt cho Claude Code |
| `scripts/clip.sh` | URL → Markdown stub vào `raw/web/` |
| `scripts/import.sh` | file local → `raw/inbox/` |
| `scripts/test.sh` | Assertions cho 2 script trên |
| `mcp/claude_desktop_config.snippet.json` | Cấu hình MCP filesystem cho Desktop |
| `.gitignore` | Bỏ qua junk |

---

## Task 0: Khởi tạo project & git

**Files:**
- Create: `.gitignore`

- [ ] **Step 1: Init git**

Run:
```bash
cd /Users/leonard/Workspace/code/personal/second-brain
git init
```
Expected: `Initialized empty Git repository ...`

- [ ] **Step 2: Tạo cây thư mục**

Run:
```bash
mkdir -p raw/web raw/meetings raw/inbox \
         wiki/concepts wiki/entities wiki/tech wiki/journal \
         .claude/skills/second-brain scripts mcp
```
Expected: không lỗi.

- [ ] **Step 3: Viết `.gitignore`**

```gitignore
.DS_Store
.omc/
*.tmp
node_modules/
.env
```

- [ ] **Step 4: Giữ thư mục rỗng bằng `.gitkeep`**

Run:
```bash
touch raw/web/.gitkeep raw/meetings/.gitkeep raw/inbox/.gitkeep \
      wiki/concepts/.gitkeep wiki/entities/.gitkeep wiki/tech/.gitkeep wiki/journal/.gitkeep
```
Expected: không lỗi.

- [ ] **Step 5: Commit**

```bash
git add -A
git commit -m "chore: init second-brain vault skeleton"
```

---

## Task 1: AGENTS.md — bộ luật vận hành (trái tim hệ thống)

**Files:**
- Create: `AGENTS.md`

- [ ] **Step 1: Viết acceptance check (checklist nội dung)**

File phải chứa đủ 5 mục: (1) read order, (2) luật CAPTURE, (3) luật QUERY + chống bịa, (4) luật COMPILE, (5) luật LINT. Sẽ verify bằng grep ở Step 3.

- [ ] **Step 2: Viết `AGENTS.md`**

```markdown
# AGENTS.md — Luật vận hành Second Brain

> Đây là bộ luật chung cho MỌI bề mặt (Claude Code & Claude Desktop/MCP).
> Đọc file này trước khi thao tác với vault.

## 0. Thứ tự đọc (BẮT BUỘC)
1. `index.md` — bản đồ vault.
2. `CRITICAL_FACTS.md` — facts cố định về user (luôn nạp).
3. Sau đó mới `grep`/đọc file liên quan trong `wiki/` và `raw/`.

## 1. CAPTURE (nạp vào)
- Mọi thứ vào `raw/` là **BẤT BIẾN** — không sửa nội dung gốc, chỉ thêm file mới.
- URL → `raw/web/YYYY-MM-DD-<slug>.md` (dùng `scripts/clip.sh` hoặc WebFetch).
- Ý/note nhanh → `raw/inbox/YYYY-MM-DD-HHMM-<slug>.md`.
- Meeting → `raw/meetings/YYYY-MM-DD-<slug>.md`.
- Mỗi file raw có YAML frontmatter: `source`, `captured_at`, `status: raw`.

## 2. QUERY (hỏi-đáp)
- Trả lời CHỈ từ nội dung trong vault.
- Mọi khẳng định kèm trích dẫn `[[file]]` (wikilink tới file nguồn).
- Nếu KHÔNG có trong vault: nói rõ "Không có trong bộ não" — KHÔNG bịa, KHÔNG dùng kiến thức ngoài trừ khi user yêu cầu rõ.
- Khi thông tin cũ/mâu thuẫn, nêu marker thời điểm `(as of YYYY-MM, source)`.

## 3. COMPILE (raw → wiki)
- Khi user nói "xử lý inbox": đọc `raw/inbox/`, chắt lọc thành note ATOMIC.
- Atomicity: 1 file = 1 khái niệm/thực thể. Đặt vào đúng `wiki/concepts|entities|tech|journal`.
- Mỗi wiki note PHẢI có ≥1 `[[wikilink]]` CÓ NGỮ CẢNH (giải thích vì sao liên kết).
- Giữ URL nguồn verbatim + marker confidence `(high|medium|low)` cho claim quan trọng.
- Sau khi compile, đánh dấu file raw đã xử lý: đổi frontmatter `status: processed`.

## 4. LINT (rà soát định kỳ)
- Khi user nói "lint" hoặc "kiểm tra bộ não": rà toàn `wiki/` tìm:
  - mâu thuẫn giữa các note;
  - claim cũ (marker thời điểm đã lâu);
  - orphan (note không ai link tới);
  - wikilink trỏ tới file không tồn tại.
- Xuất báo cáo + ĐỀ XUẤT sửa; KHÔNG tự sửa nội dung raw.

## 5. Văn phong note
- Viết cho future-Claude đọc & lập luận, không phải prose cho người.
- Ngắn, atomic, nhiều liên kết. Tiếng Việt hoặc Anh đều được, nhất quán trong 1 note.
```

- [ ] **Step 3: Verify cấu trúc**

Run:
```bash
grep -E "^## (0|1|2|3|4|5)\." AGENTS.md | wc -l
```
Expected: `6`

- [ ] **Step 4: Commit**

```bash
git add AGENTS.md
git commit -m "feat: add AGENTS.md operating rules (capture/query/compile/lint)"
```

---

## Task 2: index.md — bản đồ vault

**Files:**
- Create: `index.md`

- [ ] **Step 1: Viết `index.md`**

```markdown
# Second Brain — Index

> Claude: đọc file này ĐẦU TIÊN, rồi `CRITICAL_FACTS.md`, rồi `AGENTS.md`.

## Bản đồ vault
- `raw/` — nguồn bất biến đã capture
  - `web/` bài clip · `meetings/` họp · `inbox/` capture nhanh chưa xử lý
- `wiki/` — tri thức đã compile (atomic + wikilink)
  - `concepts/` khái niệm · `entities/` người/cty/dự án/tool · `tech/` kỹ thuật · `journal/` nhật ký
- `AGENTS.md` — luật vận hành (đọc trước khi thao tác)

## 4 use case → đường đi
- Hỏi-đáp tri thức → `wiki/` + `raw/`, trả lời kèm `[[trích dẫn]]`.
- Trợ lý kỹ thuật → `wiki/tech/`.
- Capture & kết nối ý tưởng → `raw/inbox/` → (compile) → `wiki/concepts/`.
- Bộ nhớ đời sống → `raw/` + `wiki/journal/`.

## Lệnh quen dùng
- Capture URL: `./scripts/clip.sh <url>`
- Capture file: `./scripts/import.sh <path>`
- Trong Claude: "lưu ý này: ..." / "xử lý inbox" / "lint bộ não".

## Trạng thái
- Khởi tạo: 2026-06-14. Retrieval: LLM-over-Markdown (chưa dùng RAG).
```

- [ ] **Step 2: Verify**

Run:
```bash
test -f index.md && grep -q "đọc file này ĐẦU TIÊN" index.md && echo OK
```
Expected: `OK`

- [ ] **Step 3: Commit**

```bash
git add index.md
git commit -m "feat: add index.md vault map"
```

---

## Task 3: CRITICAL_FACTS.md — facts cố định về user

**Files:**
- Create: `CRITICAL_FACTS.md`

- [ ] **Step 1: Viết `CRITICAL_FACTS.md` (template + seed tối thiểu)**

```markdown
# CRITICAL FACTS

> ~150 token. Facts ÍT THAY ĐỔI về chủ nhân. Claude luôn nạp file này.

- Tên: Leonard.
- Vai trò: Fullstack Engineer (mạnh backend) + Engineering Manager.
- Stack chính: Java, Spring Boot, Kotlin, TypeScript, PostgreSQL, microservices.
- Công cụ làm việc: sống trong Claude Code; dùng Claude Desktop + MCP cho chat.
- Ngôn ngữ: tiếng Việt là chính, kỹ thuật có thể tiếng Anh.
- Mục tiêu bộ não: hỏi-đáp tri thức, trợ lý kỹ thuật, capture ý tưởng, bộ nhớ đời sống.

<!-- Thêm facts mới ở đây khi ổn định. Đừng để file này phình quá ~200 token. -->
```

- [ ] **Step 2: Verify độ dài (~< 200 từ)**

Run:
```bash
wc -w CRITICAL_FACTS.md
```
Expected: số từ < 120 (đủ nhỏ để luôn nạp).

- [ ] **Step 3: Commit**

```bash
git add CRITICAL_FACTS.md
git commit -m "feat: add CRITICAL_FACTS seed"
```

---

## Task 4: Claude Code skill wrapper

**Files:**
- Create: `.claude/skills/second-brain/SKILL.md`

- [ ] **Step 1: Viết `SKILL.md`**

```markdown
---
name: second-brain
description: Personal second brain over a local Markdown vault. Use when the user asks to capture/clip something, ask questions about their notes/knowledge, process inbox, compile wiki notes, or lint the knowledge base. Triggers — "lưu ý này", "clip", "hỏi bộ não", "xử lý inbox", "lint bộ não", "second brain".
---

# Second Brain

Bạn đang vận hành second brain cá nhân của user (vault Markdown này là source of truth).

## Bắt buộc trước mọi thao tác
Đọc theo thứ tự: `index.md` → `CRITICAL_FACTS.md` → `AGENTS.md`.
Tuân thủ NGHIÊM NGẶT mọi luật trong `AGENTS.md` (capture/query/compile/lint).

## Tóm tắt nhanh
- CAPTURE: ghi vào `raw/` (bất biến), có frontmatter `status: raw`.
- QUERY: trả lời CHỈ từ vault, kèm `[[trích dẫn]]`; không có thì nói "không có trong bộ não".
- COMPILE: "xử lý inbox" → note atomic vào `wiki/` + `[[wikilink]]` có ngữ cảnh.
- LINT: rà mâu thuẫn/claim cũ/orphan/link gãy → báo cáo, không tự sửa raw.

Chi tiết đầy đủ: xem `AGENTS.md`.
```

- [ ] **Step 2: Verify frontmatter hợp lệ**

Run:
```bash
head -3 .claude/skills/second-brain/SKILL.md | grep -q "name: second-brain" && echo OK
```
Expected: `OK`

- [ ] **Step 3: Commit**

```bash
git add .claude/skills/second-brain/SKILL.md
git commit -m "feat: add second-brain Claude Code skill wrapper"
```

---

## Task 5: scripts/import.sh — capture file local

**Files:**
- Create: `scripts/import.sh`
- Test: `scripts/test.sh`

- [ ] **Step 1: Viết test trước (trong `scripts/test.sh`)**

```bash
#!/usr/bin/env bash
set -euo pipefail
cd "$(dirname "$0")/.."
ROOT="$(pwd)"
FAIL=0

# --- import.sh ---
echo "hello brain" > /tmp/sb_note.txt
OUT="$(./scripts/import.sh /tmp/sb_note.txt)"
if [[ -f "$OUT" ]] && grep -q "status: raw" "$OUT" && grep -q "hello brain" "$OUT"; then
  echo "PASS import.sh -> $OUT"
else
  echo "FAIL import.sh"; FAIL=1
fi

exit $FAIL
```

- [ ] **Step 2: Chạy test → phải FAIL (chưa có import.sh)**

Run:
```bash
chmod +x scripts/test.sh && ./scripts/test.sh
```
Expected: FAIL / lỗi "No such file" cho `import.sh`.

- [ ] **Step 3: Viết `scripts/import.sh`**

```bash
#!/usr/bin/env bash
# Usage: import.sh <path-to-file>  -> copies into raw/inbox/ with frontmatter, prints dest path
set -euo pipefail
cd "$(dirname "$0")/.."

SRC="${1:?usage: import.sh <file>}"
[[ -f "$SRC" ]] || { echo "not a file: $SRC" >&2; exit 1; }

TS="$(date +%Y-%m-%d-%H%M)"
BASE="$(basename "$SRC")"
SLUG="$(echo "${BASE%.*}" | tr '[:upper:] ' '[:lower:]-' | tr -cd 'a-z0-9-')"
DEST="raw/inbox/${TS}-${SLUG:-note}.md"

{
  echo "---"
  echo "source: $SRC"
  echo "captured_at: $TS"
  echo "status: raw"
  echo "---"
  echo
  cat "$SRC"
} > "$DEST"

echo "$DEST"
```

- [ ] **Step 4: Chạy test → phải PASS**

Run:
```bash
chmod +x scripts/import.sh && ./scripts/test.sh
```
Expected: `PASS import.sh -> raw/inbox/...`

- [ ] **Step 5: Commit**

```bash
git add scripts/import.sh scripts/test.sh
git commit -m "feat: add import.sh capture script with test"
```

---

## Task 6: scripts/clip.sh — capture URL

**Files:**
- Create: `scripts/clip.sh`
- Modify: `scripts/test.sh` (thêm test clip.sh ở chế độ --dry-run, không cần mạng)

- [ ] **Step 1: Thêm test vào `scripts/test.sh`** (chèn ngay trước dòng `exit $FAIL`)

```bash
# --- clip.sh (dry-run, no network) ---
OUT2="$(./scripts/clip.sh --dry-run 'https://example.com/some/Article-Title')"
if echo "$OUT2" | grep -q "raw/web/" && echo "$OUT2" | grep -q "article-title"; then
  echo "PASS clip.sh dry-run -> $OUT2"
else
  echo "FAIL clip.sh dry-run (got: $OUT2)"; FAIL=1
fi
```

- [ ] **Step 2: Chạy test → phải FAIL (chưa có clip.sh)**

Run:
```bash
./scripts/test.sh
```
Expected: FAIL cho clip.sh.

- [ ] **Step 3: Viết `scripts/clip.sh`**

```bash
#!/usr/bin/env bash
# Usage:
#   clip.sh <url>            -> fetch URL, save Markdown stub into raw/web/, print dest
#   clip.sh --dry-run <url>  -> only print computed dest path + frontmatter, no network
# Conversion: uses `pandoc` if available; else saves a stub for Claude to fetch via WebFetch.
set -euo pipefail
cd "$(dirname "$0")/.."

DRY=0
if [[ "${1:-}" == "--dry-run" ]]; then DRY=1; shift; fi
URL="${1:?usage: clip.sh [--dry-run] <url>}"

TS="$(date +%Y-%m-%d)"
# slug from last path segment for readability
LASTSEG="$(echo "$URL" | sed -E 's#/+$##; s#.*/##; s#\?.*##; s#\.[a-z]+$##')"
SLUG="$(echo "${LASTSEG:-clip}" | tr '[:upper:] ' '[:lower:]-' | tr -cd 'a-z0-9-')"
DEST="raw/web/${TS}-${SLUG:-clip}.md"

frontmatter() {
  echo "---"
  echo "source: $URL"
  echo "captured_at: $(date +%Y-%m-%d-%H%M)"
  echo "status: raw"
  echo "---"
}

if [[ "$DRY" == "1" ]]; then
  echo "$DEST"
  frontmatter
  exit 0
fi

{
  frontmatter
  echo
  if command -v pandoc >/dev/null 2>&1; then
    curl -fsSL "$URL" | pandoc -f html -t markdown 2>/dev/null || echo "<!-- fetch/convert failed; Claude: WebFetch $URL -->"
  else
    echo "<!-- pandoc not installed. Claude: WebFetch $URL and replace this stub. -->"
    echo "URL: $URL"
  fi
} > "$DEST"

echo "$DEST"
```

- [ ] **Step 4: Chạy test → phải PASS**

Run:
```bash
chmod +x scripts/clip.sh && ./scripts/test.sh
```
Expected: cả `PASS import.sh` và `PASS clip.sh dry-run`.

- [ ] **Step 5: Commit**

```bash
git add scripts/clip.sh scripts/test.sh
git commit -m "feat: add clip.sh URL capture (pandoc + Claude-fetch fallback) with dry-run test"
```

---

## Task 7: MCP filesystem config cho Claude Desktop

**Files:**
- Create: `mcp/claude_desktop_config.snippet.json`
- Create: `mcp/README.md`

- [ ] **Step 1: Viết snippet config**

`mcp/claude_desktop_config.snippet.json`:
```json
{
  "mcpServers": {
    "second-brain": {
      "command": "npx",
      "args": [
        "-y",
        "@modelcontextprotocol/server-filesystem",
        "/Users/leonard/Workspace/code/personal/second-brain"
      ]
    }
  }
}
```

- [ ] **Step 2: Viết `mcp/README.md` hướng dẫn lắp**

```markdown
# Bật Claude Desktop đọc/ghi vault qua MCP filesystem

1. Mở file cấu hình Claude Desktop:
   - macOS: `~/Library/Application Support/Claude/claude_desktop_config.json`
2. Merge nội dung `claude_desktop_config.snippet.json` vào (gộp khoá `mcpServers`).
3. Khởi động lại Claude Desktop.
4. Trong chat, yêu cầu Claude đọc `index.md` rồi `AGENTS.md` trước khi thao tác.

Lưu ý: server `@modelcontextprotocol/server-filesystem` cho phép đọc & GHI trong
đúng thư mục vault — đây là điều kiện để Desktop capture/compile được như Claude Code.
Cần có Node.js (npx) trên máy.
```

- [ ] **Step 3: Verify JSON hợp lệ**

Run:
```bash
python3 -c "import json;json.load(open('mcp/claude_desktop_config.snippet.json'));print('OK')"
```
Expected: `OK`

- [ ] **Step 4: Commit**

```bash
git add mcp/
git commit -m "feat: add Claude Desktop MCP filesystem config + setup guide"
```

---

## Task 8: Seed dữ liệu thật & nghiệm thu 5 prompt

**Files:**
- Create: `raw/inbox/2026-06-14-seed-note.md` (qua script)
- Create: `wiki/concepts/llm-wiki.md` (seed thủ công để test query)

- [ ] **Step 1: Seed 1 wiki note thật để test query**

`wiki/concepts/llm-wiki.md`:
```markdown
# LLM Wiki

Mẫu kiến trúc second brain do Andrej Karpathy đề xuất (as of 2026-04, gist.github.com/karpathy):
bỏ vector DB cho corpus cỡ vừa (~400k từ), để LLM lập luận trực tiếp trên Markdown
qua 3 giai đoạn raw → compile → lint. File `.md` là nguồn chân lý truy vết được. (confidence: high)

Liên quan: [[zettelkasten]] (atomicity dùng cho note), và là nền của vault này — xem [[../index]].
```

- [ ] **Step 2: Verify query path bằng grep (mô phỏng điều Claude làm)**

Run:
```bash
grep -rl "Karpathy" wiki/ | head -1
```
Expected: `wiki/concepts/llm-wiki.md`

- [ ] **Step 3: Capture 1 note qua script (luồng capture)**

Run:
```bash
echo "Thử nghiệm: ý tưởng dùng cron để auto-lint hằng tuần." > /tmp/sb_idea.txt
./scripts/import.sh /tmp/sb_idea.txt
```
Expected: in ra path `raw/inbox/2026-06-14-...md`.

- [ ] **Step 4: Chạy 5 prompt nghiệm thu (thủ công trong Claude Code, ghi kết quả)**

Mở `cd second-brain && claude`, chạy lần lượt và xác nhận:
- [ ] (a) "clip https://example.com" → file mới trong `raw/web/` có frontmatter `status: raw`.
- [ ] (b) "lưu ý này: <bất kỳ>" → file mới trong `raw/inbox/`.
- [ ] (c) "LLM Wiki là gì?" → trả lời **kèm trích dẫn `[[llm-wiki]]`**.
- [ ] (d) "Giá cổ phiếu Apple hôm nay?" → trả lời "không có trong bộ não", KHÔNG bịa.
- [ ] (e) "xử lý inbox" → sinh note atomic trong `wiki/` có `[[wikilink]]`, và đổi raw `status: processed`.

- [ ] **Step 5: Lặp lại (a)–(e) tương ứng trên Claude Desktop/MCP**

Xác nhận capture (a,b) và query (c,d) hoạt động qua MCP filesystem. (Compile (e) có thể chạy ở 1 trong 2 bề mặt.)

- [ ] **Step 6: Commit seed + ghi chú nghiệm thu**

```bash
git add wiki/concepts/llm-wiki.md raw/inbox/
git commit -m "test: seed note + capture sample, verify 5 acceptance prompts"
```

---

## Hoàn tất MVP

Sau Task 8: vault hoạt động đủ 3 luồng (capture/query/maintain) trên cả 2 bề mặt.
**Để dành (YAGNI):** RAG/pgvector khi corpus vượt ngưỡng context, web clipper tự động,
mobile capture, auto-lint theo lịch (cron).
