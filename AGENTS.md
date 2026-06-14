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
- Prefer notes with `status: current`. Ignore `wiki/archive/` (retired) unless the user explicitly asks for historical/retired knowledge.
- If the only matching note is `superseded` or `disputed`, say so and cite both the old note and its replacement/conflict.
- If it is NOT in the vault: say clearly "Not in the second brain" — do NOT make things up, do NOT use outside knowledge unless the user explicitly asks.
- When information is stale/conflicting, include a recency marker `(as of YYYY-MM, source)`.

## 3. COMPILE (raw → wiki) & ENRICH
- When the user says "process inbox": read `raw/inbox/`, distill into ATOMIC notes.
- Atomicity: 1 file = 1 concept/entity. Place it in the right `wiki/concepts|entities|tech|journal`.
- **Dedup before creating:** first `grep`/search `wiki/` for an existing note on the concept (by title/basename). If one exists, ENRICH it instead of creating a duplicate.
- **ENRICH = re-derive, not just append:** add the new claim/nuance, append the new source to frontmatter `sources`, adjust `(confidence: …)` by evidence (independent corroboration raises it; a lone weak source keeps it low), add `[[wikilinks]]`, and bump frontmatter `updated`.
- Every wiki note MUST have ≥1 `[[wikilink]]` WITH CONTEXT (explain why it is linked) and the frontmatter from section 5.
- Keep source URLs verbatim + a confidence marker `(high|medium|low)` for important claims.
- After compiling, mark the raw file as processed: change frontmatter to `status: processed`.

## 4. LINT (periodic review)
- When the user says "lint" or "check the brain": scan all of `wiki/` for:
  - contradictions between notes;
  - stale claims (recency marker is long past);
  - orphans (notes nothing links to);
  - wikilinks pointing to non-existent files;
  - lifecycle issues (superseded without a replacement link, open disputes, claims with confidence but no source).
- The mechanical subset can be pre-run with `scripts/lint.sh`; the contradiction check is semantic and is yours to do.
- Produce a report + SUGGESTED fixes; do NOT edit raw content automatically.

## 5. Note format & style
- Each wiki note starts with YAML frontmatter:
  ```yaml
  ---
  status: current        # current | superseded | disputed | retired
  updated: YYYY-MM       # last enrich/verify date
  sources:               # note-level provenance (URLs or source names)
    - https://example.com
  ---
  ```
- Write for future-Claude to retrieve and reason over, not prose for humans.
- Short, atomic, heavily linked. Write in English by default.

## 6. LIFECYCLE (invalidate old knowledge — never delete silently)
- **Supersede** (new info replaces old): set the old note's frontmatter `status: superseded`, add an inline `(superseded YYYY-MM → [[new-note]])` on the affected claim, and have the new note state `Supersedes [[old-note]]`. Keep the old note in place (preserves backlinks + provenance).
- **Dispute** (evidence conflicts, unresolved): set `status: disputed`, add inline `(disputed YYYY-MM: <reason> [[conflicting-note]])`, and lower `(confidence)`. Do NOT pick a winner automatically; resolve later.
- **Retire** (fully obsolete): move the file into `wiki/archive/` and set `status: retired`. It stays searchable for audit but is excluded from default QUERY.
- **Re-validation loop:** when lint flags a stale note, re-check its source (WebFetch the URL if present), then either refresh `updated` or mark it superseded/retired.
- Raw sources are never invalidated — they are the immutable audit trail; lifecycle applies to compiled `wiki/` notes only.
