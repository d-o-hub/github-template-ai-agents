#!/usr/bin/env bash
# Enforces Maximum Lines of Code (LOC) per file based on AGENTS.md standards.
set -euo pipefail

REPO_ROOT="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
cd "$REPO_ROOT"

# Default values from AGENTS.md (as fallback)
MAX_SOURCE=500
MAX_SKILL=250
MAX_AGENTS=150

readonly AGENTS_MD_FILE='AGENTS.md'

# Try to extract from AGENTS.md if available
if [[ -f "$AGENTS_MD_FILE" ]]; then
    MAX_SOURCE_RAW=$(grep -e "MAX_LINES_PER_SOURCE_FILE=" -- "$AGENTS_MD_FILE" | cut -d'=' -f2 || echo 500)
    MAX_SKILL_RAW=$(grep -e "MAX_LINES_PER_SKILL_MD=" -- "$AGENTS_MD_FILE" | cut -d'=' -f2 || echo 250)
    MAX_AGENTS_RAW=$(grep -e "MAX_LINES_AGENTS_MD=" -- "$AGENTS_MD_FILE" | cut -d'=' -f2 || echo 150)

    # Validate numeric format or fallback to defaults
    [[ "$MAX_SOURCE_RAW" =~ ^[0-9]+$ ]] && MAX_SOURCE="$MAX_SOURCE_RAW"
    [[ "$MAX_SKILL_RAW" =~ ^[0-9]+$ ]] && MAX_SKILL="$MAX_SKILL_RAW"
    [[ "$MAX_AGENTS_RAW" =~ ^[0-9]+$ ]] && MAX_AGENTS="$MAX_AGENTS_RAW"
fi

FAILED=0

echo "Checking LOC limits..."

# 1. Check AGENTS.md
if [[ -f "$AGENTS_MD_FILE" ]]; then
    LOC=$(wc -l < "$AGENTS_MD_FILE")
    if [[ "$LOC" -gt "$MAX_AGENTS" ]]; then
        echo "ERROR: $AGENTS_MD_FILE has $LOC lines (max $MAX_AGENTS)"
        FAILED=1
    fi
fi

# 2. Check SKILL.md files
# Optimization: Use xargs wc -l and awk for single-pass validation to avoid per-file process forks
if ! find .agents/skills -name "SKILL.md" -not -path "*/node_modules/*" -print0 | \
    xargs -0 -r wc -l -- | \
    awk -v max="${MAX_SKILL_OVERRIDE:-$MAX_SKILL}" -- '
    BEGIN { err = 0 }
    $NF == "total" { next }
    $1 > max {
        count = $1
        $1 = ""
        sub(/^[[:space:]]+/, "")
        print "ERROR: " $0 " has " count " lines (max " max ")"
        err = 1
    }
    END { if (err) exit(err) }'; then
    FAILED=1
fi

# 3. Check source files (excluding common artifacts and ignored dirs)
# Targeted extensions: .py, .rs, .ts, .js, .go, .sh
# Optimization: Batch processing with xargs and awk for ~10x performance gain
# Exclude: .git, target, node_modules (at any level), dist, build, .agents/skills
if ! find . -type f \( -name "*.py" -o -name "*.rs" -o -name "*.ts" -o -name "*.js" -o -name "*.go" -o -name "*.sh" \) \
    -not -path "./.git/*" \
    -not -path "./target/*" \
    -not -path "*/node_modules/*" \
    -not -path "./dist/*" \
    -not -path "./build/*" \
    -not -path "./.agents/skills/*" -print0 | \
    xargs -0 -r wc -l -- | \
    awk -v max="${MAX_SOURCE_OVERRIDE:-$MAX_SOURCE}" -- '
    BEGIN { err = 0 }
    $NF == "total" { next }
    $1 > max {
        count = $1
        $1 = ""
        sub(/^[[:space:]]+/, "")
        print "ERROR: " $0 " has " count " lines (max " max ")"
        err = 1
    }
    END { if (err) exit(err) }'; then
    FAILED=1
fi

if [[ $FAILED -ne 0 ]]; then
    echo "LOC check failed."
    exit 1
fi

echo "LOC check passed."
exit 0
