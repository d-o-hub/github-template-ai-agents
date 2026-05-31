#!/usr/bin/env bash
# Full quality gate with auto-detection for multiple languages.
# Exit 0 = silent success, Exit 2 = errors surfaced to agent.
# Used in pre-commit hook and CI.
# NOTE: errexit disabled explicitly - it causes unpredictable failures in CI
# Why +e instead of -e? We need to capture command output before exiting,
# and we aggregate all failures before deciding the final exit code.
set +e
set -uo pipefail

REPO_ROOT="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
cd "$REPO_ROOT" || exit 1

# Source lint-cache library
if [ -f "$REPO_ROOT/scripts/lib/lint_cache.sh" ]; then
    source "$REPO_ROOT/scripts/lib/lint_cache.sh"
fi

# Colors for output
if [[ -t 1 ]] && [[ "${FORCE_COLOR:-}" != "0" ]]; then
    RED='\033[0;31m'
    GREEN='\033[0;32m'
    YELLOW='\033[1;33m'
    BLUE='\033[0;34m'
    NC='\033[0m'
else
    RED=''
    GREEN=''
    NC=''
    YELLOW=''
    BLUE=''
fi

FAILED=0
DETECTED_LANGUAGES=()

printf "Running quality gate...\n"
printf "\n"

# --- Validate git hooks configuration ---
if [ "${SKIP_GLOBAL_HOOKS_CHECK:-false}" != "true" ]; then
    printf "%bValidating git hooks configuration...%b\n" "${BLUE}" "${NC}"
    if ! ./scripts/validate-git-hooks.sh; then
        FAILED=1
    fi
    printf "\n"
fi

# --- LLM Context files check ---
printf "%bChecking LLM context files...%b\n" "${BLUE}" "${NC}"
if [[ ! -f "llms.txt" ]] || [[ ! -f "llms-full.txt" ]]; then
    printf "%b  ✗ llms.txt or llms-full.txt missing%b\n" "${RED}" "${NC}"
    FAILED=1
else
    TMP_LLMS=$(mktemp)
    TMP_LLMS_FULL=$(mktemp)

    cleanup() {
        rm -f "$TMP_LLMS" "$TMP_LLMS_FULL"
    }
    trap cleanup EXIT

    (
        export LLMS_TXT="$TMP_LLMS"
        export LLMS_FULL_TXT="$TMP_LLMS_FULL"
        if ! ./scripts/generate-llms-txt.sh > /dev/null 2>&1; then
            printf "%b  ✗ Failed to generate LLM context files%b\n" "${RED}" "${NC}"
            exit 1
        fi
    )

    if ! diff -q llms.txt "$TMP_LLMS" > /dev/null; then
        printf "%b  ✗ llms.txt is out of date. Run ./scripts/generate-llms-txt.sh%b\n" "${RED}" "${NC}"
        FAILED=1
    elif ! diff -q llms-full.txt "$TMP_LLMS_FULL" > /dev/null; then
        printf "%b  ✗ llms-full.txt is out of date. Run ./scripts/generate-llms-txt.sh%b\n" "${RED}" "${NC}"
        FAILED=1
    else
        printf "%b  ✓ llms.txt and llms-full.txt are up to date%b\n" "${GREEN}" "${NC}"
    fi
fi
printf "\n"

# --- Validate GitHub Actions SHAs ---
printf "%bValidating GitHub Actions SHAs...%b\n" "${BLUE}" "${NC}"
if ! ./scripts/validate-github-actions-shas.sh; then
    FAILED=1
fi
printf "\n"

# --- Validate Gemini TOML commands ---
if [ -d ".gemini/commands" ]; then
    printf "%bValidating Gemini TOML commands...%b\n" "${BLUE}" "${NC}"
    if ! python3 ./scripts/validate_gemini_toml.py; then
        FAILED=1
    fi
    printf "\n"
fi
