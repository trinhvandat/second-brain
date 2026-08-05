---
status: current
updated: 2026-08
sources:
  - https://shipwithai.io/blog/understand-a-new-codebase--fresher-dev--tutorial--en/
---

# How to Onboard Into a New Codebase With Claude Code: The SCOPE Method

A step-by-step tutorial for reading and truly understanding an unfamiliar codebase, using Claude Code as an assistant rather than a crutch. Extends a [ShipWithAI tutorial](https://shipwithai.io/blog/understand-a-new-codebase--fresher-dev--tutorial--en/) that covers feature-tracing well but skips architecture identification and hands-on verification — the two steps that most affect whether a fresher actually understands the system afterward, versus just being able to repeat what the AI said. (confidence: medium — synthesized in conversation, not externally validated against a real onboarding cohort)

**Who this is for:** fresher, middle, senior engineers joining a new codebase. Same 5 phases for everyone — what changes is depth, not the steps.

**Time budget:** fresher 1-2 days, middle 3-4 hours, senior 1-2 hours (broken down per phase below).

**Prerequisites:** Claude Code installed and authenticated, repo cloned locally, terminal open at repo root.

---

## Overview: the SCOPE phases

```
S — System      identify project type, tech stack, architecture pattern
C — Context     map entry points and data flow (diagram)
O — One flow    trace one real feature vertically, end-to-end
P — Practice    debug/modify something small — hands-on, not just reading
E — Explain     restate from memory, then get reviewed by a real person
```

Each phase below has: **the goal**, **exact prompts to give Claude Code**, **what good output looks like**, and **a verification check** — you don't move to the next phase until you pass the check.

---

## Phase S — System (15-60 min)

**Goal:** answer 3 questions before reading any code — what kind of system is this, what stack does it use, and is the directory structure organized by layer (MVC) or by feature/domain?

**Steps:**

1. Open the repo root in a terminal and run `claude`.
2. Give it this prompt:
   > "Look at package.json/go.mod/pom.xml (whichever exists) and docker-compose.yml if present. Tell me: (1) what kind of project this is — backend, frontend, monolith, or microservices, (2) the main framework and language, (3) whether the code is organized by architectural layer (controllers/services/repositories) or by feature/domain folder."
3. If a term in the answer is unfamiliar (e.g. "this follows a layered architecture" and you don't know what that means), immediately ask a follow-up:
   > "Explain what a layered architecture is, using this project's own folder names as the example."
   This is the step the ShipWithAI tutorial skips — it assumes you already know what MVC/layered/DDD means. If you're a fresher, you don't yet, and reading on without asking this collapses your understanding for every later phase.

**Good output looks like:** "This is a monolith backend built with Spring Boot. It's organized by layer: `controller/` handles HTTP, `service/` has business logic, `repository/` talks to Postgres via JPA."

**Verification check:** close the terminal output and say out loud, in your own words, what kind of system this is and what the top 2-3 folders are for. If you can't, ask again with a more specific question — don't move on.

---

## Phase C — Context (20-45 min)

**Goal:** find the entry points (where requests/events come in) and exits (DB, external APIs, queues), and get a rough picture of how they connect.

**Steps:**

1. Ask Claude Code:
   > "List the main entry points into this system — HTTP routes, event listeners, cron jobs, CLI commands. For each, tell me the file it's defined in."
2. Pick the file for one entry point and ask for a diagram:
   > "Generate a Mermaid sequence diagram showing the path of a request through [this route file], from entry point to any external call (DB, API, queue)."
3. Paste the Mermaid output into any Mermaid renderer (or a scratch markdown file) to actually see it — don't just read the text.

**Good output looks like:** a list like `POST /login → AuthController → AuthService → UserRepository → Postgres`, plus a diagram showing the same as boxes and arrows.

**Verification check:** you should be able to name the 3-5 main entry points into the system without looking, and roughly what each layer between entry and exit does.

---

## Phase O — One flow (1-3 hours)

**Goal:** trace exactly one real, user-visible feature end-to-end, opening every file it touches, in order. This is the core technique from the ShipWithAI tutorial, and it works — vertical tracing through one concrete example beats reading files in isolation because you see *how the layers connect*, not just what each layer looks like alone.

**Steps:**

1. Pick a feature that's easy to picture (login, checkout, "create a post"). Ask:
   > "Trace the full path of [feature] from the entry point through every layer to the database. List the files in the order a request would actually pass through them."
2. Open every file in that exact order as you go — don't jump around.
3. Whenever you hit a function you don't understand, don't re-read it repeatedly. Ask Claude Code directly, naming the specific confusion:
   > "In `validatePassword()` in AuthService.java, why does it compare against a hash instead of the raw password? What hashing scheme is used here?"
4. Depth by level:
   - **Fresher:** one feature, traced deeply, asking follow-ups on every unfamiliar function.
   - **Middle:** 2-3 representative flows — one read path, one write path, one async/background path.
   - **Senior:** skip the happy path (you can guess it), trace the error-handling and retry logic instead — that's where the real design decisions live.

**Worked example (login, mirroring the ShipWithAI walkthrough):**
```
1. AuthController.java   — receives POST /login, validates request shape
2. AuthService.java      — looks up user, calls validatePassword()
3. UserRepository.java   — queries the user record from Postgres
4. SessionService.java   — creates a session, sets a cookie
5. AuthController.java   — returns 200 with user payload
```

**Verification check:** recite the ordered file list from memory, without looking at your notes.

---

## Phase P — Practice (30-90 min)

**Goal:** convert what you've read into something you've actually operated. This is the phase both the ShipWithAI tutorial and most "read + ask AI" approaches skip — and it's the one that separates "I can repeat what the AI told me" from "I understand how this runs."

**Steps — pick at least one:**

1. **Debug it live.** Set a breakpoint at the entry point of the feature you traced in Phase O, run the app, and step through line by line, watching variables change. If you don't know how to set up the debugger for this stack, ask Claude Code: *"How do I attach a debugger to this project and set a breakpoint in AuthController?"*
2. **Change something small and observable.** Edit a response string or a UI label inside the traced flow, run the app, and confirm the change shows up exactly where you expect. If it doesn't show up where you expected, your mental model of the flow is wrong — go back to Phase O.
3. **Write one test.** Ask Claude Code to help you write a unit test for one function you read in Phase O, then run it and watch it pass (and, ideally, break it on purpose once to see it fail).

**Depth by level:**
- **Fresher:** mandatory, guided — do this before moving to Phase E.
- **Middle/senior:** substitute a real small task from the sprint backlog instead of a synthetic exercise.

**Verification check:** you have evidence you touched the running system — a debugger session, a diff that changed observable behavior, or a passing test you wrote yourself.

---

## Phase E — Explain (20-40 min)

**Goal:** confirm the understanding is real, not borrowed — and fill in the context no AI has access to.

**Steps:**

1. Close all files, terminals, and notes. Write a summary of the feature flow (from Phase O) in your own words — plain prose, no copy-pasting from Claude Code's earlier output.
2. Ask Claude Code to check it:
   > "Here's my understanding of the login flow: [paste your summary]. Point out anything inaccurate or missing."
3. Fix gaps and repeat until it confirms your summary is accurate.
4. **Then — and this is the step that closes the biggest gap in AI-only onboarding — take the same summary to a real teammate or mentor** and ask: *"Here's my understanding of [feature], is this right, and is there any history I should know — a past incident, a reason it's built this way instead of the 'obvious' way?"* An AI can confirm your summary matches the code; only a person can tell you *why* the code looks the way it does.

**Verification check:** a teammate has confirmed both that your technical summary is accurate and that you're not missing non-obvious business/historical context.

---

## Full checklist

- [ ] Claude Code installed and running at repo root
- [ ] **S:** identified project type, stack, and organizing pattern (layer vs. feature)
- [ ] **S:** asked follow-up on any unfamiliar architectural term
- [ ] **C:** listed main entry points with their files
- [ ] **C:** generated and viewed a flow diagram for at least one entry point
- [ ] **O:** picked one real feature and traced it file-by-file, in order
- [ ] **O:** asked targeted follow-up questions on unfamiliar functions
- [ ] **O:** recited the ordered file list from memory
- [ ] **P:** debugged, modified, or tested something in the traced flow
- [ ] **P:** have concrete evidence of touching the running system
- [ ] **E:** wrote a from-memory summary with no references open
- [ ] **E:** had Claude Code check the summary and fixed gaps
- [ ] **E:** reviewed the summary with a real teammate for missing context

## Depth-by-level summary

| Phase | Fresher | Middle | Senior |
|---|---|---|---|
| S | Concepts explained | Self-identify, confirm | Spot anomalies |
| C | Detailed visual diagram | Quick list | Skim |
| O | 1 feature, deep | 2-3 features | Edge/error paths |
| P | Mandatory, guided | Real small task | Real bugfix, sprint 1 |
| E | Human review mandatory | Human review encouraged | Self-confirm, document for team |
| Time | 1-2 days | 3-4 hours | 1-2 hours |

## Why this differs from the ShipWithAI tutorial

The ShipWithAI tutorial ([source](https://shipwithai.io/blog/understand-a-new-codebase--fresher-dev--tutorial--en/)) is a solid *prompting cheat sheet* — its `/init` + feature-trace flow maps directly onto phases C and O above, and is genuinely good technique. But it assumes the reader already knows what MVC/layered architecture is (skips phase S), and it treats "Claude Code confirms my summary" as the finish line (skips half of phase E — the human review). Both gaps matter most for fresher engineers, who don't yet have the pattern recognition to fill them in silently. Phase P closes a third gap present in almost every AI-assisted reading approach: reading, even with follow-up questions, only builds declarative knowledge ("I can describe it"), not procedural knowledge ("I can operate it") — that requires touching the running system.

## Related

- [[augmented-llm]] — AI-assisted reading tools (Claude Code, `/init`) fit into phases S-O but shouldn't replace phase E's human review.
- [[personal-context-management]]
