#!/usr/bin/env bash
# lib/lang-checks.sh - Project language detection and per-language lint/test runners.
# Source this file from another script; it defines functions only and does not run
# anything on its own.
# Usage: source "$(dirname "${BASH_SOURCE[0]}")/lib/lang-checks.sh"
#
# Contract with the caller (all read/write global state, no locals leak):
#   RED GREEN BLUE NC  - ANSI colour variables, used verbatim in every message.
#   FAILED             - accumulator; set to 1 by any failed check.
#   DETECTED_LANGUAGES - array; reset and filled by detect_project_languages, then
#                        read back by the caller for the closing summary line.
#   lint_batch_if_changed - from lib/lint_cache.sh; caches per-file lint results.
#
# Public entry points, in the order the caller must invoke them:
#   detect_project_languages   # prints the detection banner, fills DETECTED_LANGUAGES
#   run_language_checks        # runs lint/tests per detected language

# Bodies below are kept at their original column on purpose: several printf
# format strings span a literal newline, so re-indenting the continuation line
# would change the emitted text.

# FAILED is only ever assigned in this file; the sourcing script reads it as the
# error accumulator. ShellCheck cannot follow `source`, so it reports SC2034
# ("appears unused") for a variable that is genuinely consumed downstream.
# shellcheck disable=SC2034

# ---------------------------------------------------------------------------
# _changed_files_z - emits the lintable file set, NUL-delimited, one path per record.
# Private helper: not part of the caller contract.
# ---------------------------------------------------------------------------
_changed_files_z() {
    local source_files=""

    # In CI PR context, compare against base branch
    if [[ -n "${GITHUB_BASE_REF:-}" ]]; then
        source_files=$(git diff --name-only "origin/${GITHUB_BASE_REF}...HEAD" 2>/dev/null || true)
    fi

    # Fallback: staged + unstaged changes vs HEAD
    if [[ -z "$source_files" ]]; then
        source_files=$(git diff --name-only HEAD 2>/dev/null || true)
    fi

    # If nothing changed (or first commit), fall back to all tracked files
    if [[ -z "$source_files" ]]; then
        source_files=$(git ls-files 2>/dev/null || true)
    fi

    # If still empty (no git), fall back to find
    if [[ -z "$source_files" ]]; then
        find . -type f -not -path "./.git/*" -not -path "./target/*" -not -path "*/node_modules/*" -print0 2>/dev/null || true
        return
    fi

    # Convert newline-delimited to null-delimited, one record per line. Iterate
    # rather than word-splitting $source_files: splitting would also break on
    # paths containing spaces and leaves SC2086 (and globbing) unguarded.
    local line
    while IFS= read -r line; do
        printf '%s\0' "$line"
    done <<< "$source_files"
}

# ---------------------------------------------------------------------------
# detect_project_languages - fills DETECTED_LANGUAGES from marker files on disk.
# ---------------------------------------------------------------------------
detect_project_languages() {
DETECTED_LANGUAGES=()

printf "%bDetecting project languages...%b
" "" ""
[[ -f "Cargo.toml" ]] && DETECTED_LANGUAGES+=("rust") && printf "  %b✓%b Rust
" "" ""
[[ -f "package.json" ]] && DETECTED_LANGUAGES+=("typescript") && printf "  %b✓%b TypeScript
" "" ""
{ [[ -f "requirements.txt" ]] || [[ -f "pyproject.toml" ]] || [[ -f "setup.py" ]]; } && DETECTED_LANGUAGES+=("python") && printf "  %b✓%b Python
" "" ""
[[ -f "go.mod" ]] && DETECTED_LANGUAGES+=("go") && printf "  %b✓%b Go
" "" ""
# perf: Replace grep -q with native string length check to avoid external fork overhead
[[ -n "$(find . -name "*.sh" -not -path "" -print -quit)" ]] && DETECTED_LANGUAGES+=("shell") && printf "  %b✓%b Shell
" "" ""
[[ -n "$(find . -name "*.md" -not -path "" -print -quit)" ]] && DETECTED_LANGUAGES+=("markdown") && printf "  %b✓%b Markdown
" "" ""
}

# ---------------------------------------------------------------------------
# run_language_checks - runs the lint/test command set for every detected language.
# Must be called after detect_project_languages.
# ---------------------------------------------------------------------------
run_language_checks() {
# Rust checks
if [[ " ${DETECTED_LANGUAGES[*]} " =~ " rust " ]]; then
    printf "%bRunning Rust checks...%b\n" "${BLUE}" "${NC}"
    if command -v cargo &> /dev/null; then
        if ! OUTPUT=$(cargo fmt --check 2>&1); then
            printf "%b  ✗ cargo fmt failed%b\n" "${RED}" "${NC}"
            printf "%s\n" "$OUTPUT" >&2
            FAILED=1
        else
            printf "%b  ✓ cargo fmt passed%b\n" "${GREEN}" "${NC}"
        fi
        if [[ "${SKIP_CLIPPY:-false}" != "true" ]]; then
            if ! OUTPUT=$(cargo clippy --all-targets -- -D warnings 2>&1); then
                printf "%b  ✗ cargo clippy failed%b\n" "${RED}" "${NC}"
                printf "%s\n" "$OUTPUT" >&2
                FAILED=1
            else
                printf "%b  ✓ cargo clippy passed%b\n" "${GREEN}" "${NC}"
            fi
        fi
        if [[ "${SKIP_TESTS:-false}" != "true" ]]; then
            if ! OUTPUT=$(cargo test --lib 2>&1); then
                printf "%b  ✗ cargo test failed%b\n" "${RED}" "${NC}"
                printf "%s\n" "$OUTPUT" >&2
                FAILED=1
            else
                printf "%b  ✓ cargo test passed%b\n" "${GREEN}" "${NC}"
            fi
        fi
    fi
    printf "\n"
fi

# TypeScript / JavaScript checks
if [[ " ${DETECTED_LANGUAGES[*]} " =~ " typescript " ]]; then
    printf "%bRunning TypeScript/JavaScript checks...%b\n" "${BLUE}" "${NC}"
    if command -v pnpm &> /dev/null; then
        if ! OUTPUT=$(pnpm lint 2>&1); then
            printf "%b  ✗ pnpm lint failed%b\n" "${RED}" "${NC}"
            printf "%s\n" "$OUTPUT" >&2
            FAILED=1
        else
            printf "%b  ✓ pnpm lint passed%b\n" "${GREEN}" "${NC}"
        fi
        if ! OUTPUT=$(pnpm typecheck 2>&1); then
            printf "%b  ✗ pnpm typecheck failed%b\n" "${RED}" "${NC}"
            printf "%s\n" "$OUTPUT" >&2
            FAILED=1
        else
            printf "%b  ✓ pnpm typecheck passed%b\n" "${GREEN}" "${NC}"
        fi
        if [[ "${SKIP_TESTS:-false}" != "true" ]]; then
            if ! OUTPUT=$(pnpm test 2>&1); then
                printf "%b  ✗ pnpm test failed%b\n" "${RED}" "${NC}"
                printf "%s\n" "$OUTPUT" >&2
                FAILED=1
            else
                printf "%b  ✓ pnpm test passed%b\n" "${GREEN}" "${NC}"
            fi
        fi
    fi
    printf "\n"
fi

# Shell script checks
if [[ " ${DETECTED_LANGUAGES[*]} " =~ " shell " ]]; then
    printf "%bRunning Shell script checks...%b\n" "${BLUE}" "${NC}"
    if command -v shellcheck &> /dev/null; then
        TMP_SH_LIST=$(mktemp)
        _changed_files_z | grep -z '\.sh$' > "$TMP_SH_LIST" 2>/dev/null || true
        if [[ -s "$TMP_SH_LIST" ]]; then
            # Do not pass -f quiet so errors are visible in CI
            if ! lint_batch_if_changed "$TMP_SH_LIST" "shellcheck" ".shellcheckrc" shellcheck --severity=error; then
                printf "%b  ✗ shellcheck failed%b\n" "${RED}" "${NC}"
                FAILED=1
            else
                printf "%b  ✓ shellcheck passed%b\n" "${GREEN}" "${NC}"
            fi
        else
            printf "%b  ✓ No changed shell files to check%b\n" "${GREEN}" "${NC}"
        fi
        rm -f -- "$TMP_SH_LIST"
    fi
    printf "\n"
fi

# Markdown checks
if [[ " ${DETECTED_LANGUAGES[*]} " =~ " markdown " ]]; then
    printf "%bRunning Markdown checks...%b\n" "${BLUE}" "${NC}"
    if command -v markdownlint-cli2 &> /dev/null; then
        TMP_MD_LIST=$(mktemp)
        _changed_files_z | grep -z '\.md$' > "$TMP_MD_LIST" 2>/dev/null || true
        if [[ -s "$TMP_MD_LIST" ]]; then
            if ! lint_batch_if_changed "$TMP_MD_LIST" "markdownlint" ".markdownlint-cli2.jsonc" markdownlint-cli2 >/dev/null 2>&1; then
                printf "%b  ✗ markdownlint-cli2 failed (run 'markdownlint-cli2 "**/*.md"' locally to see details)%b\n" "${RED}" "${NC}"
                FAILED=1
            else
                printf "%b  ✓ markdownlint-cli2 passed%b\n" "${GREEN}" "${NC}"
            fi
        else
            printf "%b  ✓ No changed markdown files to check%b\n" "${GREEN}" "${NC}"
        fi
        rm -f -- "$TMP_MD_LIST"
    fi
    printf "\n"
fi
}
