---
source: https://www.anthropic.com/engineering/building-effective-agents
captured_at: 2026-06-15
status: raw
author: Erik S. and Barry Zhang (Anthropic)
published: 2024-12-19
---

# Building effective agents

We've worked with dozens of teams building LLM agents across industries. Consistently, the most successful implementations use simple, composable patterns rather than complex frameworks.

Over the past year, we've worked with dozens of teams building large language model (LLM) agents across industries. Consistently, the most successful implementations weren't using complex frameworks or specialized libraries. Instead, they were building with simple, composable patterns.

In this post, we share what we've learned from working with our customers and building agents ourselves, and give practical advice for developers on building effective agents.

## What are agents?

"Agent" can be defined in several ways. Some customers define agents as fully autonomous systems that operate independently over extended periods, using various tools to accomplish complex tasks. Others use the term to describe more prescriptive implementations that follow predefined workflows. At Anthropic, we categorize all these variations as **agentic systems**, but draw an important architectural distinction between **workflows** and **agents**:

- **Workflows** are systems where LLMs and tools are orchestrated through predefined code paths.
- **Agents**, on the other hand, are systems where LLMs dynamically direct their own processes and tool usage, maintaining control over how they accomplish tasks.

## When (and when not) to use agents

When building applications with LLMs, we recommend finding the simplest solution possible, and only increasing complexity when needed. This might mean not building agentic systems at all. Agentic systems often trade latency and cost for better task performance, and you should consider when this tradeoff makes sense.

When more complexity is warranted, workflows offer predictability and consistency for well-defined tasks, whereas agents are the better option when flexibility and model-driven decision-making are needed at scale. For many applications, however, optimizing single LLM calls with retrieval and in-context examples is usually enough.

## When and how to use frameworks

There are many frameworks that make agentic systems easier to implement, including:

- The Claude Agent SDK;
- Strands Agents SDK by AWS;
- Rivet, a drag and drop GUI LLM workflow builder; and
- Vellum, another GUI tool for building and testing complex workflows.

These frameworks make it easy to get started by simplifying standard low-level tasks like calling LLMs, defining and parsing tools, and chaining calls together. However, they often create extra layers of abstraction that can obscure the underlying prompts and responses, making them harder to debug. They can also make it tempting to add complexity when a simpler setup would suffice.

We suggest that developers start by using LLM APIs directly: many patterns can be implemented in a few lines of code. If you do use a framework, ensure you understand the underlying code. Incorrect assumptions about what's under the hood are a common source of customer error.

## Building blocks, workflows, and agents

### Building block: The augmented LLM

The basic building block of agentic systems is an LLM enhanced with augmentations such as retrieval, tools, and memory. Our current models can actively use these capabilities—generating their own search queries, selecting appropriate tools, and determining what information to retain.

We recommend focusing on two key aspects of the implementation: tailoring these capabilities to your specific use case and ensuring they provide an easy, well-documented interface for your LLM. While there are many ways to implement these augmentations, one approach is through our recently released Model Context Protocol, which allows developers to integrate with a growing ecosystem of third-party tools with a simple client implementation.

### Workflow: Prompt chaining

Prompt chaining decomposes a task into a sequence of steps, where each LLM call processes the output of the previous one. You can add programmatic checks (see "gate" in the diagram) on any intermediate steps to ensure that the process is still on track.

**When to use:** Ideal for situations where the task can be easily and cleanly decomposed into fixed subtasks. The main goal is to trade off latency for higher accuracy, by making each LLM call an easier task.

**Examples:**
- Generating marketing copy, then translating it into a different language.
- Writing an outline of a document, checking that the outline meets certain criteria, then writing the document based on the outline.

### Workflow: Routing

Routing classifies an input and directs it to a specialized followup task. This workflow allows for separation of concerns, and building more specialized prompts. Without this workflow, optimizing for one kind of input can hurt performance on other inputs.

**When to use:** Works well for complex tasks where there are distinct categories that are better handled separately, and where classification can be handled accurately.

**Examples:**
- Directing different types of customer service queries (general questions, refund requests, technical support) into different downstream processes.
- Routing easy/common questions to smaller models like Claude Haiku and hard/unusual questions to more capable models like Claude Sonnet.

### Workflow: Parallelization

LLMs can sometimes work simultaneously on a task and have their outputs aggregated programmatically. Two key variations:

- **Sectioning**: Breaking a task into independent subtasks run in parallel.
- **Voting:** Running the same task multiple times to get diverse outputs.

**When to use:** Effective when divided subtasks can be parallelized for speed, or when multiple perspectives or attempts are needed for higher confidence results.

**Examples:**
- Sectioning: Implementing guardrails where one model processes user queries while another screens for inappropriate content.
- Sectioning: Automating evals where each LLM call evaluates a different aspect.
- Voting: Reviewing code for vulnerabilities with several different prompts.
- Voting: Evaluating content appropriateness with multiple prompts and vote thresholds.

### Workflow: Orchestrator-workers

A central LLM dynamically breaks down tasks, delegates them to worker LLMs, and synthesizes their results.

**When to use:** Well-suited for complex tasks where you can't predict the subtasks needed. Key difference from parallelization is its flexibility—subtasks aren't pre-defined, but determined by the orchestrator based on the specific input.

**Examples:**
- Coding products that make complex changes to multiple files each time.
- Search tasks that involve gathering and analyzing information from multiple sources.

### Workflow: Evaluator-optimizer

One LLM call generates a response while another provides evaluation and feedback in a loop.

**When to use:** Particularly effective when we have clear evaluation criteria, and when iterative refinement provides measurable value. Two signs of good fit: (1) LLM responses can be demonstrably improved when a human articulates feedback, and (2) the LLM can provide such feedback.

**Examples:**
- Literary translation where an evaluator LLM provides useful critiques.
- Complex search tasks requiring multiple rounds of searching and analysis.

### Agents

Agents begin with either a command from, or interactive discussion with, the human user. Once the task is clear, agents plan and operate independently, potentially returning to the human for further information or judgement. During execution, it's crucial for agents to gain "ground truth" from the environment at each step (such as tool call results or code execution) to assess progress. Agents can pause for human feedback at checkpoints or when encountering blockers.

Agents can handle sophisticated tasks, but their implementation is often straightforward. They are typically just LLMs using tools based on environmental feedback in a loop. It is therefore crucial to design toolsets and their documentation clearly and thoughtfully.

**When to use:** For open-ended problems where it's difficult or impossible to predict the required number of steps, and where you can't hardcode a fixed path. The LLM will potentially operate for many turns, and you must have some level of trust in its decision-making.

**Examples:**
- A coding agent to resolve SWE-bench tasks, involving edits to many files based on a task description.
- "Computer use" reference implementation, where Claude uses a computer to accomplish tasks.

## Combining and customizing these patterns

These building blocks aren't prescriptive. They're common patterns that developers can shape and combine to fit different use cases. The key to success is measuring performance and iterating on implementations. Add complexity only when it demonstrably improves outcomes.

## Summary: Three core principles

1. Maintain **simplicity** in your agent's design.
2. Prioritize **transparency** by explicitly showing the agent's planning steps.
3. Carefully craft your agent-computer interface (ACI) through thorough tool **documentation and testing**.

## Appendix 1: Agents in practice

### A. Customer support
- Support interactions naturally follow a conversation flow while requiring access to external information and actions.
- Tools can pull customer data, order history, and knowledge base articles.
- Actions such as issuing refunds or updating tickets can be handled programmatically.
- Success can be clearly measured through user-defined resolutions.

### B. Coding agents
- Code solutions are verifiable through automated tests.
- Agents can iterate on solutions using test results as feedback.
- The problem space is well-defined and structured.
- Output quality can be measured objectively.

## Appendix 2: Prompt engineering your tools

Tool definitions and specifications should be given just as much prompt engineering attention as your overall prompts.

Suggestions for tool formats:
- Give the model enough tokens to "think" before it writes itself into a corner.
- Keep the format close to what the model has seen naturally occurring in text on the internet.
- Make sure there's no formatting "overhead" such as having to keep an accurate count of thousands of lines of code, or string-escaping any code it writes.

ACI (Agent-Computer Interface) best practices:
- Put yourself in the model's shoes. Is it obvious how to use this tool based on the description and parameters?
- A good tool definition often includes example usage, edge cases, input format requirements, and clear boundaries from other tools.
- How can you change parameter names or descriptions to make things more obvious? Think of this as writing a great docstring for a junior developer.
- Test how the model uses your tools: Run many example inputs to see what mistakes the model makes, and iterate.
- Poka-yoke your tools. Change the arguments so that it is harder to make mistakes.

Example: For SWE-bench, the team spent more time optimizing tools than the overall prompt. The model made mistakes with relative filepaths after moving out of root directory; changing to always require absolute filepaths fixed it.
