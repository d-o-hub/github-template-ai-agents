#!/bin/bash
# Script: validate-skill-format.sh
# Purpose: Validate SKILL.md files have correct frontmatter format

set -euo pipefail

ERRORS=0
WARNINGS=0

log_error() {
    echo "[ERROR] $1"
    ERRORS=$((ERRORS + 1))
}

log_warning() {
    echo "[WARN] $1"
    WARNINGS=$((WARNINGS + 1))
}

log_ok() {
    echo "[OK] $1"
}

validate_skill() {
    local skill_file="$1"
    local skill_name
    skill_name=$(basename "$(dirname "$skill_file")")
    
    # Check file starts with ---
    local first_line
    first_line=$(head -n 1 "$skill_file" 2>/dev/null || echo "")
    if [[ "$first_line" != "---" ]]; then
        log_error "$skill_name: SKILL.md must start with '---' (found: '$first_line')"
        return 0
    fi
    
    # Check for heading before frontmatter
    local second_line
    second_line=$(sed -n '2p' "$skill_file" 2>/dev/null || echo "")
    if [[ "$second_line" == \#* ]]; then
        log_error "$skill_name: Found heading before frontmatter"
        return 0
    fi
    
    # Check required fields
    if ! grep -q "^name:" "$skill_file" 2>/dev/null; then
        log_error "$skill_name: Missing 'name:' field"
    fi
    
    if ! grep -q "^description:" "$skill_file" 2>/dev/null; then
        log_error "$skill_name: Missing 'description:' field"
    fi
    
    # Check recommended license field
    if ! grep -q "^license:" "$skill_file" 2>/dev/null; then
        log_warning "$skill_name: Missing 'license:' field"
    fi
    
    # Check frontmatter closure
    local fm_count=0
    fm_count=$(grep -c "^---$" "$skill_file" 2>/dev/null || echo 0)
    if [[ $fm_count -lt 2 ]]; then
        log_error "$skill_name: Frontmatter not closed (found $fm_count '---')"
    fi
    
    # Check file size
    local line_count=0
    line_count=$(wc -l < "$skill_file" 2>/dev/null || echo 0)
    if [[ $line_count -gt 250 ]]; then
        log_warning "$skill_name: Exceeds 250 lines ($line_count)"
    fi
    
    # Check evals directory
    local skill_dir
    skill_dir=$(dirname "$skill_file")
    if [[ ! -d "$skill_dir/evals" ]]; then
        log_warning "$skill_name: No evals/ directory"
    elif [[ ! -f "$skill_dir/evals/evals.json" ]]; then
        log_warning "$skill_name: No evals/evals.json"
    fi
    
    if [[ $ERRORS -eq 0 ]]; then
        log_ok "$skill_name: Valid ($line_count lines)"
    fi
}

# Main
SKILLS_DIR="${1:-.agents/skills}"

echo "=== Validating SKILL.md Format ==="
echo ""

if [[ ! -d "$SKILLS_DIR" ]]; then
    echo "Skills directory not found: $SKILLS_DIR"
    exit 1
fi

for skill_dir in "$SKILLS_DIR"/*/; do
    if [[ -d "$skill_dir" ]]; then
        skill_file="${skill_dir}SKILL.md"
        if [[ -f "$skill_file" ]]; then
            validate_skill "$skill_file"
        else
            skill_name=$(basename "$skill_dir")
            log_error "$skill_name: Missing SKILL.md"
        fi
    fi
done

echo ""
if [[ $ERRORS -eq 0 ]]; then
    echo "All SKILL.md files passed validation"
    exit 0
else
    echo "Found $ERRORS errors, $WARNINGS warnings"
    exit 1
fi
