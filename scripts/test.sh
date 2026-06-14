#!/usr/bin/env bash
set -euo pipefail
cd "$(dirname "$0")/.."
ROOT="$(pwd)"
FAIL=0

# --- import.sh ---
echo "hello brain" > /tmp/sb_note.txt
OUT="$(./scripts/import.sh /tmp/sb_note.txt)"
if [[ -f "$OUT" ]] && grep -q "status: raw" "$OUT" && grep -q "hello brain" "$OUT"; then
  echo "PASS import.sh -> $OUT"
else
  echo "FAIL import.sh"; FAIL=1
fi

# --- clip.sh (dry-run, no network) ---
OUT2="$(./scripts/clip.sh --dry-run 'https://example.com/some/Article-Title')"
if echo "$OUT2" | grep -q "raw/web/" && echo "$OUT2" | grep -q "article-title"; then
  echo "PASS clip.sh dry-run -> $OUT2"
else
  echo "FAIL clip.sh dry-run (got: $OUT2)"; FAIL=1
fi

exit $FAIL
