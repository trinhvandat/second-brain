---
status: current
updated: 2026-06
sources:
  - https://www.techtimes.com/articles/318344/20260613/claude-code-adds--fork-command-anthropic-brings-git-style-branching-ai-coding-sessions.htm
  - https://shiqimei.github.io/posts/claude-code-fork-agent-subagents
  - https://www.buildthisnow.com/blog/guide/mechanics/claude-code-fork-subagent
---

# Claude Code /fork — session branching

The `/fork` command branches an existing Claude Code session into a parallel variant, preserving full context (files, instructions, conversation history). The original session stays untouched. Mental model: git branch for AI coding sessions. (confidence: high)

## Two levels of fork

1. **Interactive `/fork`** — user types `/fork` in a session to split off an exploratory branch. Also available as CLI flag `claude --continue --fork-session`.
2. **Skill-level `context: fork`** — a skill's YAML frontmatter declares `context: fork` to run in an isolated sub-agent. Only the final result returns to the parent; all intermediate tool calls stay in the sub-agent's context. Solves the context-pollution problem for expensive skills (see examples below).

## Fork + sub-agents: the session-management model

Sub-agents divide *one approach* into parallel sub-tasks (see [[agentic-workflow-patterns]] §4 orchestrator-workers). Fork creates *parallel approaches*. Together they model how engineering teams work: branch to explore alternatives, delegate sub-tasks, merge the best result. This is a key departure from the single linear chat of first-generation AI coding assistants. (confidence: high)

## Why it matters: bounding the cost of wrong turns

The core weakness of AI coding agents is trust erosion over long multi-step work — if the agent goes down a wrong path, salvaging a linear session is painful. Fork turns that risk into a cheap experiment: try the risky approach in a branch, discard if it fails. Combined with sub-agents running in parallel instead of sequence, developers can let the agent attempt more ambitious tasks because the downside is bounded. (confidence: high)

## Practical examples

### Example 1: A/B prompting strategies
You're midway through a refactor. Fork the session. In branch A, ask the agent to use a strategy pattern. In branch B, ask for a functional approach. Compare results, keep the better one — no need to re-establish context from scratch.

### Example 2: Risky migration exploration
Session has full context of a legacy codebase. Fork before attempting a database migration approach. If the fork's migration breaks tests, discard it and continue from the safe original session.

### Example 3: Skill context isolation (context: fork)
A skill that answers "How does auth work in this codebase?" would normally read 4-5 files (500+ lines) into main context. With `context: fork`, a sub-agent does all the exploration; main context sees only the synthesized answer (~50 tokens instead of ~500+ lines).

```yaml
# Skill frontmatter example
---
name: analyze-auth
description: Analyze authentication architecture
context: fork
agent: Explore
---
```

### Example 4: Parallel module analysis
An orchestrator dispatches 5 fork children to analyze 5 separate modules simultaneously. Children 2-5 share the parent's prompt cache prefix, cutting input token cost by ~90% per child (see cost math below).

## Cost optimization: CLAUDE_CODE_FORK_SUBAGENT=1

Environment variable that enables prompt-cache sharing between fork children. (confidence: high)

```bash
export CLAUDE_CODE_FORK_SUBAGENT=1
```

Cost math at ~48,500 token shared prefix:
- Without fork: ~48,700 tokens/child × 5 children = ~243,500 tokens
- With fork: ~48,700 (child 1, full price) + ~5,050 × 4 (children 2-5, cache hit) = ~68,900 tokens
- **Savings: ~72%** for 5 parallel agents

Fork only fires when `subagent_type` is omitted. Named types (`Explore`, `Plan`) have their own logic.

## Agent types for forked skills

| Agent | Capabilities | Use case |
|---|---|---|
| `general-purpose` | All tools, full reasoning | Complex multi-step tasks |
| `Explore` | Fast file search, pattern matching | Codebase exploration |
| `Plan` | Architecture analysis, step planning | Implementation planning |
| `Bash` | Command execution only | Shell-heavy operations |

## Guards and limits

- **Recursive fork guard**: two-layer check prevents children from forking their own children (XML tag injection + querySource check). (confidence: high)
- **Incompatible with `--print` mode** (no terminal for permission bubbling) and **coordinator mode** (forked coordinator would try to orchestrate instead of execute).
- **Context scales with session length**: long sessions with many children still cost more even with caching.
- **Opt-in only**: env var must be set explicitly.

## Adoption context

Claude Code is Anthropic's fastest-growing product. ~4% of all public GitHub commits worldwide attributed to Claude Code (as of mid-2026, per industry estimates). Session-management features like /fork and sub-agents are how Anthropic deepens developer adoption by making agentic coding more controllable. (confidence: medium — single industry estimate)

Related: [[agentic-systems-taxonomy]] for the broader workflows-vs-agents framing, [[agent-computer-interface]] for tool design principles that apply to forked sub-agents.
