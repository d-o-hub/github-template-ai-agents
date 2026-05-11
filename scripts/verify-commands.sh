#!/usr/bin/env bash
# Main command verification script
# Reuses approach from https://github.com/d-oit/command-verify
# Usage: ./scripts/verify-commands.sh [--force|--stats|--json|--quick|--silent]

set -euo pipefail

REPO_ROOT="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
cd "$REPO_ROOT"

# Source libraries
if [ -f "$REPO_ROOT/scripts/lib/command-categories.sh" ]; then
    source "$REPO_ROOT/scripts/lib/command-categories.sh"
fi

if [ -f "$REPO_ROOT/scripts/lib/command-cache.sh" ]; then
    source "$REPO_ROOT/scripts/lib/command-cache.sh"
fi

if [ -f "$REPO_ROOT/scripts/lib/command-invalidation.sh" ]; then
    source "$REPO_ROOT/scripts/lib/command-invalidation.sh"
fi

# Configuration
CACHE_DIR=".cache/command-validations"
CONFIG_FILE=".command-verify.conf"
readonly UNKNOWN_CATEGORY="unknown"

# Load config if exists
[ -f "$CONFIG_FILE" ] && source "$CONFIG_FILE"

# Parse arguments
FORCE=false
STATS=false
JSON_OUTPUT=false
QUICK=false
SILENT=false

while [[ $# -gt 0 ]]; do
    case $1 in
        --force|-f) FORCE=true; shift ;;
        --stats|-s) STATS=true; shift ;;
        --json|-j) JSON_OUTPUT=true; shift ;;
        --quick|-q) QUICK=true; shift ;;
        --silent) SILENT=true; shift ;;
        --help|-h)
            echo "Usage: $0 [--force|--stats|--json|--quick|--silent]"
            echo ""
            echo "Verify all commands in markdown documentation with intelligent caching."
            echo ""
            echo "Options:"
            echo "  --force, -f    Force full validation, bypass cache"
            echo "  --stats, -s    Show detailed statistics"
            echo "  --json, -j     Output results as JSON"
            echo "  --quick, -q    Quick check (cache only)"
            echo "  --silent       Suppress output except errors"
            echo "  --help, -h     Show this help message"
            exit 0
            ;;
        *) echo "Unknown option: $1" >&2; exit 1 ;;
    esac
done

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
    YELLOW=''
    BLUE=''
    NC=''
fi

# Initialize cache
init_cache 2>/dev/null || true

# PHASE 1: Command Discovery
if ! $SILENT; then
    echo -e "${BLUE}📚 PHASE 1: Command Discovery${NC}"
fi

DISCOVERED_COMMANDS=""
if [ -x "./scripts/discover-commands.sh" ]; then
    DISCOVERED_COMMANDS=$(./scripts/discover-commands.sh 2>/dev/null | grep -v "^Discovering\|^Command\|^─\|^\$" || echo "")
fi

COMMAND_COUNT=0
if [ -n "$DISCOVERED_COMMANDS" ]; then
    COMMAND_COUNT=$(echo "$DISCOVERED_COMMANDS" | grep -c . || echo 0)
fi

if ! $SILENT; then
    echo -e "${GREEN}✓ Discovered $COMMAND_COUNT commands${NC}"
    echo ""
fi

# PHASE 2: Cache Check
if ! $SILENT; then
    echo -e "${BLUE}🔄 PHASE 2: Cache Check${NC}"
fi

if $FORCE; then
    if ! $SILENT; then
        echo -e "${YELLOW}⚡ Force mode: Clearing cache...${NC}"
    fi
    clear_cache 2>/dev/null || true
fi

# Get changed files
CHANGED_FILES=""
if type get_changed_files &> /dev/null; then
    CHANGED_FILES=$(get_changed_files 2>/dev/null || echo "")
fi
CHANGED_COUNT=0
if [ -n "$CHANGED_FILES" ]; then
    CHANGED_COUNT=$(echo "$CHANGED_FILES" | grep -c . || echo 0)
fi

if ! $SILENT; then
    echo -e "${GREEN}✓ Changed files since last validation: $CHANGED_COUNT${NC}"
fi

# PHASE 3: Validation
VALIDATED=0
CACHE_HITS=0
declare -a FAILED_COMMANDS=()
declare -A CATEGORY_COUNT=(["safe"]=0 ["conditional"]=0 ["dangerous"]=0 ["$UNKNOWN_CATEGORY"]=0)

if [ -n "$DISCOVERED_COMMANDS" ] && ! $QUICK; then
    while IFS= read -r cmd_entry; do
        [ -z "$cmd_entry" ] && continue

        # Extract command from JSON
        cmd=$(echo "$cmd_entry" | jq -r '.command' 2>/dev/null || echo "")
        [ -z "$cmd" ] || [ "$cmd" = "null" ] && continue

        # Check cache first
        CACHED=false
        if ! $FORCE && type get_cached_result &> /dev/null; then
            cached_result=$(get_cached_result "$cmd_entry" 2>/dev/null || echo "")
            if [ -n "$cached_result" ]; then
                # Check if this command needs invalidation
                if type should_invalidate_command &> /dev/null; then
                    if ! should_invalidate_command "$cmd_entry" "$CHANGED_FILES" 2>/dev/null; then
                        ((CACHE_HITS++))
                        CACHED=true

                        # Extract category from cached result
                        cached_cat=$(echo "$cached_result" | jq -r --arg unknown "$UNKNOWN_CATEGORY" '.category // $unknown' 2>/dev/null || echo "$UNKNOWN_CATEGORY")

                        # Security: Validate category against whitelist to prevent injection in arithmetic expansion
                        if [[ ! "$cached_cat" =~ ^(safe|conditional|dangerous|$UNKNOWN_CATEGORY)$ ]]; then
                            cached_cat="$UNKNOWN_CATEGORY"
                        fi

                        if [ -n "$cached_cat" ]; then
                            CATEGORY_COUNT[$cached_cat]=$((CATEGORY_COUNT[$cached_cat]+1))
                        fi
                        continue
                    fi
                else
                    ((CACHE_HITS++))
                    CACHED=true
                    continue
                fi
            fi
        fi

        # Validate command (categorize only, don't execute)
        category="$UNKNOWN_CATEGORY"
        if type categorize_command &> /dev/null; then
            category=$(categorize_command "$cmd" 2>/dev/null || echo "$UNKNOWN_CATEGORY")
        fi

        # Security: Validate category against whitelist to prevent injection in arithmetic expansion
        if [[ ! "$category" =~ ^(safe|conditional|dangerous|$UNKNOWN_CATEGORY)$ ]]; then
            category="$UNKNOWN_CATEGORY"
        fi

        # Update category count
        CATEGORY_COUNT[$category]=$((CATEGORY_COUNT[$category]+1))

        # Save to cache
        if type save_cached_result &> /dev/null; then
            # Security: Use jq to safely generate JSON and prevent injection
            result=$(jq -n --arg cat "$category" --arg cmd "$cmd" \
                '{"valid":true, "category":$cat, "command":$cmd}')
            save_cached_result "$cmd_entry" "$result" 2>/dev/null || true
        fi

        ((VALIDATED++))

        # Track dangerous commands
        if [ "$category" = "dangerous" ]; then
            FAILED_COMMANDS+=("$cmd")
        fi
    done <<< "$DISCOVERED_COMMANDS"
fi

# Calculate totals from cache + validated
TOTAL_SAFE=${CATEGORY_COUNT[safe]:-0}
TOTAL_CONDITIONAL=${CATEGORY_COUNT[conditional]:-0}
TOTAL_DANGEROUS=${CATEGORY_COUNT[dangerous]:-0}
TOTAL_UNKNOWN=${CATEGORY_COUNT[$UNKNOWN_CATEGORY]:-0}
TOTAL_ALL=$((TOTAL_SAFE + TOTAL_CONDITIONAL + TOTAL_DANGEROUS + TOTAL_UNKNOWN))

# PHASE 4: Results
if $JSON_OUTPUT; then
    cat << EOF
{
    "total_commands": $COMMAND_COUNT,
    "validated": $VALIDATED,
    "cache_hits": $CACHE_HITS,
    "categories": {
        "safe": $TOTAL_SAFE,
        "conditional": $TOTAL_CONDITIONAL,
        "dangerous": $TOTAL_DANGEROUS,
        "unknown": $TOTAL_UNKNOWN
    },
    "failed": ${#FAILED_COMMANDS[@]}
}
EOF
else
    if ! $SILENT; then
        echo ""
        echo -e "${BLUE}📊 Results:${NC}"
        echo "  Total commands:    $COMMAND_COUNT"
        echo "  Validated now:     $VALIDATED"
        echo "  From cache:        $CACHE_HITS"
        echo ""
        echo "  Categories:"
        echo -e "    Safe:          ${GREEN}$TOTAL_SAFE${NC}"
        echo -e "    Conditional:   ${YELLOW}$TOTAL_CONDITIONAL${NC}"
        echo -e "    Dangerous:     ${RED}$TOTAL_DANGEROUS${NC}"
        echo -e "    Unknown:       $TOTAL_UNKNOWN"

        if [ ${#FAILED_COMMANDS[@]} -gt 0 ]; then
            echo ""
            echo -e "${RED}⚠️  Dangerous commands found:${NC}"
            for cmd in "${FAILED_COMMANDS[@]}"; do
                echo -e "  ${RED}- $cmd${NC}"
            done
        fi

        echo ""
        if [ ${#FAILED_COMMANDS[@]} -eq 0 ]; then
            echo -e "${GREEN}✅ All commands validated successfully${NC}"
        else
            echo -e "${YELLOW}❌ Review required for ${#FAILED_COMMANDS[@]} dangerous commands${NC}"
        fi
    fi
fi

# Show stats if requested
if $STATS && ! $JSON_OUTPUT; then
    echo ""
    echo -e "${BLUE}=== Cache Statistics ===${NC}"
    if type get_cache_stats &> /dev/null; then
        get_cache_stats 2>/dev/null || echo "Cache stats unavailable"
    fi
    echo ""
    # Security: Pass variables to awk using -v to prevent injection
    echo "Cache hit rate: $(awk -v count="$COMMAND_COUNT" -v hits="$CACHE_HITS" 'BEGIN {if (count > 0) printf "%.1f", (hits/count)*100; else print "0.0"}')%"
fi

# Save current commit
save_current_commit 2>/dev/null || true

# Exit code
if [ ${#FAILED_COMMANDS[@]} -gt 0 ] && [ "${FAIL_ON_DANGEROUS:-false}" = "true" ]; then
    exit 1
fi

exit 0
