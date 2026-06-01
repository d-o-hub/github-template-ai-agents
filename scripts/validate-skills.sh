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

SKILLS_OPTIONAL=(
  "eu-ai-act-compliance"
  "durable-objects"
)

CLI_SKILL_DIRS=(
  ".claude/skills"
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
if [[ ! -d "$SKILLS_SRC" ]] || [[ -z "$(ls -A -- "$SKILLS_SRC" 2>/dev/null)" ]]; then
    echo "No skills in .agents/skills/ - nothing to validate."
    exit 0
fi

echo "Checking canonical skills and CLI symlinks..."

# Cache for readlink -f existence
HAS_READLINK_F=""
if readlink -f -- . &>/dev/null; then HAS_READLINK_F=1; else HAS_READLINK_F=0; fi

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
        printf "  ${GREEN}✓${NC} %s: %s lines\n" "$skill_name" "$SKILL_LINE_COUNT"
    fi

    # Check 2: Circular symlink detection for the skill directory
    # On Windows, we skip this check as MSYS/Cygwin symlinks appear as files
    if [ "$IS_WINDOWS" = "false" ] && [ -L "$skill_path" ]; then
        printf "  ${RED}✗${NC} %s: Circular symlink detected\n" "$skill_name" >&2
        FAILED=1
    fi

    # Check 3: Validate CLI symlinks
    # Performance optimization: Pre-calculate expected target once per skill
    expected_target=""
    if { [[ "${CHECK_SYMLINK_TARGETS:-false}" == "true" ]] || [[ -n "${CI:-}" ]]; } && [[ "$HAS_READLINK_F" -eq 1 ]]; then
        expected_target=$(readlink -f -- "$skill_path" 2>/dev/null || printf "")
    fi

    for cli_dir in "${CLI_SKILL_DIRS[@]}"; do
        # Skip validation if the CLI skill directory doesn't exist
        if [ ! -d "$REPO_ROOT/$cli_dir" ]; then
            continue
        fi

        link="$REPO_ROOT/$cli_dir/$skill_name"

        # Skip optional skills that are not linked
        is_optional=false
        for opt in "${SKILLS_OPTIONAL[@]}"; do
            if [[ "$skill_name" == "$opt" ]]; then
                is_optional=true
                break
            fi
        done
        if [[ "$is_optional" == true ]] && [ ! -L "$link" ] && [ ! -f "$link" ]; then
            continue
        fi

        if [ ! -L "$link" ] && { [ "$IS_WINDOWS" = "false" ] || [ ! -f "$link" ]; }; then
            printf "  ${RED}✗${NC} MISSING symlink: %s/%s\n" "$cli_dir" "$skill_name" >&2
            FAILED=1
        elif [ ! -d "$link" ] && { [ "$IS_WINDOWS" = "false" ] || [ ! -f "$link" ]; }; then
            # Optimized: check if target exists without subshell if possible
            # -d on a symlink already checks target existence
            printf "  ${RED}✗${NC} BROKEN symlink: %s/%s\n" "$cli_dir" "$skill_name" >&2
            FAILED=1
        else
            # Verify symlink points to correct location
            # Only do this expensive check if explicitly requested or in CI
            if [ -n "$expected_target" ]; then
                target=$(readlink -f -- "$link" 2>/dev/null || printf "")

                if [ -n "$target" ] && [ "$target" != "$expected_target" ]; then
                    printf "  ${YELLOW}⚠${NC} WRONG target: %s/%s\n" "$cli_dir" "$skill_name" >&2
                    printf "     expected: %s\n" "$expected_target"
                    printf "     actual:   %s\n" "$target"
                    WARNINGS=1
                fi
            fi
        fi
    done
done

# Check 4: skill-rules.json if it exists
echo ""
echo "Checking skill-rules.json..."
RULES_FILE="$REPO_ROOT/.agents/skill-rules.json"
if [ -f "$RULES_FILE" ]; then
    if ! python3 -c "import json, sys; json.load(open(sys.argv[1]))" "$RULES_FILE" 2>/dev/null; then
        printf "  ${RED}✗${NC} skill-rules.json: Invalid JSON\n" >&2
        FAILED=1
    else
        RULES_COUNT=$(python3 -c "import json, sys; print(len(json.load(open(sys.argv[1]))))" "$RULES_FILE")
        printf "  ${GREEN}✓${NC} skill-rules.json: Valid JSON\n"
        printf "  ${GREEN}✓${NC} skill-rules.json: %s rules defined\n" "$RULES_COUNT"
    fi
else
    echo "  (No skill-rules.json found)"
fi

if [ $FAILED -ne 0 ]; then
    echo ""
    echo -e "${RED}─────────────────────────────────────────────────────────────────${NC}"
    echo -e "${RED}│ ✗ Skill Validation FAILED                                     │${NC}"
    echo -e "${RED}─────────────────────────────────────────────────────────────────${NC}"
    echo ""
    echo "Run: ./scripts/setup-skills.sh to fix missing symlinks."
    echo "See: agents-docs/SKILLS.md for skill authoring guide."
    exit 2
fi

echo ""
echo -e "${GREEN}─────────────────────────────────────────────────────────────────${NC}"
echo -e "${GREEN}│ ✓ All skills valid                                            │${NC}"
echo -e "${GREEN}─────────────────────────────────────────────────────────────────${NC}"
exit 0
