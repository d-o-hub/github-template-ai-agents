#!/usr/bin/env bash
# Git diff-based command invalidation logic
# Source this file in other scripts to use invalidation functions

set -euo pipefail

# Default invalidation rules (can be overridden in .command-verify.conf)
# Format: "file_pattern:command_prefix"
DEFAULT_INVALIDATION_RULES=(
    "package.json:npm"
    "package.json:yarn"
    "package.json:pnpm"
    "package.json:npx"
    "Cargo.toml:cargo"
    "Cargo.lock:cargo"
    "requirements.txt:pip"
    "requirements-dev.txt:pip"
    "pyproject.toml:python"
    "setup.py:python"
    "go.mod:go"
    "go.sum:go"
    "Gemfile:bundle"
    "Gemfile.lock:gem"
    "*.md:*"
)

# Load configuration if available
if [ -f ".command-verify.conf" ]; then
    # shellcheck source=/dev/null
    source ".command-verify.conf"
fi

# Use configured rules or defaults
# Security: Store rules as array to prevent word splitting/globbing issues.
# Ensure INVALIDATION_RULES is defined as an array to avoid unbound variable errors with set -u
# and prevent "bad array subscript" errors.
if ! declare -p INVALIDATION_RULES 2>/dev/null | grep -q 'declare -a'; then
    declare -a INVALIDATION_RULES=("${DEFAULT_INVALIDATION_RULES[@]}")
fi

# Check if a file matches a glob pattern
# Usage: matches_pattern "package.json" "*.json"
matches_pattern() {
    local file="$1"
    local pattern="$2"

    # Handle ** patterns
    if [[ "$pattern" == "**"* ]]; then
        local prefix="${pattern//\*\*/}"
        [[ "$file" == "$prefix"* ]] && return 0
    fi

    # Handle simple * patterns
    if [[ "$pattern" == *"*"* ]]; then
        local regex="^${pattern//\*/.*}$"
        [[ "$file" =~ $regex ]] && return 0
    fi

    # Exact match
    [[ "$file" == "$pattern" ]]
}

# Get commands affected by a file change
# Usage: get_affected_commands "package.json" "$commands_json"
get_affected_commands() {
    local changed_file="$1"
    local commands_json="$2"
    local affected=()

    # Security: Iterate over array safely
    for rule in "${INVALIDATION_RULES[@]}"; do
        IFS=':' read -r file_pattern cmd_prefix <<< "$rule"

        # Check if changed file matches the pattern
        if matches_pattern "$changed_file" "$file_pattern"; then
            # Find commands matching the prefix
            while IFS= read -r line; do
                [ -z "$line" ] && continue
                local cmd
                # Security: Use printf instead of echo to prevent option injection
                cmd=$(printf "%s\n" "$line" | jq -r '.command' 2>/dev/null || printf "")
                [ -z "$cmd" ] || [ "$cmd" = "null" ] && continue

                # Special case: *.md means commands in that specific file
                if [[ "$file_pattern" == "*.md" ]] && [[ "$changed_file" == *.md ]]; then
                    local cmd_file
                    cmd_file=$(printf "%s\n" "$line" | jq -r '.file' 2>/dev/null || printf "")
                    if [[ "$cmd_file" == "$changed_file" ]]; then
                        affected+=("$cmd")
                    fi
                elif [[ "$cmd_prefix" == "*" ]] || [[ "$cmd" == "$cmd_prefix"* ]]; then
                    affected+=("$cmd")
                fi
            done <<< "$commands_json"
        fi
    done

    # Output unique affected commands
    if [ ${#affected[@]} -gt 0 ]; then
        printf '%s\n' "${affected[@]}" | sort -u
    fi
}

# Build invalidation report
# Usage: build_invalidation_report "file1 file2" "$commands_json"
build_invalidation_report() {
    local changed_files="$1"
    local commands_json="$2"

    printf "=== Invalidation Report ===\n\n"
    printf "Changed files:\n"
    for file in $changed_files; do
        printf "  - %s\n" "$file"
    done
    printf "\n"

    local total_affected=0
    for file in $changed_files; do
        local affected
        affected=$(get_affected_commands "$file" "$commands_json")
        local count
        # Security: Ignore grep's nonzero exit and ensure count has a default value to prevent duplicate zeros or empty values.
        count=$(printf "%s\n" "$affected" | grep -c . || true)
        count=${count:-0}

        if [ "$count" -gt 0 ]; then
            printf "File: %s → %s commands to revalidate\n" "$file" "$count"
            total_affected=$((total_affected + count))
        fi
    done

    printf "\nTotal commands to revalidate: %s\n" "$total_affected"
}

# Export functions
export -f matches_pattern
export -f get_affected_commands
export -f build_invalidation_report
