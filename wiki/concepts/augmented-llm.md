---
status: current
updated: 2026-06
sources:
  - https://www.anthropic.com/engineering/building-effective-agents
---

# Augmented LLM

The foundational building block of all [[agentic-systems-taxonomy|agentic systems]]: an LLM enhanced with retrieval, tools, and memory. Current models can actively use these — generating search queries, selecting tools, deciding what to retain. (confidence: high)

Two implementation priorities:
1. **Tailor capabilities to the specific use case** — don't add generic augmentations; match the tools and retrieval to what the task actually needs.
2. **Provide an easy, well-documented interface** — the LLM consumes tool descriptions the same way a developer consumes API docs; quality matters (see [[agent-computer-interface]]).

Model Context Protocol (MCP) is one standardized approach: allows integration with a growing ecosystem of third-party tools via a simple client implementation. (as of 2024-12, anthropic.com) (confidence: high)

All five [[agentic-workflow-patterns]] and autonomous agents assume the augmented LLM as their base unit.
