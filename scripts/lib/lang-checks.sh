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
#   SKIPPED_CHECKS     - array; appended to when a check cannot run (missing
#                        optional tool, absent package script). Skipping must be
#                        visible: the caller prints this so a green gate never
#                        implies a check ran when it did not.
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

# Declared here so the library also works standalone (e.g. sourced by a test).
if [[ -z "${SKIPPED_CHECKS+x}" ]]; then
    SKIPPED_CHECKS=()
fi

# ---------------------------------------------------------------------------
# _skip_check - records and prints a check that could not run.
# ---------------------------------------------------------------------------
_skip_check() {
    local check="$1"
    local reason="$2"
    SKIPPED_CHECKS+=("$check")
    printf "%b  - skipped %s: %s%b\n" "${YELLOW:-}" "$check" "$reason" "${NC:-}"
}

# ---------------------------------------------------------------------------
# _detect_package_manager - prints the JS package manager implied by lockfiles.
# ---------------------------------------------------------------------------
_detect_package_manager() {
    if [[ -f pnpm-lock.yaml ]]; then
        printf 'pnpm\n'
    elif [[ -f yarn.lock ]]; then
        printf 'yarn\n'
    elif [[ -f bun.lockb ]] || [[ -f bun.lock ]]; then
        printf 'bun\n'
    elif [[ -f package-lock.json ]]; then
        printf 'npm\n'
    elif [[ -f package.json ]]; then
        # No lockfile: npm ships with Node, so it is the honest default.
        printf 'npm\n'
    else
        return 1
    fi
}

# ---------------------------------------------------------------------------
# _has_package_script - succeeds when package.json declares the given script.
# ---------------------------------------------------------------------------
_has_package_script() {
    local script_name="$1"
    [[ -f package.json ]] || return 1
    if command -v node &> /dev/null; then
        node -e 'const s = require("./package.json").scripts || {};
            process.exit(Object.prototype.hasOwnProperty.call(s, process.argv[1]) ? 0 : 1)' \
            "$script_name" &> /dev/null
    elif command -v jq &> /dev/null; then
        jq -e --arg s "$script_name" '(.scripts // {}) | has($s)' package.json &> /dev/null
    else
        grep -qE "\"${script_name}\"[[:space:]]*:" package.json &> /dev/null
    fi
}

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

    # Fallback: staged + unstaged changes vs HEAD, plus untracked files so a
    # newly added script is linted before it is ever committed.
    if [[ -z "$source_files" ]]; then
        source_files=$(
            {
                git diff --name-only HEAD 2>/dev/null || true
                git ls-files --others --exclude-standard 2>/dev/null || true
            }
        )
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
[[ -n "$(find . \( -path ./.git -o -path '*/node_modules' -o -path ./target -o -path ./vendor \) -prune -o -name "*.sh" -print -quit)" ]] && DETECTED_LANGUAGES+=("shell") && printf "  %b✓%b Shell
" "" ""
[[ -n "$(find . \( -path ./.git -o -path '*/node_modules' \) -prune -o -name "*.md" -print -quit)" ]] && DETECTED_LANGUAGES+=("markdown") && printf "  %b✓%b Markdown
" "" ""
}

# ---------------------------------------------------------------------------
# _run_js_task - runs one package.json script through the detected manager.
# A script the project does not define is a skip, not a failure: absent
# `typecheck` means the project has no typecheck step to run.
# ---------------------------------------------------------------------------
_run_js_task() {
    local pm="$1"
    local task="$2"
    if ! _has_package_script "$task"; then
        _skip_check "typescript:$task" "no \"$task\" script in package.json"
        return 0
    fi
    if ! OUTPUT=$("$pm" run "$task" 2>&1); then
        printf "%b  ✗ %s %s failed%b\n" "${RED}" "$pm" "$task" "${NC}"
        printf "%s\n" "$OUTPUT" >&2
        FAILED=1
    else
        printf "%b  ✓ %s %s passed%b\n" "${GREEN}" "$pm" "$task" "${NC}"
    fi
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
    else
        _skip_check "rust:cargo" "cargo is not installed"
    fi
    printf "\n"
fi

# TypeScript / JavaScript checks
if [[ " ${DETECTED_LANGUAGES[*]} " =~ " typescript " ]]; then
    printf "%bRunning TypeScript/JavaScript checks...%b\n" "${BLUE}" "${NC}"
    JS_PM="$(_detect_package_manager || true)"
    if [[ -z "$JS_PM" ]]; then
        _skip_check "typescript" "no package.json or lockfile found"
    elif ! command -v "$JS_PM" &> /dev/null; then
        _skip_check "typescript:$JS_PM" "$JS_PM is not installed"
    else
        if [[ "${SKIP_LINT:-false}" == "true" ]]; then
            _skip_check "typescript:lint" "SKIP_LINT=true"
        else
            _run_js_task "$JS_PM" lint
        fi
        _run_js_task "$JS_PM" typecheck
        if [[ "${SKIP_TESTS:-false}" == "true" ]]; then
            _skip_check "typescript:test" "SKIP_TESTS=true"
        else
            _run_js_task "$JS_PM" test
        fi
    fi
    printf "\n"
fi

# Shell script checks
if [[ " ${DETECTED_LANGUAGES[*]} " =~ " shell " ]]; then
    printf "%bRunning Shell script checks...%b\n" "${BLUE}" "${NC}"
    if [[ "${SKIP_LINT:-false}" == "true" ]]; then
        _skip_check "shell:shellcheck" "SKIP_LINT=true"
    elif command -v shellcheck &> /dev/null; then
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
    else
        _skip_check "shell:shellcheck" "shellcheck is not installed"
    fi
    printf "\n"
fi

# Markdown checks
if [[ " ${DETECTED_LANGUAGES[*]} " =~ " markdown " ]]; then
    printf "%bRunning Markdown checks...%b\n" "${BLUE}" "${NC}"
    if [[ "${SKIP_LINT:-false}" == "true" ]]; then
        _skip_check "markdown:markdownlint-cli2" "SKIP_LINT=true"
    elif command -v markdownlint-cli2 &> /dev/null; then
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
    else
        _skip_check "markdown:markdownlint-cli2" "markdownlint-cli2 is not installed"
    fi
    printf "\n"
fi
}
