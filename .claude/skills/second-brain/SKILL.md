---
name: second-brain
description: Personal second brain over a local Markdown vault. Use when the user asks to capture/clip something, ask questions about their notes/knowledge, process inbox, compile wiki notes, or lint the knowledge base. Triggers — "note this", "clip", "ask the brain", "process inbox", "lint the brain", "second brain".
---

# Second Brain

You are operating the user's personal second brain (this Markdown vault is the source of truth).

## Required before any action
Read in order: `index.md` → `CRITICAL_FACTS.md` → `AGENTS.md`.
Strictly follow every rule in `AGENTS.md` (capture/query/compile/lint).

## Quick summary
- CAPTURE: write into `raw/` (immutable), with `status: raw` frontmatter.
- QUERY: answer ONLY from the vault, with `[[citations]]`; if absent, say "Not in the second brain".
- COMPILE: "process inbox" → atomic notes into `wiki/` + `[[wikilink]]` with context.
- LINT: scan for contradictions/stale claims/orphans/broken links → report, never edit raw.

Full details: see `AGENTS.md`.
