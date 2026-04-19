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

# Initialize cache directories
init_cache() {
    mkdir -p "$CACHE_DIR"
    mkdir -p "$COMMANDS_CACHE_DIR"
    touch "$AUDIT_LOG"
}

# Get the last validated commit hash
# Returns: commit hash or empty string if no previous validation
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
# Returns: newline-separated list of file paths
get_changed_files() {
    local last_commit
    last_commit=$(get_last_commit)
    
    if [ -z "$last_commit" ] || [ "$last_commit" = "no-git-repo" ]; then
        # First run or not a git repo - all files are "changed"
        if command -v git &> /dev/null && git rev-parse --git-dir &> /dev/null; then
            git ls-files "*.md" 2>/dev/null || true
        else
            find . -name "*.md" -type f 2>/dev/null | sed 's|^\./||' || true
        fi
    else
        # Get files changed since last validation
        git diff --name-only "$last_commit" HEAD -- "*.md" 2>/dev/null || true
    fi
}

# Check if a command needs revalidation based on changed files
# Usage: should_invalidate_command "npm run build" "file1.md file2.md package.json"
# Returns: 0 if should revalidate, 1 if cached result is valid
should_invalidate_command() {
    local cmd="$1"
    local changed_files="$2"
    
    # Load invalidation rules from config or use defaults
    local invalidation_rules
    invalidation_rules=("${INVALIDATION_RULES[@]:-package.json:npm package.json:yarn package.json:pnpm Cargo.toml:cargo requirements.txt:pip *.md:*}")
    
    # Check each changed file against invalidation rules
    for file in $changed_files; do
        local filename
        filename=$(basename "$file")
        
        # Rule: MD file change → commands in that specific file
        if [[ "$file" == *.md ]]; then
            if grep -q "\"file\":\"$file\"" <<< "$cmd" 2>/dev/null; then
                return 0
            fi
        fi
        
        # Rule: package.json → npm/yarn/pnpm commands
        if [[ "$filename" == "package.json" ]]; then
            if [[ "$cmd" =~ ^(npm|yarn|pnpm|npx|node) ]]; then
                return 0
            fi
        fi
        
        # Rule: Cargo.toml → cargo/rustc commands
        if [[ "$filename" == "Cargo.toml" ]] || [[ "$filename" == "Cargo.lock" ]]; then
            if [[ "$cmd" =~ ^(cargo|rustc) ]]; then
                return 0
            fi
        fi
        
        # Rule: requirements*.txt → pip/python commands
        if [[ "$filename" =~ ^requirements.*\.txt$ ]]; then
            if [[ "$cmd" =~ ^(pip|python) ]]; then
                return 0
            fi
        fi
        
        # Rule: pyproject.toml → python/pip commands
        if [[ "$filename" == "pyproject.toml" ]] || [[ "$filename" == "setup.py" ]]; then
            if [[ "$cmd" =~ ^(python|pip) ]]; then
                return 0
            fi
        fi
        
        # Rule: go.mod/go.sum → go commands
        if [[ "$filename" == "go.mod" ]] || [[ "$filename" == "go.sum" ]]; then
            if [[ "$cmd" =~ ^go ]]; then
                return 0
            fi
        fi
        
        # Rule: Gemfile* → bundle/gem commands
        if [[ "$filename" == "Gemfile" ]] || [[ "$filename" == "Gemfile.lock" ]]; then
            if [[ "$cmd" =~ ^(bundle|gem) ]]; then
                return 0
            fi
        fi
    done
    
    # No invalidation rule matched
    return 1
}

# Get cached validation result for a command
# Usage: get_cached_result "npm run build"
# Returns: JSON with validation result or empty if not cached
get_cached_result() {
    local cmd="$1"
    local cmd_hash
    cmd_hash=$(echo -n "$cmd" | md5sum | cut -d' ' -f1)
    
    local cache_file="$COMMANDS_CACHE_DIR/$cmd_hash.json"
    if [ -f "$cache_file" ]; then
        cat "$cache_file"
    else
        echo ""
    fi
}

# Save validation result to cache
# Usage: save_cached_result "npm run build" '{"valid":true,"category":"safe"}'
save_cached_result() {
    local cmd="$1"
    local result="$2"
    
    local cmd_hash
    cmd_hash=$(echo -n "$cmd" | md5sum | cut -d' ' -f1)
    
    echo "$result" > "$COMMANDS_CACHE_DIR/$cmd_hash.json"
    
    # Log to audit trail
    echo "$(date -Iseconds) CACHED: $cmd" >> "$AUDIT_LOG"
}

# Clear entire cache
clear_cache() {
    rm -rf "$COMMANDS_CACHE_DIR"/*
    rm -f "$LAST_COMMIT_FILE"
    rm -f "$MANIFEST_FILE"
    echo "$(date -Iseconds) CACHE_CLEARED" >> "$AUDIT_LOG"
}

# Get cache statistics
# Returns: JSON with cache stats
get_cache_stats() {
    local cached_count=0
    local total_size=0
    
    if [ -d "$COMMANDS_CACHE_DIR" ]; then
        cached_count=$(find "$COMMANDS_CACHE_DIR" -name "*.json" -type f 2>/dev/null | wc -l)
        total_size=$(du -sh "$COMMANDS_CACHE_DIR" 2>/dev/null | cut -f1 || echo "0")
    fi
    
    local last_commit=""
    local last_validation="never"
    if [ -f "$LAST_COMMIT_FILE" ]; then
        last_commit=$(cat "$LAST_COMMIT_FILE")
        if [ "$last_commit" != "no-git-repo" ]; then
            last_validation=$(git log -1 --format="%ci" "$last_commit" 2>/dev/null || echo "unknown")
        fi
    fi
    
    cat << EOF
{
    "cached_commands": $cached_count,
    "cache_size": "$total_size",
    "last_commit": "$last_commit",
    "last_validation": "$last_validation"
}
