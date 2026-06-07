#!/usr/bin/env bats

setup() {
    export TEST_TEMP_DIR="$(mktemp -d)"
    cd "$TEST_TEMP_DIR"

    git init -q
    git config user.name "Test User"
    git config user.email "test@example.com"

    mkdir -p scripts
    cp "${BATS_TEST_DIRNAME}/../scripts/commit-msg-hook.sh" scripts/
    cp "${BATS_TEST_DIRNAME}/../scripts/validate-commit-message.sh" scripts/

    cat << 'MOCK' > scripts/validate-commit-message.sh
#!/usr/bin/env bash
set -euo pipefail
MSG_FILE="$1"
SUBJECT=$(head -n 1 "$MSG_FILE")
if [[ "$SUBJECT" =~ ^(feat|fix|docs|style|refactor|perf|test|ci|chore)(\([a-z0-9-]+\))?!?:\ .{1,150}$ ]]; then
    exit 0
fi
echo "Mock validator rejected: $SUBJECT" >&2
exit 1
MOCK
    chmod +x scripts/validate-commit-message.sh

    cat << 'FAKE' > VERSION
1.0.0
FAKE

    git add -A
    git commit -q -m "chore: initial"
}

teardown() {
    rm -rf "$TEST_TEMP_DIR"
}

write_msg() {
    local content="$1"
    local file="$TEST_TEMP_DIR/COMMIT_EDITMSG"
    printf '%s\n' "$content" > "$file"
    printf '%s' "$file"
}

@test "commit-msg-hook accepts conventional subject" {
    FILE=$(write_msg "feat(api): add OAuth2 support")
    run bash scripts/commit-msg-hook.sh "$FILE"
    [ "$status" -eq 0 ]
    [[ "$output" == *"OK"* ]]
}

@test "commit-msg-hook rejects prose subject" {
    FILE=$(write_msg "I've added OAuth2 support to the API.")
    run bash scripts/commit-msg-hook.sh "$FILE"
    [ "$status" -ne 0 ]
    [[ "$output" == *"Commit aborted"* ]]
}

@test "commit-msg-hook rejects over-length subject" {
    LONG=$(printf 'x%.0s' {1..200})
    FILE=$(write_msg "feat: $LONG")
    run bash scripts/commit-msg-hook.sh "$FILE"
    [ "$status" -ne 0 ]
}

@test "commit-msg-hook skips merge commits" {
    FILE=$(write_msg "Merge branch 'feature' into main")
    run bash scripts/commit-msg-hook.sh "$FILE"
    [ "$status" -eq 0 ]
    [[ "$output" == *"skipping"* ]]
}

@test "commit-msg-hook skips revert commits" {
    FILE=$(write_msg "Revert \"feat: bad change\"")
    run bash scripts/commit-msg-hook.sh "$FILE"
    [ "$status" -eq 0 ]
}

@test "commit-msg-hook respects SKIP_COMMIT_MSG_CHECK=true" {
    FILE=$(write_msg "garbage message")
    SKIP_COMMIT_MSG_CHECK=true run bash scripts/commit-msg-hook.sh "$FILE"
    [ "$status" -eq 0 ]
    [[ "$output" == *"skipped"* ]]
}

@test "commit-msg-hook fails on missing arg" {
    run bash scripts/commit-msg-hook.sh
    [ "$status" -ne 0 ]
}

@test "commit-msg-hook skips when validator missing" {
    rm scripts/validate-commit-message.sh
    FILE=$(write_msg "feat: anything")
    run bash scripts/commit-msg-hook.sh "$FILE"
    [ "$status" -eq 0 ]
    [[ "$output" == *"skipping check"* ]]
}
