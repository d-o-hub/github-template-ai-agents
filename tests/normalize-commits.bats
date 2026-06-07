#!/usr/bin/env bats

setup() {
    export TEST_TEMP_DIR="$(mktemp -d)"
    cd "$TEST_TEMP_DIR"
    git init -q
    git config user.email "test@test"
    git config user.name "Test"
    echo "1.0.0" > VERSION
    git add VERSION
    git commit -q -m "chore: init"

    git commit --allow-empty -q -m "$(printf 'I have hardened the foo.sh script against injection.\n\nI replaced echo with printf.\n\nCo-authored-by: Bot <b@b.com>')"

    cp "${BATS_TEST_DIRNAME}/../.agents/skills/jules-delegator/scripts/normalize-commits.sh" normalize.sh
    chmod +x normalize.sh
}

teardown() {
    rm -rf "$TEST_TEMP_DIR"
}

@test "normalize-commits: dry-run reports bad subject without rewriting" {
    run ./normalize.sh --from HEAD~1 --to HEAD --type fix --scope security --dry-run
    [ "$status" -eq 0 ]
    [[ "$output" == *"non-conventional"* ]]
    [[ "$output" == *"--dry-run"* ]]
    SUBJECT=$(git log -1 --pretty=%s)
    [ "$SUBJECT" = "I have hardened the foo.sh script against injection." ]
}

@test "normalize-commits: real run rewrites subject with conventional prefix" {
    run ./normalize.sh --from HEAD~1 --to HEAD --type fix --scope security
    [ "$status" -eq 0 ]
    SUBJECT=$(git log -1 --pretty=%s)
    [[ "$SUBJECT" == "fix(security):"* ]]
    [[ "$SUBJECT" != *"Co-authored"* ]]
    BODY=$(git log -1 --pretty=%b)
    [[ "$BODY" == *"printf"* ]]
    [[ "$BODY" == *"Co-authored-by: Bot"* ]]
}

@test "normalize-commits: skips when no commits in range" {
    run ./normalize.sh --from HEAD --to HEAD --type fix --scope security
    [ "$status" -eq 0 ]
    [[ "$output" == *"No commits"* ]]
}

@test "normalize-commits: requires --from" {
    run ./normalize.sh --to HEAD --type fix
    [ "$status" -ne 0 ]
    [[ "$output" == *"Usage"* ]]
}

@test "normalize-commits: requires --type" {
    run ./normalize.sh --from HEAD~1
    [ "$status" -ne 0 ]
    [[ "$output" == *"Usage"* ]]
}

@test "normalize-commits: works without --scope" {
    run ./normalize.sh --from HEAD~1 --to HEAD --type chore
    [ "$status" -eq 0 ]
    SUBJECT=$(git log -1 --pretty=%s)
    [[ "$SUBJECT" == "chore:"* ]]
}

@test "normalize-commits: reuses existing conventional subjects" {
    git commit --allow-empty -q -m "feat: existing conventional subject"
    run ./normalize.sh --from HEAD~1 --to HEAD --type fix --scope security --dry-run
    [ "$status" -eq 0 ]
    [[ "$output" == *"All commits already conventional"* ]]
}
