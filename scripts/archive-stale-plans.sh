#!/usr/bin/env bash
# ============================================================================
# archive-stale-plans.sh — Archive Stale Progress Updates
# ============================================================================
#
# Moves progress updates from plans/ to plans/archive/ when they are
# older than 60 days. Date is parsed from the filename pattern:
#   NNN-progress-update-YYYY-MM-DD.md
#
# Usage:
#   ./scripts/archive-stale-plans.sh
# ============================================================================

set -euo pipefail

REPO_ROOT="$(cd "$(dirname "${BASH_SOURCE[0]}")/../" && pwd)"
PLANS_DIR="$REPO_ROOT/plans"
ARCHIVE_DIR="$PLANS_DIR/archive"
MOVED_COUNT=0
NOW_SECONDS=$(date +%s)
SIXTY_DAYS_SECONDS=$((60 * 24 * 60 * 60))

if [[ ! -d "$ARCHIVE_DIR" ]]; then
  echo "  (Skipping archive: plans/archive/ directory not found)"
  exit 0
fi

while IFS= read -r -d '' file; do
  filename=$(basename "$file")
  file_date=$(echo "$filename" | sed -n 's/.*-\([0-9]\{4\}-[0-9]\{2\}-[0-9]\{2\}\).*/\1/p')

  if [[ -z "$file_date" ]]; then continue; fi

  file_seconds=$(date -d "$file_date" +%s 2>/dev/null) || continue
  age_seconds=$((NOW_SECONDS - file_seconds))

  if [[ $age_seconds -gt $SIXTY_DAYS_SECONDS ]]; then
    if mv -n "$file" "$ARCHIVE_DIR/$filename" 2>/dev/null; then
      MOVED_COUNT=$((MOVED_COUNT + 1))
    else
      echo "  ~ $filename already exists in archive, skipped"
    fi
  fi
done < <(find "$PLANS_DIR" -maxdepth 1 -name '*-progress-update-*.md' -print0)

if [[ $MOVED_COUNT -eq 0 ]]; then
  echo "No stale plans to archive."
else
  echo "Archived $MOVED_COUNT stale plan(s)."
fi
