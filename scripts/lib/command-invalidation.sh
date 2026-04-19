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
INVALIDATION_RULES="${INVALIDATION_RULES[@]:-${DEFAULT_INVALIDATION_RULES[@]}}"

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

    for rule in $INVALIDATION_RULES; do
        IFS=':' read -r file_pattern cmd_prefix <<< "$rule"

        # Check if changed file matches the pattern
        if matches_pattern "$changed_file" "$file_pattern"; then
            # Find commands matching the prefix
            while IFS= read -r line; do
                [ -z "$line" ] && continue
                local cmd
                cmd=$(echo "$line" | grep -o '"command":"[^"]*"' | cut -d'"' -f4)
                [ -z "$cmd" ] && continue

                # Special case: *.md means commands in that specific file
                if [[ "$file_pattern" == "*.md" ]] && [[ "$changed_file" == *.md ]]; then
                    local cmd_file
                    cmd_file=$(echo "$line" | grep -o '"file":"[^"]*"' | cut -d'"' -f4)
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
    printf '%s\n' "${affected[@]}" | sort -u
}

# Build invalidation report
# Usage: build_invalidation_report "commit1 commit2" "$commands_json"
build_invalidation_report() {
    local changed_files="$1"
    local commands_json="$2"

    echo "=== Invalidation Report ==="
    echo ""
    echo "Changed files:"
    for file in $changed_files; do
        echo "  - $file"
    done
    echo ""

    local total_affected=0
    for file in $changed_files; do
        local affected
        affected=$(get_affected_commands "$file" "$commands_json")
        local count
        count=$(echo "$affected" | grep -c . || echo 0)

        if [ "$count" -gt 0 ]; then
            echo "File: $file → $count commands to revalidate"
            total_affected=$((total_affected + count))
        fi
    done

    echo ""
    echo "Total commands to revalidate: $total_affected"
}

# Export functions
export -f matches_pattern
export -f get_affected_commands
export -f build_invalidation_report
