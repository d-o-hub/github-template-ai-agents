#!/usr/bin/env bash
# Lightweight docs sync via git hooks - minimal tokens
set -euo pipefail

REPO_ROOT="$(cd "$(dirname "${BASH_SOURCE[0]}")/.."; pwd)"
LAST_COMMIT="${1:-HEAD~1}"
CURRENT="${2:-HEAD}"

# Security: Use printf for safe variable output
printf "Syncing docs %s → %s\n" "$LAST_COMMIT" "$CURRENT"

# Security: Use -- separator BEFORE revisions to prevent option injection from malicious revision names
diff_output=$(git diff --name-only -- "$LAST_COMMIT" "$CURRENT" -- '*.md' 2>/dev/null || true)

old_opts="$-"
set -f
old_ifs="$IFS"
IFS=$'\n'
diff_array=($diff_output)
IFS="$old_ifs"
[[ "$old_opts" != *f* ]] && set +f

for file in "${diff_array[@]}"; do
  # Security: Use printf for safe variable output
  [[ -n "$file" && -f "$REPO_ROOT/$file" ]] && printf "Updated: %s\n" "$file"
done

if [[ ${#diff_array[@]} -eq 0 && -z "${diff_array[0]:-}" ]]; then
    count=0
else
    # Security: Use printf to pipe variable content safely
    count=$(printf "%s\n" "$diff_output" | wc -l || true)
fi
printf "Done. %s files.\n" "$count"
