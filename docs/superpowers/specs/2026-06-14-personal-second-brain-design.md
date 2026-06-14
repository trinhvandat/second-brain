# Design Spec — Personal Second Brain (LLM Wiki)

- **Date:** 2026-06-14
- **Status:** Approved design → ready for implementation planning
- **Author:** Leonard (+ Claude)
- **Project root:** `/Users/leonard/Workspace/code/personal/second-brain` (greenfield)

---

## 1. Objective

Build a **personal second brain** as an *LLM Wiki*: a local-first Markdown vault
as the **source of truth**, with Claude acting as the reading/reasoning/maintenance engine.
The system serves **4 use cases on a single substrate**:

1. **Personal knowledge Q&A** — ask naturally, receive answers with source citations.
2. **Technical / work assistant** — snippets, ADRs, lessons-learned while coding.
3. **Capture & connect ideas** — quick capture, system auto-links notes (Zettelkasten + AI).
4. **Comprehensive life memory** — web articles, meeting notes, PDFs, journal.

**Why:** The bottleneck of AI in knowledge work is not the model but
*personal context* structured for LLM consumption (Tiago Forte — "Personal Context
Management"). The goal is to turn scattered notes into a "wiki that can answer" and
**self-maintain**.

## 2. Research Basis (verified 3-0)

Based on the deep-research report from 2026-06-13 (21/25 claims confirmed):

- **Karpathy's LLM Wiki (4/2026):** drops vector DB for mid-sized corpora (~100 articles /
  ~400k words); LLM reasons directly over Markdown through 3 stages: raw → compile →
  lint; `.md` files are the traceable source of truth, avoiding embedding black boxes.
  (gist Karpathy, VentureBeat)
- **obsidian-second-brain:** Claude Code skill that turns a Markdown vault into a
  **self-maintaining** KB; structured for LLM reading (`index.md` read first,
  `CRITICAL_FACTS.md` always loaded, `raw/` immutable, `wiki/` organized by entities/concepts,
  `[[wikilinks]]` required, confidence/recency markers).
  (github.com/eugeniughelbur/obsidian-second-brain)
- **Zettelkasten:** atomicity (1 note = 1 unit of knowledge, unique address); links
  must HAVE CONTEXT to generate knowledge. (zettelkasten.de)
- **NotebookLM source-grounding:** answers only from existing sources + verifiable
  citations → anti-hallucination pattern. (arXiv 2504.09720)

## 3. Design Decisions (from brainstorming)

| Decision | Choice | Notes |
|---|---|---|
| Purpose | All 4 use cases | Served on the same Markdown substrate |
| Build philosophy | Hybrid → existing vault + thin custom layer | "Custom layer" = Claude skill + small scripts, NOT an app |
| Stack | Minimal code needed | Claude Code handles ingest/query; write shell scripts only when needed |
| Retrieval | **LLM-over-Markdown** (Karpathy) | Zero infra; RAG/pgvector deferred (YAGNI) for the future |
| Surface | **Claude Code (primary) + Claude Desktop/MCP (secondary)** | Both point to the same vault |
| Operating rules | **Surface-agnostic** | Defined in `index.md` + `AGENTS.md`; SKILL.md is just a wrapper |

**Discarded approaches:**
- *RAG + pgvector*: conflicts with "minimal code needed"; YAGNI until corpus exceeds
  context window threshold.
- *Obsidian + plugin RAG (Smart Connections)*: locks into the Obsidian app; we want
  Claude as the primary agent.
- *claude.ai Projects*: **cannot write back to local files** → the "live" vault will
  gradually drift.

## 4. Architecture & Vault Structure

**Core principles:**
- `.md` files are the source of truth — every answer traces back to a specific file.
- Written **for Claude to read first, humans second** (AI-first retrieval).
- Every claim carries a marker: `(as of YYYY-MM, source.com)` + confidence level when relevant.
- `[[wikilinks]]` are required, with context explaining the link (Zettelkasten).

```
second-brain/
├── index.md              # Claude reads THIS FIRST — vault map + usage guide
├── CRITICAL_FACTS.md     # ~150 tokens, always-true facts about me, always loaded
├── AGENTS.md             # Surface-agnostic operating rules (capture/query/lint)
├── raw/                  # IMMUTABLE sources
│   ├── web/              # articles clipped from URLs (Markdown)
│   ├── meetings/         # raw meeting notes
│   └── inbox/            # quick captures, unprocessed
├── wiki/                 # Compiled knowledge — Claude writes & maintains
│   ├── concepts/         # 1 file = 1 atomic concept
│   ├── entities/         # people, companies, projects, tools
│   ├── tech/             # technical assistant use case: snippets, ADRs, lessons
│   └── journal/          # life memory use case: by day/week
├── .claude/
│   └── skills/second-brain/SKILL.md   # thin wrapper pointing to AGENTS.md
├── scripts/              # small shell scripts: clip URL, import file
└── docs/superpowers/specs/            # this spec
```

**Use case → substrate mapping:**
- Knowledge Q&A → read `wiki/` + `raw/`, answer with citations.
- Technical assistant → `wiki/tech/`.
- Capture & connect ideas → `raw/inbox/` → compile into `wiki/concepts/` + auto `[[links]]`.
- Life memory → `raw/` + `wiki/journal/`.

## 5. Units & Boundaries

| Unit | Role | Dependencies | Interface |
|---|---|---|---|
| `AGENTS.md` | Defines capture/query/maintain rules | — | Claude reads on vault entry |
| `index.md` | Vault map + reading order | directory structure | Claude reads first |
| `CRITICAL_FACTS.md` | Fixed facts about the user | — | always loaded into context |
| SKILL.md (Claude Code) | Activation wrapper + points to AGENTS.md | AGENTS.md | auto on cd into vault |
| MCP filesystem config | Allows Desktop to read/write vault | Claude Desktop | chat surface |
| `scripts/clip.sh` | URL → Markdown into raw/web/ | curl/markdown tool | CLI |
| `scripts/import.sh` | file → raw/inbox/ | — | CLI |

Each unit is independently understandable and testable in isolation. Operating rules are
decoupled from the activation mechanism (AGENTS.md vs SKILL.md) so both surfaces share
the same rules.

## 6. Three Operating Workflows

### ① CAPTURE (ingest) — low friction
- Claude Code: `clip <url>` → `raw/web/`; "note this: ..." → `raw/inbox/`.
- Desktop: paste/speak → Claude writes files via MCP filesystem.
- **Principle:** raw captures are **immutable**, not edited; process later.

### ② QUERY (Q&A) — 4 use cases
- Claude reads `index.md` + `CRITICAL_FACTS.md` first → `grep`/reads `wiki/` + `raw/`.
- Answers **with `[[file]]` citations** + confidence level.
- Not in the vault → explicitly states "Not in the second brain" (source-grounding, anti-hallucination).

### ③ MAINTAIN (compile + lint)
- *Compile*: "process inbox" → read `raw/inbox/`, write/update atomic notes in `wiki/`,
  auto-add `[[wikilinks]]` + suggest connections.
- *Lint* (periodic): scan for contradictions, outdated claims, orphans, missing links →
  report + suggest fixes.

## 7. MVP Scope (Round 1)

1. Initialize vault structure + `index.md`, `CRITICAL_FACTS.md`, `AGENTS.md`.
2. Write Claude Code skill `second-brain` (thin wrapper pointing to AGENTS.md).
3. Configure MCP filesystem for Claude Desktop to point at the vault.
4. 1-2 capture scripts (`clip.sh`, `import.sh`).
5. Seed a few real notes to test the 3 workflows.

**Out of scope (YAGNI — only when needed):** RAG/pgvector (when corpus exceeds context
threshold), automated web clipper, mobile capture, scheduled auto-lint.

## 8. Test Plan (verify MVP is usable)

5 test prompts:
- (a) capture 1 URL → Markdown file appears in `raw/web/`.
- (b) capture 1 quick idea → file in `raw/inbox/`.
- (c) ask 1 question that IS in the vault → answer **with `[[file]]` citation**.
- (d) ask 1 question that is NOT in the vault → must say "Not in the second brain", no hallucination.
- (e) "process inbox" → generate atomic note in `wiki/` with `[[link]]`.

All 5 must pass on **both surfaces** (Claude Code + Desktop/MCP) for the relevant workflow.

## 9. Risks & Open Questions

- **Scale threshold:** when corpus exceeds the context window, RAG will be needed. Karpathy
  cites ~400k words as "mid-sized"; the upper boundary is not yet quantified → monitor,
  do not build RAG yet.
- **Token cost:** "loading the wiki into context" is expensive as the vault grows → mitigate
  with selective `index.md`/grep instead of reading everything.
- **Vietnamese:** Claude's quality processing Vietnamese notes is good, but there is no
  Vietnamese embedding benchmark yet (only relevant if RAG is added later).
- **Two-surface sync:** both write to the same files → avoid simultaneous edits; vault
  does not use real-time sync so conflicts are low.

## 10. Next Steps

After the user approves this spec → invoke **writing-plans** to produce a detailed
implementation plan for the MVP (section 7).
