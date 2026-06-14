# AGENTS.md — Second Brain Operating Rules

> These rules apply to EVERY surface (Claude Code & Claude Desktop/MCP).
> Read this file before doing anything with the vault.

## 0. Reading order (MANDATORY)
1. `index.md` — vault map.
2. `CRITICAL_FACTS.md` — fixed facts about the user (always loaded).
3. Only then `grep`/read the relevant files in `wiki/` and `raw/`.

## 1. CAPTURE (ingest)
- Anything in `raw/` is **IMMUTABLE** — never edit the original content, only add new files.
- URL → `raw/web/YYYY-MM-DD-<slug>.md` (use `scripts/clip.sh` or WebFetch).
- Quick idea/note → `raw/inbox/YYYY-MM-DD-HHMM-<slug>.md`.
- Meeting → `raw/meetings/YYYY-MM-DD-<slug>.md`.
- Every raw file has YAML frontmatter: `source`, `captured_at`, `status: raw`.

## 2. QUERY (Q&A)
- Answer ONLY from content in the vault.
- Every claim cites its source with a `[[file]]` wikilink.
- If it is NOT in the vault: say clearly "Not in the second brain" — do NOT make things up, do NOT use outside knowledge unless the user explicitly asks.
- When information is stale/conflicting, include a recency marker `(as of YYYY-MM, source)`.

## 3. COMPILE (raw → wiki)
- When the user says "process inbox": read `raw/inbox/`, distill into ATOMIC notes.
- Atomicity: 1 file = 1 concept/entity. Place it in the right `wiki/concepts|entities|tech|journal`.
- Every wiki note MUST have ≥1 `[[wikilink]]` WITH CONTEXT (explain why it is linked).
- Keep source URLs verbatim + a confidence marker `(high|medium|low)` for important claims.
- After compiling, mark the raw file as processed: change frontmatter to `status: processed`.

## 4. LINT (periodic review)
- When the user says "lint" or "check the brain": scan all of `wiki/` for:
  - contradictions between notes;
  - stale claims (recency marker is long past);
  - orphans (notes nothing links to);
  - wikilinks pointing to non-existent files.
- The mechanical subset (broken links, orphans, stale-by-date) can be pre-run with `scripts/lint.sh`; the contradiction check is semantic and is yours to do.
- Produce a report + SUGGESTED fixes; do NOT edit raw content automatically.

## 5. Note style
- Write for future-Claude to retrieve and reason over, not prose for humans.
- Short, atomic, heavily linked. Write in English by default.
