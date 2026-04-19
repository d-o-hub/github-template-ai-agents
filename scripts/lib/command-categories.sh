#!/usr/bin/env bash
# Command categorization for safety assessment
# Source this file in other scripts to use categorize_command()

# Default categories (can be overridden in .command-verify.conf)
SAFE_KEYWORDS="${SAFE_KEYWORDS:-build:test:lint:check:status:list:help:version:describe:doc:info:show:get}"
CONDITIONAL_KEYWORDS="${CONDITIONAL_KEYWORDS:-install:clean:format:migrate:update:init:add:remove:delete:replace}"
DANGEROUS_KEYWORDS="${DANGEROUS_KEYWORDS:-rm:delete:drop:force:destroy:purge:reset:hard:kill:terminate}"

# Load project-specific configuration if available
if [ -f ".command-verify.conf" ]; then
    # shellcheck source=/dev/null
    source ".command-verify.conf"
fi

# Categorize a command as safe, conditional, dangerous, or unknown
# Usage: categorize_command "npm run build"
# Returns: category name via stdout
categorize_command() {
    local cmd="$1"
    local cmd_lower
    cmd_lower=$(echo "$cmd" | tr '[:upper:]' '[:lower:]')
    
    # Check dangerous first (highest priority)
    IFS=':' read -ra keywords <<< "$DANGEROUS_KEYWORDS"
    for keyword in "${keywords[@]}"; do
        [ -z "$keyword" ] && continue
        if [[ "$cmd_lower" == *"$keyword"* ]]; then
            echo "dangerous"
            return 0
        fi
    done
    
    # Check conditional
    IFS=':' read -ra keywords <<< "$CONDITIONAL_KEYWORDS"
    for keyword in "${keywords[@]}"; do
        [ -z "$keyword" ] && continue
        if [[ "$cmd_lower" == *"$keyword"* ]]; then
            echo "conditional"
            return 0
        fi
    done
    
    # Check safe
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
# Usage: get_category_description "safe"
get_category_description() {
    case "$1" in
        safe)
            echo "No side effects - can run without modifications"
            ;;
        conditional)
            echo "May modify files - review before running"
            ;;
        dangerous)
            echo "Potentially destructive - requires careful review"
            ;;
        unknown)
            echo "Category not determined - manual review recommended"
            ;;
        *)
            echo "Unknown category: $1"
            ;;
    esac
}

# Check if a command is safe to run automatically
# Usage: is_safe_to_run "npm run build"
# Returns: 0 if safe, 1 otherwise
is_safe_to_run() {
    local category
    category=$(categorize_command "$1")
    [ "$category" = "safe" ]
}

# Check if a command requires warning before running
# Usage: requires_warning "rm -rf /tmp"
# Returns: 0 if warning needed, 1 otherwise
requires_warning() {
    local category
    category=$(categorize_command "$1")
    [ "$category" = "dangerous" ] || [ "$category" = "conditional" ]
}

# Print colored category badge
# Usage: print_category_badge "safe"
print_category_badge() {
    local category="$1"
    local color
    
    case "$category" in
        safe)       color='\033[0;32m' ;;  # Green
        conditional) color='\033[1;33m' ;;  # Yellow
        dangerous)  color='\033[0;31m' ;;  # Red
        unknown)    color='\033[0;36m' ;;  # Cyan
        *)          color='\033[0m' ;;     # Reset
    esac
    
    echo -e "${color}[${category}]${NC}"
}

# Count commands by category from JSON input
# Usage: echo "$json" | count_commands_by_category
count_commands_by_category() {
    local safe=0 conditional=0 dangerous=0 unknown=0
    
    while IFS= read -r line; do
        local cmd
        cmd=$(echo "$line" | grep -o '"command":"[^"]*"' | cut -d'"' -f4)
        [ -z "$cmd" ] && continue
        
        local cat
        cat=$(categorize_command "$cmd")
        case "$cat" in
            safe) ((safe++)) ;;
            conditional) ((conditional++)) ;;
            dangerous) ((dangerous++)) ;;
            *) ((unknown++)) ;;
        esac
    done
    
    echo "safe:$safe conditional:$conditional dangerous:$dangerous unknown:$unknown"
}

# Export functions for use in subshells
export -f categorize_command
export -f get_category_description
export -f is_safe_to_run
export -f requires_warning
export -f print_category_badge
export -f count_commands_by_category
