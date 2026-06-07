#!/usr/bin/env bash
# SessionStart hook — injects project doc context into agent sessions (read-only)
set -euo pipefail

DOCS_ROOT="${DOCS_ROOT:-agents-docs}"
CHANGELOG="${CHANGELOG:-CHANGELOG.md}"

printf "=== Project Context ===\n"
printf "Docs root : %s\n" "$DOCS_ROOT"

# Print doc structure map
if [[ -d "$DOCS_ROOT" ]]; then
  printf -- "--- Docs Map ---\n"
  find -- "$DOCS_ROOT" -maxdepth 2 -type f -name '*.md' | sort
fi

# Print latest changelog entry
if [[ -f "$CHANGELOG" ]]; then
  printf -- "--- Latest Changelog Entry ---\n"
  awk '/^## /{count++; if(count==2) exit} count==1{print}' "$CHANGELOG"
fi

printf "=====================\n"
