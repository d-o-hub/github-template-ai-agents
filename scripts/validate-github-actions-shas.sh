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
    while IFS=: read -r line_num line; do
        # Extract the action reference (the part after "uses:")
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
            # Extract SHA
            action_sha=$(echo "$action_ref" | cut -d'@' -f2)

            # Check for placeholder patterns: all same char, or repeating 8-char blocks
            if echo "$action_sha" | grep -qE '^(.)\1{39}$|^([0-9a-f]{8})\2{4}$'; then
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
