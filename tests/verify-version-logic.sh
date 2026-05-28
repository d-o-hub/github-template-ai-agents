#!/usr/bin/env bash
# Tests the version comparison logic from scripts/lib/skill-validation.sh
# Specifically tests the hardening against octal interpretation and malformed input.

set -uo pipefail

# Mock environment
SKILL_NAME="test-skill"
YELLOW='\033[0;33m'
NC='\033[0m'

# Function to test (extracted and slightly adapted for standalone testing)
# We test the core arithmetic logic:
# if [[ "$s_major" -lt "$c_major" ]] || \
#    { [[ "$s_major" -eq "$c_major" ]] && [[ $((10#$c_minor - 10#$s_minor)) -gt 1 ]]; }; then
#     ...
# fi
test_version_diff() {
    local c_major="$1"
    local c_minor="$2"
    local s_major="$3"
    local s_minor="$4"
    local expected_warning="$5"
    local skill_name="test-skill"
    local template_version="${s_major}.${s_minor}"
    local current_version="${c_major}.${c_minor}"

    # Pre-arithmetic validation (as in the script)
    if [[ ! "$c_major" =~ ^[0-9]+$ ]] || [[ ! "$c_minor" =~ ^[0-9]+$ ]] || \
       [[ ! "$s_major" =~ ^[0-9]+$ ]] || [[ ! "$s_minor" =~ ^[0-9]+$ ]]; then
        c_major=0; c_minor=0; s_major=0; s_minor=0
    fi

    # The actual logic being tested
    local warning=""
    if [[ "$s_major" -lt "$c_major" ]] || \
       { [[ "$s_major" -eq "$c_major" ]] && [[ $((10#$c_minor - 10#$s_minor)) -gt 1 ]]; }; then
        warning="template_version ${template_version} is >1 minor behind current ${current_version}"
    fi

    if [[ "$warning" == *"$expected_warning"* ]] && [[ -n "$expected_warning" || -z "$warning" ]]; then
        printf "  \033[0;32m✓\033[0m Test Passed: %s.%s vs %s.%s (Expected: '%s')\n" "$s_major" "$s_minor" "$c_major" "$c_minor" "$expected_warning"
        return 0
    else
        printf "  \033[0;31m✗\033[0m Test Failed: %s.%s vs %s.%s\n" "$s_major" "$s_minor" "$c_major" "$c_minor"
        printf "    Expected warning containing: '%s'\n" "$expected_warning"
        printf "    Actual warning: '%s'\n" "$warning"
        return 1
    fi
}

echo "Running version comparison logic tests..."

FAILED=0

# Case 1: Leading zeros (the main fix)
# 0.08 vs 0.10 -> diff 2 -> Warning expected
test_version_diff "0" "10" "0" "08" "is >1 minor behind" || FAILED=1
# 0.09 vs 0.10 -> diff 1 -> No warning expected
test_version_diff "0" "10" "0" "09" "" || FAILED=1

# Case 2: Major version behind -> Warning expected
test_version_diff "1" "0" "0" "9" "is >1 minor behind" || FAILED=1

# Case 3: Exactly 1 minor behind -> No warning expected
test_version_diff "1" "2" "1" "1" "" || FAILED=1

# Case 4: Malformed input (Injection attempt)
# If c_minor contains injection, it should be caught by regex and set to 0.
test_version_diff "0" "1 + \$(touch /tmp/PWNED)" "0" "0" "" || FAILED=1
if [ -f /tmp/PWNED ]; then
    echo "  ✗ SECURITY FAILURE: Injection executed!"
    rm /tmp/PWNED
    FAILED=1
else
    echo "  ✓ Security Check: No injection executed."
fi

if [ $FAILED -eq 0 ]; then
    echo "All tests passed!"
    exit 0
else
    echo "Some tests failed!"
    exit 1
fi
