#!/usr/bin/env bash
# SessionStart hook — injects compact project context into agent sessions (read-only)
# Keep this thin: full doc trees belong behind progressive disclosure (skills/docs),
# not in every session start (see agents-docs/HARNESS.md).
set -euo pipefail

DOCS_ROOT="${DOCS_ROOT:-agents-docs}"
CHANGELOG="${CHANGELOG:-CHANGELOG.md}"

printf "=== Project Context ===\n"
printf "Docs root : %s\n" "$DOCS_ROOT"
printf "Canonical : AGENTS.md | skills: .agents/skills/ | plans: plans/\n"

# Top-level docs only (avoid dumping every nested markdown path)
if [[ -d "$DOCS_ROOT" ]]; then
  printf -- "--- Docs index (top-level) ---\n"
  find -- "$DOCS_ROOT" -maxdepth 1 -type f -name '*.md' | sort | head -n 30
  printf "Full map when needed: find %s -maxdepth 2 -type f -name '*.md'\n" "$DOCS_ROOT"
  if [[ -f "$DOCS_ROOT/ADOPTION_PROFILES.md" ]]; then
    printf "Adoption: %s/ADOPTION_PROFILES.md\n" "$DOCS_ROOT"
  fi
fi

# Print latest changelog entry
if [[ -f "$CHANGELOG" ]]; then
  printf -- "--- Latest Changelog Entry ---\n"
  awk '/^## /{count++; if(count==2) exit} count==1{print}' "$CHANGELOG"
fi

printf "=====================\n"
