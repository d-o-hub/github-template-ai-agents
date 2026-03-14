#!/usr/bin/env bash
# Validates all CLI skill symlinks and SKILL.md files.
# Used in pre-commit hook and CI. Exit 2 on failure (surfaced to agent).
set -euo pipefail

REPO_ROOT="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
SKILLS_SRC="$REPO_ROOT/.agents/skills"

CLI_SKILL_DIRS=(
  ".claude/skills"
  ".opencode/agent"
  ".gemini/skills"
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

for skill_path in "$SKILLS_SRC"/*/; do
    [ -d "$skill_path" ] || continue
    skill_name="$(basename "$skill_path")"
    
    # Skip consolidated/backup folders
    if [[ "$skill_name" == _* ]]; then
        continue
    fi
    
    # Check 1: SKILL.md must exist
    if [ ! -f "$skill_path/SKILL.md" ]; then
        echo "  ${RED}✗${NC} $skill_name: Missing SKILL.md" >&2
        FAILED=1
        continue
    fi
    
    # Check 2: SKILL.md must have YAML frontmatter with name and description
    if ! grep -q "^name:" "$skill_path/SKILL.md" 2>/dev/null; then
        echo "  ${RED}✗${NC} $skill_name: SKILL.md missing 'name:' in frontmatter" >&2
        FAILED=1
    fi
    
    if ! grep -q "^description:" "$skill_path/SKILL.md" 2>/dev/null; then
        echo "  ${RED}✗${NC} $skill_name: SKILL.md missing 'description:' in frontmatter" >&2
        FAILED=1
    fi
    
    # Check 3: SKILL.md line count (<= MAX_SKILL_LINES)
    line_count=$(wc -l < "$skill_path/SKILL.md" | tr -d ' ')
    if [ "$line_count" -gt "$MAX_SKILL_LINES" ]; then
        echo "  ${RED}✗${NC} $skill_name: SKILL.md exceeds $MAX_SKILL_LINES lines ($line_count lines)" >&2
        echo "      Consider moving detailed content to reference/ folder" >&2
        FAILED=1
    else
        echo "  ${GREEN}✓${NC} $skill_name: $line_count lines"
    fi
    
    # Check 4: Circular symlink detection
    if [ -L "$skill_path" ]; then
        echo "  ${RED}✗${NC} $skill_name: Circular symlink detected" >&2
        FAILED=1
    fi
done

echo ""

# --- Validate CLI symlinks ---
echo "Checking CLI symlinks..."

for skill_path in "$SKILLS_SRC"/*/; do
    [ -d "$skill_path" ] || continue
    skill_name="$(basename "$skill_path")"
    
    # Skip consolidated/backup folders
    if [[ "$skill_name" == _* ]]; then
        continue
    fi
    
    for cli_dir in "${CLI_SKILL_DIRS[@]}"; do
        link="$REPO_ROOT/$cli_dir/$skill_name"
        
        if [ ! -L "$link" ]; then
            echo "  ${RED}✗${NC} MISSING symlink: $cli_dir/$skill_name" >&2
            FAILED=1
        elif [ ! -d "$link" ]; then
            echo "  ${RED}✗${NC} BROKEN symlink: $cli_dir/$skill_name -> $(readlink "$link")" >&2
            FAILED=1
        else
            # Verify symlink points to correct location
            target=$(readlink "$link")
            expected_rel="$(realpath --relative-to="$REPO_ROOT/$cli_dir" "$skill_path")"
            if [ "$target" != "$expected_rel" ]; then
                echo "  ${YELLOW}⚠${NC} WRONG target: $cli_dir/$skill_name" >&2
                echo "      Expected: $expected_rel" >&2
                echo "      Actual:   $target" >&2
                WARNINGS=1
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
            echo "  ${RED}✗${NC} skill-rules.json: Invalid JSON" >&2
            FAILED=1
        else
            echo "  ${GREEN}✓${NC} skill-rules.json: Valid JSON"
            
            # Check for required fields in rules
            rule_count=$(jq '.rules | length' "$SKILLS_SRC/skill-rules.json")
            echo "  ${GREEN}✓${NC} skill-rules.json: $rule_count rules defined"
        fi
    else
        echo "  ${YELLOW}⚠${NC} jq not installed - skipping JSON validation"
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
