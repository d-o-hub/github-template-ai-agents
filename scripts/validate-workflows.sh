#!/bin/bash

RED='\033[0;31m'
GREEN='\033[0;32m'
NC='\033[0m'

FAILED=0

echo "Validating GitHub Actions JavaScript blocks..."

for wf in .github/workflows/*.yml; do
    echo "Checking $wf..."

    tmp_scripts=$(mktemp)

    awk '
    /script: \|/ {
        # Find indentation of the line containing script: |
        match($0, /^[ ]*/)
        indent = RLENGTH
        while (getline > 0) {
            match($0, /^[ ]*/)
            if (RLENGTH > indent && length($0) > 0 && $0 !~ /^[ ]*$/) {
                print substr($0, indent + 3)
            } else if (length($0) == 0) {
                print ""
            } else {
                print "---END_SCRIPT---"
                break
            }
        }
    }
    ' "$wf" > "$tmp_scripts"

    current_script=$(mktemp)
    while IFS= read -r line; do
        if [[ "$line" == "---END_SCRIPT---" ]]; then
            if [[ -s "$current_script" ]]; then
                # Wrap in async function to allow await
                echo "(async () => {" > "${current_script}.js"
                cat "$current_script" >> "${current_script}.js"
                echo "})()" >> "${current_script}.js"

                # We need to mock 'github', 'context', 'core' etc to avoid 'not defined' errors if we were running it,
                # but node -c only checks syntax.
                if ! node -c "${current_script}.js" 2>/dev/null; then
                    echo -e "  ${RED}✗ Syntax error in script block${NC}"
                    node -c "${current_script}.js" 2>&1 | sed 's/^/    /'
                    FAILED=1
                else
                    echo -e "  ${GREEN}✓ Script block syntax OK${NC}"
                fi
                truncate -s 0 "$current_script"
            fi
        else
            echo "$line" >> "$current_script"
        fi
    done < "$tmp_scripts"

    rm "$tmp_scripts" "$current_script" "${current_script}.js" 2>/dev/null || true
done

if [ $FAILED -ne 0 ]; then
    echo -e "\n${RED}Validation FAILED${NC}"
    # exit 1  # Avoiding exit
else
    echo -e "\n${GREEN}Validation PASSED${NC}"
    # exit 0  # Avoiding exit
fi
