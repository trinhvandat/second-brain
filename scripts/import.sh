#!/usr/bin/env bash
# Usage: import.sh <path-to-file>  -> copies into raw/inbox/ with frontmatter, prints dest path
set -euo pipefail
cd "$(dirname "$0")/.."

SRC="${1:?usage: import.sh <file>}"
[[ -f "$SRC" ]] || { echo "not a file: $SRC" >&2; exit 1; }

TS="$(date +%Y-%m-%d-%H%M)"
BASE="$(basename "$SRC")"
SLUG="$(echo "${BASE%.*}" | tr '[:upper:] ' '[:lower:]-' | tr -cd 'a-z0-9-')"
DEST="raw/inbox/${TS}-${SLUG:-note}.md"

mkdir -p "$(dirname "$DEST")"
{
  echo "---"
  echo "source: \"$SRC\""
  echo "captured_at: $TS"
  echo "status: raw"
  echo "---"
  echo
  cat "$SRC"
} > "$DEST"

echo "$DEST"
