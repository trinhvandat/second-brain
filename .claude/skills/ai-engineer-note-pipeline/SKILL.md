---
name: ai-engineer-note-pipeline
description: Research an AI-engineer wiki topic, synthesize a vault-styled note, then loop junior/middle/senior review until it reads well — runs the saved .claude/workflows/ai-engineer-note-pipeline.js multi-agent workflow. Use when the user wants to add/write/research a new note under wiki/tech/ai-engineer/, or explicitly says "note pipeline", "chạy pipeline note", "viết note ai-engineer bằng workflow".
---

# AI Engineer Note Pipeline

Runs the saved workflow at `.claude/workflows/ai-engineer-note-pipeline.js` (Research → Synthesize → Review → Revise) to produce one wiki note under `wiki/tech/ai-engineer/`.

## When to use

Invoke this whenever the user wants a new (or replacement) note added to the `ai-engineer` roadmap track, especially if they paste a topic description and/or seed source links/URLs.

## Steps

1. **Gather inputs** — from the user's message, figure out:
   - `topic` — a clear 1-3 sentence description of the concept (use the user's own text if they gave one; don't rewrite it into something thinner).
   - `category` — the subfolder under `wiki/tech/ai-engineer/` (`llm`, `prompt`, `agent`, `rag`, `eval`, `sec`, `infra`, `finetune` — see the "Categories so far" list in `wiki/tech/ai-engineer-roadmap.md`). Ask if it's genuinely ambiguous; otherwise infer from the topic.
   - `slug` — short kebab-case identifier for the filename (e.g. `perception-user-input`).
   - `seedSources` — any URLs the user pasted.
   - `seedContext` — any raw text/definition the user pasted alongside the URLs.
   If the user didn't specify category/slug explicitly, propose one and proceed (don't block on confirmation unless truly unclear).

2. **Check the roadmap row** — read `wiki/tech/ai-engineer-roadmap.md`, find (or decide) the exact row text this note should attach to under the relevant category table. If no matching row exists yet, add one first (`| <topic> | planned | — |`) so the workflow's roadmap-edit step has something to match against. Use that exact row text as `roadmapRowTopic`.

3. **Derive paths**:
   - `filePath`: `/Users/leonard/Workspace/code/personal/second-brain/wiki/tech/ai-engineer/<category>/<category>-<slug>.md`
   - `roadmapPath`: `/Users/leonard/Workspace/code/personal/second-brain/wiki/tech/ai-engineer-roadmap.md`

4. **Pick `relatedNotes`** — 2-4 existing note slugs (no category prefix duplication issues — use the `[[wikilink]]` slug as written in the vault) that are topically adjacent, for the synthesis step to cross-link. `ai-engineer-roadmap` is always a safe include.

5. **Edit the script's `DEFAULT_ARGS`, don't pass `args` to `Workflow`**. Passing `args` directly to a named/scriptPath `Workflow` call is confirmed unreliable here — it can silently drop fields or fall back to the script's stale `DEFAULT_ARGS` (verified 2026-08: a run passing `args={topic: "Perception..."}` actually researched/wrote about the *old* default topic "agent loop" instead — caught before the Synthesize/Write step ran, so no note file was corrupted, but the run was wasted).
   - `Read` `.claude/workflows/ai-engineer-note-pipeline.js`.
   - `Edit` its `DEFAULT_ARGS` block (topic, category, slug, filePath, roadmapPath, roadmapRowTopic, relatedNotes, and `seedSources`/`seedContext` if the user gave sources/a draft definition) in place, for the new topic.

6. **Launch the workflow with `scriptPath` only — no `args`, no `resumeFromRunId` for a new topic**:
   ```
   Workflow({ scriptPath: "<repo-abs-path>/.claude/workflows/ai-engineer-note-pipeline.js" })
   ```
   This runs in the background — tell the user it's running and that you'll report back when it completes. Do not poll; you'll be notified.
   (Only use `resumeFromRunId` when cheaply re-testing the *same* topic after editing the script's prompts/rules — not for a new topic.)

7. **On completion, verify on disk before reporting done** — don't trust the workflow's returned JSON `result` blob alone. `ls`/`grep`/`Read` the actual note `filePath` and the actual roadmap row to confirm they were written as expected, then summarize: file path, number of revise rounds, whether all 3 review personas passed. If not approved after max rounds, surface the remaining persona feedback so the user can decide whether to accept as-is or iterate further.

## Notes

- This is a **named saved workflow** — it doesn't require "ultracode" or ultracode-mode to trigger; being asked for by name (via this skill) is itself sufficient opt-in per the Workflow tool's rules.
- If the user wants to tweak the pipeline logic itself (add a research angle, change review persona count, adjust the max revise rounds), edit `.claude/workflows/ai-engineer-note-pipeline.js`'s logic directly (not just `DEFAULT_ARGS`) — that's a repo file, not something this skill should regenerate.
- This procedure mirrors `AGENTS.md` §6 ("AI-Engineer roadmap note pipeline") — if the two ever drift, treat `AGENTS.md` as the source of truth and update this skill to match.
</content>
