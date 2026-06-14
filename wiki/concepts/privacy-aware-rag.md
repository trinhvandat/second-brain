---
status: current
updated: 2026-06
sources:
  - https://arxiv.org/html/2503.15548v1
---

# Privacy-Aware RAG

RAG systems often lack built-in mechanisms to enforce strict user isolation and secure data
access, creating a cross-user data-leakage risk. The proposed fix authenticates the user,
establishes a tiered cryptographic key hierarchy for exclusive access to private knowledge
bases, and filters other users' private data out of final retrieval results
(as of 2026-06, arXiv 2503.15548). (confidence: high)

Takeaway for a self-built brain: isolation must be added deliberately — it is not a default
of RAG. This is one reason this vault favors the [[llm-wiki]] approach (local files, no shared
vector store) for a single user, and why a hosted silo like [[notebooklm]] handles isolation
for you instead.
