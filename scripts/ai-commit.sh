#!/usr/bin/env bash
# Helper for AI agents to create valid conventional commits.
# Usage: ./scripts/ai-commit.sh --type <type> [--scope <scope>] --subject <subject> [--body <body> ...]

set -euo pipefail

# Configuration
readonly BODY_WRAP_WIDTH=100

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

if [[ -z "$TYPE" ]] || [[ -z "$SUBJECT" ]]; then
    echo "Usage: $0 --type <type> [--scope <scope>] --subject <subject> [--body <body> ...]"
    exit 1
fi

if [[ ${#SUBJECT} -gt 72 ]]; then
    echo "Error: Subject is too long (${#SUBJECT} > 72 chars)." >&2
    exit 1
fi

# Build message
MSG="${TYPE}"
if [[ -n "$SCOPE" ]]; then
    MSG="${MSG}(${SCOPE})"
fi
MSG="${MSG}: ${SUBJECT}"

# Add blank line and bodies
if [[ ${#BODIES[@]} -gt 0 ]]; then
    MSG="${MSG}"$'\n'
    for BODY in "${BODIES[@]}"; do
        # Wrap body to $BODY_WRAP_WIDTH chars
        # Security: Use printf for safe variable expansion and prevent option injection
        WRAPPED_BODY=$(printf "%s\n" "$BODY" | fold -s -w "$BODY_WRAP_WIDTH")
        MSG="${MSG}"$'\n'"${WRAPPED_BODY}"$'\n'
    done
fi

# Create temp file
TMP_MSG=$(mktemp)
# Security: Ensure cleanup of temporary commit message file
trap 'rm -f "$TMP_MSG"' EXIT ERR

# Security: Use printf for safe variable writing and to prevent backslash interpretation (structural injection)
printf "%s\n" "$MSG" > "$TMP_MSG"

# Validate
REPO_ROOT="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
if ! "$REPO_ROOT/scripts/validate-commit-message.sh" "$TMP_MSG"; then
    echo "Commit message validation failed."
    exit 1
fi

# Commit
git commit -F "$TMP_MSG"
