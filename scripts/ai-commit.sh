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

# Build message
MSG="${TYPE}"
if [ -n "$SCOPE" ]; then
    MSG="${MSG}(${SCOPE})"
fi
MSG="${MSG}: ${SUBJECT}"

# Add blank line and bodies
if [ ${#BODIES[@]} -gt 0 ]; then
    MSG="${MSG}\n"
    for BODY in "${BODIES[@]}"; do
        # Wrap body to 100 chars
        WRAPPED_BODY=$(echo "$BODY" | fold -s -w 100)
        MSG="${MSG}\n${WRAPPED_BODY}\n"
    done
fi

# Create temp file
TMP_MSG=$(mktemp)
echo -e "$MSG" > "$TMP_MSG"

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
