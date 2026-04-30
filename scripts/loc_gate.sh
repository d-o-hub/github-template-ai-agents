#!/usr/bin/env bash
# Enforces Maximum Lines of Code (LOC) per file based on AGENTS.md standards.
# Optimized version using batch processing to reduce process forks.
set -euo pipefail

REPO_ROOT="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
cd "$REPO_ROOT"

# Default values from AGENTS.md (as fallback)
MAX_SOURCE=500
MAX_SKILL=250
MAX_AGENTS=150

# Try to extract from AGENTS.md if available
if [ -f "AGENTS.md" ]; then
    # Use a single awk pass to extract all limits at once
    mapfile -t LIMITS < <(awk -F'=' '
        /MAX_LINES_PER_SOURCE_FILE/ { source=$2 }
        /MAX_LINES_PER_SKILL_MD/ { skill=$2 }
        /MAX_LINES_AGENTS_MD/ { agents=$2 }
        END { print source; print skill; print agents }
    ' AGENTS.md)
    MAX_SOURCE=${LIMITS[0]:-$MAX_SOURCE}
    MAX_SKILL=${LIMITS[1]:-$MAX_SKILL}
    MAX_AGENTS=${LIMITS[2]:-$MAX_AGENTS}
fi

FAILED=0

echo "Checking LOC limits..."

# 1. Check AGENTS.md
if [ -f "AGENTS.md" ]; then
    LOC=$(wc -l < "AGENTS.md")
    if [ "$LOC" -gt "$MAX_AGENTS" ]; then
        echo "ERROR: AGENTS.md has $LOC lines (max $MAX_AGENTS)"
        FAILED=1
    fi
fi

# 2. Check SKILL.md files
# Bolt: Optimization - Use xargs wc -l and awk for bulk processing.
# Handles filenames with spaces by clearing the first field (count) and trimming.
# Processes all files before exiting to report all violations.
if ! find .agents/skills -name "SKILL.md" -not -path "*/node_modules/*" -print0 | xargs -0 -r wc -l | awk -v max="$MAX_SKILL" '
    BEGIN { status = 0 }
    $1 > max && $2 != "total" {
        count = $1
        $1 = ""; sub(/^[[:space:]]+/, "")
        print "ERROR: " $0 " has " count " lines (max " max ")"
        status = 1
    }
    END { exit status }
'; then
    FAILED=1
fi

# 3. Check source files (excluding common artifacts and ignored dirs)
# Targeted extensions: .py, .rs, .ts, .js, .go, .sh
if ! find . -type f \( -name "*.py" -o -name "*.rs" -o -name "*.ts" -o -name "*.js" -o -name "*.go" -o -name "*.sh" \) \
    -not -path "./.git/*" \
    -not -path "./target/*" \
    -not -path "./node_modules/*" \
    -not -path "./dist/*" \
    -not -path "./build/*" \
    -not -path "./.agents/skills/*" -print0 | xargs -0 -r wc -l | awk -v max="$MAX_SOURCE" '
    BEGIN { status = 0 }
    $1 > max && $2 != "total" {
        count = $1
        $1 = ""; sub(/^[[:space:]]+/, "")
        print "ERROR: " $0 " has " count " lines (max " max ")"
        status = 1
    }
    END { exit status }
'; then
    FAILED=1
fi

if [ $FAILED -ne 0 ]; then
    echo "LOC check failed."
    exit 1
fi

echo "LOC check passed."
exit 0
