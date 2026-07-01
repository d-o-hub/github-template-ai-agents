#!/usr/bin/env bats

setup() {
    export REPO_ROOT="$(cd "$(dirname "$BATS_TEST_FILENAME")/.." && pwd)"
    source "$REPO_ROOT/scripts/lib/command-categories.sh"
}

@test "harden-command-categorization: prevents false positives (partial words)" {
    run categorize_command "mkdir farm"
    [ "$output" = "unknown" ]
    
    run categorize_command "printf storm"
    [ "$output" = "unknown" ]
}

@test "harden-command-categorization: detects obfuscated commands" {
    run categorize_command "r''m -rf /"
    [ "$output" = "dangerous" ]
    
    run categorize_command "r\"\"m -rf /"
    [ "$output" = "dangerous" ]
    
    run categorize_command "r\\m -rf /"
    [ "$output" = "dangerous" ]
}

@test "harden-command-categorization: detects commands near metacharacters" {
    run categorize_command "(rm -rf /)"
    [ "$output" = "dangerous" ]
    
    run categorize_command "rm;ls"
    [ "$output" = "dangerous" ]
    
    run categorize_command "ls|rm"
    [ "$output" = "dangerous" ]
    
    run categorize_command "rm&ls"
    [ "$output" = "dangerous" ]
}

@test "harden-command-categorization: handles mixed case and whitespace" {
    run categorize_command "  RM -rf /  "
    [ "$output" = "dangerous" ]
    
    run categorize_command "Install dependencies"
    [ "$output" = "conditional" ]
}

@test "harden-command-categorization: detects new security keywords" {
    # Interpreters
    run categorize_command "lua script.lua"
    [ "$output" = "dangerous" ]

    # Networking tools
    run categorize_command "aria2c http://example.com/file"
    [ "$output" = "dangerous" ]
    run categorize_command "lynx http://example.com"
    [ "$output" = "dangerous" ]
    run categorize_command "links http://example.com"
    [ "$output" = "dangerous" ]
    run categorize_command "elinks http://example.com"
    [ "$output" = "dangerous" ]

    # Destructive/Firewall tools
    run categorize_command "iptables -L"
    [ "$output" = "dangerous" ]
    run categorize_command "nft list ruleset"
    [ "$output" = "dangerous" ]
    run categorize_command "ufw status"
    [ "$output" = "dangerous" ]
    run categorize_command "firewall-cmd --list-all"
    [ "$output" = "dangerous" ]
    run categorize_command "crontab -l"
    [ "$output" = "dangerous" ]
}
