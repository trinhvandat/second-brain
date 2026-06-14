# Personal Second Brain — Implementation Plan

> **For agentic workers:** REQUIRED SUB-SKILL: Use superpowers:subagent-driven-development (recommended) or superpowers:executing-plans to implement this plan task-by-task. Steps use checkbox (`- [ ]`) syntax for tracking.

**Goal:** Build a personal second brain as an LLM Wiki — a local-first Markdown vault as the source of truth, with Claude (Code + Desktop/MCP) as the brain for reading/writing/maintaining, serving Q&A + technical assistant + idea capture + life memory.

**Architecture:** `.md` files are the source of truth; no vector DB, Claude reasons directly over Markdown (Karpathy LLM Wiki pattern). Operating rules are placed in `AGENTS.md` (surface-agnostic) so both Claude Code and Claude Desktop/MCP read from the same source; SKILL.md is just a thin wrapper. Three pipelines: capture (immutable raw) → compile (atomic wiki + wikilinks) → lint.

**Tech Stack:** Markdown, Bash (clip/import scripts), Claude Code skill, MCP filesystem server (Claude Desktop), git.

**Spec:** `docs/superpowers/specs/2026-06-14-personal-second-brain-design.md`

---

## File Structure

| File | Responsibility |
|---|---|
| `index.md` | Vault map + reading order; Claude reads this first |
| `CRITICAL_FACTS.md` | Fixed facts about the user (~150 tokens), always loaded |
| `AGENTS.md` | Operating rules for capture/query/maintain (surface-agnostic) |
| `raw/web/`, `raw/meetings/`, `raw/inbox/` | Immutable sources |
| `wiki/concepts/`, `wiki/entities/`, `wiki/tech/`, `wiki/journal/` | Compiled knowledge |
| `.claude/skills/second-brain/SKILL.md` | Activation wrapper for Claude Code |
| `scripts/clip.sh` | URL → Markdown stub into `raw/web/` |
| `scripts/import.sh` | local file → `raw/inbox/` |
| `scripts/test.sh` | Assertions for the 2 scripts above |
| `mcp/claude_desktop_config.snippet.json` | MCP filesystem config for Desktop |
| `.gitignore` | Ignore junk files |

---

## Task 0: Initialize project & git

**Files:**
- Create: `.gitignore`

- [ ] **Step 1: Init git**

Run:
```bash
cd /Users/leonard/Workspace/code/personal/second-brain
git init
```
Expected: `Initialized empty Git repository ...`

- [ ] **Step 2: Create directory tree**

Run:
```bash
mkdir -p raw/web raw/meetings raw/inbox \
         wiki/concepts wiki/entities wiki/tech wiki/journal \
         .claude/skills/second-brain scripts mcp
```
Expected: no error.

- [ ] **Step 3: Write `.gitignore`**

```gitignore
.DS_Store
.omc/
*.tmp
node_modules/
.env
```

- [ ] **Step 4: Keep empty directories with `.gitkeep`**

Run:
```bash
touch raw/web/.gitkeep raw/meetings/.gitkeep raw/inbox/.gitkeep \
      wiki/concepts/.gitkeep wiki/entities/.gitkeep wiki/tech/.gitkeep wiki/journal/.gitkeep
```
Expected: no error.

- [ ] **Step 5: Commit**

```bash
git add -A
git commit -m "chore: init second-brain vault skeleton"
```

---

## Task 1: AGENTS.md — operating rules (heart of the system)

**Files:**
- Create: `AGENTS.md`

- [ ] **Step 1: Write acceptance check (content checklist)**

The file must contain all 5 sections: (1) read order, (2) CAPTURE rules, (3) QUERY rules + anti-hallucination, (4) COMPILE rules, (5) LINT rules. Will be verified with grep in Step 3.

- [ ] **Step 2: Write `AGENTS.md`**

```markdown
# AGENTS.md — Second Brain Operating Rules

> These are the shared operating rules for ALL surfaces (Claude Code & Claude Desktop/MCP).
> Read this file before operating on the vault.

## 0. Reading order (REQUIRED)
1. `index.md` — vault map.
2. `CRITICAL_FACTS.md` — fixed facts about the user (always loaded).
3. Only then `grep`/read relevant files in `wiki/` and `raw/`.

## 1. CAPTURE
- Everything in `raw/` is **IMMUTABLE** — do not modify the original content, only add new files.
- URL → `raw/web/YYYY-MM-DD-<slug>.md` (use `scripts/clip.sh` or WebFetch).
- Quick note/idea → `raw/inbox/YYYY-MM-DD-HHMM-<slug>.md`.
- Meeting → `raw/meetings/YYYY-MM-DD-<slug>.md`.
- Each raw file has YAML frontmatter: `source`, `captured_at`, `status: raw`.

## 2. QUERY
- Answer ONLY from content within the vault.
- Every assertion includes a citation `[[file]]` (wikilink to the source file).
- If NOT in the vault: clearly state "Not in the second brain" — do NOT hallucinate, do NOT use outside knowledge unless the user explicitly requests it.
- When information is outdated/contradictory, include a timestamp marker `(as of YYYY-MM, source)`.

## 3. COMPILE (raw → wiki)
- When the user says "process inbox": read `raw/inbox/`, distill into ATOMIC notes.
- Atomicity: 1 file = 1 concept/entity. Place in the correct `wiki/concepts|entities|tech|journal`.
- Each wiki note MUST have ≥1 wikilink with context `[[wikilink]]` (explain why the link exists).
- Keep the source URL verbatim + confidence marker `(high|medium|low)` for important claims.
- After compiling, mark the raw file as processed: change frontmatter `status: processed`.

## 4. LINT (periodic review)
- When the user says "lint" or "lint the brain": scan all of `wiki/` for:
  - contradictions between notes;
  - stale claims (outdated timestamp markers);
  - orphans (notes with no incoming links);
  - wikilinks pointing to non-existent files.
- Output a report + SUGGEST fixes; do NOT modify raw content.

## 5. Note writing style
- Write for future-Claude to read & reason over, not as prose for humans.
- Short, atomic, richly linked. Write in English by default.
```

- [ ] **Step 3: Verify structure**

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

## Task 2: index.md — vault map

**Files:**
- Create: `index.md`

- [ ] **Step 1: Write `index.md`**

```markdown
# Second Brain — Index

> Claude: read this file FIRST, then `CRITICAL_FACTS.md`, then `AGENTS.md`.

## Vault map
- `raw/` — captured immutable sources
  - `web/` clipped articles · `meetings/` meetings · `inbox/` quick captures not yet processed
- `wiki/` — compiled knowledge (atomic + wikilinks)
  - `concepts/` concepts · `entities/` people/companies/projects/tools · `tech/` technical · `journal/` journal
- `AGENTS.md` — operating rules (read before operating)

## 4 use cases → pathways
- Knowledge Q&A → `wiki/` + `raw/`, answer with `[[citation]]`.
- Technical assistant → `wiki/tech/`.
- Capture & connect ideas → `raw/inbox/` → (compile) → `wiki/concepts/`.
- Life memory → `raw/` + `wiki/journal/`.

## Common commands
- Capture URL: `./scripts/clip.sh <url>`
- Capture file: `./scripts/import.sh <path>`
- In Claude: "note this: ..." / "process inbox" / "lint the brain".

## Status
- Initialized: 2026-06-14. Retrieval: LLM-over-Markdown (RAG not yet in use).
```

- [ ] **Step 2: Verify**

Run:
```bash
test -f index.md && grep -q "read this file FIRST" index.md && echo OK
```
Expected: `OK`

- [ ] **Step 3: Commit**

```bash
git add index.md
git commit -m "feat: add index.md vault map"
```

---

## Task 3: CRITICAL_FACTS.md — fixed facts about the user

**Files:**
- Create: `CRITICAL_FACTS.md`

- [ ] **Step 1: Write `CRITICAL_FACTS.md` (template + minimal seed)**

```markdown
# CRITICAL FACTS

> ~150 tokens. Facts that RARELY CHANGE about the owner. Claude always loads this file.

- Name: Leonard.
- Role: Fullstack Engineer (strong backend) + Engineering Manager.
- Primary stack: Java, Spring Boot, Kotlin, TypeScript, PostgreSQL, microservices.
- Work tools: lives in Claude Code; uses Claude Desktop + MCP for chat.
- Language: Vietnamese primarily, English for technical topics.
- Second brain goals: knowledge Q&A, technical assistant, idea capture, life memory.

<!-- Add new facts here once stable. Do not let this file grow beyond ~200 tokens. -->
```

- [ ] **Step 2: Verify length (~< 200 words)**

Run:
```bash
wc -w CRITICAL_FACTS.md
```
Expected: word count < 120 (small enough to always load).

- [ ] **Step 3: Commit**

```bash
git add CRITICAL_FACTS.md
git commit -m "feat: add CRITICAL_FACTS seed"
```

---

## Task 4: Claude Code skill wrapper

**Files:**
- Create: `.claude/skills/second-brain/SKILL.md`

- [ ] **Step 1: Write `SKILL.md`**

```markdown
---
name: second-brain
description: Personal second brain over a local Markdown vault. Use when the user asks to capture/clip something, ask questions about their notes/knowledge, process inbox, compile wiki notes, or lint the knowledge base. Triggers — "note this", "clip", "ask the brain", "process inbox", "lint the brain", "second brain".
---

# Second Brain

You are operating the user's personal second brain (this Markdown vault is the source of truth).

## Required before any operation
Read in order: `index.md` → `CRITICAL_FACTS.md` → `AGENTS.md`.
STRICTLY follow all rules in `AGENTS.md` (capture/query/compile/lint).

## Quick summary
- CAPTURE: write to `raw/` (immutable), with frontmatter `status: raw`.
- QUERY: answer ONLY from the vault, with `[[citation]]`; if not found, say "not in the second brain".
- COMPILE: "process inbox" → atomic notes into `wiki/` + wikilinks with context `[[wikilink]]`.
- LINT: scan for contradictions/stale claims/orphans/broken links → report, do not modify raw.

Full details: see `AGENTS.md`.
```

- [ ] **Step 2: Verify frontmatter is valid**

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

## Task 5: scripts/import.sh — capture local file

**Files:**
- Create: `scripts/import.sh`
- Test: `scripts/test.sh`

- [ ] **Step 1: Write test first (in `scripts/test.sh`)**

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

- [ ] **Step 2: Run test → must FAIL (import.sh does not exist yet)**

Run:
```bash
chmod +x scripts/test.sh && ./scripts/test.sh
```
Expected: FAIL / "No such file" error for `import.sh`.

- [ ] **Step 3: Write `scripts/import.sh`**

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

- [ ] **Step 4: Run test → must PASS**

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
- Modify: `scripts/test.sh` (add clip.sh test in --dry-run mode, no network required)

- [ ] **Step 1: Add test to `scripts/test.sh`** (insert just before the `exit $FAIL` line)

```bash
# --- clip.sh (dry-run, no network) ---
OUT2="$(./scripts/clip.sh --dry-run 'https://example.com/some/Article-Title')"
if echo "$OUT2" | grep -q "raw/web/" && echo "$OUT2" | grep -q "article-title"; then
  echo "PASS clip.sh dry-run -> $OUT2"
else
  echo "FAIL clip.sh dry-run (got: $OUT2)"; FAIL=1
fi
```

- [ ] **Step 2: Run test → must FAIL (clip.sh does not exist yet)**

Run:
```bash
./scripts/test.sh
```
Expected: FAIL for clip.sh.

- [ ] **Step 3: Write `scripts/clip.sh`**

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

- [ ] **Step 4: Run test → must PASS**

Run:
```bash
chmod +x scripts/clip.sh && ./scripts/test.sh
```
Expected: both `PASS import.sh` and `PASS clip.sh dry-run`.

- [ ] **Step 5: Commit**

```bash
git add scripts/clip.sh scripts/test.sh
git commit -m "feat: add clip.sh URL capture (pandoc + Claude-fetch fallback) with dry-run test"
```

---

## Task 7: MCP filesystem config for Claude Desktop

**Files:**
- Create: `mcp/claude_desktop_config.snippet.json`
- Create: `mcp/README.md`

- [ ] **Step 1: Write config snippet**

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

- [ ] **Step 2: Write `mcp/README.md` setup guide**

```markdown
# Enable Claude Desktop to read/write the vault via MCP filesystem

1. Open the Claude Desktop config file:
   - macOS: `~/Library/Application Support/Claude/claude_desktop_config.json`
2. Merge the contents of `claude_desktop_config.snippet.json` into it (merge the `mcpServers` key).
3. Restart Claude Desktop.
4. In chat, ask Claude to read `index.md` then `AGENTS.md` before operating.

Note: the `@modelcontextprotocol/server-filesystem` server allows reading & WRITING within
the vault directory — this is required for Desktop to capture/compile the same as Claude Code.
Node.js (npx) must be installed on the machine.
```

- [ ] **Step 3: Verify valid JSON**

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

## Task 8: Seed real data & acceptance testing with 5 prompts

**Files:**
- Create: `raw/inbox/2026-06-14-seed-note.md` (via script)
- Create: `wiki/concepts/llm-wiki.md` (manually seeded to test query)

- [ ] **Step 1: Seed 1 real wiki note to test query**

`wiki/concepts/llm-wiki.md`:
```markdown
# LLM Wiki

Second brain architecture pattern proposed by Andrej Karpathy (as of 2026-04, gist.github.com/karpathy):
drops the vector DB for mid-sized corpora (~400k words), letting the LLM reason directly over Markdown
through 3 stages: raw → compile → lint. `.md` files are the traceable source of truth. (confidence: high)

Related: [[zettelkasten]] (atomicity applied to notes), and the foundation of this vault — see [[../index]].
```

- [ ] **Step 2: Verify query path using grep (simulating what Claude does)**

Run:
```bash
grep -rl "Karpathy" wiki/ | head -1
```
Expected: `wiki/concepts/llm-wiki.md`

- [ ] **Step 3: Capture 1 note via script (capture pipeline)**

Run:
```bash
echo "Test idea: use a cron job to auto-lint weekly." > /tmp/sb_idea.txt
./scripts/import.sh /tmp/sb_idea.txt
```
Expected: prints path `raw/inbox/2026-06-14-...md`.

- [ ] **Step 4: Run 5 acceptance prompts (manually in Claude Code, record results)**

Open `cd second-brain && claude`, run each prompt in order and confirm:
- [ ] (a) "clip https://example.com" → new file in `raw/web/` with frontmatter `status: raw`.
- [ ] (b) "note this: <anything>" → new file in `raw/inbox/`.
- [ ] (c) "What is LLM Wiki?" → answer **with citation `[[llm-wiki]]`**.
- [ ] (d) "What is Apple's stock price today?" → answer "Not in the second brain", do NOT hallucinate.
- [ ] (e) "process inbox" → generate atomic note in `wiki/` with `[[wikilink]]`, and change raw `status: processed`.

- [ ] **Step 5: Repeat (a)–(e) on Claude Desktop/MCP**

Confirm capture (a,b) and query (c,d) work via MCP filesystem. (Compile (e) can run on either surface.)

- [ ] **Step 6: Commit seed + acceptance test notes**

```bash
git add wiki/concepts/llm-wiki.md raw/inbox/
git commit -m "test: seed note + capture sample, verify 5 acceptance prompts"
```

---

## MVP Complete

After Task 8: the vault operates all 3 pipelines (capture/query/maintain) on both surfaces.
**Deferred (YAGNI):** RAG/pgvector when corpus exceeds context threshold, automated web clipper,
mobile capture, scheduled auto-lint (cron).
