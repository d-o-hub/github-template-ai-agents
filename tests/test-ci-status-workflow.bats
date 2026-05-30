#!/usr/bin/env bats

setup() {
    TEST_TEMP_DIR="$(mktemp -d)"
    # Create a directory for mocks
    MOCK_BIN="$TEST_TEMP_DIR/bin"
    mkdir -p "$MOCK_BIN"

    # Create a log file for git calls
    GIT_LOG="$TEST_TEMP_DIR/git_calls.log"
    touch "$GIT_LOG"

    # Create a mock git that logs push commands and delegates others to real git
    cat <<EOF > "$MOCK_BIN/git"
#!/bin/bash
if [[ "\$1" == "push" ]]; then
    echo "push \$@" >> "$GIT_LOG"
    exit 0
fi
exec /usr/bin/git "\$@"
EOF
    chmod +x "$MOCK_BIN/git"

    # Setup test repo
    REPO_DIR="$TEST_TEMP_DIR/repo"
    mkdir -p "$REPO_DIR"
    cd "$REPO_DIR" || exit 1

    # Use real git for setup
    /usr/bin/git init -b main
    /usr/bin/git config user.email "test@example.com"
    /usr/bin/git config user.name "Test User"

    touch ci-status.json ci-summary.md
    /usr/bin/git add ci-status.json ci-summary.md
    /usr/bin/git commit -m "initial commit"

    # Prepend mock bin to PATH for the tests
    export PATH="$MOCK_BIN:$PATH"
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

@test "git push uses TARGET_BRANCH correctly" {
    export TARGET_BRANCH="feature-branch"
    echo "modified" > ci-status.json

    # Logic from workflow
    git add ci-status.json ci-summary.md
    if git diff --staged --quiet; then
        echo "No changes"
        false
    else
        git commit -m "ci: update ci status artifacts [skip ci]"
        git push origin "HEAD:$TARGET_BRANCH"
    fi

    grep -q "push origin HEAD:feature-branch" "$GIT_LOG"
}

@test "git push handles main branch correctly" {
    export TARGET_BRANCH="main"
    echo "modified" > ci-status.json

    # Logic from workflow
    git add ci-status.json ci-summary.md
    if git diff --staged --quiet; then
        echo "No changes"
        false
    else
        git commit -m "ci: update ci status artifacts [skip ci]"
        git push origin "HEAD:$TARGET_BRANCH"
    fi

    grep -q "push origin HEAD:main" "$GIT_LOG"
}
