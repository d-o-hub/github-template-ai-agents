#!/usr/bin/env bash
# Full quality gate with auto-detection for multiple languages.
# Exit 0 = silent success, Exit 2 = errors surfaced to agent.
# Used in pre-commit hook and CI.
# NOTE: We don't use set -e because it has unpredictable behavior in CI
set -uo pipefail

REPO_ROOT="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
cd "$REPO_ROOT"

# Colors for output (disabled in CI via TTY check, or via FORCE_COLOR=0)
if [[ -t 1 ]] && [[ "${FORCE_COLOR:-}" != "0" ]]; then
    RED='\033[0;31m'
    GREEN='\033[0;32m'
    YELLOW='\033[1;33m'
    BLUE='\033[0;34m'
    NC='\033[0m'
else
    RED=''
    GREEN=''
    YELLOW=''
    BLUE=''
    NC=''
fi

FAILED=0
DETECTED_LANGUAGES=()

echo "Running quality gate..."
echo ""

# --- Always: validate skill symlinks ---
echo -e "${BLUE}Validating skill symlinks...${NC}"
if ! ./scripts/validate-skills.sh; then
    FAILED=1
fi
echo ""

# --- Auto-detect project languages ---
echo -e "${BLUE}Detecting project languages...${NC}"

# Rust
if [ -f "Cargo.toml" ]; then
    echo "  ${GREEN}✓${NC} Rust (Cargo.toml)"
    DETECTED_LANGUAGES+=("rust")
fi

# TypeScript / JavaScript
if [ -f "package.json" ]; then
    echo "  ${GREEN}✓${NC} TypeScript/JavaScript (package.json)"
    DETECTED_LANGUAGES+=("typescript")
fi

# Python
if [ -f "requirements.txt" ] || [ -f "pyproject.toml" ] || [ -f "setup.py" ]; then
    echo "  ${GREEN}✓${NC} Python (requirements.txt/pyproject.toml)"
    DETECTED_LANGUAGES+=("python")
fi

# Go
if [ -f "go.mod" ]; then
    echo "  ${GREEN}✓${NC} Go (go.mod)"
    DETECTED_LANGUAGES+=("go")
fi

# Shell scripts (always check if .sh files exist)
if find . -name "*.sh" -not -path "./.git/*" | grep -q .; then
    echo "  ${GREEN}✓${NC} Shell scripts detected"
    DETECTED_LANGUAGES+=("shell")
fi

# Markdown (always check if .md files exist)
if find . -name "*.md" -not -path "./.git/*" | grep -q .; then
    echo "  ${GREEN}✓${NC} Markdown files detected"
    DETECTED_LANGUAGES+=("markdown")
fi

if [ ${#DETECTED_LANGUAGES[@]} -eq 0 ]; then
    echo -e "${YELLOW}  No recognized project files found.${NC}"
    echo "  Add Cargo.toml, package.json, requirements.txt, go.mod, or source files."
fi
echo ""

# --- Run language-specific checks ---

# Rust checks
if [[ " ${DETECTED_LANGUAGES[*]} " =~ " rust " ]]; then
    echo -e "${BLUE}Running Rust checks...${NC}"
    
    if command -v cargo &> /dev/null; then
        # Format check
        if ! OUTPUT=$(cargo fmt --check 2>&1); then
            echo -e "${RED}  ✗ cargo fmt failed${NC}"
            echo "$OUTPUT" >&2
            FAILED=1
        else
            echo -e "${GREEN}  ✓ cargo fmt passed${NC}"
        fi
        
        # Clippy (only if not in CI skip mode)
        if [ "${SKIP_CLIPPY:-false}" != "true" ]; then
            if ! OUTPUT=$(cargo clippy --all-targets -- -D warnings 2>&1); then
                echo -e "${RED}  ✗ cargo clippy failed${NC}"
                echo "$OUTPUT" >&2
                FAILED=1
            else
                echo -e "${GREEN}  ✓ cargo clippy passed${NC}"
            fi
        fi
        
        # Tests (only if not in CI skip mode)
        if [ "${SKIP_TESTS:-false}" != "true" ]; then
            if ! OUTPUT=$(cargo test --lib 2>&1); then
                echo -e "${RED}  ✗ cargo test failed${NC}"
                echo "$OUTPUT" >&2
                FAILED=1
            else
                echo -e "${GREEN}  ✓ cargo test passed${NC}"
            fi
        fi
    else
        echo -e "${YELLOW}  ⚠ cargo not installed - skipping Rust checks${NC}"
    fi
    echo ""
fi

# TypeScript / JavaScript checks
if [[ " ${DETECTED_LANGUAGES[*]} " =~ " typescript " ]]; then
    echo -e "${BLUE}Running TypeScript/JavaScript checks...${NC}"
    
    if command -v pnpm &> /dev/null; then
        # Lint
        if ! OUTPUT=$(pnpm lint 2>&1); then
            echo -e "${RED}  ✗ pnpm lint failed${NC}"
            echo "$OUTPUT" >&2
            FAILED=1
        else
            echo -e "${GREEN}  ✓ pnpm lint passed${NC}"
        fi
        
        # Typecheck
        if ! OUTPUT=$(pnpm typecheck 2>&1); then
            echo -e "${RED}  ✗ pnpm typecheck failed${NC}"
            echo "$OUTPUT" >&2
            FAILED=1
        else
            echo -e "${GREEN}  ✓ pnpm typecheck passed${NC}"
        fi
        
        # Tests
        if [ "${SKIP_TESTS:-false}" != "true" ]; then
            if ! OUTPUT=$(pnpm test 2>&1); then
                echo -e "${RED}  ✗ pnpm test failed${NC}"
                echo "$OUTPUT" >&2
                FAILED=1
            else
                echo -e "${GREEN}  ✓ pnpm test passed${NC}"
            fi
        fi
    elif command -v npm &> /dev/null; then
        # Fallback to npm
        if ! OUTPUT=$(npm run lint 2>&1); then
            echo -e "${RED}  ✗ npm lint failed${NC}"
            echo "$OUTPUT" >&2
            FAILED=1
        else
            echo -e "${GREEN}  ✓ npm lint passed${NC}"
        fi
        
        if ! OUTPUT=$(npm run typecheck 2>&1); then
            echo -e "${RED}  ✗ npm typecheck failed${NC}"
            echo "$OUTPUT" >&2
            FAILED=1
        else
            echo -e "${GREEN}  ✓ npm typecheck passed${NC}"
        fi
        
        if [ "${SKIP_TESTS:-false}" != "true" ]; then
            if ! OUTPUT=$(npm test 2>&1); then
                echo -e "${RED}  ✗ npm test failed${NC}"
                echo "$OUTPUT" >&2
                FAILED=1
            else
                echo -e "${GREEN}  ✓ npm test passed${NC}"
            fi
        fi
    else
        echo -e "${YELLOW}  ⚠ pnpm/npm not installed - skipping TypeScript checks${NC}"
    fi
    echo ""
fi

# Python checks
if [[ " ${DETECTED_LANGUAGES[*]} " =~ " python " ]]; then
    echo -e "${BLUE}Running Python checks...${NC}"
    
    if command -v ruff &> /dev/null; then
        if ! OUTPUT=$(ruff check . 2>&1); then
            echo -e "${RED}  ✗ ruff check failed${NC}"
            echo "$OUTPUT" >&2
            FAILED=1
        else
            echo -e "${GREEN}  ✓ ruff check passed${NC}"
        fi
    else
        echo -e "${YELLOW}  ⚠ ruff not installed - skipping Python lint${NC}"
    fi
    
    if command -v black &> /dev/null; then
        if ! OUTPUT=$(black --check . 2>&1); then
            echo -e "${RED}  ✗ black check failed${NC}"
            echo "$OUTPUT" >&2
            FAILED=1
        else
            echo -e "${GREEN}  ✓ black check passed${NC}"
        fi
    else
        echo -e "${YELLOW}  ⚠ black not installed - skipping Python format${NC}"
    fi
    
    if [ "${SKIP_TESTS:-false}" != "true" ]; then
        if command -v pytest &> /dev/null; then
            if ! OUTPUT=$(pytest tests/ -q 2>&1); then
                echo -e "${RED}  ✗ pytest failed${NC}"
                echo "$OUTPUT" >&2
                FAILED=1
            else
                echo -e "${GREEN}  ✓ pytest passed${NC}"
            fi
        else
            echo -e "${YELLOW}  ⚠ pytest not installed - skipping Python tests${NC}"
        fi
    fi
    echo ""
fi

# Go checks
if [[ " ${DETECTED_LANGUAGES[*]} " =~ " go " ]]; then
    echo -e "${BLUE}Running Go checks...${NC}"
    
    if command -v go &> /dev/null; then
        # Format check
        if ! OUTPUT=$(gofmt -l . 2>&1); then
            echo -e "${RED}  ✗ gofmt found unformatted files${NC}"
            echo "$OUTPUT" >&2
            FAILED=1
        else
            echo -e "${GREEN}  ✓ gofmt passed${NC}"
        fi
        
        # Vet
        if ! OUTPUT=$(go vet ./... 2>&1); then
            echo -e "${RED}  ✗ go vet failed${NC}"
            echo "$OUTPUT" >&2
            FAILED=1
        else
            echo -e "${GREEN}  ✓ go vet passed${NC}"
        fi
        
        # Tests
        if [ "${SKIP_TESTS:-false}" != "true" ]; then
            if ! OUTPUT=$(go test ./... 2>&1); then
                echo -e "${RED}  ✗ go test failed${NC}"
                echo "$OUTPUT" >&2
                FAILED=1
            else
                echo -e "${GREEN}  ✓ go test passed${NC}"
            fi
        fi
    else
        echo -e "${YELLOW}  ⚠ go not installed - skipping Go checks${NC}"
    fi
    echo ""
fi

# Shell script checks
if [[ " ${DETECTED_LANGUAGES[*]} " =~ " shell " ]]; then
    echo -e "${BLUE}Running Shell script checks...${NC}"

    if command -v shellcheck &> /dev/null; then
        # Find all shell scripts and check them
        SHELL_SCRIPTS=$(find . -name "*.sh" -not -path "./.git/*" -not -path "./target/*" 2>/dev/null)
        if [ -n "$SHELL_SCRIPTS" ]; then
            # Run shellcheck, exclude info-level warnings (SC2034: unused variables)
            if ! OUTPUT=$(echo "$SHELL_SCRIPTS" | xargs shellcheck -e SC2034 2>&1); then
                echo -e "${RED}  ✗ shellcheck failed${NC}"
                echo "$OUTPUT" >&2
                FAILED=1
            else
                echo -e "${GREEN}  ✓ shellcheck passed${NC}"
            fi
        fi
    else
        echo -e "${YELLOW}  ⚠ shellcheck not installed - skipping shell checks${NC}"
    fi
    
    # BATS tests (if tests directory exists)
    if [ -d "tests" ] && [ "${SKIP_TESTS:-false}" != "true" ]; then
        if command -v bats &> /dev/null; then
            if ! OUTPUT=$(bats tests/ 2>&1); then
                echo -e "${RED}  ✗ bats tests failed${NC}"
                echo "$OUTPUT" >&2
                FAILED=1
            else
                echo -e "${GREEN}  ✓ bats tests passed${NC}"
            fi
        else
            echo -e "${YELLOW}  ⚠ bats not installed - skipping shell tests${NC}"
        fi
    fi
    echo ""
fi

# Markdown checks (if markdownlint is available)
if [[ " ${DETECTED_LANGUAGES[*]} " =~ " markdown " ]]; then
    echo -e "${BLUE}Running Markdown checks...${NC}"
    
    if command -v markdownlint &> /dev/null; then
        if ! OUTPUT=$(markdownlint "**/*.md" --ignore node_modules --ignore target 2>&1); then
            echo -e "${RED}  ✗ markdownlint failed${NC}"
            echo "$OUTPUT" >&2
            FAILED=1
        else
            echo -e "${GREEN}  ✓ markdownlint passed${NC}"
        fi
    else
        echo -e "${YELLOW}  ⚠ markdownlint not installed - skipping markdown checks${NC}"
    fi
    echo ""
fi

# --- Final result ---
if [ $FAILED -ne 0 ]; then
    echo -e "${RED}─────────────────────────────────────────────────────────────────${NC}"
    echo -e "${RED}│ ✗ Quality Gate FAILED                                         │${NC}"
    echo -e "${RED}─────────────────────────────────────────────────────────────────${NC}"
    echo ""
    echo "Fix the errors above and re-run quality gate."
    echo "Use SKIP_TESTS=true or SKIP_CLIPPY=true to skip specific checks."
    exit 2
fi

echo -e "${GREEN}─────────────────────────────────────────────────────────────────${NC}"
echo -e "${GREEN}│ ✓ All Quality Gates PASSED                                    │${NC}"
echo -e "${GREEN}─────────────────────────────────────────────────────────────────${NC}"
echo ""
echo "Languages checked: ${DETECTED_LANGUAGES[*]}"
