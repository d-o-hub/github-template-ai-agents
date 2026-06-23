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
AUTHORING_FAILED=0

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
    [[ -d "$skill_path" ]] || continue
    # Performance optimization: Use Bash parameter expansion instead of basename
    skill_name="${skill_path%/}"
    skill_name="${skill_name##*/}"
    
    # Skip consolidated/backup folders, eval workspace directories, and skills-evaluation
    if [[ "$skill_name" == _* ]] || [[ "$skill_name" == *-workspace ]] || [[ "$skill_name" == skills-evaluation ]]; then
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
    if [[ "$IS_WINDOWS" == "false" ]] && [[ -L "$skill_path" ]]; then
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
        if [[ ! -d "$REPO_ROOT/$cli_dir" ]]; then
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
        if [[ "$is_optional" == true ]] && [[ ! -L "$link" ]] && [[ ! -f "$link" ]]; then
            continue
        fi

        if [[ ! -L "$link" ]] && { [[ "$IS_WINDOWS" == "false" ]] || [[ ! -f "$link" ]]; }; then
            printf "  ${RED}✗${NC} MISSING symlink: %s/%s\n" "$cli_dir" "$skill_name" >&2
            FAILED=1
        elif [[ ! -d "$link" ]] && { [[ "$IS_WINDOWS" == "false" ]] || [[ ! -f "$link" ]]; }; then
            # Optimized: check if target exists without subshell if possible
            # -d on a symlink already checks target existence
            printf "  ${RED}✗${NC} BROKEN symlink: %s/%s\n" "$cli_dir" "$skill_name" >&2
            FAILED=1
        else
            # Verify symlink points to correct location
            # Only do this expensive check if explicitly requested or in CI
            if [[ -n "$expected_target" ]]; then
                target=$(readlink -f -- "$link" 2>/dev/null || printf "")

                if [[ -n "$target" ]] && [[ "$target" != "$expected_target" ]]; then
                    printf "  ${YELLOW}⚠${NC} WRONG target: %s/%s\n" "$cli_dir" "$skill_name" >&2
                    printf "     expected: %s\n" "$expected_target"
                    printf "     actual:   %s\n" "$target"
                    WARNINGS=1
                fi
            fi
        fi
    done
done

# Check 4: Authoring compliance checks (per-skill SKILL.md requirements)
echo ""
echo "Checking skill authoring compliance..."

for skill_path in "$SKILLS_SRC"/*/; do
    [[ -d "$skill_path" ]] || continue
    skill_name="${skill_path%/}"
    skill_name="${skill_name##*/}"

    # Skip consolidated/backup folders, eval workspace directories, and skills-evaluation
    if [[ "$skill_name" == _* ]] || [[ "$skill_name" == *-workspace ]] || [[ "$skill_name" == skills-evaluation ]]; then
        continue
    fi

    skill_file="${skill_path}SKILL.md"
    [[ -f "$skill_file" ]] || continue

    skill_failed=0

    # Extract frontmatter and section checks in a single native pass to avoid subshell overhead
    skill_front_name=""
    has_category=""
    has_rationalizations=0
    has_red_flags=0

    # Load content natively to avoid multiple grep/awk processes per skill
    content=$(< "$skill_file")

    # Extract frontmatter safely using bash parameter expansion
    content_no_top="${content#---$'\n'}"
    fm="${content_no_top%%$'\n'---*}"

    if [[ "$fm" =~ (^|$'\n')name:[[:space:]]*([^$'\n'$'\r']+) ]]; then
        skill_front_name="${BASH_REMATCH[2]}"
    fi

    if [[ "$fm" =~ (^|$'\n')category: ]]; then
        has_category="yes"
    fi

    if [[ "$content" =~ (^|$'\n')"## Rationalizations" ]]; then
        has_rationalizations=1
    fi

    if [[ "$content" =~ (^|$'\n')"## Red Flags" ]]; then
        has_red_flags=1
    fi

    # Check: name field must not contain uppercase, spaces, or non-hyphen special chars
    if [[ -n "$skill_front_name" ]]; then
        if [[ "$skill_front_name" =~ [A-Z] ]] || [[ "$skill_front_name" =~ [[:space:]] ]] || [[ "$skill_front_name" =~ [^a-z0-9-] ]]; then
            printf "  ${RED}✗${NC} %s: name field contains invalid characters: '%s'\n" "$skill_name" "$skill_front_name"
            skill_failed=1
        fi
    fi

    # Check: frontmatter must contain category field
    if [[ -z "$has_category" ]]; then
        printf "  ${RED}✗${NC} %s: Missing 'category' field in frontmatter\n" "$skill_name"
        skill_failed=1
    fi

    # Check: body must contain ## Rationalizations heading
    if [[ "$has_rationalizations" -eq 0 ]]; then
        printf "  ${RED}✗${NC} %s: Missing '## Rationalizations' section\n" "$skill_name"
        skill_failed=1
    fi

    # Check: body must contain ## Red Flags heading
    if [[ "$has_red_flags" -eq 0 ]]; then
        printf "  ${RED}✗${NC} %s: Missing '## Red Flags' section\n" "$skill_name"
        skill_failed=1
    fi

    # Check: evals/evals.json must exist and contain >= 3 eval cases
    evals_file="${skill_path}evals/evals.json"
    if [[ ! -f "$evals_file" ]]; then
        printf "  ${RED}✗${NC} %s: Missing evals/evals.json\n" "$skill_name"
        skill_failed=1
    else
        if command -v jq >/dev/null 2>&1; then
            eval_count=$(jq '.evals | length' "$evals_file" 2>/dev/null || echo 0)
        else
            eval_count=$(python3 -c "import json,sys; d=json.load(open(sys.argv[1])); print(len(d.get('evals', [])))" "$evals_file" 2>/dev/null || echo 0)
        fi
        if [[ "$eval_count" -lt 3 ]]; then
            printf "  ${RED}✗${NC} %s: evals/evals.json has %d eval cases (need >= 3)\n" "$skill_name" "$eval_count"
            skill_failed=1
        fi
    fi

    # Check: SKILL.md line count (WARN, not FAIL)
    skill_lines=$(wc -l < "$skill_file")
    if [[ "$skill_lines" -gt "$MAX_SKILL_LINES" ]]; then
        printf "  ${YELLOW}⚠${NC} %s: SKILL.md exceeds %d lines (%d lines)\n" "$skill_name" "$MAX_SKILL_LINES" "$skill_lines"
    fi

    if [[ $skill_failed -ne 0 ]]; then
        AUTHORING_FAILED=1
    fi
done

if [[ $AUTHORING_FAILED -ne 0 ]]; then
    echo ""
    echo -e "${YELLOW}─────────────────────────────────────────────────────────────────${NC}"
    echo -e "${YELLOW}│ ⚠ Skill authoring compliance issues found                   │${NC}"
    echo -e "${YELLOW}─────────────────────────────────────────────────────────────────${NC}"
    echo ""
    echo "New skills must have: category, ## Rationalizations, ## Red Flags,"
    echo "valid name field, and evals/evals.json with >= 3 eval cases."
    echo "See: .agents/skills/SKILL_TEMPLATE.md for the canonical structure."
    echo "See: CONTRIBUTING.md → Creating or Updating Skills for the workflow."
    WARNINGS=1
fi

# Check 5: skill-rules.json if it exists
echo ""
echo "Checking skill-rules.json..."
RULES_FILE="$REPO_ROOT/.agents/skill-rules.json"
if [[ -f "$RULES_FILE" ]]; then
    if command -v jq >/dev/null 2>&1; then
        if ! jq . "$RULES_FILE" >/dev/null 2>&1; then
            printf "  ${RED}✗${NC} skill-rules.json: Invalid JSON\n" >&2
            FAILED=1
        else
            RULES_COUNT=$(jq 'length' "$RULES_FILE" 2>/dev/null || echo 0)
            printf "  ${GREEN}✓${NC} skill-rules.json: Valid JSON\n"
            printf "  ${GREEN}✓${NC} skill-rules.json: %s rules defined\n" "$RULES_COUNT"
        fi
    else
        if ! python3 -c "import json, sys; json.load(open(sys.argv[1]))" "$RULES_FILE" 2>/dev/null; then
            printf "  ${RED}✗${NC} skill-rules.json: Invalid JSON\n" >&2
            FAILED=1
        else
            RULES_COUNT=$(python3 -c "import json, sys; print(len(json.load(open(sys.argv[1]))))" "$RULES_FILE")
            printf "  ${GREEN}✓${NC} skill-rules.json: Valid JSON\n"
            printf "  ${GREEN}✓${NC} skill-rules.json: %s rules defined\n" "$RULES_COUNT"
        fi
    fi
else
    echo "  (No skill-rules.json found)"
fi

if [[ $FAILED -ne 0 ]]; then
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
