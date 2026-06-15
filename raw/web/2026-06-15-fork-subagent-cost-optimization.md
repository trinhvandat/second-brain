---
source: https://www.buildthisnow.com/blog/guide/mechanics/claude-code-fork-subagent
captured_at: 2026-06-15
status: raw
author: Build This Now
published: 2026-04-22
---

# Fork Subagents in Claude Code — Cost Optimization

CLAUDE_CODE_FORK_SUBAGENT=1 lets parallel child agents share their parent's prompt cache prefix, cutting input token costs by up to 90% for children 2-N.

## How It Works

A fork child gets the exact bytes of its parent's already-rendered system prompt via override.systemPrompt. Same bytes, not a new render. Tool array passes through with useExactTools: true, bypassing resolveAgentTools() entirely. Serialization stays byte-identical, making prompt cache work.

Every parent tool-use block in child's message history gets a FORK_PLACEHOLDER_RESULT. Cache boundary falls right before per-child directive, so children diverge only at their specific instruction.

## Cost Math

At 48,500 tokens shared prefix:
- Without fork: ~48,700 tokens per child
- With fork (children 2-N): ~5,050 tokens per child

Five parallel agents: without fork ~243,500 tokens; with fork ~48,700 + ~20,200 = ~68,900 tokens.

## Enable

export CLAUDE_CODE_FORK_SUBAGENT=1

Fork only fires when subagent_type is omitted. Named types (Explore, Plan) have their own logic.

## Recursive Fork Guard

Two guards prevent infinite recursion: (1) querySource === 'agent:builtin:fork' fast-path check, (2) fallback message-history scan for boilerplate XML tag. Both must agree before guard fires.

Fork is incompatible with coordinator mode and --print mode.

## Limits

- Incompatible with --print mode (no terminal for permission bubbling)
- Incompatible with coordinator mode
- Context window scales with session length — long sessions with many children cost more
- Opt-in only via env var
