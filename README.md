# Second Brain

> A local-first Markdown vault that Claude reads, answers from, and maintains — your notes turned into a wiki that talks back.

![Markdown](https://img.shields.io/badge/format-Markdown-000?logo=markdown)
![Bash](https://img.shields.io/badge/scripts-Bash%203.2%2B-4EAA25?logo=gnubash&logoColor=white)
![Claude Code](https://img.shields.io/badge/engine-Claude%20Code%20%2B%20MCP-d97757)
![No vector DB](https://img.shields.io/badge/retrieval-LLM--over--Markdown-blue)
![Local-first](https://img.shields.io/badge/data-local--first-success)

A personal knowledge base built on the **LLM Wiki** pattern (Karpathy): no vector database, no app, no cloud. Knowledge lives in plain `.md` files you own; Claude reasons directly over them and keeps them tidy. Every answer traces back to a specific file.

---

## Why this exists

- **You own everything.** Plain-text Markdown on your disk. No lock-in, no silo, fully `grep`-able and git-versioned.
- **Answers you can trust.** Claude answers *only* from the vault, with `[[file]]` citations. Nothing in the vault → it says "Not in the second brain" instead of hallucinating.
- **It maintains itself.** A capture → compile → lint loop turns raw clippings into atomic, cross-linked notes, and flags broken links, orphans, stale claims, and superseded knowledge.

## How it works

```
CAPTURE ──► COMPILE ──► LINT          QUERY (any time)
(raw/,      (atomic       (scripts/lint.sh    (Claude reads the
 immutable)  wiki notes    + Claude semantic    vault, cites files)
             + [[links]])  pass)
```

`.md` files are the source of truth. The operating rules live in [`AGENTS.md`](AGENTS.md) and are read by **both** Claude Code and Claude Desktop, so the two surfaces behave identically.

## Requirements

- [Claude Code](https://claude.com/claude-code) (primary surface), and/or Claude Desktop for a chat-style surface
- `bash` 3.2+ (macOS system bash works), `git`
- Optional: `pandoc` for richer URL clipping, Node.js (`npx`) for the Claude Desktop MCP server

## Install

```bash
git clone <your-remote> second-brain   # or just use this folder
cd second-brain
chmod +x scripts/*.sh
bash scripts/test.sh                    # sanity check — expect all PASS, exit 0
```

That's it — no build, no dependencies. The Claude Code skill auto-activates when you start Claude in this directory.

### Optional: Claude Desktop (chat surface)

Point Claude Desktop's MCP filesystem server at this vault so you can capture/ask from chat too. See [`mcp/README.md`](mcp/README.md) (merge `mcp/claude_desktop_config.snippet.json` into your Desktop config).

## Usage

Start Claude in the vault:

```bash
cd second-brain && claude
```

**Capture** — get things in (raw stays immutable):

```bash
./scripts/clip.sh https://example.com/article   # URL → raw/web/<date>-<slug>.md
./scripts/import.sh ~/notes/meeting.md          # file → raw/inbox/
```
…or just tell Claude: `note this: <anything>`.

**Ask** — query your knowledge, with citations:

```
> ask the brain: what is the LLM Wiki pattern?
LLM Wiki drops the vector DB for mid-sized corpora and lets the LLM reason
directly over Markdown (raw → compile → lint) [[llm-wiki]]. (confidence: high)
```
Ask something not in the vault and it answers `Not in the second brain.`

**Maintain** — compile inbox into wiki notes and lint:

```
> process inbox      # raw/inbox/ → atomic wiki notes with [[wikilinks]]
> lint the brain     # semantic review (contradictions) + the mechanical checks below
```

```bash
./scripts/lint.sh    # fast mechanical pass; exit 0 = clean, 1 = issues
```
```
=== Second Brain lint (vault: …) ===
[broken wikilinks] none
[orphan notes] none
[stale claims] none
[broken supersession] none
[open disputes] none
[unsourced claims] none
[misplaced retired] none
=== 0 issue group(s) found ===
```

## Layout

```
index.md            # Claude reads this first — vault map
CRITICAL_FACTS.md   # always-loaded facts about you
AGENTS.md           # operating rules (capture/query/compile/lint/lifecycle)
raw/                # immutable captures: web/ · meetings/ · inbox/
wiki/               # compiled, atomic, cross-linked knowledge
  concepts/ entities/ tech/ · archive/ (retired notes)
scripts/            # clip.sh · import.sh · lint.sh · test.sh
mcp/                # Claude Desktop MCP filesystem config
docs/superpowers/   # design spec + implementation plan
```

## Knowledge lifecycle

Notes never get silently deleted. Each wiki note carries frontmatter (`status`, `updated`, `sources`) and moves through states:

| State | Meaning | Mechanism |
|---|---|---|
| `current` | live knowledge | default |
| `superseded` | replaced by newer info | inline `(superseded YYYY-MM → [[new]])`, kept in place |
| `disputed` | conflicting evidence, unresolved | `status: disputed`, confidence lowered |
| `retired` | obsolete | moved to `wiki/archive/`, excluded from default answers |

`scripts/lint.sh` enforces the mechanical half of this; Claude does the semantic half. Full rules: [`AGENTS.md`](AGENTS.md) §6.

## Learn more

- **Design rationale & decisions** → [`docs/superpowers/specs/`](docs/superpowers/specs/)
- **Implementation plan** → [`docs/superpowers/plans/`](docs/superpowers/plans/)
- **Operating rules** → [`AGENTS.md`](AGENTS.md)

Built on prior art: Karpathy's *LLM Wiki*, Tiago Forte's *Building a Second Brain*, and Luhmann's *Zettelkasten* — see the seeded notes under `wiki/concepts/`.
