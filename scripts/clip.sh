#!/usr/bin/env bash
# Usage:
#   clip.sh <url>            -> fetch URL, save Markdown stub into raw/web/, print dest
#   clip.sh --dry-run <url>  -> only print computed dest path + frontmatter, no network
# Conversion: uses `pandoc` if available; else saves a stub for Claude to fetch via WebFetch.
set -euo pipefail
cd "$(dirname "$0")/.."

DRY=0
if [[ "${1:-}" == "--dry-run" ]]; then DRY=1; shift; fi
URL="${1:?usage: clip.sh [--dry-run] <url>}"

TS="$(date +%Y-%m-%d)"
# slug from last path segment for readability
LASTSEG="$(echo "$URL" | sed -E 's#/+$##; s#.*/##; s#\?.*##; s#\.[a-z]+$##')"
SLUG="$(echo "${LASTSEG:-clip}" | tr '[:upper:] ' '[:lower:]-' | tr -cd 'a-z0-9-')"
DEST="raw/web/${TS}-${SLUG:-clip}.md"

frontmatter() {
  echo "---"
  echo "source: $URL"
  echo "captured_at: $(date +%Y-%m-%d-%H%M)"
  echo "status: raw"
  echo "---"
}

if [[ "$DRY" == "1" ]]; then
  echo "$DEST"
  frontmatter
  exit 0
fi

{
  frontmatter
  echo
  if command -v pandoc >/dev/null 2>&1; then
    curl -fsSL "$URL" | pandoc -f html -t markdown 2>/dev/null || echo "<!-- fetch/convert failed; Claude: WebFetch $URL -->"
  else
    echo "<!-- pandoc not installed. Claude: WebFetch $URL and replace this stub. -->"
    echo "URL: $URL"
  fi
} > "$DEST"

echo "$DEST"
