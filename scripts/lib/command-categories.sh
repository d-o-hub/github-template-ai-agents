#!/usr/bin/env bash
# Command categorization for safety assessment
# Source this file in other scripts to use categorize_command()
set -euo pipefail

# Default categories (can be overridden in .command-verify.conf)
SAFE_KEYWORDS="${SAFE_KEYWORDS:-build:test:lint:check:status:list:help:version:describe:doc:info:show:get}"
CONDITIONAL_KEYWORDS="${CONDITIONAL_KEYWORDS:-install:clean:format:migrate:update:init:add:remove:delete:replace}"
DANGEROUS_KEYWORDS="${DANGEROUS_KEYWORDS:-rm:delete:drop:force:destroy:purge:reset:hard:kill:terminate}"

# Custom patterns for categories (E3)
SAFE_PATTERNS=()
CONDITIONAL_PATTERNS=()
DANGEROUS_PATTERNS=()

# Load project-specific configuration if available
if [ -f ".command-verify.conf" ]; then
    # shellcheck source=/dev/null
    source ".command-verify.conf"
fi

# Categorize a command as safe, conditional, dangerous, or unknown
categorize_command() {
    local cmd="$1"
    local cmd_lower
    cmd_lower=$(echo "$cmd" | tr '[:upper:]' '[:lower:]')

    # Check custom dangerous patterns first (E3)
    for pattern in "${DANGEROUS_PATTERNS[@]:-}"; do
        [ -z "$pattern" ] && continue
        if [[ "$cmd_lower" == *"$pattern"* ]]; then
            echo "dangerous"
            return 0
        fi
    done

    # Check dangerous keywords
    IFS=':' read -ra keywords <<< "$DANGEROUS_KEYWORDS"
    for keyword in "${keywords[@]}"; do
        [ -z "$keyword" ] && continue
        if [[ "$cmd_lower" == *"$keyword"* ]]; then
            echo "dangerous"
            return 0
        fi
    done

    # Check custom conditional patterns (E3)
    for pattern in "${CONDITIONAL_PATTERNS[@]:-}"; do
        [ -z "$pattern" ] && continue
        if [[ "$cmd_lower" == *"$pattern"* ]]; then
            echo "conditional"
            return 0
        fi
    done

    # Check conditional keywords
    IFS=':' read -ra keywords <<< "$CONDITIONAL_KEYWORDS"
    for keyword in "${keywords[@]}"; do
        [ -z "$keyword" ] && continue
        if [[ "$cmd_lower" == *"$keyword"* ]]; then
            echo "conditional"
            return 0
        fi
    done

    # Check custom safe patterns (E3)
    for pattern in "${SAFE_PATTERNS[@]:-}"; do
        [ -z "$pattern" ] && continue
        if [[ "$cmd_lower" == *"$pattern"* ]]; then
            echo "safe"
            return 0
        fi
    done

    # Check safe keywords
    IFS=':' read -ra keywords <<< "$SAFE_KEYWORDS"
    for keyword in "${keywords[@]}"; do
        [ -z "$keyword" ] && continue
        if [[ "$cmd_lower" == *"$keyword"* ]]; then
            echo "safe"
            return 0
        fi
    done

    # Unknown category
    echo "unknown"
    return 0
}

# Get description for a category
get_category_description() {
    case "$1" in
        safe) echo "No side effects - can run without modifications" ;;
        conditional) echo "May modify files - review before running" ;;
        dangerous) echo "Potentially destructive - requires careful review" ;;
        unknown) echo "Category not determined - manual review recommended" ;;
        *) echo "Unknown category: $1" ;;
    esac
}

is_safe_to_run() {
    local category
    category=$(categorize_command "$1")
    [ "$category" = "safe" ]
}

requires_warning() {
    local category
    category=$(categorize_command "$1")
    [ "$category" = "dangerous" ] || [ "$category" = "conditional" ]
}

print_category_badge() {
    local category="$1"
    local color
    case "$category" in
        safe) color='\033[0;32m' ;;
        conditional) color='\033[1;33m' ;;
        dangerous) color='\033[0;31m' ;;
        unknown) color='\033[0;36m' ;;
        *) color='\033[0m' ;;
    esac
    echo -e "${color}[${category}]${NC}"
}

export -f categorize_command get_category_description is_safe_to_run requires_warning print_category_badge
