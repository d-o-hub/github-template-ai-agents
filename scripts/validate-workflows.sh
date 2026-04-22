#!/bin/bash

RED='\033[0;31m'
GREEN='\033[0;32m'
NC='\033[0m'

FAILED=0

echo "Validating GitHub Actions JavaScript blocks..."

for wf in .github/workflows/*.yml .github/workflows/*.yaml; do
    [ -e "$wf" ] || continue
    echo "Checking $wf..."

    tmp_scripts=$(mktemp)

    # Extract script blocks and detect script injection risks
    awk '
    /script: [|>]-?/ {
        # Find indentation of the line containing script: |
        match($0, /^[ ]*/)
        indent = RLENGTH
        while (getline > 0) {
            # Check for script injection (direct interpolation)
            # We strip secrets first to avoid false negatives when both are on one line
            line_check = $0
            gsub(/\$\{\{[[:space:]]*secrets\.[^}]+\}\}/, "", line_check)
            if (line_check ~ /\$\{\{/) {
                print "---INJECTION_RISK---" $0
            }

            match($0, /^[ ]*/)
            if (RLENGTH > indent && length($0) > 0 && $0 !~ /^[ ]*$/) {
                # Preserve whitespace by printing from indent+3
                # (assuming standard 2-space YAML indent + 2-space block indent)
                # If indentation is different, this might be off, but most use 2.
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
    while IFS= read -r line || [[ -n "$line" ]]; do
        if [[ "$line" == "---INJECTION_RISK---"* ]]; then
            echo -e "  ${RED}✗ Security Warning: Direct interpolation in script block detected${NC}"
            echo -e "    Line: ${line#---INJECTION_RISK---}"
            echo -e "    Risk: Script injection. Use environment variables instead."
            FAILED=1
            continue
        fi

        if [[ "$line" == "---END_SCRIPT---" ]]; then
            if [[ -s "$current_script" ]]; then
                js_wrapper="${current_script}.js"
                # Wrap in async function to allow await
                echo "(async () => {" > "$js_wrapper"
                cat "$current_script" >> "$js_wrapper"
                echo "})()" >> "$js_wrapper"

                # We need to mock 'github', 'context', 'core' etc to avoid 'not defined' errors
                # if we were running it, but node -c only checks syntax.
                if ! node -c "$js_wrapper" 2>/dev/null; then
                    echo -e "  ${RED}✗ Syntax error in script block${NC}"
                    node -c "$js_wrapper" 2>&1 | sed 's/^/    /'
                    FAILED=1
                else
                    echo -e "  ${GREEN}✓ Script block syntax OK${NC}"
                fi
                rm -f "$js_wrapper"
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
    exit 1
else
    echo -e "\n${GREEN}Validation PASSED${NC}"
    exit 0
fi
