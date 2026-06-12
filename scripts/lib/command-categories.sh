#!/usr/bin/env bash
# Command categorization for safety assessment
# Source this file in other scripts to use categorize_command()
set -euo pipefail

# Default categories (can be overridden in .command-verify.conf)
SAFE_KEYWORDS="${SAFE_KEYWORDS:-build:test:lint:check:status:list:help:version:describe:doc:info:show:get}"
CONDITIONAL_KEYWORDS="${CONDITIONAL_KEYWORDS:-install:clean:format:migrate:update:init:add:remove:delete:replace}"
DANGEROUS_KEYWORDS="${DANGEROUS_KEYWORDS:-rm:delete:drop:force:destroy:purge:reset:hard:kill:terminate:eval:exec}"

# Custom patterns for categories (E3)
SAFE_PATTERNS=()
CONDITIONAL_PATTERNS=()
DANGEROUS_PATTERNS=()

# Load project-specific configuration if available
if [[ -f ".command-verify.conf" ]]; then
    # shellcheck source=/dev/null
    source ".command-verify.conf"
fi

# Categorize a command as safe, conditional, dangerous, or unknown
categorize_command() {
    local cmd="$1"
    local cmd_lower
    # Security: Use printf for safe variable expansion and to prevent option injection.
    # Normalize input by removing common shell escapes/quotes and converting to lowercase.
    # Strips metacharacters used for obfuscation: quotes, backslashes, backticks,
    # dollar signs, braces, parentheses, and brackets.
    cmd_lower=$(printf "%s\n" "$cmd" | tr -d "'\"\\\\\`\$(){}[]" | tr '[:upper:]' '[:lower:]')

    # Regex for word boundaries including common shell metacharacters and commas
    local boundary="(^|[[:space:]]|[\|&;()<>|,])"
    local end_boundary="($|[[:space:]]|[\|&;()<>|,])"

    # Check custom dangerous patterns first (E3)
    for pattern in "${DANGEROUS_PATTERNS[@]:-}"; do
        [[ -z "$pattern" ]] && continue
        if [[ "$cmd_lower" == *"$pattern"* ]]; then
            printf "dangerous\n"
            return 0
        fi
    done

    # Optimization: Use localized IFS and arrays instead of here-strings (<<<) to eliminate
    # subshell overhead and temporary file creation during high-frequency looping.
    local old_opts="$-"
    set -f # Prevent globbing when splitting into arrays
    local IFS=':'
    local keywords=($DANGEROUS_KEYWORDS)

    # Check dangerous keywords with boundaries to avoid false positives (e.g., mkdir farm)
    # while still catching commands near shell metacharacters (e.g., (rm) or rm;ls)
    for keyword in "${keywords[@]}"; do
        [[ -z "$keyword" ]] && continue
        if [[ "$cmd_lower" =~ ${boundary}${keyword}${end_boundary} ]]; then
            [[ "$old_opts" != *f* ]] && set +f
            printf "dangerous\n"
            return 0
        fi
    done

    # Check custom conditional patterns (E3)
    for pattern in "${CONDITIONAL_PATTERNS[@]:-}"; do
        [[ -z "$pattern" ]] && continue
        if [[ "$cmd_lower" == *"$pattern"* ]]; then
            [[ "$old_opts" != *f* ]] && set +f
            printf "conditional\n"
            return 0
        fi
    done

    # Check conditional keywords with boundaries
    local c_keywords=($CONDITIONAL_KEYWORDS)
    for keyword in "${c_keywords[@]}"; do
        [[ -z "$keyword" ]] && continue
        if [[ "$cmd_lower" =~ ${boundary}${keyword}${end_boundary} ]]; then
            [[ "$old_opts" != *f* ]] && set +f
            printf "conditional\n"
            return 0
        fi
    done

    # Check custom safe patterns (E3)
    for pattern in "${SAFE_PATTERNS[@]:-}"; do
        [[ -z "$pattern" ]] && continue
        if [[ "$cmd_lower" == *"$pattern"* ]]; then
            [[ "$old_opts" != *f* ]] && set +f
            printf "safe\n"
            return 0
        fi
    done

    # Check safe keywords with boundaries
    local s_keywords=($SAFE_KEYWORDS)
    for keyword in "${s_keywords[@]}"; do
        [[ -z "$keyword" ]] && continue
        if [[ "$cmd_lower" =~ ${boundary}${keyword}${end_boundary} ]]; then
            [[ "$old_opts" != *f* ]] && set +f
            printf "safe\n"
            return 0
        fi
    done
    [[ "$old_opts" != *f* ]] && set +f

    # Unknown category
    printf "unknown\n"
    return 0
}

# Color reset code
NC='\033[0m'

# Get description for a category
get_category_description() {
    local category="$1"
    case "$category" in
        safe) printf "No side effects - can run without modifications\n" ;;
        conditional) printf "May modify files - review before running\n" ;;
        dangerous) printf "Potentially destructive - requires careful review\n" ;;
        unknown) printf "Category not determined - manual review recommended\n" ;;
        *) printf "Unknown category: %s\n" "$1" ;;
    esac
    return 0
}

is_safe_to_run() {
    local cmd="$1"
    local category
    category=$(categorize_command "$cmd")
    [[ "$category" == "safe" ]]
}

requires_warning() {
    local cmd="$1"
    local category
    category=$(categorize_command "$cmd")
    [[ "$category" == "dangerous" ]] || [[ "$category" == "conditional" ]]
}

print_category_badge() {
    local badge_category="$1"
    local category="$badge_category"
    local color
    case "$category" in
        safe) color='\033[0;32m' ;;
        conditional) color='\033[1;33m' ;;
        dangerous) color='\033[0;31m' ;;
        unknown) color='\033[0;36m' ;;
        *) color='\033[0m' ;;
    esac
    # Security: Use printf for safe variable output.
    # Note: %b is used for color codes to ensure they are interpreted correctly.
    printf "%b[%s]%b\n" "$color" "$category" "$NC"
    return 0
}

export -f categorize_command get_category_description is_safe_to_run requires_warning print_category_badge
