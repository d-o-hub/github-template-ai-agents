#!/usr/bin/env bash
# Command categorization for safety assessment
# Source this file in other scripts to use categorize_command()
set -euo pipefail

# Security Hardening: 2026-06-20 - Prevented keyword merging bypasses.
# Default categories (can be overridden in .command-verify.conf)
SAFE_KEYWORDS="${SAFE_KEYWORDS:-build:test:lint:check:status:list:help:version:describe:doc:info:show:get}"
CONDITIONAL_KEYWORDS="${CONDITIONAL_KEYWORDS:-install:clean:format:migrate:update:init:add:remove:delete:replace:chmod:chown:chgrp:setfacl}"
# Destructive and administrative commands (strict boundaries)
DESTRUCTIVE_KEYWORDS="${DESTRUCTIVE_KEYWORDS:-rm:delete:drop:force:destroy:purge:reset:hard:kill:terminate:eval:exec:sudo:doas:docker:kubectl:podman:rmdir:dd}"
# Language interpreters (broad boundaries to catch versioned ones like python3.11)
INTERPRETER_KEYWORDS="${INTERPRETER_KEYWORDS:-sh:bash:zsh:python:python3:node:perl:ruby:php:deno:bun}"
# Networking tools (strict boundaries to avoid false positives like curl.sh)
NETWORK_KEYWORDS="${NETWORK_KEYWORDS:-curl:wget:nc:netcat:nmap:ssh:scp:sftp:rsync:socat}"

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
    # Normalize input by removing common shell escapes/quotes and converting to lowercase.
    # Strips metacharacters used for obfuscation: quotes and backslashes are removed.
    # Other shell metacharacters that act as separators (backticks, dollar signs, braces,
    # parentheses, brackets, semicolons, etc.) are replaced with spaces to prevent
    # keyword merging bypasses (e.g., curl${IFS}url).
    # Optimization: Use native Bash parameter expansion instead of tr pipeline to eliminate subshells.
    cmd_lower="$cmd"
    cmd_lower="${cmd_lower//\'/}"
    cmd_lower="${cmd_lower//\"/}"
    cmd_lower="${cmd_lower//\\/}"
    cmd_lower="${cmd_lower//\`/ }"
    cmd_lower="${cmd_lower//\$/ }"
    cmd_lower="${cmd_lower//\(/ }"
    cmd_lower="${cmd_lower//\)/ }"
    cmd_lower="${cmd_lower//\{/ }"
    cmd_lower="${cmd_lower//\}/ }"
    cmd_lower="${cmd_lower//\[/ }"
    cmd_lower="${cmd_lower//\]/ }"
    cmd_lower="${cmd_lower//;/ }"
    cmd_lower="${cmd_lower//&/ }"
    cmd_lower="${cmd_lower//|/ }"
    cmd_lower="${cmd_lower//</ }"
    cmd_lower="${cmd_lower//>/ }"
    cmd_lower="${cmd_lower//,/ }"

    # Note: Using `cmd_lower="${cmd_lower,,}"` is supported as per repository memory for bash 4.0+.
    cmd_lower="${cmd_lower,,}"

    # Regex for word boundaries including common shell metacharacters, commas, slashes, and colons.
    # Slashes are included to detect path-prefixed commands (e.g., /bin/rm).
    # Colons are included to handle colon-prefixed commands or multi-command strings.
    local boundary="(^|[[:space:]]|[|&;()<>,\/:])"
    local end_boundary="($|[[:space:]]|[|&;()<>,\/:])"
    # Broad boundary to catch versioned interpreters (e.g., python3.11)
    local broad_end_boundary="($|[[:space:]]|[|&;()<>,\/:\.])"

    # Check custom dangerous patterns first (E3)
    for pattern in "${DANGEROUS_PATTERNS[@]:-}"; do
        [[ -z "$pattern" ]] && continue
        if [[ "$cmd_lower" == *"$pattern"* ]]; then
            printf "dangerous\n"
            return 0
        fi
    done

    # Check destructive keywords with strict boundaries
    local destructive_regex="${boundary}(${DESTRUCTIVE_KEYWORDS//:/|})${end_boundary}"
    if [[ "$cmd_lower" =~ $destructive_regex ]]; then
        printf "dangerous\n"
        return 0
    fi

    # Check interpreter keywords with broad boundaries (to catch python3.11)
    local interpreter_regex="${boundary}(${INTERPRETER_KEYWORDS//:/|})${broad_end_boundary}"
    if [[ "$cmd_lower" =~ $interpreter_regex ]]; then
        # Negative lookahead alternative: ensure it is not a script file like python.sh
        if [[ "$cmd_lower" =~ ${boundary}(${INTERPRETER_KEYWORDS//:/|})\.(sh|py|pl|rb|js) ]]; then
             : # Matches script name, continue
        else
             printf "dangerous\n"
             return 0
        fi
    fi

    # Check network keywords with strict boundaries
    local network_regex="${boundary}(${NETWORK_KEYWORDS//:/|})${end_boundary}"
    if [[ "$cmd_lower" =~ $network_regex ]]; then
        # Ensure it is not followed by .sh or .py which indicates a script name
        if [[ "$cmd_lower" =~ ${boundary}(${NETWORK_KEYWORDS//:/|})\.(sh|py|pl|rb|js) ]]; then
            : # Likely a script name, ignore
        else
            printf "dangerous\n"
            return 0
        fi
    fi

    # Check custom conditional patterns (E3)
    for pattern in "${CONDITIONAL_PATTERNS[@]:-}"; do
        [[ -z "$pattern" ]] && continue
        if [[ "$cmd_lower" == *"$pattern"* ]]; then
            printf "conditional\n"
            return 0
        fi
    done

    # Check conditional keywords with boundaries
    local conditional_regex="${boundary}(${CONDITIONAL_KEYWORDS//:/|})${end_boundary}"
    if [[ "$cmd_lower" =~ $conditional_regex ]]; then
        printf "conditional\n"
        return 0
    fi

    # Check custom safe patterns (E3)
    for pattern in "${SAFE_PATTERNS[@]:-}"; do
        [[ -z "$pattern" ]] && continue
        if [[ "$cmd_lower" == *"$pattern"* ]]; then
            printf "safe\n"
            return 0
        fi
    done

    # Check safe keywords with boundaries
    local safe_regex="${boundary}(${SAFE_KEYWORDS//:/|})${end_boundary}"
    if [[ "$cmd_lower" =~ $safe_regex ]]; then
        printf "safe\n"
        return 0
    fi

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
