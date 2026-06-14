# Second Brain — Index

> Claude: read this file FIRST, then `CRITICAL_FACTS.md`, then `AGENTS.md`.

## Vault map
- `raw/` — immutable captured sources
  - `web/` clipped articles · `meetings/` meetings · `inbox/` quick unprocessed captures
- `wiki/` — compiled knowledge (atomic + wikilinks)
  - `concepts/` concepts · `entities/` people/companies/projects/tools · `tech/` technical · `journal/` journal
- `AGENTS.md` — operating rules (read before doing anything)

## 4 use cases → path
- Knowledge Q&A → `wiki/` + `raw/`, answer with `[[citations]]`.
- Technical assistant → `wiki/tech/`.
- Capture & connect ideas → `raw/inbox/` → (compile) → `wiki/concepts/`.
- Life memory → `raw/` + `wiki/journal/`.

## Common commands
- Capture URL: `./scripts/clip.sh <url>`
- Capture file: `./scripts/import.sh <path>`
- Mechanical lint: `./scripts/lint.sh` (broken links, orphans, stale claims)
- In Claude: "note this: ..." / "process inbox" / "lint the brain".

## Status
- Initialized: 2026-06-14. Retrieval: LLM-over-Markdown (no RAG yet).
