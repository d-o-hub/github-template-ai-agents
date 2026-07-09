#!/usr/bin/env bash
# Command categorization for safety assessment
# Source this file in other scripts to use categorize_command()
set -euo pipefail

# Security Hardening: 2026-07-06 - Hardened regex matching and expanded keywords.
# Default categories (can be overridden in .command-verify.conf)
SAFE_KEYWORDS="${SAFE_KEYWORDS:-build:test:lint:check:status:list:help:version:describe:doc:info:show:get:ls:cat:echo:grep:find:pwd:diff:cd:head:tail:sort:uniq:wc:git:log:pgrep:type:which:df:du:free:top:ps:history}"
CONDITIONAL_KEYWORDS="${CONDITIONAL_KEYWORDS:-install:clean:format:migrate:update:init:add:remove:delete:replace:chmod:chown:chgrp:setfacl:ssh-keygen:openssl:gpg:mv:cp:ln:link:patch:tar:zip:unzip:gzip:gunzip:bzip2:xz:make:touch:gh:xargs:apt:apt-get:yum:dnf:zypper:brew:pipx}"
# Destructive and administrative commands (strict boundaries)
DESTRUCTIVE_KEYWORDS="${DESTRUCTIVE_KEYWORDS:-rm:delete:drop:force:destroy:purge:reset:hard:kill:killall:terminate:eval:exec:sudo:doas:docker:kubectl:podman:rmdir:dd:source:env:su:systemctl:shred:mkfs:mke2fs:mkswap:cryptsetup:reboot:shutdown:pkill:sed:truncate:unlink:tee:parted:fdisk:gdisk:sfdisk:wipe:srm:badblocks:alias:unalias:iptables:nft:ufw:firewall-cmd:crontab:pkexec:mount:umount:chroot:unshare:nsenter:git-remote-ext:poweroff:halt:swapon:swapoff:modprobe:insmod:rmmod:sysctl:strace:gdb:-f:-y}"
# Language interpreters (broad boundaries to catch versioned ones like python3.11)
INTERPRETER_KEYWORDS="${INTERPRETER_KEYWORDS:-sh:bash:zsh:python:python3:pip3:node:perl:ruby:php:deno:bun:npx:npm:yarn:pnpm:cargo:go:pip:composer:bundle:pipenv:poetry:conda:mamba:uv:lua:awk}"
# Networking tools (strict boundaries to avoid false positives like curl.sh)
NETWORK_KEYWORDS="${NETWORK_KEYWORDS:-curl:wget:nc:netcat:nmap:ssh:scp:sftp:rsync:socat:nslookup:dig:host:nc.openbsd:nc.traditional:telnet:ftp:tftp:ssh-add:ssh-agent:ncat:tcpdump:wireshark:tshark:aria2c:lynx:links:elinks:expect:rclone:ssh-copy-id:ssh-keyscan:ngrok:cloudflared:aws:gcloud:az}"
# Script extensions treated as safe — a keyword followed by one of these is a script, not a bare command
SAFE_EXTENSIONS=(sh py pl rb js ts mjs bash zsh csh ksh fish)
_ext_str="${SAFE_EXTENSIONS[*]}"
SAFE_EXT_PATTERN="\.(${_ext_str// /|})$"
unset _ext_str

# Custom patterns for categories (E3)
SAFE_PATTERNS=()
CONDITIONAL_PATTERNS=()
DANGEROUS_PATTERNS=(ext::)

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
    # Security: Remove backslash-newline combinations first to defeat multi-line obfuscation.
    cmd_lower="${cmd_lower//\\$'\n'/}"
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
    # Use -- as a boundary to detect dangerous flags like --force without matching mid-word hyphens.
    local boundary="(^|[[:space:]]|[|&;()<>,\/:]|--)"
    local end_boundary="($|[[:space:]]|[|&;()<>,\/:]|--)"
    # Broad boundary to catch versioned interpreters (e.g., python3.11)
    local broad_end_boundary="($|[[:space:]]|[|&;()<>,\/:\.])"

    # Specific check for dot (.) as source command
    # Matches ". " at start of string or after a separator
    if [[ "$cmd_lower" =~ (^|[[:space:]]|[|&;()<>,\/:])\.[[:space:]] ]]; then
        printf "dangerous\n"
        return 0
    fi

    # Check custom dangerous patterns first (E3)
    for pattern in "${DANGEROUS_PATTERNS[@]:-}"; do
        [[ -z "$pattern" ]] && continue
        if [[ "$cmd_lower" == *"$pattern"* ]]; then
            printf "dangerous\n"
            return 0
        fi
    done

    # Check destructive keywords with broad boundaries (to catch mkfs.ext4)
    # Allows optional trailing alphanumeric chars, dots, and hyphens immediately after the keyword.
    # Security: Use a hardened suffix pattern to avoid false positives from unrelated words.
    # Security: Escape literal dots in keywords to prevent accidental wildcard matching.
    # Optimization: Use a loop to validate EVERY match to prevent bypasses where a safe-looking
    # script name in the same command string causes the whole string to be exempt.
    local escaped_destructive="${DESTRUCTIVE_KEYWORDS//./\\.}"
    local destructive_regex="${boundary}(${escaped_destructive//:/|})([.][a-z0-9]+|[0-9-][a-z0-9.]*)?${broad_end_boundary}"
    local temp_destructive="$cmd_lower"
    local full_match suffix
    while [[ "$temp_destructive" =~ $destructive_regex ]]; do
        full_match="${BASH_REMATCH[0]}"
        suffix="${BASH_REMATCH[3]}"
        # If any match is NOT a script file, mark as dangerous
        if [[ ! "$suffix" =~ $SAFE_EXT_PATTERN ]]; then
            printf "dangerous\n"
            return 0
        fi
        # Match was a script, advance to check remaining string
        temp_destructive="${temp_destructive#*"$full_match"}"
    done

    # Check interpreter keywords with broad boundaries (to catch python3.11)
    # Allows optional trailing alphanumeric chars, dots, and hyphens immediately after the keyword.
    local escaped_interpreter="${INTERPRETER_KEYWORDS//./\\.}"
    local interpreter_regex="${boundary}(${escaped_interpreter//:/|})([.][a-z0-9]+|[0-9-][a-z0-9.]*)?${broad_end_boundary}"
    local temp_interpreter="$cmd_lower"
    while [[ "$temp_interpreter" =~ $interpreter_regex ]]; do
        full_match="${BASH_REMATCH[0]}"
        suffix="${BASH_REMATCH[3]}"
        if [[ ! "$suffix" =~ $SAFE_EXT_PATTERN ]]; then
            printf "dangerous\n"
            return 0
        fi
        temp_interpreter="${temp_interpreter#*"$full_match"}"
    done

    # Check network keywords with broad boundaries
    # Allows optional trailing alphanumeric chars, dots, and hyphens immediately after the keyword.
    local escaped_network="${NETWORK_KEYWORDS//./\\.}"
    local network_regex="${boundary}(${escaped_network//:/|})([.][a-z0-9]+|[0-9-][a-z0-9.]*)?${broad_end_boundary}"
    local temp_network="$cmd_lower"
    while [[ "$temp_network" =~ $network_regex ]]; do
        full_match="${BASH_REMATCH[0]}"
        suffix="${BASH_REMATCH[3]}"
        if [[ ! "$suffix" =~ $SAFE_EXT_PATTERN ]]; then
            printf "dangerous\n"
            return 0
        fi
        temp_network="${temp_network#*"$full_match"}"
    done

    # Check custom conditional patterns (E3)
    for pattern in "${CONDITIONAL_PATTERNS[@]:-}"; do
        [[ -z "$pattern" ]] && continue
        if [[ "$cmd_lower" == *"$pattern"* ]]; then
            printf "conditional\n"
            return 0
        fi
    done

    # Check conditional keywords with boundaries
    local escaped_conditional="${CONDITIONAL_KEYWORDS//./\\.}"
    local conditional_regex="${boundary}(${escaped_conditional//:/|})${end_boundary}"
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
    local escaped_safe="${SAFE_KEYWORDS//./\\.}"
    local safe_regex="${boundary}(${escaped_safe//:/|})${end_boundary}"
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
