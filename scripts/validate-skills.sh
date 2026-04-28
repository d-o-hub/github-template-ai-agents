#!/usr/bin/env bash
# Validates all CLI skill symlinks and SKILL.md files.
# Used in pre-commit hook and CI. Exit 2 on failure (surfaced to agent).
# Note: OpenCode reads directly from .agents/skills/ - no symlinks to validate.
# NOTE: errexit disabled explicitly - it causes unpredictable failures in CI
set +e
set -uo pipefail

REPO_ROOT="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
SKILLS_SRC="$REPO_ROOT/.agents/skills"
# shellcheck source=lib/skill-validation.sh
source "$REPO_ROOT/scripts/lib/skill-validation.sh"

CLI_SKILL_DIRS=(
  ".claude/skills"
  ".gemini/skills"
  ".qwen/skills"
)

FAILED=0
WARNINGS=0

# Detect Windows (MSYS/Cygwin) to handle symlink differences
IS_WINDOWS=false
if [[ "$OSTYPE" == "msys" || "$OSTYPE" == "cygwin" ]]; then
    IS_WINDOWS=true
fi

# If no skills exist, nothing to validate
if [ ! -d "$SKILLS_SRC" ] || [ -z "$(ls -A "$SKILLS_SRC" 2>/dev/null)" ]; then
    echo "No skills in .agents/skills/ - nothing to validate."
    exit 0
fi

echo "Checking canonical skills and CLI symlinks..."

# Cache for readlink -f existence
HAS_READLINK_F=""
if readlink -f . &>/dev/null; then HAS_READLINK_F=1; else HAS_READLINK_F=0; fi

for skill_path in "$SKILLS_SRC"/*/; do
    [ -d "$skill_path" ] || continue
    # Performance optimization: Use Bash parameter expansion instead of basename
    skill_name="${skill_path%/}"
    skill_name="${skill_name##*/}"
    
    # Skip consolidated/backup folders
    if [[ "$skill_name" == _* ]]; then
        continue
    fi
    
    # Check 1: SKILL.md format and frontmatter
    skill_file="${skill_path}SKILL.md"
    if ! validate_skill_file "$skill_file"; then
        # Check if it was a failure or just a warning (validate_skill_file returns non-zero for errors)
        # Note: validate_skill_file in library handles printing the status line
        FAILED=1
    else
        # If valid, print the success line like validate-skill-format.sh does
        echo -e "  ${GREEN}✓${NC} $skill_name: $SKILL_LINE_COUNT lines"
    fi

    # Check 2: Circular symlink detection for the skill directory
    # On Windows, we skip this check as MSYS/Cygwin symlinks appear as files
    if [ "$IS_WINDOWS" = "false" ] && [ -L "$skill_path" ]; then
        echo -e "  ${RED}✗${NC} $skill_name: Circular symlink detected" >&2
        FAILED=1
    fi

    # Check 3: Validate CLI symlinks
    # Performance optimization: Pre-calculate expected target once per skill
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
        elif [ ! -L "$link" ] && { [ "$IS_WINDOWS" = "false" ] || [ ! -f "$link" ]; }; then
            echo -e "  ${RED}✗${NC} MISSING symlink: $cli_dir/$skill_name" >&2
            FAILED=1
        elif [ ! -d "$link" ]; then
            # Optimized: check if target exists without subshell if possible
            # -d on a symlink already checks target existence
            echo -e "  ${RED}✗${NC} BROKEN symlink: $cli_dir/$skill_name" >&2
            FAILED=1
        else
            # Verify symlink points to correct location
            # Only do this expensive check if explicitly requested or in CI
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
