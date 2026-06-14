---
status: current
updated: 2026-06
sources:
  - raw/inbox/2026-06-14-0807-sbidea.md
---

# Periodic auto-lint with cron

Idea: run the vault's LINT step automatically every week instead of manually, using `cron`
to periodically have Claude scan for contradictions/stale claims/orphans/broken links. (as of 2026-06, raw/inbox)

This is an extension of the *lint* stage in [[llm-wiki]] (raw → compile → lint) —
turning lint from a manual action into a periodic one. It belongs to the MVP's "deferred (YAGNI)"
list: only build it once the vault is large enough that manual linting becomes costly. (confidence: medium — still just an idea)
