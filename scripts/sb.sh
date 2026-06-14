#!/usr/bin/env bash
# Quick text capture — zero friction.
#   sb.sh some thought I want to keep
#   echo "longer note" | sb.sh
# Writes a raw/inbox/ note (status: raw) and prints the destination path.
set -uo pipefail
cd "$(dirname "$0")/.."

if [[ "$#" -gt 0 ]]; then TEXT="$*"; else TEXT="$(cat)"; fi
TEXT="${TEXT#"${TEXT%%[![:space:]]*}"}"   # ltrim
[[ -z "$TEXT" ]] && { echo "usage: sb.sh <text>   (or pipe text via stdin)" >&2; exit 1; }

TS="$(date +%Y-%m-%d-%H%M)"
SLUG="$(printf '%s' "$TEXT" | tr '[:upper:] ' '[:lower:]-' | tr -cd 'a-z0-9-' | cut -c1-40)"
SLUG="${SLUG%-}"
DEST="raw/inbox/${TS}-${SLUG:-note}.md"

mkdir -p raw/inbox
{
  echo "---"
  echo "source: \"quick capture (sb)\""
  echo "captured_at: $TS"
  echo "status: raw"
  echo "---"
  echo
  printf '%s\n' "$TEXT"
} > "$DEST"

echo "$DEST"
