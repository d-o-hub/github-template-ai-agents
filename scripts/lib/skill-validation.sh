#!/usr/bin/env bash
# lib/skill-validation.sh - Shared skill validation functions
# Source this file from other validation scripts.
# Usage: source "$(dirname "${BASH_SOURCE[0]}")/lib/skill-validation.sh"

REPO_ROOT="${REPO_ROOT:-$(cd "$(dirname "${BASH_SOURCE[0]}")/../.." && pwd)}"
SKILLS_SRC="$REPO_ROOT/.agents/skills"
MAX_SKILL_LINES=${MAX_SKILL_LINES:-250}

# Color codes
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[0;33m'
NC='\033[0m'

# Validate a single SKILL.md file for format correctness
# Returns 0 if valid, 1 if invalid (prints errors to stderr)
validate_skill_file() {
    local skill_file="$1"
    local skill_name
    skill_name="$(basename "$(dirname "$skill_file")")"
    local errors=0

    # Check exists
    if [[ ! -f "$skill_file" ]]; then
        echo -e "  ${RED}✗${NC} $skill_name: Missing SKILL.md" >&2
        return 1
    fi

    # Check starts with ---
    local first
    first=$(head -1 "$skill_file")
    if [[ "$first" != "---" ]]; then
        echo -e "  ${RED}✗${NC} $skill_name: Must start with '---'" >&2
        ((errors++))
    fi

    # Check has name field
    if ! grep -q "^name:" "$skill_file" 2>/dev/null; then
        echo -e "  ${RED}✗${NC} $skill_name: Missing 'name:' field" >&2
        ((errors++))
    fi

    # Check has description field
    if ! grep -q "^description:" "$skill_file" 2>/dev/null; then
        echo -e "  ${RED}✗${NC} $skill_name: Missing 'description:' field" >&2
        ((errors++))
    fi

    # Check line count
    local line_count
    line_count=$(wc -l < "$skill_file" | tr -d ' ')
    if [[ "$line_count" -gt "$MAX_SKILL_LINES" ]]; then
        echo -e "  ${RED}✗${NC} $skill_name: SKILL.md exceeds $MAX_SKILL_LINES lines ($line_count lines)" >&2
        ((errors++))
    fi

    return $errors
}
