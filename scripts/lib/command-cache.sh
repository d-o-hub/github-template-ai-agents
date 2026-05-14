#!/usr/bin/env bash
# Git diff-based cache management for command verification
# Source this file in other scripts to use cache functions

set -euo pipefail

# Cache directory configuration
CACHE_DIR="${CACHE_DIR:-.cache/command-validations}"
LAST_COMMIT_FILE="$CACHE_DIR/last-commit.txt"
COMMANDS_CACHE_DIR="$CACHE_DIR/commands"
MANIFEST_FILE="$CACHE_DIR/manifest.json"
AUDIT_LOG="$CACHE_DIR/audit.log"
MAX_AUDIT_LOG_LINES=1000

# Initialize cache directories
init_cache() {
    mkdir -p "$CACHE_DIR"
    mkdir -p "$COMMANDS_CACHE_DIR"
    touch "$AUDIT_LOG"
}

# Get the last validated commit hash
get_last_commit() {
    if [ -f "$LAST_COMMIT_FILE" ]; then
        cat "$LAST_COMMIT_FILE"
    else
        echo ""
    fi
}

# Save current commit as last validated
save_current_commit() {
    if command -v git &> /dev/null && git rev-parse --git-dir &> /dev/null; then
        git rev-parse HEAD > "$LAST_COMMIT_FILE"
    else
        echo "no-git-repo" > "$LAST_COMMIT_FILE"
    fi
}

# Get list of changed markdown files since last validation
get_changed_files() {
    local last_commit
    last_commit=$(get_last_commit)

    if [ -z "$last_commit" ] || [ "$last_commit" = "no-git-repo" ]; then
        if command -v git &> /dev/null && git rev-parse --git-dir &> /dev/null; then
            git ls-files "*.md" 2>/dev/null || true
        else
            find . -name "*.md" -type f 2>/dev/null | sed 's|^./||' || true
        fi
    else
        git diff --name-only "$last_commit" HEAD -- "*.md" 2>/dev/null || true
    fi
}

# Check if a command needs revalidation
should_invalidate_command() {
    local cmd_json="$1"
    local changed_files="$2"

    local cmd
    cmd=$(echo "$cmd_json" | jq -r '.command')
    local file
    file=$(echo "$cmd_json" | jq -r '.file')

    # Use a loop that handles spaces in filenames if needed, though here changed_files is space-separated
    for changed in $changed_files; do
        if [[ "$changed" == "$file" ]]; then
            return 0
        fi

        # Dependency based invalidation
        case "$(basename "$changed")" in
            package.json) [[ "$cmd" =~ ^(npm|yarn|pnpm|npx|node) ]] && return 0 ;;
            Cargo.toml|Cargo.lock) [[ "$cmd" =~ ^(cargo|rustc) ]] && return 0 ;;
            requirements*.txt|pyproject.toml|setup.py) [[ "$cmd" =~ ^(pip|python) ]] && return 0 ;;
            go.mod|go.sum) [[ "$cmd" =~ ^go ]] && return 0 ;;
            Gemfile*) [[ "$cmd" =~ ^(bundle|gem) ]] && return 0 ;;
        esac
    done
    return 1
}

# Get structured cache path (E1)
get_cache_path() {
    local cmd_json="$1"
    local file
    file=$(echo "$cmd_json" | jq -r '.file // "unknown"')
    local line
    line=$(echo "$cmd_json" | jq -r '.line // 0')

    # Sanitize file path for use in directory structure
    local safe_file
    safe_file=$(echo "$file" | sed 's|^./||' | tr '/' '_')

    echo "$COMMANDS_CACHE_DIR/${safe_file}_line_${line}.json"
}

# Get cached validation result
get_cached_result() {
    local cache_file
    cache_file=$(get_cache_path "$1")

    if [ -f "$cache_file" ]; then
        cat "$cache_file"
    else
        echo ""
    fi
}

# Save validation result to cache and rotate audit log (E5)
save_cached_result() {
    local cmd_json="$1"
    local result="$2"

    local cache_file
    cache_file=$(get_cache_path "$cmd_json")
    mkdir -p "$(dirname "$cache_file")"
    echo "$result" > "$cache_file"

    # Log to audit trail and rotate
    local cmd
    cmd=$(echo "$cmd_json" | jq -r '.command')
    echo "$(date -Iseconds) CACHED: $cmd" >> "$AUDIT_LOG"

    if [ "$(wc -l < "$AUDIT_LOG")" -gt "$MAX_AUDIT_LOG_LINES" ]; then
        tail -n "$MAX_AUDIT_LOG_LINES" "$AUDIT_LOG" > "${AUDIT_LOG}.tmp" && mv "${AUDIT_LOG}.tmp" "$AUDIT_LOG"
    fi
}

# Clear entire cache
clear_cache() {
    rm -rf "$COMMANDS_CACHE_DIR"/*
    rm -f "$LAST_COMMIT_FILE"
    rm -f "$MANIFEST_FILE"
    echo "$(date -Iseconds) CACHE_CLEARED" >> "$AUDIT_LOG"
}

export -f init_cache get_last_commit save_current_commit get_changed_files should_invalidate_command get_cached_result save_cached_result clear_cache
