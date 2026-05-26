#!/usr/bin/env bash
# Lightweight docs sync via git hooks - minimal tokens
set -euo pipefail

REPO_ROOT="$(cd "$(dirname "${BASH_SOURCE[0]}")/.."; pwd)"
LAST_COMMIT="${1:-HEAD~1}"
CURRENT="${2:-HEAD}"

# Security: Use printf for safe variable output
printf "Syncing docs %s → %s\n" "$LAST_COMMIT" "$CURRENT"

# Security: Use -- separator to prevent option injection from malicious branch names
diff_output=$(git diff --name-only -- "$LAST_COMMIT" "$CURRENT" -- '*.md' 2>/dev/null || true)

while IFS= read -r file; do
  # Security: Use printf for safe variable output
  [[ -n "$file" && -f "$REPO_ROOT/$file" ]] && printf "Updated: %s\n" "$file"
done <<< "$diff_output"

if [ -z "$diff_output" ]; then
    count=0
else
    # Security: Use printf to pipe variable content safely
    count=$(printf "%s\n" "$diff_output" | wc -l || true)
fi
printf "Done. %s files.\n" "$count"
