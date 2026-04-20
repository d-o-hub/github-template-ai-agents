#!/usr/bin/env bash
# Validates all CLI skill symlinks and SKILL.md files.
# Used in pre-commit hook and CI. Exit 2 on failure (surfaced to agent).
# Note: OpenCode reads directly from .agents/skills/ - no symlinks to validate.
# NOTE: errexit disabled explicitly - it causes unpredictable failures in CI
set +e
set -uo pipefail

# Color codes for output
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[0;33m'
NC='\033[0m' # No Color

REPO_ROOT="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
SKILLS_SRC="$REPO_ROOT/.agents/skills"

CLI_SKILL_DIRS=(
  ".claude/skills"
  ".gemini/skills"
  ".qwen/skills"
)

FAILED=0
WARNINGS=0

# Configuration
MAX_SKILL_LINES=${MAX_SKILL_LINES:-250}

echo "Validating skills..."
echo ""

# If no skills exist, nothing to validate
if [ ! -d "$SKILLS_SRC" ] || [ -z "$(ls -A "$SKILLS_SRC" 2>/dev/null)" ]; then
    echo "No skills in .agents/skills/ - nothing to validate."
    exit 0
fi

# --- Validate canonical skills in .agents/skills/ ---
echo "Checking canonical skills in .agents/skills/..."

# Read current version once
CURRENT_VERSION=$(cat "$REPO_ROOT/VERSION" 2>/dev/null | tr -d '[:space:]')

for skill_path in "$SKILLS_SRC"/*/; do
    [ -d "$skill_path" ] || continue
    # Performance optimization: Use Bash parameter expansion instead of basename
    skill_name="${skill_path%/}"
    skill_name="${skill_name##*/}"
    
    # Skip consolidated/backup folders
    if [[ "$skill_name" == _* ]]; then
        continue
    fi
    
    # Check 1: SKILL.md must exist
    skill_file="$skill_path/SKILL.md"
    if [ ! -f "$skill_file" ]; then
        echo -e "  ${RED}✗${NC} $skill_name: Missing SKILL.md" >&2
        FAILED=1
        continue
    fi

    # Optimized check: read file once
    has_name=0
    has_description=0
    has_version=0
    template_version=""
    line_count=0

    while IFS= read -r line || [[ -n "$line" ]]; do
        ((line_count++))
        [[ $line == "name:"* ]] && has_name=1
        [[ $line == "description:"* ]] && has_description=1
        [[ $line == "version:"* ]] && has_version=1
        if [[ $line == "template_version:"* ]]; then
            template_version="${line#template_version:}"
            template_version="${template_version//\"/}"
            template_version="${template_version#"${template_version%%[![:space:]]*}"}"
            template_version="${template_version%"${template_version##*[![:space:]]}"}"
        fi
    done < "$skill_file"

    if [ $has_name -eq 0 ]; then
        echo -e "  ${RED}✗${NC} $skill_name: SKILL.md missing 'name:' in frontmatter" >&2
        FAILED=1
    fi

    if [ $has_description -eq 0 ]; then
        echo -e "  ${RED}✗${NC} $skill_name: SKILL.md missing 'description:' in frontmatter" >&2
        FAILED=1
    fi

    # Check 2b: Warn if missing version field (non-breaking)
    if [ $has_version -eq 0 ]; then
        echo -e "  ${YELLOW}⚠${NC} $skill_name: Missing 'version:' field (recommended)" >&2
        WARNINGS=1
    fi

    # Check 2c: Warn if template_version is older than current by >1 minor version
    if [ -n "$template_version" ] && [ -n "$CURRENT_VERSION" ]; then
        c_major="${CURRENT_VERSION%%.*}"
        rest="${CURRENT_VERSION#*.}"
        c_minor="${rest%%.*}"

        s_major="${template_version%%.*}"
        s_rest="${template_version#*.}"
        s_minor="${s_rest%%.*}"

        if [[ "$s_major" -lt "$c_major" ]] || \
           { [[ "$s_major" -eq "$c_major" ]] && [[ $((c_minor - s_minor)) -gt 1 ]]; }; then
            echo -e "  ${YELLOW}⚠${NC} $skill_name: template_version $template_version is >1 minor behind current $CURRENT_VERSION" >&2
            WARNINGS=1
        fi
    fi

    # Check 3: SKILL.md line count (<= MAX_SKILL_LINES)
    if [ "$line_count" -gt "$MAX_SKILL_LINES" ]; then
        echo -e "  ${RED}✗${NC} $skill_name: SKILL.md exceeds $MAX_SKILL_LINES lines ($line_count lines)" >&2
        echo "      Consider moving detailed content to reference/ folder" >&2
        FAILED=1
    else
        echo -e "  ${GREEN}✓${NC} $skill_name: $line_count lines"
    fi

    # Check 4: Circular symlink detection
    if [ -L "$skill_path" ]; then
        echo -e "  ${RED}✗${NC} $skill_name: Circular symlink detected" >&2
        FAILED=1
    fi
done

echo ""

# --- Validate CLI symlinks ---
echo "Checking CLI symlinks..."

# Cache for readlink -f
HAS_READLINK_F=""
if readlink -f . &>/dev/null; then HAS_READLINK_F=1; else HAS_READLINK_F=0; fi

for skill_path in "$SKILLS_SRC"/*/; do
    [ -d "$skill_path" ] || continue
    skill_name="${skill_path%/}"
    skill_name="${skill_name##*/}"
    
    # Skip consolidated/backup folders
    if [[ "$skill_name" == _* ]]; then
        continue
    fi
    
    # Performance optimization: Pre-calculate expected target once per skill
    # This avoids redundant subshell calls in the inner CLI directory loop
    expected_target=""
    if { [ "${CHECK_SYMLINK_TARGETS:-false}" = "true" ] || [ -n "${CI:-}" ]; } && [ "$HAS_READLINK_F" -eq 1 ]; then
        expected_target=$(readlink -f "$skill_path" 2>/dev/null || echo "")
    fi

    for cli_dir in "${CLI_SKILL_DIRS[@]}"; do
        link="$REPO_ROOT/$cli_dir/$skill_name"

        # .qwen/skills may be real dirs (not symlinks) - accept either
        if [[ "$cli_dir" == ".qwen/skills" ]]; then
            if [ ! -d "$link" ]; then
                echo -e "  ${RED}✗${NC} MISSING: $cli_dir/$skill_name" >&2
                FAILED=1
            fi
        elif [ ! -L "$link" ]; then
            echo -e "  ${RED}✗${NC} MISSING symlink: $cli_dir/$skill_name" >&2
            FAILED=1
        elif [ ! -d "$link" ]; then
            # Optimized: check if target exists without subshell if possible
            # readlink (without -f) is a subshell but better than nothing
            # However, -d on a symlink already checks target existence
            echo -e "  ${RED}✗${NC} BROKEN symlink: $cli_dir/$skill_name -> $(readlink "$link" 2>/dev/null || echo "unknown")" >&2
            FAILED=1
        else
            # Verify symlink points to correct location
            # Only do this expensive check if explicitly requested or in CI
            # For Bolt optimization, we use the pre-calculated expected_target
            if [ -n "$expected_target" ]; then
                target=$(readlink -f "$link" 2>/dev/null || echo "")

                if [ -n "$target" ] && [ "$target" != "$expected_target" ]; then
                    echo -e "  ${YELLOW}⚠${NC} WRONG target: $cli_dir/$skill_name" >&2
                    echo "      Expected: $expected_target" >&2
                    echo "      Actual:   $target" >&2
                    WARNINGS=1
                fi
            fi
        fi
    done
done

echo ""

# --- Validate skill-rules.json if it exists ---
if [ -f "$SKILLS_SRC/skill-rules.json" ]; then
    echo "Checking skill-rules.json..."
    
    # Check JSON validity
    if command -v jq &> /dev/null; then
        if ! jq empty "$SKILLS_SRC/skill-rules.json" 2>/dev/null; then
            echo -e "  ${RED}✗${NC} skill-rules.json: Invalid JSON" >&2
            FAILED=1
        else
            echo -e "  ${GREEN}✓${NC} skill-rules.json: Valid JSON"

            # Check for required fields in rules
            rule_count=$(jq '.rules | length' "$SKILLS_SRC/skill-rules.json")
            echo -e "  ${GREEN}✓${NC} skill-rules.json: $rule_count rules defined"
        fi
    else
        echo -e "  ${YELLOW}⚠${NC} jq not installed - skipping JSON validation"
    fi
    echo ""
fi

# --- Summary ---
if [ $FAILED -ne 0 ]; then
    echo "─────────────────────────────────────────────────────────────────" >&2
    echo "│ ✗ Skill Validation FAILED                                     │" >&2
    echo "─────────────────────────────────────────────────────────────────" >&2
    echo "" >&2
    echo "Run: ./scripts/setup-skills.sh to fix missing symlinks." >&2
    echo "See: agents-docs/SKILLS.md for skill authoring guide." >&2
    exit 2
fi

if [ $WARNINGS -ne 0 ]; then
    echo "─────────────────────────────────────────────────────────────────"
    echo "│ ⚠ Skill Validation completed with warnings                    │"
    echo "─────────────────────────────────────────────────────────────────"
    echo ""
    echo "Consider fixing warnings for optimal setup."
fi

echo "─────────────────────────────────────────────────────────────────"
echo "│ ✓ All skill validations passed                                │"
echo "─────────────────────────────────────────────────────────────────"
