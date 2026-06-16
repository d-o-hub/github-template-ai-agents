#!/usr/bin/env bats

setup() {
    export REPO_ROOT="$BATS_TMPDIR/analyze-codebase"
    mkdir -p "$REPO_ROOT"/{.agents/skills/skill1,agents-docs,plans,scripts,.github,.commandcode/taste}
    git -C "$REPO_ROOT" init -q -b main
    git -C "$REPO_ROOT" config user.email "test@example.com"
    git -C "$REPO_ROOT" config user.name "Test"

    cat <<'EOF' > "$REPO_ROOT/AGENTS.md"
# Test Repo
EOF
    cat <<'EOF' > "$REPO_ROOT/.agents/skills/skill1/SKILL.md"
---
name: skill1
version: "0.1.0"
license: MIT
description: "Test skill"
---
# Skill 1
EOF
    touch "$REPO_ROOT/.commandcode/taste/taste.md"
}

teardown() {
    rm -rf "$REPO_ROOT"
}

run_analyze() {
    cd "$REPO_ROOT" || exit 1
    bash "$BATS_TEST_DIRNAME/../scripts/analyze-codebase.sh" "$@"
}

@test "analyze-codebase.sh exits 0 on a clean repo" {
    run run_analyze
    [ "$status" -eq 0 ]
    [[ "$output" == *"Analysis: 0 errors"* ]]
}

@test "analyze-codebase.sh writes a Markdown report" {
    run_analyze > /dev/null
    [ -d "$REPO_ROOT/reports" ]
    run ls "$REPO_ROOT/reports/"
    [[ "$output" == *"codebase-analysis-"* ]]
}

@test "analyze-codebase.sh reports tracked .pyc as an error" {
    echo "tracked cache" > "$REPO_ROOT/bad.pyc"
    git -C "$REPO_ROOT" add bad.pyc
    git -C "$REPO_ROOT" commit -q -m "add pyc"

    run run_analyze
    [ "$status" -eq 1 ]
    [[ "$output" == *"Tracked cache"* ]]
}

@test "analyze-codebase.sh reports missing required files" {
    rm -rf "$REPO_ROOT/plans"
    run run_analyze
    [ "$status" -eq 1 ]
    [[ "$output" == *"plans missing"* ]]
}

@test "analyze-codebase.sh --help exits 0" {
    run run_analyze --help
    [ "$status" -eq 0 ]
    [[ "$output" == *"Usage"* ]]
}

@test "analyze-codebase.sh --fix adds patterns to .gitignore" {
    echo "stale" > "$REPO_ROOT/.DS_Store"
    git -C "$REPO_ROOT" add .DS_Store
    git -C "$REPO_ROOT" commit -q -m "ds"
    touch "$REPO_ROOT/.gitignore"

    run_analyze --fix > /dev/null
    run grep -F ".DS_Store" "$REPO_ROOT/.gitignore"
    [ "$status" -eq 0 ]
}
