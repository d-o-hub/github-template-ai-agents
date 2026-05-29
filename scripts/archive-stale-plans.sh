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
CUTOFF_DATE=$(date -d "@$((NOW_SECONDS - SIXTY_DAYS_SECONDS))" +%Y-%m-%d)

if [[ ! -d "$ARCHIVE_DIR" ]]; then
  echo "  (Skipping archive: plans/archive/ directory not found)"
  exit 0
fi

# Performance optimization: Use a bash array to collect files to move,
# and use bash parameter expansion, regex, and native bash globbing instead of subshells.
files_to_move=()

shopt -s nullglob
for file in "$PLANS_DIR"/*-progress-update-*.md; do
  # Use parameter expansion instead of basename
  filename="${file##*/}"

  # Extract date using bash regex instead of echo | sed
  if [[ "$filename" =~ -([0-9]{4}-[0-9]{2}-[0-9]{2})\.md$ ]]; then
    file_date="${BASH_REMATCH[1]}"
  else
    continue
  fi

  # Lexicographical comparison of ISO 8601 dates works perfectly
  if [[ "$file_date" < "$CUTOFF_DATE" ]]; then
    # We will do a batched move, but we should also handle the "already exists" case
    # to maintain exactly the same behavior as before
    if [[ -f "$ARCHIVE_DIR/$filename" ]]; then
      printf "  ~ %s already exists in archive, skipped\n" "$filename"
    else
      files_to_move+=("$file")
    fi
  fi
done
shopt -u nullglob

# Batch move files if any
if [[ ${#files_to_move[@]} -gt 0 ]]; then
  # mv -n won't overwrite existing files anyway, but we already checked above
  if mv -n -- "${files_to_move[@]}" "$ARCHIVE_DIR/" 2>/dev/null; then
    MOVED_COUNT=${#files_to_move[@]}
  fi
fi

if [[ $MOVED_COUNT -eq 0 ]]; then
  echo "No stale plans to archive."
else
  echo "Archived $MOVED_COUNT stale plan(s)."
fi
