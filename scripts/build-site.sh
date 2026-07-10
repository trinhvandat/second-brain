#!/usr/bin/env bash
# Sync the publishable vault notes into the Quartz content directory.
#
# The website (site/, Quartz 4/5) publishes a SUBSET of the vault:
#   - wiki/concepts, wiki/entities, wiki/tech, wiki/journal   (compiled notes)
#   - site/homepage.md  -> content/index.md                   (custom landing page)
# Explicitly EXCLUDED: wiki/archive/ (retired notes), raw/ (private source captures),
# and everything else in the repo.
#
# This is the single source of truth for "what gets published" — used by both local
# dev (`./scripts/build-site.sh && cd site && npx quartz build --serve`) and CI.
#
# site/content/ is regenerated from scratch on every run and is git-ignored.
#
# Usage: build-site.sh
# Exit:  0 = synced, 2 = bad environment.
set -uo pipefail

REPO="$(cd "$(dirname "$0")/.." && pwd)"
SITE="$REPO/site"
CONTENT="$SITE/content"

[[ -d "$SITE" ]] || { echo "build-site: '$SITE' not found (is Quartz installed?)" >&2; exit 2; }
[[ -f "$SITE/homepage.md" ]] || { echo "build-site: missing site/homepage.md" >&2; exit 2; }

# Keep the generated content/ out of `git status` WITHOUT a committed .gitignore
# entry (Quartz globs with gitignore:true, so a tracked ignore would make the build
# skip every note). .git/info/exclude is local-only and invisible to Quartz's glob.
GIT_DIR="$(cd "$REPO" && git rev-parse --git-dir 2>/dev/null || true)"
if [[ -n "$GIT_DIR" ]]; then
  EXCLUDE="$REPO/$GIT_DIR/info/exclude"
  mkdir -p "$(dirname "$EXCLUDE")"
  grep -qxF 'site/content/' "$EXCLUDE" 2>/dev/null || echo 'site/content/' >> "$EXCLUDE"
fi

# Folders under wiki/ to publish (archive/ deliberately omitted).
PUBLISH_DIRS="concepts entities tech journal"

echo "build-site: rebuilding $CONTENT"
rm -rf "$CONTENT"
mkdir -p "$CONTENT"

for d in $PUBLISH_DIRS; do
  src="$REPO/wiki/$d"
  [[ -d "$src" ]] || { echo "  skip wiki/$d (not found)"; continue; }
  # Copy the folder, then drop .gitkeep placeholders that would become empty pages.
  cp -R "$src" "$CONTENT/$d"
  find "$CONTENT/$d" -name '.gitkeep' -delete 2>/dev/null
  count=$(find "$CONTENT/$d" -name '*.md' | wc -l | tr -d ' ')
  echo "  + wiki/$d ($count notes)"
done

# Landing page.
cp "$SITE/homepage.md" "$CONTENT/index.md"
echo "  + homepage.md -> index.md"

total=$(find "$CONTENT" -name '*.md' | wc -l | tr -d ' ')
echo "build-site: $total pages ready in site/content/"
