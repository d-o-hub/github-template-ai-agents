#!/usr/bin/env bats

setup() {
    TEST_TEMP_DIR="$(mktemp -d)"
    MOCK_BIN="$TEST_TEMP_DIR/bin"
    mkdir -p "$MOCK_BIN"
    GIT_LOG="$TEST_TEMP_DIR/git_calls.log"
    touch "$GIT_LOG"

    cat <<'MOCK' > "$MOCK_BIN/git"
#!/bin/bash
if [[ "$1" == "push" ]]; then
    echo "push $@" >> "GIT_LOG_PLACEHOLDER"
    exit 0
fi
exec /usr/bin/git "$@"
MOCK
    sed -i "s|GIT_LOG_PLACEHOLDER|$GIT_LOG|g" "$MOCK_BIN/git"
    chmod +x "$MOCK_BIN/git"

    REPO_DIR="$TEST_TEMP_DIR/repo"
    mkdir -p "$REPO_DIR"
    cd "$REPO_DIR" || exit 1

    /usr/bin/git init -b main
    /usr/bin/git config user.email "test@example.com"
    /usr/bin/git config user.name "Test User"

    mkdir -p .github/ci-status
    touch .github/ci-status/ci-status.json .github/ci-status/ci-summary.md
    /usr/bin/git add .github/ci-status/ci-status.json .github/ci-status/ci-summary.md
    /usr/bin/git commit -m "initial commit"

    export PATH="$MOCK_BIN:$PATH"
}

teardown() {
    rm -rf "$TEST_TEMP_DIR"
}

@test "commit logic stages and commits changes when artifacts are modified" {
    echo "modified" > .github/ci-status/ci-status.json

    # Logic from workflow
    git add .github/ci-status/ci-status.json .github/ci-status/ci-summary.md
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
    git add .github/ci-status/ci-status.json .github/ci-status/ci-summary.md
    if git diff --staged --quiet; then
        echo "No changes"
    else
        git commit -m "ci: update ci status artifacts [skip ci]"
        false
    fi

    [ "$(git log -1 --pretty=%s)" = "initial commit" ]
}

@test "push uses TARGET_BRANCH correctly" {
    export TARGET_BRANCH="feature-branch"
    echo "modified" > .github/ci-status/ci-status.json

    # Logic from workflow
    git add .github/ci-status/ci-status.json .github/ci-status/ci-summary.md
    if git diff --staged --quiet; then
        echo "No changes"
        false
    else
        git commit -m "ci: update ci status artifacts [skip ci]"
        git push origin "HEAD:$TARGET_BRANCH"
    fi

    grep -q "push origin HEAD:feature-branch" "$GIT_LOG"
}

@test "retry loop retries on push failure then succeeds" {
    PUSH_CALL_FILE="$TEST_TEMP_DIR/push_calls"
    echo "0" > "$PUSH_CALL_FILE"
    GIT_LOG_COPY="$GIT_LOG"
    cat > "$MOCK_BIN/git" <<MOCK
#!/bin/bash
if [[ "\$1" == "push" ]]; then
    COUNT=\$(cat "$PUSH_CALL_FILE")
    COUNT=\$((COUNT + 1))
    echo "\$COUNT" > "$PUSH_CALL_FILE"
    echo "push \$@" >> "$GIT_LOG_COPY"
    if [ "\$COUNT" -le 1 ]; then
        echo "! [rejected] push failed" >&2
        exit 1
    fi
    exit 0
fi
exec /usr/bin/git "\$@"
MOCK
    chmod +x "$MOCK_BIN/git"

    export TARGET_BRANCH="main"
    echo "modified" > .github/ci-status/ci-status.json

    git add .github/ci-status/ci-status.json .github/ci-status/ci-summary.md
    git commit -m "ci: update ci status artifacts [skip ci]"

    MAX_RETRIES=3
    PUSHED=false
    for i in $(seq 1 "$MAX_RETRIES"); do
        if git push origin "HEAD:$TARGET_BRANCH"; then
            PUSHED=true
            break
        fi
        echo "Push failed (attempt $i), retrying..."
        sleep 0.1
    done

    [ "$PUSHED" = true ]
    grep -q "push origin HEAD:main" "$GIT_LOG"
}

@test "retry loop gives up after max retries" {
    cat > "$MOCK_BIN/git" <<'MOCK'
#!/bin/bash
if [[ "$1" == "push" ]]; then
    echo "push $@" >> "GIT_LOG_PLACEHOLDER"
    echo "! [rejected] push failed" >&2
    exit 1
fi
exec /usr/bin/git "$@"
MOCK
    sed -i "s|GIT_LOG_PLACEHOLDER|$GIT_LOG|g" "$MOCK_BIN/git"
    chmod +x "$MOCK_BIN/git"

    export TARGET_BRANCH="main"
    echo "modified" > .github/ci-status/ci-status.json

    git add .github/ci-status/ci-status.json .github/ci-status/ci-summary.md
    git commit -m "ci: update ci status artifacts [skip ci]"

    MAX_RETRIES=3
    PUSHED=false
    for i in $(seq 1 "$MAX_RETRIES"); do
        if git push origin "HEAD:$TARGET_BRANCH"; then
            PUSHED=true
            break
        fi
    done

    [ "$PUSHED" = false ]
    [ "$(grep -c "push origin HEAD:main" "$GIT_LOG")" -eq "$MAX_RETRIES" ]
}

@test "git push handles main branch correctly" {
    export TARGET_BRANCH="main"
    echo "modified" > .github/ci-status/ci-status.json

    # Logic from workflow
    git add .github/ci-status/ci-status.json .github/ci-status/ci-summary.md
    if git diff --staged --quiet; then
        echo "No changes"
        false
    else
        git commit -m "ci: update ci status artifacts [skip ci]"
        git push origin "HEAD:$TARGET_BRANCH"
    fi

    grep -q "push origin HEAD:main" "$GIT_LOG"
}
