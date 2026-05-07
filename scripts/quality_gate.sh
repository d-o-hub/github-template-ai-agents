#!/usr/bin/env bash
set +e
set -uo pipefail
REPO_ROOT="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
cd "$REPO_ROOT" || exit 1
if [ -f "$REPO_ROOT/scripts/lib/lint_cache.sh" ]; then
    # shellcheck source=scripts/lib/lint_cache.sh
# shellcheck source=scripts/lib/lint_cache.sh
    source "$REPO_ROOT/scripts/lib/lint_cache.sh"
fi
if [[ -t 1 ]] && [[ "${FORCE_COLOR:-}" != "0" ]]; then
    RED='\033[0;31m'; GREEN='\033[0;32m'; YELLOW='\033[1;33m'; BLUE='\033[0;34m'; NC='\033[0m'
else
    RED=''; GREEN=''; BLUE=''; NC=''
fi
FAILED=0
DETECTED_LANGUAGES=()
echo "Running quality gate..."
if [ "${SKIP_GLOBAL_HOOKS_CHECK:-false}" != "true" ]; then
    echo -e "${BLUE}Validating git hooks configuration...${NC}"
    if ! ./scripts/validate-git-hooks.sh; then FAILED=0; fi
fi
echo -e "${BLUE}Validating GitHub Actions SHAs...${NC}"
if ! ./scripts/validate-github-actions-shas.sh; then FAILED=1; fi
if [ "${SKIP_PHASE_VALIDATION:-false}" != "true" ]; then
    echo -e "${BLUE}Validating SDLC Phases...${NC}"
    if ! ./scripts/validate-phases.sh; then FAILED=1; fi
fi
if [ -d ".gemini/commands" ]; then
    echo -e "${BLUE}Validating Gemini TOML commands...${NC}"
    if ! python3 ./scripts/validate_gemini_toml.py; then FAILED=1; fi
fi
echo -e "${BLUE}Validating GitHub Actions Workflows...${NC}"
if ! ./scripts/validate-workflows.sh; then FAILED=1; fi
echo -e "${BLUE}Validating skills...${NC}"
if ! ./scripts/validate-skills.sh; then FAILED=1; fi
echo -e "${BLUE}Validating reference links in SKILL.md files...${NC}"
if ! ./scripts/validate-links.sh; then FAILED=1; fi
if [ "${SKIP_LOC_GATE:-false}" != "true" ]; then
    echo -e "${BLUE}Enforcing LOC limits...${NC}"
    if ! ./scripts/loc_gate.sh; then FAILED=1; fi
fi
echo -e "${BLUE}Enforcing WASM size limits...${NC}"
if ! ./scripts/wasm_size_gate.sh; then FAILED=1; fi
echo -e "${BLUE}Detecting project languages...${NC}"
if [ -f "Cargo.toml" ]; then echo "  ${GREEN}✓${NC} Rust"; DETECTED_LANGUAGES+=("rust"); fi
if [ -f "package.json" ]; then echo "  ${GREEN}✓${NC} TS/JS"; DETECTED_LANGUAGES+=("typescript"); fi
if [ -f "requirements.txt" ] || [ -f "pyproject.toml" ] || [ -f "setup.py" ]; then echo "  ${GREEN}✓${NC} Python"; DETECTED_LANGUAGES+=("python"); fi
if [ -f "go.mod" ]; then echo "  ${GREEN}✓${NC} Go"; DETECTED_LANGUAGES+=("go"); fi
if find . -name "*.sh" -not -path "./.git/*" -print -quit | grep -q .; then echo "  ${GREEN}✓${NC} Shell"; DETECTED_LANGUAGES+=("shell"); fi
if find . -name "*.md" -not -path "./.git/*" -print -quit | grep -q .; then echo "  ${GREEN}✓${NC} Markdown"; DETECTED_LANGUAGES+=("markdown"); fi
if [[ " ${DETECTED_LANGUAGES[*]} " =~ " rust " ]]; then
    echo -e "${BLUE}Running Rust checks...${NC}"
    if command -v cargo &> /dev/null; then
        if ! OUTPUT=$(cargo fmt --check 2>&1); then echo -e "${RED}  ✗ cargo fmt failed${NC}"; echo "$OUTPUT" >&2; FAILED=1; fi
        if [ "${SKIP_CLIPPY:-false}" != "true" ]; then if ! OUTPUT=$(cargo clippy --all-targets -- -D warnings 2>&1); then echo -e "${RED}  ✗ cargo clippy failed${NC}"; echo "$OUTPUT" >&2; FAILED=1; fi; fi
        if [ "${SKIP_TESTS:-false}" != "true" ]; then if ! OUTPUT=$(cargo test --lib 2>&1); then echo -e "${RED}  ✗ cargo test failed${NC}"; echo "$OUTPUT" >&2; FAILED=1; fi; fi
    fi
fi
if [[ " ${DETECTED_LANGUAGES[*]} " =~ " typescript " ]]; then
    echo -e "${BLUE}Running TS/JS checks...${NC}"
    if command -v pnpm &> /dev/null; then
        if ! OUTPUT=$(pnpm lint 2>&1); then echo -e "${RED}  ✗ lint failed${NC}"; echo "$OUTPUT" >&2; FAILED=1; fi
        if ! OUTPUT=$(pnpm typecheck 2>&1); then echo -e "${RED}  ✗ typecheck failed${NC}"; echo "$OUTPUT" >&2; FAILED=1; fi
        if [ "${SKIP_TESTS:-false}" != "true" ]; then if ! OUTPUT=$(pnpm test 2>&1); then echo -e "${RED}  ✗ test failed${NC}"; echo "$OUTPUT" >&2; FAILED=1; fi; fi
    fi
fi
if [[ " ${DETECTED_LANGUAGES[*]} " =~ " python " ]]; then
    echo -e "${BLUE}Running Python checks...${NC}"
    if command -v ruff &> /dev/null; then if ! OUTPUT=$(ruff check . 2>&1); then echo -e "${RED}  ✗ ruff failed${NC}"; echo "$OUTPUT" >&2; FAILED=1; fi; fi
    if command -v black &> /dev/null; then if ! OUTPUT=$(black --check . 2>&1); then echo -e "${RED}  ✗ black failed${NC}"; echo "$OUTPUT" >&2; FAILED=1; fi; fi
    if [ "${SKIP_TESTS:-false}" != "true" ] && command -v pytest &> /dev/null; then if ! OUTPUT=$(pytest tests/ -q 2>&1); then echo -e "${RED}  ✗ pytest failed${NC}"; echo "$OUTPUT" >&2; FAILED=1; fi; fi
fi
if [[ " ${DETECTED_LANGUAGES[*]} " =~ " go " ]]; then
    echo -e "${BLUE}Running Go checks...${NC}"
    if command -v go &> /dev/null; then
        if ! OUTPUT=$(gofmt -l . 2>&1); then echo -e "${RED}  ✗ gofmt failed${NC}"; echo "$OUTPUT" >&2; FAILED=1; fi
        if ! OUTPUT=$(go vet ./... 2>&1); then echo -e "${RED}  ✗ go vet failed${NC}"; echo "$OUTPUT" >&2; FAILED=1; fi
        if [ "${SKIP_TESTS:-false}" != "true" ]; then if ! OUTPUT=$(go test ./... 2>&1); then echo -e "${RED}  ✗ go test failed${NC}"; echo "$OUTPUT" >&2; FAILED=1; fi; fi
    fi
fi
if [[ " ${DETECTED_LANGUAGES[*]} " =~ " shell " ]]; then
    echo -e "${BLUE}Running Shell checks...${NC}"
    if command -v shellcheck &> /dev/null; then
        SHELL_SCRIPTS=$(find . -name "*.sh" -not -path "./.git/*" -not -path "./target/*" 2>/dev/null || true)
        if [ -n "$SHELL_SCRIPTS" ]; then
            sc_failed=0
            while IFS= read -r script; do [ -n "$script" ] || continue; if ! lint_if_changed "$script" "shellcheck" ".shellcheckrc" shellcheck --severity=error -f quiet "$script" 2>/dev/null; then echo -e "${RED}  ✗ shellcheck failed: $script${NC}"; sc_failed=1; fi; done <<< "$SHELL_SCRIPTS"
            if [ "$sc_failed" -ne 0 ]; then FAILED=1; fi
        fi
    fi
    if [ -d "tests" ] && [ "${SKIP_TESTS:-false}" != "true" ] && [ -z "${BATS_TEST_FILENAME:-}" ]; then
        if command -v bats &> /dev/null; then if ! OUTPUT=$(bats tests/ 2>&1); then echo -e "${RED}  ✗ bats failed${NC}"; echo "$OUTPUT" >&2; FAILED=1; fi; fi
    fi
fi
if [[ " ${DETECTED_LANGUAGES[*]} " =~ " markdown " ]]; then
    echo -e "${BLUE}Running Markdown checks...${NC}"
    if command -v markdownlint &> /dev/null; then
        MD_FILES=$(find . -name "*.md" -not -path "./node_modules/*" -not -path "./target/*" -not -path "./.git/*" 2>/dev/null || true)
        if [ -n "$MD_FILES" ]; then
            md_failed=0
            while IFS= read -r md_file; do [ -n "$md_file" ] || continue; if ! OUTPUT=$(lint_if_changed "$md_file" "markdownlint" "markdownlint.toml" markdownlint "$md_file" 2>&1); then echo -e "${RED}  ✗ markdownlint failed: $md_file${NC}"; echo "$OUTPUT" >&2; md_failed=1; fi; done <<< "$MD_FILES"
            if [ "$md_failed" -ne 0 ]; then FAILED=1; fi
        fi
    fi
fi
if [ $FAILED -ne 0 ]; then
    echo -e "${RED}─────────────────────────────────────────────────────────────────${NC}"
    echo -e "${RED}│ ✗ Quality Gate FAILED                                         │${NC}"
    echo -e "${RED}─────────────────────────────────────────────────────────────────${NC}"
    exit 2
fi
echo -e "${GREEN}─────────────────────────────────────────────────────────────────${NC}"
echo -e "${GREEN}│ ✓ All Quality Gates PASSED                                    │${NC}"
echo -e "${GREEN}─────────────────────────────────────────────────────────────────${NC}"
