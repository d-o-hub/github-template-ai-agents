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
source "$REPO_ROOT/scripts/lib/skill-validation.sh" || exit 2

# shellcheck source=lib/optional_skills.sh
source "$REPO_ROOT/scripts/lib/optional_skills.sh" || exit 2

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

# Empty skill sets still need routing validation (references may be stale).
if [[ ! -d "$SKILLS_SRC" ]] || [[ -z "$(ls -A -- "$SKILLS_SRC" 2>/dev/null)" ]]; then
    echo "No skills in .agents/skills/ - checking routing configuration only."
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

    content=$(< "$skill_file")

    has_rationalizations=0
    has_red_flags=0

    # Anchored complete headings, not prefix matches such as Red FlagsMissing.
    heading_pattern=$'(^|\n)##[[:blank:]]+Rationalizations[[:blank:]]*(\r?\n|$)'
    if [[ "$content" =~ $heading_pattern ]]; then
        has_rationalizations=1
    fi

    heading_pattern=$'(^|\n)##[[:blank:]]+Red[[:blank:]]Flags[[:blank:]]*(\r?\n|$)'
    if [[ "$content" =~ $heading_pattern ]]; then
        has_red_flags=1
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

    # Use the runner's static schema/fixture checks and named minimum contract.
    if ! python3 - "$REPO_ROOT/scripts" "$skill_path" <<'PYTHON_EVAL_CHECK'; then
import sys
from pathlib import Path

sys.path.insert(0, sys.argv[1])
from lib.eval_validators import EvalStatus, run_structure_check

skill = Path(sys.argv[2])
result = run_structure_check(skill)
if result.status == EvalStatus.FAIL:
    for issue in result.details:
        print(f"  ✗ {skill.name}: {issue}")
    sys.exit(1)
PYTHON_EVAL_CHECK
        skill_failed=1
    fi

    if [[ $skill_failed -ne 0 ]]; then
        AUTHORING_FAILED=1
    fi
done

if [[ $AUTHORING_FAILED -ne 0 ]]; then
    echo ""
    echo -e "${RED}─────────────────────────────────────────────────────────────────${NC}"
    echo -e "${RED}│ ✗ Skill authoring compliance issues found                   │${NC}"
    echo -e "${RED}─────────────────────────────────────────────────────────────────${NC}"
    echo ""
    echo "New skills must have: category, ## Rationalizations, ## Red Flags,"
    echo "valid name field, and evals/evals.json with >= 3 eval cases."
    echo "See: .agents/skills/SKILL_TEMPLATE.md for the canonical structure."
    echo "See: CONTRIBUTING.md → Creating or Updating Skills for the workflow."
    FAILED=1
fi

# Check 5: skill-rules.json if it exists
echo ""
echo "Checking skill-rules.json..."
# Both locations already exist in the template. Validate each without deleting,
# migrating or overwriting either: adopters may intentionally maintain both.
if ! python3 - "$REPO_ROOT" <<'PYTHON_RULES_CHECK'; then
import json
import re
import sys
from pathlib import Path

root = Path(sys.argv[1])
failed = False
found = False
for path in (root / ".agents/skill-rules.json", root / ".agents/skills/skill-rules.json"):
    if not path.is_file():
        continue
    found = True
    label = str(path.relative_to(root))
    issues = []
    try:
        data = json.loads(path.read_text(encoding="utf-8"))
    except (OSError, UnicodeError, json.JSONDecodeError, RecursionError) as exc:
        issues.append(f"Invalid JSON: {exc}")
        data = None
    rules = data.get("rules") if isinstance(data, dict) else None
    if not isinstance(rules, list):
        issues.append("expected an object with a 'rules' array")
    else:
        for idx, rule in enumerate(rules, 1):
            prefix = f"rule #{idx}"
            if not isinstance(rule, dict):
                issues.append(f"{prefix}: must be an object")
                continue
            skill = rule.get("skill")
            if not isinstance(skill, str) or not re.fullmatch(r"[a-z0-9]+(?:-[a-z0-9]+)*", skill):
                issues.append(f"{prefix}: 'skill' must be a canonical skill name")
            elif not (root / ".agents/skills" / skill / "SKILL.md").is_file():
                issues.append(f"{prefix}: referenced skill '{skill}' has no SKILL.md")
            if rule.get("priority") not in ("high", "medium", "low"):
                issues.append(f"{prefix}: 'priority' must be high, medium or low")
            if not isinstance(rule.get("autoActivate"), bool):
                issues.append(f"{prefix}: 'autoActivate' must be a boolean")
            triggers = rule.get("triggers")
            if not isinstance(triggers, dict):
                issues.append(f"{prefix}: 'triggers' must be an object")
                continue
            for key in ("keywords", "patterns", "files"):
                values = triggers.get(key)
                if not isinstance(values, list) or not all(isinstance(v, str) and v.strip() for v in values):
                    issues.append(f"{prefix}: triggers.{key} must be an array of non-empty strings")
            patterns = triggers.get("patterns")
            if isinstance(patterns, list):
                for pattern in patterns:
                    if not isinstance(pattern, str):
                        continue
                    try:
                        re.compile(pattern)
                    except (re.error, RecursionError) as exc:
                        issues.append(f"{prefix}: invalid trigger pattern {pattern!r}: {exc}")
    if issues:
        failed = True
        for issue in issues:
            print(f"  ✗ {label}: {issue}")
    else:
        print(f"  ✓ {label}: Valid routing rules")
        print(f"  ✓ {label}: {len(data['rules'])} rules defined")
if not found:
    print("  (No skill-rules.json found)")
sys.exit(1 if failed else 0)
PYTHON_RULES_CHECK
    FAILED=1
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
