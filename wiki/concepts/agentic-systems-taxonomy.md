---
status: current
updated: 2026-06
sources:
  - https://www.anthropic.com/engineering/building-effective-agents
---

# Agentic systems taxonomy

Anthropic distinguishes two architectural categories within agentic systems (confidence: high):

- **Workflows**: LLMs and tools orchestrated through predefined code paths. Predictable, consistent, suited for well-defined tasks.
- **Agents**: LLMs dynamically direct their own processes and tool usage. Flexible, suited for open-ended problems where the number of steps is unpredictable.

Core design principle: always start with the simplest solution possible. For many applications, optimizing a single LLM call with retrieval and in-context examples is enough — no agentic system needed. Add complexity only when it demonstrably improves outcomes. (as of 2024-12, anthropic.com) (confidence: high)

The tradeoff: agentic systems trade latency and cost for better task performance. Workflows trade latency for accuracy. Agents trade cost (many LLM calls) and error-compounding risk for autonomy and flexibility.

Three core principles for agent design:
1. **Simplicity** — keep the design minimal.
2. **Transparency** — explicitly show planning steps.
3. **ACI quality** — invest heavily in tool documentation and testing (see [[agent-computer-interface]]).

The foundational building block for all agentic systems is the [[augmented-llm]].

Five workflow patterns exist at increasing complexity: prompt chaining, routing, parallelization, orchestrator-workers, evaluator-optimizer — see [[agentic-workflow-patterns]].

Frameworks (Claude Agent SDK, Strands Agents SDK, Rivet, Vellum) simplify getting started but add abstraction layers that obscure prompts/responses and make debugging harder. Recommendation: start with raw LLM APIs; if using a framework, understand the underlying code. (confidence: high)
