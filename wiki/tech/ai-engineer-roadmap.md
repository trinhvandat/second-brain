---
status: current
updated: 2026-08
sources: ["https://roadmap.sh/ai-agents"]
---

# AI Engineer Roadmap (hub)

Hub note for a self-paced learning series, tracking **[roadmap.sh/ai-agents](https://roadmap.sh/ai-agents)** as of 2026-08-17. The table below mirrors the *actual* node tree of that roadmap (pulled from its source content, one row per roadmap node, in roadmap order) — not a loose paraphrase. Individual lesson notes live under `wiki/tech/ai-engineer/`; most nodes are still `planned` (no atomic note yet) — the inline "Note cơ bản" (short definition) + "Reference" link in each row is meant to stand in until a full note is written.

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
- **Table columns:** `Topic` (title — one-line definition, straight from the roadmap.sh source content), `Stage` (`planned` / `learning` / `done`), `Note` (wikilink to the atomic note if one exists, else `—`), `Reference` (one primary external link roadmap.sh points to for that node — pull more when writing the full note).

## Topics
117 leaf nodes across 16 sections, mirroring roadmap.sh/ai-agents' actual tree (verified against its source content repo on 2026-08-17). 29 have atomic notes so far; the rest carry an inline definition + reference link until promoted.

### Prerequisites — before you start
| Topic | Stage | Note | Reference |
|---|---|---|---|
| Basic Backend Development — before you start learning how to build AI agents, have basic knowledge of backend dev: a programming language, working with a database, and API basics. | planned | — | [Introduction to the server-side](https://developer.mozilla.org/en-US/docs/Learn/Server-side/First_steps/Introduction) |
| Git and Terminal Usage — Git and the terminal are key tools for AI agents and developers, used for version control and running commands. | planned | — | [Git Basics](https://git-scm.com/doc) |
| REST API Knowledge — REST (Representational State Transfer) is an architectural style for designing networked applications, the most common way agents call external services. | planned | — | [What is RESTful API? - AWS](https://aws.amazon.com/what-is/restful-api/) |

### LLM Fundamentals — prerequisite layer (`llm-`)
| Topic | Stage | Note | Reference |
|---|---|---|---|
| What is an LLM / Transformer Models — a neural network architecture that reads input all at once (attention) instead of one piece at a time, the basis of modern LLMs. | done | [[llm-large-language-model]] | [Exploring Open Source AI Models: LLMs and Transformer Architectures](https://llmmodels.org/blog/exploring-open-source-ai-models-llms-and-transformer-architectures/) |
| Embeddings & Vector Search — embeddings turn words/images/data into vectors that preserve meaning; similar items end up close together, enabling semantic search. | done | [[llm-embedding]] | [OpenAI Embeddings API Documentation](https://platform.openai.com/docs/guides/embeddings/what-are-embeddings) |
| Tokenization — the step where raw text is broken into small pieces (tokens), each given a unique number the model operates on. | done | [[llm-tokenization]] | [Explaining Tokens — the Language and Currency of AI](https://blogs.nvidia.com/blog/ai-tokens-explained/) |
| Context Windows — the chunk of text (in tokens) a model can read/attend to at one time. | done | [[llm-context-window]] | [What is a Context Window in AI? - IBM](https://www.ibm.com/think/topics/context-window) |
| Token Based Pricing & Pricing of Common Models — most LLM providers charge per token read/written; a token is roughly 4 characters of text. | done | [[llm-token-pricing]] | [OpenAI Pricing](https://openai.com/api/pricing/) |
| Generation Controls — Temperature (randomness of output) | done | [[llm-temperature]] | [What Temperature Means in NLP and AI](https://thenewstack.io/what-temperature-means-in-natural-language-processing-and-ai/) |
| Generation Controls — Top-p / nucleus sampling (probability-mass cutoff for next-token choice) | done | [[llm-top-p]] | [Nucleus Sampling](https://nn.labml.ai/sampling/nucleus.html) |
| Generation Controls — Frequency Penalty (discourages repeating the same tokens) | done | [[llm-frequency-penalty]] | [Understanding Frequency Penalty and Presence Penalty](https://medium.com/@the_tori_report/understanding-frequency-penalty-and-presence-penalty-how-to-fine-tune-ai-generated-text-e5e4f5e779cd) |
| Generation Controls — Presence Penalty (discourages reusing any token already seen, regardless of count) | done | [[llm-presence-penalty]] | [Understanding Presence Penalty and Frequency Penalty](https://medium.com/@pushparajgenai2025/understanding-presence-penalty-and-frequency-penalty-in-openai-chat-completion-api-calls-2e3a22547b48) |
| Generation Controls — Stopping Criteria (rules for when the model halts generation) | done | [[llm-stopping-criteria]] | [Defining Stopping Criteria in Large Language Models](https://www.metriccoders.com/post/defining-stopping-criteria-in-large-language-models-a-practical-guide) |
| Generation Controls — Max Length (hard cap on tokens generated per reply) | done | [[llm-max-length]] | [Utilising Max Token Context Window of Anthropic Claude](https://medium.com/@nampreetsingh/utilising-max-token-context-window-of-anthropic-claude-on-amazon-bedrock-7377d94b2dfa) |
| Open Weight Models — models whose trained parameters are published and can be downloaded/run/fine-tuned by anyone. | done | [[llm-open-weight-models]] | [BLOOM BigScience](https://bigscience.huggingface.co/) |
| Closed Weight Models — models whose trained parameters are kept private, accessed only via a hosted API. | done | [[llm-closed-weight-models]] | [OpenAI's GPT-4](https://openai.com/gpt-4) |
| Streamed vs Unstreamed Responses — streaming sends tokens to the client as they're generated (lower perceived latency); unstreamed waits for the full response. | done | [[llm-streamed-vs-unstreamed-responses]] | [Streaming Responses in AI](https://dev.to/pranshu_kabra_fe98a73547a/streaming-responses-in-ai-how-ai-outputs-are-generated-in-real-time-18kb) |
| Reasoning vs Standard Models — reasoning models break a task into explicit steps before answering; standard models answer in one pass. | done | [[llm-reasoning-vs-standard-models]] | [ReAct: Synergizing Reasoning and Acting in Language Models](https://react-lm.github.io/) |
| Fine-tuning vs Prompt Engineering — two ways to steer model output: prompt engineering shapes the input, fine-tuning retrains weights on examples. | done | [[llm-fine-tuning]] | [OpenAI Fine Tuning](https://platform.openai.com/docs/guides/fine-tuning) |
| Basics of RAG (primer — deep dive under `rag-`) — Retrieval-Augmented Generation: let the model look up relevant facts before replying, instead of relying only on trained-in knowledge. | done | [[llm-rag-basics]] | [What Is RAG in AI and How to Use It?](https://www.v7labs.com/blog/what-is-rag) |
| Artificial General Intelligence (definitions, approaches, safety) — background, not on critical path | done | [[llm-artificial-general-intelligence]] | — |

### AI Agents 101 (`agent-`)
| Topic | Stage | Note | Reference |
|---|---|---|---|
| What are AI Agents? — a program/system that senses its environment, decides what the data means, picks an action toward a goal, then observes results and learns for next time. | done | [[agent-what-are-ai-agents]] | [What are AI Agents? - AWS](https://aws.amazon.com/what-is/ai-agents/) |
| What are Tools? — extra skills/resources (functions, APIs, DBs) an agent can call on to complete a task it can't do from language alone. | done | [[agent-what-are-tools]] | [Compare 50+ AI Agent Tools in 2025 - AIMultiple](https://research.aimultiple.com/ai-agent-tools/) |

### Agent Loop (`agent-`)
| Topic | Stage | Note | Reference |
|---|---|---|---|
| The agent loop — perceive → reason/plan → act/invoke tool → observe/reflect (overview) | done | [[agent-loop]] | [What is an Agent Loop? - HF Agents Course](https://huggingface.co/learn/agents-course/en/unit1/agent-steps-and-structure) |
| 1. Perception / User Input — the first step: the agent gathers data from the outside world (user text, sensors, API responses). | done | [[agent-perception-user-input]] | [Perception in AI: Understanding Its Types and Importance](https://marktalks.com/perception-in-ai-understanding-its-types-and-importance/) |
| 2. Reason and Plan — the agent thinks before it acts: interprets the goal, breaks it into steps, decides what to do next. | done | [[agent-reason-plan]] | [ReAct: Synergizing Reasoning and Acting in Language Models](https://react-lm.github.io/) |
| 3. Acting / Tool Invocation — the agent chooses a tool and runs it to fetch real-world data or change something. | done | [[agent-acting-tool-invocation]] | [What are Tools in AI Agents? - HF Agents Course](https://huggingface.co/learn/agents-course/en/unit1/tools) |
| 4. Observation & Reflection — the agent reviews the tool's output, checks progress toward the goal, and decides whether to loop again or stop. | done | [[agent-observation-reflection]] | [Best Practices for Prompting and Self-checking - OpenAI](https://platform.openai.com/docs/guides/prompt-engineering) |

### Example Use Cases (`agent-`)
| Topic | Stage | Note | Reference |
|---|---|---|---|
| Personal assistant — an agent that helps one person manage daily tasks (scheduling, reminders, email triage). | planned | — | [A Complete Guide on AI-powered Personal Assistants](https://medium.com/@alexander_clifford/a-complete-guide-on-ai-powered-personal-assistants-with-examples-2f5cd894d566) |
| Code generation — agents that take a plain-language request and write or edit source code to meet it. | planned | — | [GitHub Copilot](https://github.com/features/copilot) |
| Data Analysis — agents that pull data from files/DBs/streams and summarize or chart it automatically. | planned | — | [How AI Will Transform Data Analysis in 2025](https://www.devfi.com/ai-transform-data-analysis-2025/) |
| Web Scraping / Crawling — agents that collect data from many web pages without human help. | planned | — | [Crawl AI](https://www.crawlai.org/) |
| NPC / Game AI — agents used by game studios to control non-player character behavior. | planned | — | [Unreal Engine — AI for NPCs](https://dev.epicgames.com/documentation/en-us/unreal-engine/artificial-intelligence-in-unreal-engine?application_version=5.3) |

### Prompt Engineering (`prompt-`)
| Topic | Stage | Note | Reference |
|---|---|---|---|
| What is Prompt Engineering — the skill of writing clear instructions/questions so an AI system gives the answer you want (roadmap.sh has a dedicated prompt-engineering track). | done | [[prompt-engineering]] | [Dedicated Prompt Engineering Roadmap](https://roadmap.sh/prompt-engineering) |
| Writing Good Prompts — be specific in what you want | done | [[prompt-writing-good-prompts-be-specific]] | [Prompt Engineering Guide](https://www.promptingguide.ai/) |
| Writing Good Prompts — provide additional context (background facts, constraints, goals) | done | [[prompt-writing-good-prompts-provide-context]] | [What is Context in Prompt Engineering?](https://www.godofprompt.ai/blog/what-is-context-in-prompt-engineering) |
| Writing Good Prompts — use relevant technical terms for domain tasks | learning | [[prompt-writing-good-prompts-use-technical-terms]] | [AI Terms Glossary](https://www.moveworks.com/us/en/resources/ai-terms-glossary) |
| Writing Good Prompts — use examples in your prompt (few-shot) | done | [[prompt-writing-good-prompts-use-examples]] | [10 Real-World AI Agent Examples in 2025](https://www.chatbase.co/blog/ai-agent-examples) |
| Writing Good Prompts — iterate and test your prompts (treat v1 as a draft) | learning | [[prompt-writing-good-prompts-iterate-test]] | [Prompt Engineering Best Practices - DeepLearning.AI](https://www.deeplearning.ai/short-courses/chatgpt-prompt-engineering-for-developers/) |
| Writing Good Prompts — specify length, format, etc | learning | [[prompt-writing-good-prompts-specify-format]] | [Mastering Prompt Engineering: Format, Length, and Audience](https://techlasi.com/savvy/mastering-prompt-engineering-format-length-and-audience-examples-for-2024/) |
| Tree-of-Thought — organizes an agent's reasoning as a branching tree of intermediate thoughts, exploring multiple paths before committing. | done | [[prompt-engineering]] (see "Tree of Thoughts (ToT)") | [Tree of Thoughts (ToT) - Prompt Engineering Guide](https://www.promptingguide.ai/techniques/tot) |
| Chain of Thought (CoT) — prompting technique where the model "thinks out loud" through intermediate reasoning steps before the final answer. | done | [[prompt-engineering]] (see "Chain-of-Thought (CoT) prompting") | [Chain-of-Thought Prompting Elicits Reasoning in LLMs](https://arxiv.org/abs/2201.11903) |

### Tools / Actions (`agent-`)
| Topic | Stage | Note | Reference |
|---|---|---|---|
| Tool Definition — any skill/function an agent can call: has a name, description, and a clear input/output schema. | learning | [[agent-tool-definition]] | [What are Tools? - HF Agents Course](https://huggingface.co/learn/agents-course/en/unit1/tools) |
| Examples of Tools — Web Search | learning | [[agent-tools-web-search]] | [8 Best AI Search Engines for 2025](https://usefulai.com/tools/ai-search-engines) |
| Examples of Tools — Code Execution / REPL | learning | [[agent-tools-code-execution]] | [What is a REPL? - Replit](https://docs.replit.com/getting-started/intro-replit) |
| Examples of Tools — Database Queries | learning | [[agent-tools-database-queries]] | [Building Your Own Database Agent - DeepLearning.AI](https://www.deeplearning.ai/short-courses/building-your-own-database-agent/) |
| Examples of Tools — API Requests | learning | [[agent-tools-api-requests]] | [Introduction to APIs - MDN](https://developer.mozilla.org/en-US/docs/Learn_web_development/Extensions/Client-side_APIs/Introduction) |
| Examples of Tools — File System Access | learning | [[agent-tools-filesystem-access]] | [Filesystem MCP server for AI Agents](https://playbooks.com/mcp/mateicanavra-filesystem) |
| Examples of Tools — Email / Slack / SMS | learning | [[agent-tools-email-slack-sms]] | [Twilio Messaging API](https://www.twilio.com/docs/usage/api) |

### Model Context Protocol / MCP (`agent-`)
| Topic | Stage | Note | Reference |
|---|---|---|---|
| Model Context Protocol (MCP) — an open standard defining how an agent packages context (system role, memory, tool calls, etc.) when talking to a model, and how tools/data sources plug in. | learning | [[agent-mcp-overview]] | [Model Context Protocol — official](https://modelcontextprotocol.io/introduction) |
| MCP Hosts — the app/environment (e.g. Claude Desktop, an IDE) that runs an MCP client and coordinates with servers. | learning | [[agent-mcp-hosts]] | [Model Context Protocol — official](https://modelcontextprotocol.io/introduction) |
| MCP Client — the component inside the host that talks to MCP servers on behalf of the model. | learning | [[agent-mcp-client]] | [Model Context Protocol — official](https://modelcontextprotocol.io/introduction) |
| MCP Servers — the process that exposes tools/resources/prompts to MCP clients over the protocol. | learning | [[agent-mcp-servers]] | [punkpeye/awesome-mcp-servers](https://github.com/punkpeye/awesome-mcp-servers) |
| Creating MCP Servers — building a server that exposes your own tools/data via MCP. | learning | [[agent-mcp-creating-servers]] | [Model Context Protocol (MCP) — Anthropic announcement](https://www.anthropic.com/news/model-context-protocol) |
| MCP deployment modes — Local Desktop (server runs on your own machine) | learning | [[agent-mcp-deploy-local]] | [Build a Simple Local MCP Server](https://blog.stackademic.com/build-simple-local-mcp-server-5434d19572a4) |
| MCP deployment modes — Remote / Cloud (server hosted on a cloud provider) | learning | [[agent-mcp-deploy-remote]] | [Edge AI vs. Cloud AI](https://medium.com/@hassaanidrees7/edge-ai-vs-cloud-ai-real-time-intelligence-vs-centralized-processing-df8c6e94fd11) |

### Agent Memory (`agent-`)
| Topic | Stage | Note | Reference |
|---|---|---|---|
| What is Agent Memory? — the part of an agent that tracks what already happened: past messages, learned facts, prior steps — across a turn or across sessions. | learning | [[agent-memory-what-is-agent-memory]] | [Agentic Memory for LLM Agents](https://arxiv.org/abs/2502.12110) |
| Short-term memory — facts passed as part of the current prompt/context, discarded after the session ends. | learning | [[agent-memory-short-term]] | [Memory Management in AI Agents - LangChain](https://python.langchain.com/docs/how_to/chatbots_memory/) |
| Long-term memory — information persisted outside the prompt (vector DB, SQL, files) and retrieved across sessions. | learning | [[agent-memory-long-term]] | [Long Term Memory in AI Agents](https://medium.com/@alozie_igbokwe/ai-101-long-term-memory-in-ai-agents-35f87f2d0ce0) |
| Episodic vs Semantic Memory — episodic = specific past events/interactions; semantic = general facts/knowledge distilled from them. | learning | [[agent-memory-episodic-semantic]] | [What Is AI Agent Memory? - IBM](https://www.ibm.com/think/topics/ai-agent-memory) |
| User Profile Storage — stable per-user facts (name, preferences, past choices) kept across sessions to personalize behavior. | learning | [[agent-memory-user-profile-storage]] | [Storage Technology Explained: AI and Data Storage](https://www.computerweekly.com/feature/Storage-technology-explained-AI-and-the-data-storage-it-needs) |
| Summarization / Compression — condensing past conversation into a shorter form to keep the gist without storing every line. | learning | [[agent-memory-summarization-compression]] | [Evaluating LLMs for Text Summarization](https://insights.sei.cmu.edu/blog/evaluating-llms-for-text-summarization-introduction/) |
| Forgetting / Aging Strategies — deliberately dropping stale or low-value memory over time so context stays useful and bounded. | learning | [[agent-memory-forgetting-aging]] | [Memory Management - LangChain](https://python.langchain.com/docs/how_to/chatbots_memory/) |

### Agent Architectures (`agent-`)
| Topic | Stage | Note | Reference |
|---|---|---|---|
| ReAct (Reason + Act) — alternates explicit reasoning steps with tool-invoking actions, using each observation to inform the next reasoning step. | learning | [[agent-architecture-react]] | [ReAct: Synergizing Reasoning and Acting in Language Models](https://react-lm.github.io/) |
| Chain of Thought (CoT) — reused here as an architecture pattern; see Prompt Engineering above for the technique itself. | planned | — | — |
| RAG Agent — an agent that retrieves relevant documents before generating, so answers are grounded in fresh/reliable facts. | learning | [[agent-architecture-rag-agent]] | [What is RAG? - AWS](https://aws.amazon.com/what-is/retrieval-augmented-generation/) |
| RAG & Vector Databases (deep-dive, child of RAG Agent) — how retrieval + vector stores combine to ground agent responses in stored data. | done | [[vector-search]] | [Understanding RAG and Vector Databases](https://pureai.com/Articles/2025/03/03/Understanding-RAG.aspx) |
| Planner–Executor — splits agent work into two clear roles: a planner that decides the steps, and an executor that carries them out. | learning | [[agent-architecture-planner-executor]] | [Plan-and-Execute Agents - LangChain](https://blog.langchain.dev/planning-agents/) |
| DAG Agents — agent workflow modeled as a Directed Acyclic Graph of nodes/tasks with no loops, enabling parallel/ordered execution. | learning | [[agent-architecture-dag]] | [Airflow: Directed Acyclic Graphs](https://airflow.apache.org/docs/apache-airflow/stable/concepts/dags.html) |
| Tree-of-Thought — reused here as an architecture pattern; see Prompt Engineering above for the technique itself. | planned | — | — |
| Multi-agent orchestration patterns — multiple autonomous agents interacting to reach individual or collective goals. | learning | — see also [[graph-engineering]], [[agentic-systems-taxonomy]], [[agent-architecture-multi-agent-orchestration]] | [Guide to multi-agent systems (MAS) - Google Cloud](https://cloud.google.com/discover/what-is-a-multi-agent-system) |
| Self-Critique Agents — agents that generate output, critique their own result, then refine it before finishing. | learning | [[agent-architecture-self-critique]] | [Reflection Agents - LangChain](https://blog.langchain.com/reflection-agents/) |

### Building AI Agents (`agent-`)
| Topic | Stage | Note | Reference |
|---|---|---|---|
| Manual from scratch — writing every part of the agent loop yourself via direct LLM API calls, without a framework. | learning | [[agent-building-manual-from-scratch]] | [A Step-by-Step Guide to Building an AI Agent From Scratch](https://www.neurond.com/blog/how-to-build-an-ai-agent) |
| LLM-native function calling (overview) — letting the model itself decide when to call a function/tool and with what arguments. | learning | [[agent-building-function-calling-overview]] | [A Comprehensive Guide to Function Calling in LLMs](https://thenewstack.io/a-comprehensive-guide-to-function-calling-in-llms/) |
| OpenAI Functions Calling | learning | [[agent-building-openai-function-calling]] | [OpenAI Docs — Function Calling](https://platform.openai.com/docs/guides/function-calling) |
| Gemini Function Calling | learning | [[agent-building-gemini-function-calling]] | [Function Calling with the Gemini API](https://ai.google.dev/gemini-api/docs/function-calling) |
| Anthropic Tool Use | learning | [[agent-building-anthropic-tool-use]] | [Anthropic Tool Use](https://docs.anthropic.com/en/docs/build-with-claude/tool-use/overview) |
| OpenAI Assistant API | learning | [[agent-building-openai-assistant-api]] | [OpenAI Docs — Assistants API Overview](https://platform.openai.com/docs/assistants/overview) |
| Building with frameworks — LangChain | learning | [[agent-building-langchain]] | [LangChain Documentation](https://python.langchain.com/docs/introduction/) |
| Building with frameworks — LangGraph | learning | [[agent-building-langgraph]] | [LangGraph Docs](https://docs.langchain.com/oss/python/langgraph/overview) |
| Building with frameworks — LlamaIndex | learning | [[agent-building-llamaindex]] | [LlamaIndex](https://llamaindex.ai/) |
| Building with frameworks — Haystack | learning | [[agent-building-haystack]] | [Haystack](https://haystack.deepset.ai/) |
| Building with frameworks — AutoGen | planned | — | [AutoGen - Microsoft Research](https://www.microsoft.com/en-us/research/project/autogen/) |
| Building with frameworks — CrewAI | planned | — | [CrewAI](https://crewai.com/) |
| Building with frameworks — Agno | planned | — | [Agno Docs](https://docs.agno.com/) |
| Building with frameworks — Smol Depot | planned | — | [smol.ai](https://smol.candycode.dev/) |

### RAG deep-dive (`rag-`)
Only one confirmed roadmap.sh node here besides the primer under LLM Fundamentals and the RAG Agent under Architectures — the earlier speculative rows (chunking/hybrid search/reranking) weren't found in the actual source content and have been dropped pending confirmation; add back with a source link if they turn out to exist.
| Topic | Stage | Note | Reference |
|---|---|---|---|
| RAG & Vector Databases — see Agent Architectures above (roadmap.sh nests this node there, under RAG Agent). | done | [[vector-search]] | [Understanding RAG and Vector Databases](https://pureai.com/Articles/2025/03/03/Understanding-RAG.aspx) |

### Evaluation & Testing (`eval-`)
| Topic | Stage | Note | Reference |
|---|---|---|---|
| Metrics to Track — the numeric signals used to judge how well an agent performs (accuracy, task success, latency, cost, etc). | planned | — | [Robustness Testing for AI - MIT-IBM Watson AI Lab](https://mitibmwatsonailab.mit.edu/category/robustness/) |
| Unit Testing for Individual Tools — checking that each tool an agent uses works correctly in isolation. | planned | — | [Unit Testing Agents - Patronus AI](https://docs.patronus.ai/docs/agent_evals/unit_testing) |
| Integration Testing for Flows — checking that the agent works end-to-end, across every step from user input to final action. | planned | — | [Integration Testing for AI-based Features with Humans - Microsoft Research](https://www.microsoft.com/en-us/research/publication/hint-integration-testing-for-ai-based-features-with-humans-in-the-loop/) |
| Human-in-the-Loop Evaluation — letting real people judge agent output/behavior as part of the eval loop. | planned | — | [Human in the Loop · Cloudflare Agents](https://developers.cloudflare.com/agents/concepts/human-in-the-loop/) |
| Eval frameworks — Ragas | planned | — | [Ragas Documentation](https://docs.ragas.io/en/latest/) |
| Eval frameworks — DeepEval | planned | — | [DeepEval](https://www.deepeval.com/) |
| Eval frameworks — LangSmith | planned | — | [LangSmith](https://smith.langchain.com/) |

### Observability & Deployment (`infra-`)
| Topic | Stage | Note | Reference |
|---|---|---|---|
| Structured Logging & Tracing — recording what an agent does in a structured, queryable way so problems can be found and fixed fast. | planned | — | [Understanding Structured Logging](https://www.graphapp.ai/blog/understanding-structured-logging-a-comprehensive-guide) |
| Observability tools — Helicone | planned | — | [Helicone](https://www.helicone.ai/) |
| Observability tools — LangFuse | planned | — | [LangFuse](https://langfuse.com/) |
| Observability tools — OpenLLMetry | planned | — | [OpenLLMetry / Traceloop](https://www.traceloop.com/blog/openllmetry) |

### Security & Ethics (`sec-`)
| Topic | Stage | Note | Reference |
|---|---|---|---|
| Prompt Injection / Jailbreaks — tricks that make an agent ignore its instructions or leak/perform things it shouldn't. | planned | — | [Prompt Injection vs. Jailbreaking: What's the Difference?](https://learnprompting.org/blog/injection_jailbreaking) |
| Tool Sandboxing / Permissioning — restricting an agent to a safe zone where it can only run approved actions. | planned | — | [AI Sandbox - Harvard University IT](https://www.huit.harvard.edu/ai-sandbox) |
| Data Privacy & PII Redaction — stripping/masking personal data (names, phone numbers, addresses) from agent inputs/outputs and logs. | planned | — | [GDPR Compliance Overview](https://gdpr.eu/) |
| Bias & Toxicity Guardrails — controls that keep an agent's outputs from being unfair or harmful. | planned | — | [Define the Agent Guardrails - Salesforce Trailhead](https://trailhead.salesforce.com/content/learn/modules/agentforce-agent-planning/define-the-agent-guardrails) |
| Safety & Red-Team Testing — deliberately probing an agent for harmful/risky behavior before and after release (roadmap.sh has a dedicated red-teaming track). | planned | — | [Dedicated AI Red Teaming Roadmap](https://roadmap.sh/ai-red-teaming) |

### Fine-tuning (`finetune-`) — not confirmed on the current roadmap.sh/ai-agents tree
Kept from an earlier draft of this hub; no matching node was found when cross-checking against the roadmap's actual source content on 2026-08-17. Deprioritized either way — this track favors prompt engineering/RAG over training. Remove or re-add with a source link if it turns out to exist elsewhere in the tree.
| Topic | Stage | Note |
|---|---|---|
| SFT vs RLHF vs DPO | planned | — |
| LoRA / PEFT | planned | — |

## Related
- [[graph-engineering]] — deep dive on multi-agent orchestration patterns, overlaps with Agent Architectures.
- [[agentic-systems-taxonomy]] — taxonomy note, overlaps with AI Agents 101 / Agent Architectures — still stub, promote when filled in.
- [[agentic-ai-course-setup]] — course/tooling setup note, precedes this roadmap.
