#!/usr/bin/env bash
# Helper for AI agents to create valid conventional commits.
# Usage: ./scripts/ai-commit.sh --type <type> [--scope <scope>] --subject <subject> [--body <body> ...]

set -euo pipefail

# Configuration
BODY_WRAP_WIDTH=100

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

# Build message
MSG="${TYPE}"
if [ -n "$SCOPE" ]; then
    MSG="${MSG}(${SCOPE})"
fi
MSG="${MSG}: ${SUBJECT}"

# Add blank line and bodies
if [ ${#BODIES[@]} -gt 0 ]; then
    MSG="${MSG}"$'\n'
    for BODY in "${BODIES[@]}"; do
        # Wrap body to prevent long lines in commit message
        # Use printf to prevent option injection if BODY starts with -
        WRAPPED_BODY=$(printf "%s\n" "$BODY" | fold -s -w "$BODY_WRAP_WIDTH")
        MSG="${MSG}"$'\n'"${WRAPPED_BODY}"$'\n'
    done
fi

# Create temp file and ensure cleanup
TMP_MSG=$(mktemp)
trap 'rm -f "$TMP_MSG"' EXIT ERR

# Use printf %s to prevent interpretation of backslash escapes in user content
printf "%s\n" "$MSG" > "$TMP_MSG"

# Validate
REPO_ROOT="$(git rev-parse --show-toplevel)"
if ! "$REPO_ROOT/scripts/validate-commit-message.sh" "$TMP_MSG"; then
    echo "Commit message validation failed."
    exit 1
fi

# Commit
git commit -F "$TMP_MSG"
