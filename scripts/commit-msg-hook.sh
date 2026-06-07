#!/usr/bin/env bash
# Git commit-msg hook.
# Validates the commit message against commitlint rules.
# Install: cp scripts/commit-msg-hook.sh .git/hooks/commit-msg && chmod +x .git/hooks/commit-msg
set -euo pipefail

if [[ "${SKIP_COMMIT_MSG_CHECK:-false}" == "true" ]]; then
    printf 'commit-msg hook skipped (SKIP_COMMIT_MSG_CHECK=true)\n'
    exit 0
fi

COMMIT_MSG_FILE="${1:-}"
if [[ -z "$COMMIT_MSG_FILE" ]] || [[ ! -f "$COMMIT_MSG_FILE" ]]; then
    printf 'commit-msg: missing or invalid commit message file\n' >&2
    exit 1
fi

REPO_ROOT="$(git rev-parse --show-toplevel)"
VALIDATOR="$REPO_ROOT/scripts/validate-commit-message.sh"

if [[ ! -f "$VALIDATOR" ]]; then
    printf 'commit-msg: validator not found at %s\n' "$VALIDATOR" >&2
    printf 'commit-msg: skipping check (install with ./scripts/bootstrap.sh)\n'
    exit 0
fi

FIRST_LINE=$(head -n 1 "$COMMIT_MSG_FILE")

if [[ "$FIRST_LINE" == "Merge "* ]] || [[ "$FIRST_LINE" == "Revert "* ]] || [[ "$FIRST_LINE" == "fixup! "* ]] || [[ "$FIRST_LINE" == "squash! "* ]]; then
    printf 'commit-msg: skipping check for %s message\n' "${FIRST_LINE%% *}"
    exit 0
fi

if ! "$VALIDATOR" "$COMMIT_MSG_FILE"; then
    printf '\n' >&2
    printf 'Commit aborted: message does not match commitlint rules.\n' >&2
    printf 'Expected: type(scope): subject (max %s chars)\n' "${MAX_COMMIT_SUBJECT_LENGTH:-150}" >&2
    printf 'Types: feat, fix, docs, style, refactor, perf, test, ci, chore\n' >&2
    printf 'Bypass with SKIP_COMMIT_MSG_CHECK=true (not recommended).\n' >&2
    exit 1
fi

printf 'commit-msg: OK\n'
exit 0
