#!/usr/bin/env bash
# Validate that GitHub Actions SHAs in workflows are valid commit SHAs
# and that all external actions are pinned to a 40-character SHA.
# Exits 0 if all SHAs are valid, 1 if any are invalid or unpinned.

set -euo pipefail

REPO_ROOT="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
cd "$REPO_ROOT" || exit 1

# Colors
if [[ -t 1 ]] && [[ "${FORCE_COLOR:-}" != "0" ]]; then
    RED='\033[0;31m'
    GREEN='\033[0;32m'
    NC='\033[0m'
else
    RED=''
    GREEN=''
    NC=''
fi

FAILED=0

# Find all workflow files
mapfile -t WORKFLOW_FILES < <(find .github/workflows -name "*.yml" -o -name "*.yaml" 2>/dev/null || true)

if [ ${#WORKFLOW_FILES[@]} -eq 0 ]; then
    echo -e "${GREEN}No workflow files found${NC}"
    exit 0
fi

# Extract action uses lines
for file in "${WORKFLOW_FILES[@]}"; do
    # Only match lines that look like YAML uses keys at the appropriate indentation
    # Allows for bullet points "- uses:"
    while IFS=: read -r line_num line; do
        # Extract the action reference (the part after "uses:")
        # Handles single/double quotes and trailing comments
        action_ref=$(echo "$line" | sed -n 's/.*uses:[[:space:]]*//p' | sed "s/['\"]//g" | cut -d' ' -f1 | cut -d'#' -f1)

        # Skip empty lines or malformed uses
        [ -z "$action_ref" ] && continue

        # Skip local actions (starting with ./)
        if [[ "$action_ref" == ./* ]]; then
            continue
        fi

        # Skip docker actions
        if [[ "$action_ref" == docker://* ]]; then
            continue
        fi

        # Check if it uses a SHA pinning (@ followed by 40 hex chars)
        if [[ "$action_ref" =~ @([a-f0-9]{40})$ ]]; then
            # Extract SHA from regex match
            action_sha="${BASH_REMATCH[1]}"

            # Check for placeholder patterns:
            # 1. All same char: e.g. 0000... or ffff...
            # 2. Repeating 8-char blocks: e.g. 1234567812345678123456781234567812345678

            # Check all same char
            first_char="${action_sha:0:1}"
            all_same=true
            for (( i=1; i<${#action_sha}; i++ )); do
                if [[ "${action_sha:$i:1}" != "$first_char" ]]; then
                    all_same=false
                    break
                fi
            done

            # Check repeating 8-char blocks
            block8="${action_sha:0:8}"
            repeating8=true
            if [[ "$action_sha" != "$block8$block8$block8$block8$block8" ]]; then
                repeating8=false
            fi

            if [ "$all_same" = true ] || [ "$repeating8" = true ]; then
                echo -e "${RED}Invalid/placeholder SHA found in $file line $line_num: $action_sha${NC}"
                FAILED=1
            fi
        else
            echo -e "${RED}Unpinned external action found in $file line $line_num: $action_ref${NC}"
            echo -e "  External actions MUST be pinned to a 40-character commit SHA for security."
            FAILED=1
        fi
    done < <(grep -n "^[[:space:]]*\(-[[:space:]]*\)\?uses:" "$file" || true)
done

if [ $FAILED -eq 0 ]; then
    echo -e "${GREEN}All GitHub Actions SHAs appear valid and pinned${NC}"
else
    echo -e "${RED}Found unpinned actions or invalid/placeholder SHAs in workflows${NC}"
fi

exit $FAILED
