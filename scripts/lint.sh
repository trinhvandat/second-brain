#!/usr/bin/env bash
# Mechanical lint pass for the second-brain vault.
#
# Checks (the deterministic subset of AGENTS.md section 4):
#   1. broken wikilinks  — [[name]] with no matching <name>.md in the vault
#   2. orphan wiki notes — a wiki/ note nothing links to
#   3. stale claims      — "(as of YYYY-MM" markers older than STALE_MONTHS
#
# Semantic checks (contradictions between notes) are NOT done here — they require
# an LLM and remain Claude's job. This script is a fast pre-pass.
#
# Usage: lint.sh [VAULT_DIR]   (defaults to the repo root containing this script)
# Exit:  0 = clean, 1 = issues found, 2 = bad usage.
# Portable to bash 3.2 (macOS system bash): no associative arrays / mapfile.
set -uo pipefail

VAULT="${1:-$(cd "$(dirname "$0")/.." && pwd)}"
cd "$VAULT" || { echo "lint: cannot cd into '$VAULT'" >&2; exit 2; }

STALE_MONTHS=6

# Linkable/scannable note set = all of wiki/ plus the two root entry notes.
roots=()
for r in index.md CRITICAL_FACTS.md; do [[ -f "$r" ]] && roots+=("$r"); done

# basename helper (strip any path + .md)
base_of() { printf '%s' "$1" | sed -E 's#.*/##; s#\.md$##'; }

# Newline-delimited sets (bash 3.2 has no associative arrays).
ALL_BASENAMES="$(find wiki "${roots[@]}" -name '*.md' 2>/dev/null | sed -E 's#.*/##; s#\.md$##')"
REFERENCED="$(grep -rhoE '\[\[[^]]+\]\]' wiki "${roots[@]}" 2>/dev/null \
              | sed -E 's/^\[\[//; s/\]\]$//; s#.*/##; s#\.md$##')"

in_set() { printf '%s\n' "$2" | grep -Fxq -- "$1"; }

issues=0
echo "=== Second Brain lint ($(date +%Y-%m-%d), vault: $VAULT) ==="

# --- 1. broken wikilinks ---
broken=""
while IFS= read -r f; do
  [[ -z "$f" ]] && continue
  while IFS= read -r tgt; do
    [[ -z "$tgt" ]] && continue
    base="$(base_of "$tgt")"
    [[ -z "$base" ]] && continue
    in_set "$base" "$ALL_BASENAMES" || broken+="  $f -> [[$tgt]] (no ${base}.md)"$'\n'
  done < <(grep -oE '\[\[[^]]+\]\]' "$f" 2>/dev/null | sed -E 's/^\[\[//; s/\]\]$//')
done < <(find wiki -name '*.md' 2>/dev/null)   # only wiki notes: root docs use [[...]] illustratively
if [[ -n "$broken" ]]; then
  echo "[broken wikilinks]"; printf '%s' "$broken"; issues=$((issues+1))
else
  echo "[broken wikilinks] none"
fi

# --- 2. orphan wiki notes (entry notes index/CRITICAL_FACTS are exempt) ---
orphans=""
while IFS= read -r f; do
  [[ -z "$f" ]] && continue
  base="$(base_of "$f")"
  in_set "$base" "$REFERENCED" || orphans+="  $f"$'\n'
done < <(find wiki -name '*.md' 2>/dev/null)
if [[ -n "$orphans" ]]; then
  echo "[orphan notes]"; printf '%s' "$orphans"; issues=$((issues+1))
else
  echo "[orphan notes] none"
fi

# --- 3. stale claims ("(as of YYYY-MM") older than STALE_MONTHS ---
stale=""
cy="$(date +%Y)"; cm="$(date +%m)"
while IFS= read -r hit; do
  [[ -z "$hit" ]] && continue
  f="${hit%%:*}"
  ym="$(printf '%s' "$hit" | grep -oE '[0-9]{4}-[0-9]{2}' | head -1)"
  [[ -z "$ym" ]] && continue
  yy="${ym%-*}"; mm="${ym#*-}"
  months=$(( (10#$cy - 10#$yy) * 12 + (10#$cm - 10#$mm) ))
  (( months > STALE_MONTHS )) && stale+="  $f -> (as of $ym, ${months} months old)"$'\n'
done < <(grep -rEo '\(as of [0-9]{4}-[0-9]{2}' wiki "${roots[@]}" 2>/dev/null)
if [[ -n "$stale" ]]; then
  echo "[stale claims]"; printf '%s' "$stale"; issues=$((issues+1))
else
  echo "[stale claims] none"
fi

echo "=== $issues issue group(s) found ==="
echo "Note: contradictions between notes need a semantic pass — ask Claude to \"lint the brain\"."
[[ "$issues" -eq 0 ]] && exit 0 || exit 1
