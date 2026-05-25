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
    rm -f -- "$TMP_JS_FILE"
}
trap cleanup EXIT

# Support both .yml and .yaml extensions
for wf in .github/workflows/*.yml .github/workflows/*.yaml; do
    [ -e "$wf" ] || continue
    echo "Checking $wf..."

    # Use a variable to accumulate the current script block to avoid line-by-line file I/O
    current_block=""

    # Extract script blocks and detect script injection risks
    # Handles both run: and script: blocks, and both single-line and multiline formats.
    while IFS= read -r line; do
        if [[ "$line" == "---INJECTION_RISK---"* ]]; then
            printf "  ${RED}⚠ Potential script injection risk detected:${NC}\n"
            printf "    %s\n" "${line#---INJECTION_RISK---}"
            printf "    Use environment variables instead of direct \${{ }} interpolation.\n"
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
                    printf "  ${RED}✗ Syntax error in script block${NC}\n"
                    node -c "$TMP_JS_FILE" 2>&1 | sed 's/^/    /'
                    FAILED=1
                else
                    printf "  ${GREEN}✓ Script block syntax OK${NC}\n"
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
    function is_safe(expr) {
        gsub(/^[[:space:]]+|[[:space:]]+$/, "", expr)
        if (expr ~ /^(env|steps|jobs|inputs|matrix|strategy|secrets|needs)\./) return 1
        if (expr ~ /^github\.(repository|repository_owner|sha|run_id|run_number|run_attempt|retention_days|workflow|job|action|action_path|workspace|actor|triggering_actor|event_name)$/) return 1
        return 0
    }
    function check_injection(line) {
        temp = line
        while (match(temp, /\$\{\{[^}]+\}\}/)) {
            block = substr(temp, RSTART + 3, RLENGTH - 5)
            if (!is_safe(block)) {
                print "---INJECTION_RISK---" line
                break
            }
            temp = substr(temp, RSTART + RLENGTH)
        }
    }
    BEGIN { in_block = 0; indent = 0; is_script = 0 }
    /^[[:space:]]*(-[[:space:]]*)?(run|script):[[:space:]]*[|>]-?$/ {
        if (in_block && is_script) print "---END_SCRIPT---"
        in_block = 1
        is_script = ($0 ~ /script:/)
        match($0, /^[ ]*/)
        indent = RLENGTH
        next
    }
    /^[[:space:]]*(-[[:space:]]*)?(run|script):/ {
        if (in_block && is_script) print "---END_SCRIPT---"
        in_block = 0
        is_script = ($0 ~ /script:/)
        check_injection($0)
        if (is_script) {
            line = $0
            sub(/^[[:space:]]*(-[[:space:]]*)?script:[[:space:]]*/, "", line)
            print line
            print "---END_SCRIPT---"
        }
        next
    }
    in_block {
        match($0, /^[ ]*/)
        if (RLENGTH > indent || length($0) == 0) {
            check_injection($0)
            if (is_script) {
                if (length($0) > indent + 2) print substr($0, indent + 3)
                else print ""
            }
        } else {
            if (is_script) print "---END_SCRIPT---"
            in_block = 0
        }
    }
    ' "$wf")

    # Ensure any trailing script block is finalized
    if [[ -n "$current_block" ]]; then
        # shellcheck disable=SC2059
        printf "(async () => {\n%s\n})()" "$current_block" > "$TMP_JS_FILE"
        if ! node -c "$TMP_JS_FILE" 2>/dev/null; then
            printf "  ${RED}✗ Syntax error in script block${NC}\n"
            node -c "$TMP_JS_FILE" 2>&1 | sed 's/^/    /'
            FAILED=1
        else
            printf "  ${GREEN}✓ Script block syntax OK${NC}\n"
        fi
        current_block=""
    fi
done

if [ $FAILED -ne 0 ]; then
    printf "\n${RED}Validation FAILED${NC}\n"
    exit 1
else
    printf "\n${GREEN}Validation PASSED${NC}\n"
    exit 0
fi
