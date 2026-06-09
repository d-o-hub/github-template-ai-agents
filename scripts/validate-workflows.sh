#!/usr/bin/env bash
# Validates JavaScript blocks in GitHub Actions workflows.
# Checks syntax using node -c and scans for script injection risks.

RED=$'\033[0;31m'
GREEN=$'\033[0;32m'
NC=$'\033[0m'

FAILED=0

printf "Validating GitHub Actions JavaScript blocks...\n"

# Create temporary file for script validation once
TMP_JS_FILE=$(mktemp /tmp/workflow-script-XXXXXX.js)

# Ensure cleanup on exit
cleanup() {
    rm -f -- "$TMP_JS_FILE"
}
trap cleanup EXIT

# Allow passing specific files or directories to check
CHECK_PATHS=("$@")
if [[ ${#CHECK_PATHS[@]} -eq 0 ]]; then
    # Support both .yml and .yaml extensions
    shopt -s nullglob
    CHECK_PATHS=(.github/workflows/*.yml .github/workflows/*.yaml)
    shopt -u nullglob
fi

if [[ ${#CHECK_PATHS[@]} -eq 0 ]]; then
    printf "No workflow files found to validate.\n"
    exit 0
fi

for wf in "${CHECK_PATHS[@]}"; do
    [[ -e "$wf" ]] || continue
    printf "Checking %s...\n" "$wf"

    current_block=""

    # Extract script blocks and detect script injection risks
    while IFS= read -r line; do
        if [[ "$line" == "---INJECTION_RISK---"* ]]; then
            printf "  %b⚠ Potential script injection risk detected:%b\n" "${RED}" "${NC}"
            printf "    %s\n" "${line#---INJECTION_RISK---}"
            printf "    Use environment variables instead of direct \${{ }} interpolation.\n"
            FAILED=1
            continue
        fi

        if [[ "$line" == "---END_SCRIPT---" ]]; then
            if [[ -n "$current_block" ]]; then
                printf "(async () => {\n%s\n})()" "$current_block" > "$TMP_JS_FILE"

                if ! node -c "$TMP_JS_FILE" 2>/dev/null; then
                    printf "  %b✗ Syntax error in script block%b\n" "${RED}" "${NC}"
                    node -c "$TMP_JS_FILE" 2>&1 | sed 's/^/    /'
                    FAILED=1
                else
                    printf "  %b✓ Script block syntax OK%b\n" "${GREEN}" "${NC}"
                fi
                current_block=""
            fi
        else
            if [[ -z "$current_block" ]]; then
                current_block="$line"
            else
                current_block="$current_block"$'\n'"$line"
            fi
        fi
    done < <(awk -- '
    function is_injection_risk(line) {
        if (line !~ /\$\{\{/) return 0
        # Whitelist safe contexts and safe github properties
        safe = "^\\$\\{\\{[[:space:]]*(env|steps|jobs|inputs|matrix|strategy|secrets|needs|github\\.(repository|actor|sha|workflow|run_id|run_number|event_name|job|token))[.[:alnum:]_-]*[[:space:]]*\\}\\}"
        temp = line
        while (match(temp, /\$\{\{[^}]+\}\}/)) {
            m = substr(temp, RSTART, RLENGTH)
            if (m !~ safe) return 1
            temp = substr(temp, RSTART + RLENGTH)
        }
        return 0
    }
    function process_line(line) {
        if (line ~ /^[[:space:]]*(-[[:space:]]*)?(run|script):/) {
            if (line ~ /: [|>]-?/) {
                in_block = 1
                is_script = (line ~ /script:/)
                match(line, /^[ ]*/)
                indent = RLENGTH
                return
            } else {
                if (is_injection_risk(line)) print "---INJECTION_RISK---" line
                if (line ~ /script:/) {
                    l = line
                    sub(/^[[:space:]]*(-[[:space:]]*)?script:[[:space:]]*/, "", l)
                    print l
                    print "---END_SCRIPT---"
                }
                return
            }
        }
    }
    BEGIN { in_block = 0; indent = 0; is_script = 0 }
    in_block {
        match($0, /^[ ]*/)
        if (RLENGTH > indent || length($0) == 0) {
            if (is_injection_risk($0)) print "---INJECTION_RISK---" $0
            if (is_script) {
                if (length($0) == 0) print ""
                else print substr($0, indent + 3)
            }
        } else {
            if (is_script) print "---END_SCRIPT---"
            in_block = 0
            process_line($0)
        }
        next
    }
    { process_line($0) }
    ' "$wf")
done

if [[ $FAILED -ne 0 ]]; then
    printf "\n${RED}Validation FAILED${NC}\n"
    exit 1
else
    printf "\n${GREEN}Validation PASSED${NC}\n"
    exit 0
fi
