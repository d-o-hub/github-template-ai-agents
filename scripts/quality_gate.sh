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
# shellcheck source=scripts/lib/lint_cache.sh
if [ -f "$REPO_ROOT/scripts/lib/lint_cache.sh" ]; then
    # shellcheck source=scripts/lib/lint_cache.sh
    source "$REPO_ROOT/scripts/lib/lint_cache.sh"
fi

# Colors for output (disabled in CI via TTY check, or via FORCE_COLOR=0)
# TTY check (-t 1): Determines if stdout is a terminal (not redirected to file/pipe)
# This prevents ANSI codes from appearing in CI logs while keeping colors for local dev
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

# FAILED acts as an error accumulator - any failed check sets this to 1
# We don't exit immediately so we can report ALL issues, not just the first
FAILED=0

# DETECTED_LANGUAGES stores which language ecosystems are present in the repo
# We use this array to conditionally run only relevant checks
DETECTED_LANGUAGES=()

echo "Running quality gate..."
echo ""

# --- Validate git hooks configuration (prevent global hooks from overriding local) ---
if [ "${SKIP_GLOBAL_HOOKS_CHECK:-false}" != "true" ]; then
    echo -e "${BLUE}Validating git hooks configuration...${NC}"
    if ! ./scripts/validate-git-hooks.sh; then
        # Don't fail the quality gate, just warn
        FAILED=1
    fi
    echo ""
fi

# --- Validate GitHub Actions SHAs ---
echo -e "${BLUE}Validating GitHub Actions SHAs...${NC}"
if ! ./scripts/validate-github-actions-shas.sh; then
    FAILED=1
fi
echo ""

# --- Validate Gemini TOML commands ---
if [ -d ".gemini/commands" ]; then
    echo -e "${BLUE}Validating Gemini TOML commands...${NC}"
    if ! python3 ./scripts/validate_gemini_toml.py; then
        FAILED=1
    fi
    echo ""
fi

# --- Validate GitHub Actions Workflows ---
echo -e "${BLUE}Validating GitHub Actions Workflows...${NC}"
if ! ./scripts/validate-workflows.sh; then
    FAILED=1
fi
echo ""

# --- Always: validate skills (symlinks and format) ---
echo -e "${BLUE}Validating skills...${NC}"
if ! ./scripts/validate-skills.sh; then
    FAILED=1
fi
echo ""

# --- Validate reference links in SKILL.md files ---
echo -e "${BLUE}Validating reference links in SKILL.md files...${NC}"
if ! ./scripts/validate-links.sh; then
    FAILED=1
fi
echo ""

# --- ADR compliance check ---
if [ -f "./scripts/check-adr-compliance.sh" ]; then
    echo -e "${BLUE}Checking ADR compliance...${NC}"
    if ! ./scripts/check-adr-compliance.sh; then
        FAILED=1
    fi
    echo ""
fi

# --- Plan numbering check ---
if [ -f "./scripts/check-plan-numbering.sh" ]; then
    echo -e "${BLUE}Checking plan numbering...${NC}"
    if ! ./scripts/check-plan-numbering.sh; then
        FAILED=1
    fi
    echo ""
fi

# --- Enforce LOC limits ---
echo -e "${BLUE}Enforcing LOC limits...${NC}"
if ! ./scripts/loc_gate.sh; then
    FAILED=1
fi
echo ""

# --- Enforce WASM size limits ---
echo -e "${BLUE}Enforcing WASM size limits...${NC}"
if ! ./scripts/wasm_size_gate.sh; then
    FAILED=1
fi
echo ""

# --- Auto-detect project languages ---
echo -e "${BLUE}Detecting project languages...${NC}"

# Rust detection
if [ -f "Cargo.toml" ]; then
    echo "  ${GREEN}✓${NC} Rust (Cargo.toml)"
    DETECTED_LANGUAGES+=("rust")
fi

# TypeScript/JavaScript detection
if [ -f "package.json" ]; then
    echo "  ${GREEN}✓${NC} TypeScript/JavaScript (package.json)"
    DETECTED_LANGUAGES+=("typescript")
fi

# Python detection
if [ -f "requirements.txt" ] || [ -f "pyproject.toml" ] || [ -f "setup.py" ]; then
    echo "  ${GREEN}✓${NC} Python (requirements.txt/pyproject.toml)"
    DETECTED_LANGUAGES+=("python")
fi

# Go detection
if [ -f "go.mod" ]; then
    echo "  ${GREEN}✓${NC} Go (go.mod)"
    DETECTED_LANGUAGES+=("go")
fi

# Shell script detection
if find . -name "*.sh" -not -path "./.git/*" -print -quit | grep -q .; then
    echo "  ${GREEN}✓${NC} Shell scripts detected"
    DETECTED_LANGUAGES+=("shell")
fi

# Markdown detection
if find . -name "*.md" -not -path "./.git/*" -print -quit | grep -q .; then
    echo "  ${GREEN}✓${NC} Markdown files detected"
    DETECTED_LANGUAGES+=("markdown")
fi

if [ ${#DETECTED_LANGUAGES[@]} -eq 0 ]; then
    echo -e "${YELLOW}  No recognized project files found.${NC}"
fi
echo ""

# --- Run language-specific checks ---

# Rust checks
if [[ " ${DETECTED_LANGUAGES[*]} " =~ " rust " ]]; then
    echo -e "${BLUE}Running Rust checks...${NC}"
    if command -v cargo &> /dev/null; then
        if ! OUTPUT=$(cargo fmt --check 2>&1); then
            echo -e "${RED}  ✗ cargo fmt failed${NC}"
            printf "%s\n" "$OUTPUT" >&2
            FAILED=1
        else
            echo -e "${GREEN}  ✓ cargo fmt passed${NC}"
        fi
        if [ "${SKIP_CLIPPY:-false}" != "true" ]; then
            if ! OUTPUT=$(cargo clippy --all-targets -- -D warnings 2>&1); then
                echo -e "${RED}  ✗ cargo clippy failed${NC}"
                printf "%s\n" "$OUTPUT" >&2
                FAILED=1
            else
                echo -e "${GREEN}  ✓ cargo clippy passed${NC}"
            fi
        fi
        if [ "${SKIP_TESTS:-false}" != "true" ]; then
            if ! OUTPUT=$(cargo test --lib 2>&1); then
                echo -e "${RED}  ✗ cargo test failed${NC}"
                printf "%s\n" "$OUTPUT" >&2
                FAILED=1
            else
                echo -e "${GREEN}  ✓ cargo test passed${NC}"
            fi
        fi
    fi
    echo ""
fi

# TypeScript / JavaScript checks
if [[ " ${DETECTED_LANGUAGES[*]} " =~ " typescript " ]]; then
    echo -e "${BLUE}Running TypeScript/JavaScript checks...${NC}"
    if command -v pnpm &> /dev/null; then
        if ! OUTPUT=$(pnpm lint 2>&1); then
            echo -e "${RED}  ✗ pnpm lint failed${NC}"
            printf "%s\n" "$OUTPUT" >&2
            FAILED=1
        else
            echo -e "${GREEN}  ✓ pnpm lint passed${NC}"
        fi
        if ! OUTPUT=$(pnpm typecheck 2>&1); then
            echo -e "${RED}  ✗ pnpm typecheck failed${NC}"
            printf "%s\n" "$OUTPUT" >&2
            FAILED=1
        else
            echo -e "${GREEN}  ✓ pnpm typecheck passed${NC}"
        fi
        if [ "${SKIP_TESTS:-false}" != "true" ]; then
            if ! OUTPUT=$(pnpm test 2>&1); then
                echo -e "${RED}  ✗ pnpm test failed${NC}"
                printf "%s\n" "$OUTPUT" >&2
                FAILED=1
            else
                echo -e "${GREEN}  ✓ pnpm test passed${NC}"
            fi
        fi
    fi
    echo ""
fi

# Shell script checks
if [[ " ${DETECTED_LANGUAGES[*]} " =~ " shell " ]]; then
    echo -e "${BLUE}Running Shell script checks...${NC}"
    if command -v shellcheck &> /dev/null; then
        SHELL_SCRIPTS=$(find . -name "*.sh" -not -path "./.git/*" -not -path "./target/*" 2>/dev/null || true)
        if [ -n "$SHELL_SCRIPTS" ]; then
            sc_failed=0
            while IFS= read -r script; do
                [ -n "$script" ] || continue
                if ! lint_if_changed "$script" "shellcheck" ".shellcheckrc" shellcheck --severity=error -f quiet "$script" >/dev/null 2>&1; then
                    echo -e "${RED}  ✗ shellcheck failed: $script${NC}"
                    sc_failed=1
                fi
            done <<< "$SHELL_SCRIPTS"
            if [ $sc_failed -eq 0 ]; then
                echo -e "${GREEN}  ✓ shellcheck passed${NC}"
            else
                FAILED=1
            fi
        fi
    fi
    echo ""
fi

# Markdown checks
if [[ " ${DETECTED_LANGUAGES[*]} " =~ " markdown " ]]; then
    echo -e "${BLUE}Running Markdown checks...${NC}"
    if command -v markdownlint &> /dev/null; then
        MD_FILES=$(find . -name "*.md" -not -path "./node_modules/*" -not -path "./target/*" -not -path "./.git/*" 2>/dev/null || true)
        if [ -n "$MD_FILES" ]; then
            md_failed=0
            TMP_MD_OUT=$(mktemp)
            while IFS= read -r md_file; do
                [ -n "$md_file" ] || continue
                if ! lint_if_changed "$md_file" "markdownlint" "markdownlint.toml" markdownlint "$md_file" >"$TMP_MD_OUT" 2>&1; then
                    echo -e "${RED}  ✗ markdownlint failed: $md_file${NC}"
                    cat "$TMP_MD_OUT" >&2
                    md_failed=1
                fi
            done <<< "$MD_FILES"
            rm -f "$TMP_MD_OUT"
            if [ $md_failed -eq 0 ]; then
                echo -e "${GREEN}  ✓ markdownlint passed${NC}"
            else
                FAILED=1
            fi
        fi
    fi
    echo ""
fi

# Final status
if [ $FAILED -ne 0 ]; then
    echo -e "${RED}─────────────────────────────────────────────────────────────────${NC}"
    echo -e "${RED}│ ✗ Quality Gate FAILED                                         │${NC}"
    echo -e "${RED}─────────────────────────────────────────────────────────────────${NC}"
    exit 2
fi

echo -e "${GREEN}─────────────────────────────────────────────────────────────────${NC}"
echo -e "${GREEN}│ ✓ All Quality Gates PASSED                                    │${NC}"
echo -e "${GREEN}─────────────────────────────────────────────────────────────────${NC}"
echo ""
echo "Languages checked: ${DETECTED_LANGUAGES[*]}"
