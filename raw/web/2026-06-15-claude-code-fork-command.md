---
source: https://www.techtimes.com/articles/318344/20260613/claude-code-adds--fork-command-anthropic-brings-git-style-branching-ai-coding-sessions.htm
captured_at: 2026-06-15
status: raw
author: Jerry Owens (Tech Times)
published: 2026-06-13
---

# Claude Code Adds a '/fork' Command: Anthropic Brings Git-Style Branching to AI Coding Sessions

Anthropic has given its coding tool a feature that sounds small and changes the workflow more than its size suggests. The "/fork" command and a new command-line interface for Claude Code lets developers branch an existing session into parallel variants to test alternative approaches without losing the original state.

## What '/fork' actually does

The "/fork" command lets a developer branch an existing Claude Code session into a parallel variant. You can take a session where the model already has the full context of your problem, your files, your earlier instructions, and split off a copy to try a different approach without destroying the original. If the new direction works, you keep it; if it does not, the original session is untouched.

The pattern is borrowed directly from version control. By matching a workflow developers already trust, Anthropic lowers the learning curve and makes experimentation cheap.

## How it fits with nested sub-agents

Claude Code's nested sub-agents let a primary session spawn coordinated sub-agents that work on parts of a task in parallel. Where sub-agents divide one approach into parallel work, forking creates parallel approaches. Together they give Claude Code a session-management model that resembles how engineering teams actually operate: branch to explore alternatives, delegate sub-tasks, then merge the best result.

## Why this is a developer-adoption story

Claude Code has become Anthropic's growth engine, and the adoption is bottom-up. One analysis estimated that around 4 percent of all public commits on GitHub worldwide were being authored by Claude Code. Session-management features like forking and sub-agents deepen that foothold by making agentic coding more controllable.

These features attack the core weakness of AI coding agents: trust over long, multi-step work. Forking turns risk into a cheap experiment — branch, try the risky approach, and discard the branch if it fails. Sub-agents let work proceed in parallel instead of one fragile sequence. The result: a developer can let the agent attempt more ambitious tasks because the cost of a wrong turn is bounded.
