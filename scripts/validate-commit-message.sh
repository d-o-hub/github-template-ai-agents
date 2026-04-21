#!/usr/bin/env bash
# Validate a commit message using commitlint.
# Usage: ./scripts/validate-commit-message.sh <commit-msg-file>

set -euo pipefail

COMMIT_MSG_FILE="${1:-}"

if [ -z "$COMMIT_MSG_FILE" ]; then
    echo "Error: No commit message file specified."
    echo "Usage: $0 <commit-msg-file>"
    exit 1
fi

if [ ! -f "$COMMIT_MSG_FILE" ]; then
    echo "Error: Commit message file not found: $COMMIT_MSG_FILE"
    exit 1
fi

# Run commitlint
if ! npx commitlint --edit "$COMMIT_MSG_FILE"; then
    exit 1
fi

exit 0
