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
LROOT="$(mktemp -d)"; LROOT2=""; L3=""
trap 'rm -rf "${LROOT:-}" "${LROOT2:-}" "${L3:-}"' EXIT
mkdir -p "$LROOT/wiki/concepts"
printf '# A\nSee [[b]] and [[ghost]].\n' > "$LROOT/wiki/concepts/a.md"
printf '# B\nText (as of 2020-01, src).\n' > "$LROOT/wiki/concepts/b.md"
printf '# index\n' > "$LROOT/index.md"
printf '# facts\n' > "$LROOT/CRITICAL_FACTS.md"
OUT3="$(./scripts/lint.sh "$LROOT")"; RC3=$?
if echo "$OUT3" | grep -q "ghost" \
   && echo "$OUT3" | grep -A20 '\[orphan notes\]' | grep -q "a.md" \
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

# Lifecycle fixture: exercises supersession/dispute/unsourced checks + archive exclusion.
L3="$(mktemp -d)"
mkdir -p "$L3/wiki/concepts" "$L3/wiki/archive"
printf '# index\n' > "$L3/index.md"; printf '# facts\n' > "$L3/CRITICAL_FACTS.md"
# superseded note pointing at a non-existent replacement → broken supersession
printf -- '---\nstatus: superseded\nupdated: 2026-06\nsources:\n  - https://x\n---\n# Gone\nOld (superseded 2026-06 → [[nowhere]]).\n' > "$L3/wiki/concepts/gone.md"
# disputed note → open dispute
printf -- '---\nstatus: disputed\nupdated: 2026-06\nsources:\n  - https://x\n---\n# Hot\nContested. (confidence: low)\n' > "$L3/wiki/concepts/hot.md"
# confidence marker but no source URL / sources: key → unsourced; also links retired (must resolve)
printf -- '---\nstatus: current\nupdated: 2026-06\n---\n# Claimy\nA bold claim. (confidence: high) See [[retired]].\n' > "$L3/wiki/concepts/claimy.md"
# VALID superseded note → existing target [[claimy]]: must NOT be flagged as broken supersession
printf -- '---\nstatus: superseded\nupdated: 2026-06\nsources:\n  - https://x\n---\n# Moved\nOld. (superseded 2026-06 → [[claimy]])\n' > "$L3/wiki/concepts/moved.md"
# prose "(superseded by …)" without the canonical dated marker: must NOT trigger the check
printf -- '---\nstatus: current\nupdated: 2026-06\nsources:\n  - https://x\n---\n# Prose\nThis term was (superseded by the new standard) ages ago. See [[claimy]].\n' > "$L3/wiki/concepts/prose.md"
# retired note in archive: must be excluded from orphan + stale scans, still resolvable as target
printf -- '---\nstatus: retired\nupdated: 2020-01\nsources:\n  - https://x\n---\n# Retired\nObsolete.\n' > "$L3/wiki/archive/retired.md"
# retired note NOT in archive: must be flagged as misplaced retired
printf -- '---\nstatus: retired\nupdated: 2026-06\nsources:\n  - https://x\n---\n# Stray\nShould be archived. See [[claimy]].\n' > "$L3/wiki/concepts/stray-retired.md"
OUT5="$(./scripts/lint.sh "$L3")"; RC5=$?
ok5=1
echo "$OUT5" | grep -A8 '\[broken supersession\]' | grep -q "gone.md"     || ok5=0
echo "$OUT5" | grep -A8 '\[broken supersession\]' | grep -q "moved.md"    && ok5=0   # valid target must NOT be flagged
echo "$OUT5" | grep -A8 '\[broken supersession\]' | grep -q "prose.md"    && ok5=0   # prose "(superseded by…)" must NOT trigger
echo "$OUT5" | grep -A3 '\[open disputes\]'        | grep -q "hot.md"      || ok5=0
echo "$OUT5" | grep -A3 '\[unsourced claims\]'     | grep -q "claimy.md"   || ok5=0
echo "$OUT5" | grep -A20 '\[orphan notes\]'        | grep -q "archive/retired" && ok5=0   # archive must NOT be orphan-scanned
echo "$OUT5" | grep -A20 '\[stale claims\]'        | grep -q "archive/retired" && ok5=0   # archive must NOT be stale-scanned
echo "$OUT5" | grep -A8 '\[misplaced retired\]'    | grep -q "stray-retired.md"   || ok5=0   # retired outside archive → flagged
echo "$OUT5" | grep -A8 '\[misplaced retired\]'    | grep -q "archive/retired.md" && ok5=0   # archived retired → NOT flagged
[[ "$RC5" -eq 1 ]] || ok5=0
if [[ "$ok5" -eq 1 ]]; then
  echo "PASS lint.sh lifecycle (supersession+dispute+unsourced, archive excluded)"
else
  echo "FAIL lint.sh lifecycle fixture (rc=$RC5)"; echo "$OUT5"; FAIL=1
fi
rm -rf "$L3"

exit $FAIL
