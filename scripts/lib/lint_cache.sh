#!/usr/bin/env bash

# File-hash cache for linters to skip unchanged files.
# Stored in .git/lint-cache/

# Ensure REPO_ROOT is set
if [ -z "${REPO_ROOT:-}" ]; then
    REPO_ROOT="$(cd "$(dirname "${BASH_SOURCE[0]}")/../.." && pwd)"
fi

# Define CACHE_DIR - relative to .git
# We use git rev-parse to find the real .git dir (handles worktrees/submodules)
if command -v git &> /dev/null && git -C "$REPO_ROOT" rev-parse --git-dir &> /dev/null; then
    GIT_DIR=$(git -C "$REPO_ROOT" rev-parse --git-dir)
    # If GIT_DIR is relative, make it absolute relative to REPO_ROOT
    if [[ "$GIT_DIR" != /* ]]; then
        GIT_DIR="$REPO_ROOT/$GIT_DIR"
    fi
    CACHE_DIR="$GIT_DIR/lint-cache"
else
    # Fallback if not in a git repo (unlikely for a pre-commit hook)
    CACHE_DIR="$REPO_ROOT/.lint-cache"
fi

mkdir -p -- "$CACHE_DIR"

# Global associative array for config hash caching (Bash 4+)
# This avoids re-hashing the same config file hundreds of times
declare -A _CONFIG_HASH_CACHE

# Helper for portable sha256
_get_hash_internal() {
    local file="$1"
    if [ ! -f "$file" ]; then
        printf "none\n"
        return
    fi
    # Optimization: Use internal Bash variables if we can avoid external tools
    # but for content hashing, external tool is safer.
    if command -v sha256sum &> /dev/null; then
        local res
        res=$(sha256sum -- "$file")
        printf "%s\n" "${res%% *}"
    elif command -v shasum &> /dev/null; then
        local res
        res=$(shasum -a 256 -- "$file")
        printf "%s\n" "${res%% *}"
    else
        # Security: Fail closed if no cryptographic hashing tool is available
        # to prevent collision-prone fallbacks that could bypass security checks.
        printf "Error: Neither sha256sum nor shasum is available. Cannot generate secure cache keys.\n" >&2
        exit 1
    fi
}

lint_if_changed() {
    local file="$1"
    local tool_id="$2"
    local config_file="$3"
    shift 3
    # The remaining arguments are the command to run

    # Performance optimization: Compute cache key early for timestamp fast-path
    # Replace characters that might be problematic in filenames
    # Use native Bash parameter expansion instead of tr subshell
    local safe_file="${file//[\/\. ]/_}"
    local cache_key="$CACHE_DIR/${tool_id}_${safe_file}"

    # Fast-path: Check if cache_key exists and is newer than the source file
    # This avoids expensive sha256sum calls for unchanged files (~3.5ms vs ~0.01ms per call)
    if [[ -f "$cache_key" ]] && [[ "$cache_key" -nt "$file" ]]; then
        local skip=1
        if [[ -n "$config_file" ]]; then
            local real_config=""
            if [[ -f "$config_file" ]]; then
                real_config="$config_file"
            elif [[ -f "$REPO_ROOT/$config_file" ]]; then
                real_config="$REPO_ROOT/$config_file"
            fi

            # If config file is newer than our cache, we cannot skip
            if [[ -n "$real_config" ]] && [[ ! "$cache_key" -nt "$real_config" ]]; then
                skip=0
            fi
        fi
        [[ $skip -eq 1 ]] && return 0
    fi

    # Compute hashes
    local file_hash
    file_hash=$(_get_hash_internal "$file")

    local config_hash="none"
    if [[ -n "$config_file" ]]; then
        # Check if config_file is in memory cache
        # Using associative array lookup directly for robustness with keys containing dots
        local cached_val=""
        cached_val="${_CONFIG_HASH_CACHE["$config_file"]-}"
        if [[ -n "$cached_val" ]]; then
            config_hash="$cached_val"
        else
            # Check if config_file is absolute or relative to REPO_ROOT
            local real_config=""
            if [ -f "$config_file" ]; then
                real_config="$config_file"
            elif [ -f "$REPO_ROOT/$config_file" ]; then
                real_config="$REPO_ROOT/$config_file"
            fi

            if [ -n "$real_config" ]; then
                config_hash=$(_get_hash_internal "$real_config")
                _CONFIG_HASH_CACHE["$config_file"]="$config_hash"
            fi
        fi
    fi

    local cache_value="${file_hash}:${config_hash}"

    # Check cache (secondary check against content hash for robustness)
    # Performance optimization: Use read instead of cat subshell
    if [[ -f "$cache_key" ]]; then
        local cached_content
        read -r cached_content < "$cache_key" || true
        if [[ "$cached_content" == "$cache_value" ]]; then
            return 0  # Unchanged, skip
        fi
    fi

    # Run the command
    if "$@"; then
        printf "%s\n" "$cache_value" > "$cache_key"
        return 0
    else
        # If it failed, we don't update the cache, so it runs again next time
        # Also remove existing cache entry to be safe
        rm -f -- "$cache_key"
        return 1
    fi
}
