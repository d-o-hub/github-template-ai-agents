#!/bin/bash
# Script: validate-skill-format.sh
# Purpose: Validate SKILL.md files have correct frontmatter format
# Usage: ./scripts/validate-skill-format.sh [skill-path]

set -euo pipefail

RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
NC='\033[0m'

ERRORS=0
WARNINGS=0

log_error() {
    echo -e "${RED}[ERROR]${NC} $1"
    ERRORS=$((ERRORS + 1))
}

log_warning() {
    echo -e "${YELLOW}[WARN]${NC} $1"
    WARNINGS=$((WARNINGS + 1))
}

log_info() {
    echo -e "${GREEN}[OK]${NC} $1"
}

validate_skill() {
    local skill_file="$1"
    local skill_name
    skill_name=$(basename "$(dirname "$skill_file")")
    
    # Check file exists
    if [[ ! -f "$skill_file" ]]; then
        log_error "SKILL.md not found for $skill_name"
        return 0
    fi
    
    # Check file starts with frontmatter delimiter
    local first_line
    first_line=$(head -1 "$skill_file")
    if [[ "$first_line" != "---" ]]; then
        log_error "$skill_name: SKILL.md must start with '---' (frontmatter delimiter)"
        log_error "  First line is: '$first_line'"
        return 0
    fi
    
    # Check for content before frontmatter (second line should be name: or empty, not a heading)
    local second_line
    second_line=$(sed -n '2p' "$skill_file")
    if [[ "$second_line" == "# "* ]]; then
        log_error "$skill_name: Found heading before frontmatter. Move frontmatter to the very beginning."
        return 0
    fi
    
    # Check for required fields in frontmatter
    if ! grep -q "^name:" "$skill_file"; then
        log_error "$skill_name: Missing required 'name:' field in frontmatter"
    fi
    
    if ! grep -q "^description:" "$skill_file"; then
        log_error "$skill_name: Missing required 'description:' field in frontmatter"
    else
        # Check description isn't too long (max 1024 chars as per skill-creator)
        local desc
        desc=$(sed -n '/^description:/,/^[^ ]/p' "$skill_file" | head -n -1)
        if [[ ${#desc} -gt 1024 ]]; then
            log_warning "$skill_name: description exceeds 1024 characters (${#desc} chars)"
        fi
    fi
    
    # Check for recommended fields
    if ! grep -q "^license:" "$skill_file"; then
        log_warning "$skill_name: Missing recommended 'license:' field"
    fi
    
    # Check for proper frontmatter closure (second ---)
    local fm_count
    fm_count=$(grep -c "^---$" "$skill_file" || true)
    if [[ $fm_count -lt 2 ]]; then
        log_error "$skill_name: Frontmatter not properly closed (missing second '---')"
    fi
    
    # Check file size (should be under 250 lines per skill-creator)
    local line_count
    line_count=$(wc -l < "$skill_file")
    if [[ $line_count -gt 250 ]]; then
        log_warning "$skill_name: SKILL.md exceeds 250 lines ($line_count lines). Consider moving content to references/"
    fi
    
    # Check for evals directory
    local skill_dir
    skill_dir=$(dirname "$skill_file")
    if [[ ! -d "$skill_dir/evals" ]]; then
        log_warning "$skill_name: Missing evals/ directory"
    elif [[ ! -f "$skill_dir/evals/evals.json" ]]; then
        log_warning "$skill_name: Missing evals/evals.json"
    fi
    
    if [[ $ERRORS -eq 0 ]]; then
        log_info "$skill_name: Valid format ($line_count lines)"
    fi
}

# Main execution
SKILLS_DIR="${1:-.agents/skills}"

echo "=== Validating SKILL.md Format ==="
echo ""

# Check if directory exists
if [[ ! -d "$SKILLS_DIR" ]]; then
    log_error "Skills directory not found: $SKILLS_DIR"
    exit 1
fi

# Count total skills
total=0
for skill_dir in "$SKILLS_DIR"/*/; do
    if [[ -d "$skill_dir" ]]; then
        ((total++)) || true
    fi
done

echo "Found $total skills to validate"
echo ""

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
echo "=== Summary ==="
if [[ $ERRORS -eq 0 ]]; then
    echo -e "${GREEN}All SKILL.md files passed format validation${NC}"
    exit 0
else
    echo -e "${RED}Found $ERRORS errors, $WARNINGS warnings${NC}"
    echo ""
    echo "Common fixes:"
    echo "  1. SKILL.md must start with '---' (no content before frontmatter)"
    echo "  2. Required fields: name, description"
    echo "  3. Recommended fields: license"
    echo "  4. Frontmatter must be closed with second '---'"
    exit 1
fi
