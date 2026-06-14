---
status: current
updated: 2026-06
sources:
  - https://leonard-garden.github.io/agentic-ai-course/module-00-foundation/lessons/03-setup/
---

# Agentic AI course — environment setup (Module 00, Lesson 03)

Setup required before the course: Java 17+ & Maven 3.8+ (primary stack), an Anthropic API
key in the `ANTHROPIC_API_KEY` env var (never hardcoded), Claude Code CLI (npm global +
browser auth), plus Node.js 18+ (MCP, Module 03) and Python 3.11+ (Agent SDK, Module 02).
(as of 2026-06, leonard-garden.github.io) (confidence: high)

First API call is `HelloClaude.java` using the cheapest model tier to conserve credits —
see [[claude-models]] for the lineup (Haiku is the cheapest). Guardrails: console spend
limits, `.gitignore` the `.env`, and all 10 verification checks pass before Module 01.
