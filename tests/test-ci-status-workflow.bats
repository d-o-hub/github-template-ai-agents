#!/usr/bin/env bats

setup() {
    TEST_TEMP_DIR="$(mktemp -d)"
    cd "$TEST_TEMP_DIR" || exit 1
    git init -b main
    git config user.email "test@example.com"
    git config user.name "Test User"

    touch ci-status.json ci-summary.md
    git add ci-status.json ci-summary.md
    git commit -m "initial commit"
}

teardown() {
    rm -rf "$TEST_TEMP_DIR"
}

@test "commit logic stages and commits changes when artifacts are modified" {
    echo "modified" > ci-status.json

    # Logic from workflow
    git add ci-status.json ci-summary.md
    if git diff --staged --quiet; then
        echo "No changes"
        false
    else
        git commit -m "ci: update ci status artifacts [skip ci]"
    fi

    [ "$(git log -1 --pretty=%s)" = "ci: update ci status artifacts [skip ci]" ]
}

@test "commit logic does nothing when artifacts are unchanged" {
    # Logic from workflow
    git add ci-status.json ci-summary.md
    if git diff --staged --quiet; then
        echo "No changes"
    else
        git commit -m "ci: update ci status artifacts [skip ci]"
        false
    fi

    [ "$(git log -1 --pretty=%s)" = "initial commit" ]
}
