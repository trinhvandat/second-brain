---
status: current
updated: 2026-06
sources:
  - https://www.anthropic.com/engineering/building-effective-agents
---

# Agentic workflow patterns

Five composable workflow patterns for LLM-based systems, ordered by increasing complexity. All build on the [[augmented-llm]]. Part of the [[agentic-systems-taxonomy]]. (confidence: high)

## 1. Prompt chaining

Task decomposed into a fixed sequence of LLM calls; each processes the output of the previous. Programmatic "gates" can check intermediate results.

- **When**: task cleanly decomposes into fixed subtasks; trade latency for accuracy.
- **Example**: generate marketing copy → translate to another language.

## 2. Routing

Classify input → direct to a specialized downstream prompt/process. Separation of concerns; optimizing one path doesn't hurt others.

- **When**: distinct categories better handled separately; classification is accurate.
- **Example**: customer service queries → general / refund / tech-support paths. Also: route easy questions to cheaper models (Haiku), hard ones to stronger models (Sonnet).

## 3. Parallelization

Multiple LLM calls run simultaneously; outputs aggregated. Two sub-patterns:

- **Sectioning**: independent subtasks in parallel (e.g., one LLM handles query while another screens for inappropriate content).
- **Voting**: same task run N times for diverse outputs / higher confidence (e.g., multiple prompts review code for vulnerabilities).

- **When**: subtasks are independent; or need multiple perspectives for confidence.

## 4. Orchestrator-workers

Central LLM dynamically breaks down task → delegates to worker LLMs → synthesizes results. Unlike parallelization, subtasks are not pre-defined but determined at runtime by the orchestrator.

- **When**: can't predict subtasks in advance (e.g., coding: which files to change depends on the task).
- **Example**: coding products editing multiple files; multi-source search & analysis.
- **Real-world implementation**: Claude Code's sub-agent system uses this pattern — a primary session dynamically spawns worker agents per module/file. Combined with [[claude-code-fork]] for parallel *approaches* (not just parallel tasks), this becomes even more powerful.

## 5. Evaluator-optimizer

One LLM generates; another evaluates and provides feedback in a loop. Analogous to human iterative writing/editing.

- **When**: clear evaluation criteria exist; iterative refinement yields measurable improvement. Two fitness tests: (1) human feedback demonstrably improves responses, (2) LLM can provide that feedback.
- **Example**: literary translation with evaluator critiques; multi-round search refinement.

These patterns are composable — combine and customize to fit the use case. Always measure performance and iterate. (confidence: high)

When you compose these patterns into a larger multi-agent system, the organizing layer is [[graph-engineering]] — modeling each pattern as a node/edge topology (chaining→sequential, routing→conditional edges, parallelization→fan-out, orchestrator-workers→supervisor, evaluator-optimizer→feedback cycle), which is directly relevant to a Claude Code plugin/harness.
