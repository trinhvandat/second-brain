---
source: https://shiqimei.github.io/posts/claude-code-fork-agent-subagents
captured_at: 2026-06-15
status: raw
author: Shiqi Mei
published: 2026-01-11
---

# Claude Code's Fork and Agent Arguments: Running Skills in Sub-Agents

Claude Code addresses the context pollution problem with two skill arguments: `context: fork` and `agent: <type>`.

## The Problem

When a skill runs, all intermediate work (Read calls, Grep results, Bash output, reasoning) happens in main conversation context. A skill exploring a codebase might make 20+ tool calls, burning context that could be used for actual work.

## The Solution: context: fork

Runs a skill in an isolated sub-agent:
1. Claude spawns a sub-agent with fresh context
2. Sub-agent receives only skill instructions and user query
3. Sub-agent executes independently
4. Only the final result returns to main conversation

## Agent Types

- `general-purpose`: All tools, full reasoning — complex multi-step tasks
- `Explore`: Fast file search, pattern matching — codebase exploration
- `Plan`: Architecture analysis, step planning — implementation planning
- `Bash`: Command execution only — shell-heavy operations

## When to Use Fork

Use when skill: reads multiple files to synthesize, performs exploratory searches, requires multi-step reasoning, could consume significant context inline.

Don't use when: skill is simple, you need intermediate results in main conversation, spawning overhead exceeds context savings.

## Complete Efficiency Stack

1. Progressive disclosure: only frontmatter loads at startup (~20 tokens/skill)
2. On-demand loading: full content loads only when triggered
3. Script execution: deterministic ops run outside context
4. Context fork: LLM-driven ops run in isolated sub-agents
