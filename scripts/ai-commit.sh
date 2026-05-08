#!/usr/bin/env bash
# Helper for AI agents to create valid conventional commits.
# Usage: ./scripts/ai-commit.sh --type <type> [--scope <scope>] --subject <subject> [--body <body> ...]

set -euo pipefail

TYPE=""
SCOPE=""
SUBJECT=""
BODIES=()

while [[ $# -gt 0 ]]; do
  case $1 in
    --type)
      TYPE="$2"
      shift 2
      ;;
    --scope)
      SCOPE="$2"
      shift 2
      ;;
    --subject)
      SUBJECT="$2"
      shift 2
      ;;
    --body)
      BODIES+=("$2")
      shift 2
      ;;
    *)
      echo "Unknown option: $1"
      exit 1
      ;;
  esac
done

if [ -z "$TYPE" ] || [ -z "$SUBJECT" ]; then
    echo "Usage: $0 --type <type> [--scope <scope>] --subject <subject> [--body <body> ...]"
    exit 1
fi

if [ ${#SUBJECT} -gt 72 ]; then
    echo "Error: Subject is too long (${#SUBJECT} > 72 chars)."
    exit 1
fi

# Build subject line
SUBJECT_LINE="${TYPE}"
if [ -n "$SCOPE" ]; then
    SUBJECT_LINE="${SUBJECT_LINE}(${SCOPE})"
fi
SUBJECT_LINE="${SUBJECT_LINE}: ${SUBJECT}"

# Create temp file
TMP_MSG=$(mktemp)

# Use printf to write the subject line literally (preventing escape sequence expansion)
printf "%s\n" "$SUBJECT_LINE" > "$TMP_MSG"

# Add bodies if present
if [ ${#BODIES[@]} -gt 0 ]; then
    # Add mandatory blank line after subject
    printf "\n" >> "$TMP_MSG"
    for BODY in "${BODIES[@]}"; do
        # Wrap body to 100 chars - use printf to handle variables safely
        WRAPPED_BODY=$(printf "%s" "$BODY" | fold -s -w 100)
        printf "%s\n\n" "$WRAPPED_BODY" >> "$TMP_MSG"
    done
fi

# Validate
REPO_ROOT="$(git rev-parse --show-toplevel)"
if ! "$REPO_ROOT/scripts/validate-commit-message.sh" "$TMP_MSG"; then
    echo "Commit message validation failed."
    rm "$TMP_MSG"
    exit 1
fi

# Commit
git commit -F "$TMP_MSG"
rm "$TMP_MSG"
