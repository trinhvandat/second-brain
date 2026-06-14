#!/usr/bin/env bash
# Mechanical lint pass for the second-brain vault.
#
# Structural checks (deterministic subset of AGENTS.md section 4):
#   1. broken wikilinks  — [[name]] with no matching <name>.md in the vault
#   2. orphan wiki notes — an active wiki/ note nothing links to
#   3. stale claims      — "(as of YYYY-MM" / "updated: YYYY-MM" older than STALE_MONTHS
# Lifecycle checks (AGENTS.md section 6):
#   4. broken supersession — status:superseded with no/missing "→ [[replacement]]"
#   5. open disputes       — status:disputed (or inline) needing resolution
#   6. unsourced claims    — a (confidence: …) marker with no source URL / sources entry
#
# Semantic checks (contradictions between notes) are NOT done here — they require
# an LLM and remain Claude's job. This script is a fast pre-pass.
#
# Notes under wiki/archive/ are retired: excluded from link/orphan/lifecycle/stale
# scans, but still resolvable as link targets.
#
# Usage: lint.sh [VAULT_DIR]   (defaults to the repo root containing this script)
# Exit:  0 = clean, 1 = issues found, 2 = bad usage.
# Portable to bash 3.2 (macOS system bash): no associative arrays / mapfile.
# Limitation: notes are matched by basename, so filenames should be unique across
# the vault and must not contain ':' or '|'.
set -uo pipefail

VAULT="${1:-$(cd "$(dirname "$0")/.." && pwd)}"
cd "$VAULT" || { echo "lint: cannot cd into '$VAULT'" >&2; exit 2; }

STALE_MONTHS=6

roots=()
for r in index.md CRITICAL_FACTS.md; do [[ -f "$r" ]] && roots+=("$r"); done

base_of() { printf '%s' "$1" | sed -E 's/[|].*//; s#.*/##; s#\.md$##'; }
in_set()  { printf '%s\n' "$2" | grep -Fxq -- "$1"; }
status_of() { grep -m1 -E '^status:[[:space:]]*' "$1" 2>/dev/null | sed -E 's/^status:[[:space:]]*//; s/[[:space:]]*$//'; }

# Resolution set: ALL wiki notes (incl archive) + roots — links to retired notes still resolve.
ALL_BASENAMES="$(find wiki ${roots[@]+"${roots[@]}"} -name '*.md' 2>/dev/null | sed -E 's#.*/##; s#\.md$##')"

# Active notes = wiki minus archive (retired). The scope of every scan below.
ACTIVE_FILES="$(find wiki -name '*.md' -not -path '*/archive/*' 2>/dev/null)"

# Referenced basenames from active notes + roots (alias-stripped).
REFERENCED="$(
  { printf '%s\n' "$ACTIVE_FILES"; printf '%s\n' ${roots[@]+"${roots[@]}"}; } \
  | while IFS= read -r f; do [[ -f "$f" ]] && grep -ohE '\[\[[^]]+\]\]' "$f" 2>/dev/null; done \
  | sed -E 's/^\[\[//; s/\]\]$//; s/[|].*//; s#.*/##; s#\.md$##'
)"

issues=0
echo "=== Second Brain lint ($(date +%Y-%m-%d), vault: $VAULT) ==="

# --- 1. broken wikilinks (active wiki notes only; root docs use [[...]] illustratively) ---
broken=""
while IFS= read -r f; do
  [[ -z "$f" ]] && continue
  while IFS= read -r tgt; do
    [[ -z "$tgt" ]] && continue
    base="$(base_of "$tgt")"
    [[ -z "$base" ]] && continue
    in_set "$base" "$ALL_BASENAMES" || broken+="  $f -> [[$tgt]] (no ${base}.md)"$'\n'
  done < <(grep -oE '\[\[[^]]+\]\]' "$f" 2>/dev/null | sed -E 's/^\[\[//; s/\]\]$//')
done <<< "$ACTIVE_FILES"
if [[ -n "$broken" ]]; then echo "[broken wikilinks]"; printf '%s' "$broken"; issues=$((issues+1)); else echo "[broken wikilinks] none"; fi

# --- 2. orphan wiki notes (entry notes index/CRITICAL_FACTS exempt; archive excluded) ---
orphans=""
while IFS= read -r f; do
  [[ -z "$f" ]] && continue
  base="$(base_of "$f")"
  in_set "$base" "$REFERENCED" || orphans+="  $f"$'\n'
done <<< "$ACTIVE_FILES"
if [[ -n "$orphans" ]]; then echo "[orphan notes]"; printf '%s' "$orphans"; issues=$((issues+1)); else echo "[orphan notes] none"; fi

# --- 3. stale claims ("(as of YYYY-MM" or "updated: YYYY-MM") older than STALE_MONTHS ---
stale=""
cy="$(date +%Y)"; cm="$(date +%m)"
while IFS= read -r hit; do
  [[ -z "$hit" ]] && continue
  f="${hit%%:*}"
  ym="$(printf '%s' "${hit#*:}" | grep -oE '[0-9]{4}-[0-9]{2}' | head -1)"
  [[ -z "$ym" ]] && continue
  yy="${ym%-*}"; mm="${ym#*-}"
  months=$(( (10#$cy - 10#$yy) * 12 + (10#$cm - 10#$mm) ))
  (( months > STALE_MONTHS )) && stale+="  $f -> (as of $ym, ${months} months old) → revalidate source"$'\n'
done < <(
  { printf '%s\n' "$ACTIVE_FILES"; printf '%s\n' ${roots[@]+"${roots[@]}"}; } \
  | while IFS= read -r f; do [[ -f "$f" ]] && grep -EHo '(\(as of [0-9]{4}-[0-9]{2})|(^updated: [0-9]{4}-[0-9]{2})' "$f" 2>/dev/null; done
)
if [[ -n "$stale" ]]; then echo "[stale claims]"; printf '%s' "$stale"; issues=$((issues+1)); else echo "[stale claims] none"; fi

# --- 4. broken supersession (status:superseded must point to an existing replacement) ---
supbad=""
while IFS= read -r f; do
  [[ -z "$f" ]] && continue
  st="$(status_of "$f")"
  if [[ "$st" == "superseded" ]] || grep -q '(superseded' "$f" 2>/dev/null; then
    link="$(grep -oE 'superseded[^[]*\[\[[^]]+\]\]' "$f" 2>/dev/null | grep -oE '\[\[[^]]+\]\]' | head -1)"
    if [[ -z "$link" ]]; then
      supbad+="  $f -> superseded but no '→ [[replacement]]'"$'\n'
    else
      b="$(base_of "$link")"
      in_set "$b" "$ALL_BASENAMES" || supbad+="  $f -> superseded → $link (missing ${b}.md)"$'\n'
    fi
  fi
done <<< "$ACTIVE_FILES"
if [[ -n "$supbad" ]]; then echo "[broken supersession]"; printf '%s' "$supbad"; issues=$((issues+1)); else echo "[broken supersession] none"; fi

# --- 5. open disputes (need resolution) ---
disp=""
while IFS= read -r f; do
  [[ -z "$f" ]] && continue
  st="$(status_of "$f")"
  if [[ "$st" == "disputed" ]] || grep -q '(disputed' "$f" 2>/dev/null; then
    disp+="  $f -> open dispute, needs resolution"$'\n'
  fi
done <<< "$ACTIVE_FILES"
if [[ -n "$disp" ]]; then echo "[open disputes]"; printf '%s' "$disp"; issues=$((issues+1)); else echo "[open disputes] none"; fi

# --- 6. unsourced claims ((confidence: …) but no source URL / sources entry) ---
nosrc=""
while IFS= read -r f; do
  [[ -z "$f" ]] && continue
  if grep -q '(confidence:' "$f" 2>/dev/null; then
    if ! grep -qE 'https?://' "$f" 2>/dev/null && ! grep -q '^sources:' "$f" 2>/dev/null; then
      nosrc+="  $f -> has (confidence) but no source URL / sources: entry"$'\n'
    fi
  fi
done <<< "$ACTIVE_FILES"
if [[ -n "$nosrc" ]]; then echo "[unsourced claims]"; printf '%s' "$nosrc"; issues=$((issues+1)); else echo "[unsourced claims] none"; fi

echo "=== $issues issue group(s) found ==="
echo "Note: contradictions between notes need a semantic pass — ask Claude to \"lint the brain\"."
[[ "$issues" -eq 0 ]] && exit 0 || exit 1
