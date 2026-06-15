---
status: current
updated: 2026-06
sources:
  - https://www.anthropic.com/engineering/building-effective-agents
---

# Agent-Computer Interface (ACI)

The interface between an LLM agent and its tools — analogous to HCI (Human-Computer Interface) but for models. Anthropic recommends investing as much effort in ACI design as one would in HCI. Core principle of [[agentic-systems-taxonomy]]. (confidence: high)

## Tool format guidelines

- Give the model enough tokens to "think" before it writes itself into a corner.
- Keep formats close to what the model has seen naturally in internet text (e.g., prefer markdown over JSON for code output — JSON requires escaping newlines/quotes).
- Avoid formatting overhead: don't require accurate line counts in diffs or string-escaping of generated code.

## ACI design best practices

1. **Empathize with the model**: if it's not obvious how to use a tool from its description and parameters, it's not obvious to the model either.
2. **Write tool definitions like great docstrings**: include example usage, edge cases, input format requirements, and clear boundaries from other tools.
3. **Name parameters clearly**: especially important when many similar tools exist. Think of it as writing docs for a junior developer.
4. **Test empirically**: run many example inputs, observe mistakes, iterate on tool definitions.
5. **Poka-yoke** (error-proof): change arguments so mistakes are harder to make.

## Case study: SWE-bench tool optimization

Anthropic spent more time optimizing tools than the overall prompt for their SWE-bench agent. Key finding: the model made mistakes with relative filepaths after moving out of the root directory. Fix: always require absolute filepaths → the model used this flawlessly. (as of 2024-12, anthropic.com) (confidence: high)

Tool definitions deserve just as much prompt engineering attention as the overall system prompt. This connects to [[augmented-llm]] — the quality of tool documentation directly impacts agent reliability.
