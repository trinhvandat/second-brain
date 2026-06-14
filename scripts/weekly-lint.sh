#!/usr/bin/env bash
# Weekly maintenance wrapper for cron: run lint.sh, append a timestamped report to
# .lint-history.log, and (on macOS) post a desktop notification if issues are found.
# Cron has a minimal PATH; lint.sh only needs find/grep/sed/date (all in /usr/bin).
set -uo pipefail
cd "$(dirname "$0")/.."

LOG=".lint-history.log"
TS="$(date '+%Y-%m-%d %H:%M')"
OUT="$(./scripts/lint.sh 2>&1)"; RC=$?

{
  echo "=== $TS (exit $RC) ==="
  printf '%s\n' "$OUT"
  echo
} >> "$LOG"

if [[ "$RC" -ne 0 ]]; then
  COUNT="$(printf '%s' "$OUT" | grep -oE '[0-9]+ issue group' | grep -oE '[0-9]+' | head -1)"
  if command -v osascript >/dev/null 2>&1; then
    osascript -e "display notification \"${COUNT:-Some} issue group(s) found — run 'lint the brain'\" with title \"Second Brain lint\"" 2>/dev/null || true
  fi
fi

exit $RC
