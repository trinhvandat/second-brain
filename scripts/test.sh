#!/usr/bin/env bash
set -uo pipefail
cd "$(dirname "$0")/.."
FAIL=0

# --- import.sh ---
echo "hello brain" > /tmp/sb_note.txt
OUT="$(./scripts/import.sh /tmp/sb_note.txt)"
if [[ -f "$OUT" ]] && grep -q "status: raw" "$OUT" && grep -q "hello brain" "$OUT"; then
  echo "PASS import.sh -> $OUT"
else
  echo "FAIL import.sh"; FAIL=1
fi
[[ -n "${OUT:-}" && -f "$OUT" ]] && rm -f "$OUT"

# --- clip.sh (dry-run, no network) ---
OUT2="$(./scripts/clip.sh --dry-run 'https://example.com/some/Article-Title')"
if echo "$OUT2" | grep -q "raw/web/" && echo "$OUT2" | grep -q "article-title"; then
  echo "PASS clip.sh dry-run -> $OUT2"
else
  echo "FAIL clip.sh dry-run (got: $OUT2)"; FAIL=1
fi

# --- lint.sh (isolated fixture vaults, no dependency on the real vault) ---
# Dirty fixture: a.md links [[b]] (ok) + [[ghost]] (broken); a.md is an orphan
# (nothing links to it); b.md has a stale "(as of 2020-01" marker.
LROOT="$(mktemp -d)"
mkdir -p "$LROOT/wiki/concepts"
printf '# A\nSee [[b]] and [[ghost]].\n' > "$LROOT/wiki/concepts/a.md"
printf '# B\nText (as of 2020-01, src).\n' > "$LROOT/wiki/concepts/b.md"
printf '# index\n' > "$LROOT/index.md"
printf '# facts\n' > "$LROOT/CRITICAL_FACTS.md"
OUT3="$(./scripts/lint.sh "$LROOT")"; RC3=$?
if echo "$OUT3" | grep -q "ghost" && echo "$OUT3" | grep -q "a.md" \
   && echo "$OUT3" | grep -q "2020-01" && [[ "$RC3" -eq 1 ]]; then
  echo "PASS lint.sh detects broken+orphan+stale (exit 1)"
else
  echo "FAIL lint.sh dirty fixture (rc=$RC3)"; echo "$OUT3"; FAIL=1
fi

# Clean fixture: x<->y link each other, no stale, no broken → exit 0.
LROOT2="$(mktemp -d)"
mkdir -p "$LROOT2/wiki"
printf '# X\nlinks [[y]]\n' > "$LROOT2/wiki/x.md"
printf '# Y\nlinks [[x]]\n' > "$LROOT2/wiki/y.md"
printf '# index\n' > "$LROOT2/index.md"
printf '# facts\n' > "$LROOT2/CRITICAL_FACTS.md"
OUT4="$(./scripts/lint.sh "$LROOT2")"; RC4=$?
if [[ "$RC4" -eq 0 ]] && echo "$OUT4" | grep -q "0 issue group"; then
  echo "PASS lint.sh clean fixture (exit 0)"
else
  echo "FAIL lint.sh clean fixture (rc=$RC4)"; echo "$OUT4"; FAIL=1
fi
rm -rf "$LROOT" "$LROOT2"

exit $FAIL
