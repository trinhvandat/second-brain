---
status: current
updated: 2026-06
sources:
  - https://www.saner.ai/blogs/10-best-second-brain-ai-apps
  - https://arxiv.org/html/2504.09720v2
---

# NotebookLM

Google's source-grounded research assistant: it answers only from the documents you upload
and attaches verifiable inline citations anchored to specific source passages, which
distinguishes it from a general chatbot (as of 2026-06, saner.ai / arXiv 2504.09720).
(confidence: high)

It is the clearest product example of the anti-hallucination "source-grounding" pattern this
vault's QUERY rule borrows — answer from sources or say you don't know (see [[llm-wiki]]).
Unlike a self-owned vault, it is a silo: you cannot point it at your local files as the
source of truth. For the data-isolation concerns of such retrieval systems, see
[[privacy-aware-rag]].
