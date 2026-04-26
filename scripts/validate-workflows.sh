#!/bin/bash
# Validates JavaScript blocks in GitHub Actions workflows.
# Checks syntax using node -c and scans for script injection risks.

RED='\033[0;31m'
GREEN='\033[0;32m'
NC='\033[0m'

FAILED=0

echo "Validating GitHub Actions JavaScript blocks..."

# Create temporary file for script validation once
# We use a fixed name in /tmp to avoid repeated mktemp calls
TMP_JS_FILE=$(mktemp /tmp/workflow-script-XXXXXX.js)

# Ensure cleanup on exit
cleanup() {
    rm -f "$TMP_JS_FILE"
}
trap cleanup EXIT

# Support both .yml and .yaml extensions
for wf in .github/workflows/*.yml .github/workflows/*.yaml; do
    [ -e "$wf" ] || continue
    echo "Checking $wf..."

    # Use a variable to accumulate the current script block to avoid line-by-line file I/O
    current_block=""

    # Extract script blocks and detect script injection risks
    # Handles various YAML block scalar types: |, |#, >, >-
    # Process output of awk directly to avoid intermediate temp file
    while IFS= read -r line; do
        if [[ "$line" == "---INJECTION_RISK---"* ]]; then
            echo -e "  ${RED}⚠ Potential script injection risk detected:${NC}"
            echo -e "    ${line#---INJECTION_RISK---}"
            echo -e "    Use environment variables instead of direct \${{ }} interpolation."
            FAILED=1
            continue
        fi

        if [[ "$line" == "---END_SCRIPT---" ]]; then
            if [[ -n "$current_block" ]]; then
                # Wrap in async function to allow await and write to file in one go
                # shellcheck disable=SC2059
                printf "(async () => {\n%s\n})()" "$current_block" > "$TMP_JS_FILE"

                # node -c only checks syntax, which is what we want
                if ! node -c "$TMP_JS_FILE" 2>/dev/null; then
                    echo -e "  ${RED}✗ Syntax error in script block${NC}"
                    node -c "$TMP_JS_FILE" 2>&1 | sed 's/^/    /'
                    FAILED=1
                else
                    echo -e "  ${GREEN}✓ Script block syntax OK${NC}"
                fi
                current_block=""
            fi
        else
            # Accumulate line in variable with a newline
            if [[ -z "$current_block" ]]; then
                current_block="$line"
            else
                current_block="$current_block"$'\n'"$line"
            fi
        fi
    done < <(awk '
    /script: [|>]-?/ {
        match($0, /^[ ]*/)
        indent = RLENGTH
        while (getline > 0) {
            match($0, /^[ ]*/)
            if (RLENGTH > indent && length($0) > 0 && $0 !~ /^[ ]*$/) {
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
    ' "$wf")
done

if [ $FAILED -ne 0 ]; then
    echo -e "\n${RED}Validation FAILED${NC}"
    exit 1
else
    echo -e "\n${GREEN}Validation PASSED${NC}"
    exit 0
fi
