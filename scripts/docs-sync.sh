#!/usr/bin/env bash
# Lightweight docs sync via git hooks - minimal tokens
set -euo pipefail

REPO_ROOT="$(cd "$(dirname "${BASH_SOURCE[0]}")/.."; pwd)"
LAST_COMMIT="${1:-HEAD~1}"
CURRENT="${2:-HEAD}"

echo "Syncing docs $LAST_COMMIT → $CURRENT"

diff_output=$(git diff --name-only "$LAST_COMMIT" "$CURRENT" -- '*.md' 2>/dev/null || true)

while IFS= read -r file; do
  [[ -n "$file" && -f "$REPO_ROOT/$file" ]] && echo "Updated: $file"
done <<< "$diff_output"

if [ -z "$diff_output" ]; then
    count=0
else
    count=$(printf "%s\n" "$diff_output" | wc -l || true)
fi
echo "Done. $count files."