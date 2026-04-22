#!/bin/bash
# Validates JavaScript blocks in GitHub Actions workflows.
# Checks syntax using node -c and scans for script injection risks.

RED='\033[0;31m'
GREEN='\033[0;32m'
NC='\033[0m'

FAILED=0

echo "Validating GitHub Actions JavaScript blocks..."

# Support both .yml and .yaml extensions
for wf in .github/workflows/*.yml .github/workflows/*.yaml; do
    [ -e "$wf" ] || continue
    echo "Checking $wf..."

    tmp_scripts=$(mktemp)

    # Extract script blocks and detect script injection risks
    # Handles various YAML block scalar types: |, |#, >, >-
    awk '
    /script: [|>]-?/ {
        # Find indentation of the line containing script: |
        match($0, /^[ ]*/)
        indent = RLENGTH
        while (getline > 0) {
            match($0, /^[ ]*/)
            if (RLENGTH > indent && length($0) > 0 && $0 !~ /^[ ]*$/) {
                # Check for direct string interpolation of github context which is a risk
                # We strip "secrets." first to avoid false positives on secrets which are safe
                line = $0
                gsub(/secrets\./, "SAFE_SECRET", line)
                if (line ~ /\$\{\{/ && line !~ /\$\{\{.*(env|steps|jobs|inputs|matrix).*/ ) {
                    print "---INJECTION_RISK---" $0
                }
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
        if [[ "$line" == "---INJECTION_RISK---"* ]]; then
            echo -e "  ${RED}⚠ Potential script injection risk detected:${NC}"
            echo -e "    ${line#---INJECTION_RISK---}"
            echo -e "    Use environment variables instead of direct \${{ }} interpolation."
            FAILED=1
            continue
        fi

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
                rm "${current_script}.js" 2>/dev/null || true
            fi
        else
            echo "$line" >> "$current_script"
        fi
    done < "$tmp_scripts"

    rm "$tmp_scripts" "$current_script" 2>/dev/null || true
done

if [ $FAILED -ne 0 ]; then
    echo -e "\n${RED}Validation FAILED${NC}"
    exit 1
else
    echo -e "\n${GREEN}Validation PASSED${NC}"
    exit 0
fi
