---
status: current
updated: 2026-08
sources: []
---

# AI Engineer Roadmap (hub)

Hub note for a self-paced learning series, tracking **[roadmap.sh/ai-agents](https://roadmap.sh/ai-agents)** as of 2026-08. Categories/topics below are a loose skeleton mirroring that roadmap's structure, freely renamed/reordered/added-to as learning progresses. This file is the single index; individual lesson notes live under `wiki/tech/ai-engineer/`.

**Why this track over the broader [roadmap.sh/ai-engineer](https://roadmap.sh/ai-engineer):** that one is a generalist "build AI products" track (pretrained models, OpenAI Platform specifics, multimodal AI...) — AI Agents goes deep specifically on agent loops, tool use/MCP, memory, architectures (ReAct/CoT/Planner-Executor/DAG/ToT), and evaluation, which is the more directly applicable track given existing work with multi-agent orchestration (see [[graph-engineering]], [[agentic-systems-taxonomy]]). Its own prerequisite layer (LLM Fundamentals + Embeddings/Vector Search) is already mostly covered by notes below.

## Convention (read before adding a note)
- **Location:** one atomic note per topic in `wiki/tech/ai-engineer/<category>/<category>-<slug>.md` — files live inside a per-category subfolder so the Quartz sidebar Explorer groups/collapses them by category instead of listing everything flat and alphabetized. `<category>-<slug>.md` filenames also keep the prefix (redundant with the folder, but keeps `grep`/wikilinks unambiguous and survives a future flatten if ever needed).
- **Naming:** no numeric prefixes (renumbering on insert is annoying — the folder does the grouping now, the prefix inside the filename is just for grep-ability).
- **Categories so far** (folder name = prefix, minus trailing `-`): `llm/` (LLM fundamentals — prerequisite layer: architecture, tokenization, generation controls, model families; also holds `vector-search.md`, which predates the prefix convention), `prompt/` (prompt engineering), `agent/` (AI Agents 101, tools/MCP, memory, architectures, building — the core of this track), `rag/` (retrieval/RAG deep-dive, also used as an agent architecture pattern — the RAG *primer* lives under `llm/` per the table below), `eval/` (evaluation & testing for agents), `sec/` (agent security & ethics — prompt injection, tool sandboxing, red-teaming), `infra/` (serving/deployment/observability/MLOps), `finetune/` (fine-tuning/training — deprioritized by this track, kept for later). Add new category folders as needed — update this list when you do, and `mkdir` the folder before adding the first note in it.
- **Frontmatter:** standard vault frontmatter (`status`, `updated`, `sources` — see `AGENTS.md` §5) plus two series-specific fields:
  ```yaml
  roadmap: ai-engineer
  stage: planned | learning | done
  ```
  `roadmap: ai-engineer` lets any note be found via grep regardless of folder; `stage` tracks progress without overloading the lifecycle `status` field.
- **Capture while learning:** quick raw notes go to `raw/inbox/YYYY-MM-DD-HHMM-<slug>.md` as usual (per `AGENTS.md` §1). When asked to "compile"/"process inbox" for an AI-engineer topic, promote into `wiki/tech/ai-engineer/<category>-<slug>.md` with the frontmatter above, link it from the table below, and flip its `stage`.
- **Normalize pass:** periodically (or on request) re-scan `wiki/tech/ai-engineer/*.md`, dedupe overlapping topics, fix wikilinks, and sync this table's stage/links against each note's actual `stage` frontmatter — this table should never drift far from ground truth in the notes themselves.

## Topics

### LLM Fundamentals — prerequisite layer (`llm-`)
| Topic | Stage | Note |
|---|---|---|
| What is an LLM (architecture overview, training pipeline, scaling laws, limitations) | learning | [[llm-large-language-model]] |
| Embeddings & vector search (vectors, similarity, ANN search, vector DB) | learning | [[llm-embedding]] |
| Tokenization | learning | [[llm-tokenization]] |
| Context windows & token-based pricing | learning | [[llm-context-window]], [[llm-token-pricing]] |
| Generation controls (temperature, top-p, frequency/presence penalty, stopping criteria, max length) | learning | [[llm-temperature]], [[llm-top-p]], [[llm-frequency-penalty]], [[llm-presence-penalty]], [[llm-stopping-criteria]], [[llm-max-length]] |
| Open-weight vs closed-weight models, model families & licenses | learning | [[llm-open-weight-models]], [[llm-closed-weight-models]] |
| Streamed vs unstreamed responses (TTFT, SSE/WebSocket, decoding strategies) | learning | [[llm-streamed-vs-unstreamed-responses]] |
| Reasoning vs standard models | learning | [[llm-reasoning-vs-standard-models]] |
| Fine-tuning vs prompt engineering (when to use which) | planned | — |
| Basics of RAG (primer — deep dive under `rag-`) | learning | [[llm-rag-basics]] |
| Artificial General Intelligence (definitions, approaches, safety) — background, not on critical path | learning | [[llm-artificial-general-intelligence]] |

### Prompt Engineering (`prompt-`)
| Topic | Stage | Note |
|---|---|---|
| Writing good prompts (specificity, context, examples, iteration, format constraints) | planned | — |
| Structured output / function calling | planned | — |

### AI Agents 101 (`agent-`)
| Topic | Stage | Note |
|---|---|---|
| What are AI agents? (vs plain LLM calls / vs RAG) | learning | [[agent-what-are-ai-agents]] |
| What are tools? | planned | — |
| The agent loop — perceive → reason/plan → act/invoke tool → observe/reflect | learning | [[agent-loop]] |
| Perception / user input — step 1 of the agent loop | learning | [[agent-perception-user-input]] |
| Reason and Plan — step 2 of the agent loop | learning | [[agent-reason-plan]] |
| Example use cases (personal assistant, code gen, data analysis, web scraping, NPC/game AI) | planned | — |

### Tools & MCP (`agent-`)
| Topic | Stage | Note |
|---|---|---|
| Tool definition (name/description, input-output schema, error handling, usage examples) | planned | — |
| Examples of tools (web search, code exec/REPL, DB queries, API requests, file system) | planned | — |
| Model Context Protocol (MCP) — hosts, clients, servers | planned | — |
| Creating MCP servers, deployment modes (local desktop vs remote/cloud) | planned | — |

### Agent Memory (`agent-`)
| Topic | Stage | Note |
|---|---|---|
| What is agent memory — short-term (within prompt) vs long-term (vector DB/SQL/custom) | planned | — |
| Episodic vs semantic memory | planned | — |
| Maintaining memory: RAG+vector DB, user profile storage, summarization/compression, forgetting/aging strategies | planned | — |

### Agent Architectures (`agent-`)
| Topic | Stage | Note |
|---|---|---|
| ReAct (Reason + Act) | planned | — |
| Chain of Thought (CoT) | planned | — |
| RAG Agent | planned | — |
| Planner–Executor | planned | — |
| DAG agents | planned | — |
| Tree-of-Thought | planned | — |
| Multi-agent orchestration patterns | planned | — see also [[graph-engineering]], [[agentic-systems-taxonomy]] |

### Building Agents (`agent-`)
| Topic | Stage | Note |
|---|---|---|
| Manual from scratch (direct LLM API calls, implementing the agent loop, parsing output, error/rate-limit handling) | planned | — |
| LLM-native function calling (OpenAI Functions, Gemini Function Calling, Anthropic Tool Use, Assistant API) | planned | — |
| Building with frameworks (LangChain, LlamaIndex, Haystack, AutoGen, CrewAI) | planned | — |

### RAG (`rag-`)
| Topic | Stage | Note |
|---|---|---|
| Chunking strategies | planned | — |
| Vector search / embeddings retrieval | planned | — |
| Hybrid search & reranking | planned | — |
| RAG vs fine-tuning (when each wins) | planned | — |

### Evaluation & Testing (`eval-`)
| Topic | Stage | Note |
|---|---|---|
| Metrics to track for agents | planned | — |
| Unit testing individual tools / integration testing flows | planned | — |
| Human-in-the-loop evaluation | planned | — |
| Eval frameworks (LangSmith, Ragas, DeepEval) | planned | — |

### Security & Ethics (`sec-`)
| Topic | Stage | Note |
|---|---|---|
| Prompt injection / jailbreaks | planned | — |
| Tool sandboxing / permissioning | planned | — |
| Data privacy & PII redaction | planned | — |
| Bias & toxicity guardrails | planned | — |
| Safety & red-team testing | planned | — |

### Infra, Observability & Deployment (`infra-`)
| Topic | Stage | Note |
|---|---|---|
| Structured logging & tracing | planned | — |
| Observability tools (LangSmith, Helicone, LangFuse, OpenLLMetry) | planned | — |
| Model serving (vLLM, TGI, etc.) | planned | — |
| Cost/latency tradeoffs | planned | — |

### Fine-tuning (`finetune-`) — deprioritized by this track
| Topic | Stage | Note |
|---|---|---|
| SFT vs RLHF vs DPO | planned | — |
| LoRA / PEFT | planned | — |

## Related
- [[graph-engineering]] — deep dive on multi-agent orchestration patterns, overlaps with Agent Architectures.
- [[agentic-systems-taxonomy]] — taxonomy note, overlaps with AI Agents 101 / Agent Architectures — still stub, promote when filled in.
- [[agentic-ai-course-setup]] — course/tooling setup note, precedes this roadmap.
