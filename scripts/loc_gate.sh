#!/usr/bin/env bash
# Enforces Maximum Lines of Code (LOC) per file based on AGENTS.md standards.
set -euo pipefail

REPO_ROOT="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
cd "$REPO_ROOT"

# Default values from AGENTS.md (as fallback)
MAX_SOURCE=500
MAX_SKILL=250
MAX_AGENTS=150

# Try to extract from AGENTS.md if available
if [ -f "AGENTS.md" ]; then
    MAX_SOURCE=$(grep "MAX_LINES_PER_SOURCE_FILE=" AGENTS.md | cut -d'=' -f2 || echo 500)
    MAX_SKILL=$(grep "MAX_LINES_PER_SKILL_MD=" AGENTS.md | cut -d'=' -f2 || echo 250)
    MAX_AGENTS=$(grep "MAX_LINES_AGENTS_MD=" AGENTS.md | cut -d'=' -f2 || echo 150)
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
while IFS= read -r skill_file; do
    [ -f "$skill_file" ] || continue
    LOC=$(wc -l < "$skill_file")
    if [ "$LOC" -gt "$MAX_SKILL" ]; then
        echo "ERROR: $skill_file has $LOC lines (max $MAX_SKILL)"
        FAILED=1
    fi
done < <(find .agents/skills -name "SKILL.md" -not -path "*/node_modules/*")

# 3. Check source files (excluding common artifacts and ignored dirs)
# Targeted extensions: .py, .rs, .ts, .js, .go, .sh
while IFS= read -r src_file; do
    [ -f "$src_file" ] || continue
    LOC=$(wc -l < "$src_file")
    if [ "$LOC" -gt "$MAX_SOURCE" ]; then
        echo "ERROR: $src_file has $LOC lines (max $MAX_SOURCE)"
        FAILED=1
    fi
done < <(find . -type f \( -name "*.py" -o -name "*.rs" -o -name "*.ts" -o -name "*.js" -o -name "*.go" -o -name "*.sh" \) \
    -not -path "./.git/*" \
    -not -path "./target/*" \
    -not -path "./node_modules/*" \
    -not -path "./dist/*" \
    -not -path "./build/*" \
    -not -path "./.agents/skills/*" )

if [ $FAILED -ne 0 ]; then
    echo "LOC check failed."
    exit 1
fi

echo "LOC check passed."
exit 0
