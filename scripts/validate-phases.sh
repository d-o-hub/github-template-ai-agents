#!/usr/bin/env bash
# Validates SDLC phase progression and artifact existence.
# Used in quality_gate.sh.

REPO_ROOT="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
PHASES_FILE="$REPO_ROOT/PHASES.md"

# Colors for output
if [[ -t 1 ]] && [[ "${FORCE_COLOR:-}" != "0" ]]; then
    RED='\033[0;31m'
    GREEN='\033[0;32m'
    NC='\033[0m'
else
    RED=''
    GREEN=''
    NC=''
fi

if [ ! -f "$PHASES_FILE" ]; then
    echo -e "${RED}✗${NC} PHASES.md missing. Run 'cp templates/PHASES.md PHASES.md' to initialize."
    exit 1
fi

CURRENT_PHASE=$(grep "Current Phase:" "$PHASES_FILE" | cut -d':' -f2 | xargs)

echo "Validating Phase: $CURRENT_PHASE"

FAILED=0

check_artifact() {
    local file=$1
    local phase=$2
    if [ ! -f "$REPO_ROOT/$file" ]; then
        echo -e "  ${RED}✗${NC} Missing $file for phase $phase"
        FAILED=1
    else
        echo -e "  ${GREEN}✓${NC} $file exists"
    fi
}

check_approval() {
    local phase=$1
    # Find the line number of the phase header
    local line_num
    line_num=$(grep -n "## $phase" "$PHASES_FILE" | cut -d: -f1)
    if [ -z "$line_num" ]; then
        echo -e "  ${RED}✗${NC} Phase header '## $phase' not found in PHASES.md"
        FAILED=1
        return
    fi
    # Check the next 10 lines for the approval marker
    if ! tail -n "+$line_num" "$PHASES_FILE" | head -n 10 | grep -qi "Human Approval: \[x\]"; then
        echo -e "  ${RED}✗${NC} Human Approval missing in PHASES.md for phase $phase"
        FAILED=1
    else
        echo -e "  ${GREEN}✓${NC} Human Approval found for phase $phase"
    fi
}

case "$CURRENT_PHASE" in
    SPECIFY)
        # No specific artifacts required to be *finished* yet
        ;;
    PLAN)
        check_artifact "SPEC.md" "SPECIFY"
        check_approval "1. SPECIFY"
        ;;
    TASKS)
        check_artifact "SPEC.md" "SPECIFY"
        check_approval "1. SPECIFY"
        check_artifact "PLAN.md" "PLAN"
        check_approval "2. PLAN"
        ;;
    IMPLEMENT)
        check_artifact "SPEC.md" "SPECIFY"
        check_approval "1. SPECIFY"
        check_artifact "PLAN.md" "PLAN"
        check_approval "2. PLAN"
        check_artifact "TASKS.md" "TASKS"
        check_approval "3. TASKS"
        ;;
    *)
        echo -e "${RED}✗${NC} Unknown phase: $CURRENT_PHASE"
        exit 1
        ;;
esac

if [ $FAILED -ne 0 ]; then
    exit 2
fi

echo -e "${GREEN}✓ Phase validation passed${NC}"
exit 0
