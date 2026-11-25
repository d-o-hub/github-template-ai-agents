#!/usr/bin/env bats
# Behaviour tests for scripts/validate-git-hooks.sh.
#
# The validator must judge the hooks directory git would actually execute, not the
# literal core.hooksPath string: relative and absolute spellings of the same
# directory have to agree, and a path that leaves the shipped .githooks/ dead has
# to fail even when it "looks standard".

setup() {
    TEST_TEMP_DIR="$(mktemp -d)"
    mkdir -p "$TEST_TEMP_DIR/home"
    git init -q "$TEST_TEMP_DIR/repo"

    # A validator copy reads REPO_ROOT from its own location, so the fixture repo
    # needs one; this keeps the real repository's config out of the test.
    mkdir -p "$TEST_TEMP_DIR/repo/scripts"
    cp "${BATS_TEST_DIRNAME}/../scripts/validate-git-hooks.sh" "$TEST_TEMP_DIR/repo/scripts/"
    chmod +x "$TEST_TEMP_DIR/repo/scripts/validate-git-hooks.sh"

    # Hermetic config: the developer's own global/system hooksPath must not leak in.
    export GIT_CONFIG_GLOBAL="$TEST_TEMP_DIR/home/gitconfig"
    export GIT_CONFIG_SYSTEM=/dev/null
    : > "$GIT_CONFIG_GLOBAL"

    cd "$TEST_TEMP_DIR/repo"
}

teardown() {
    cd "${BATS_TEST_DIRNAME}/.."
    rm -rf "$TEST_TEMP_DIR"
}

ship_githooks() {
    mkdir -p .githooks
    printf '#!/usr/bin/env bash\nexit 0\n' > .githooks/pre-commit
    chmod +x .githooks/pre-commit
}

@test "unset hooksPath warns but stays non-fatal (fresh clone, no bootstrap)" {
    ship_githooks
    run ./scripts/validate-git-hooks.sh
    echo "$output"
    [ "$status" -eq 0 ]
    [[ "$output" == *"no core.hooksPath configured"* ]]
}

@test "relative .git/hooks fails once the repository ships .githooks" {
    ship_githooks
    git config --local core.hooksPath .git/hooks
    run ./scripts/validate-git-hooks.sh
    echo "$output"
    [ "$status" -eq 1 ]
    [[ "$output" == *"bypasses the expected hooks directory"* ]]
}

@test "absolute .git/hooks agrees with the relative spelling" {
    ship_githooks
    git config --local core.hooksPath "$PWD/.git/hooks"
    run ./scripts/validate-git-hooks.sh
    echo "$output"
    [ "$status" -eq 1 ]
    [[ "$output" == *"bypasses the expected hooks directory"* ]]
}

@test "relative .githooks passes" {
    ship_githooks
    git config --local core.hooksPath .githooks
    run ./scripts/validate-git-hooks.sh
    echo "$output"
    [ "$status" -eq 0 ]
    [[ "$output" == *"validated"* ]]
}

@test "absolute .githooks passes, matching the relative spelling" {
    ship_githooks
    git config --local core.hooksPath "$PWD/.githooks"
    run ./scripts/validate-git-hooks.sh
    echo "$output"
    [ "$status" -eq 0 ]
    [[ "$output" != *"ERROR"* ]]
}

@test "hooksPath aimed at a missing .githooks fails" {
    git config --local core.hooksPath .githooks
    run ./scripts/validate-git-hooks.sh
    echo "$output"
    [ "$status" -eq 1 ]
    [[ "$output" == *"<missing directory>"* ]]
}

@test "repo without .githooks still accepts the git default hooks dir" {
    git config --local core.hooksPath .git/hooks
    run ./scripts/validate-git-hooks.sh
    echo "$output"
    [ "$status" -eq 0 ]
}

@test "repo without .githooks still rejects an unrelated hooks dir" {
    mkdir -p unrelated-hooks
    git config --local core.hooksPath unrelated-hooks
    run ./scripts/validate-git-hooks.sh
    echo "$output"
    [ "$status" -eq 1 ]
    [[ "$output" == *"bypasses the expected hooks directory"* ]]
    [[ "$output" == *"no .githooks/ directory"* ]]
}

@test "global hooksPath warns and exits 0, unchanged from the historical check" {
    ship_githooks
    git config --global core.hooksPath "$TEST_TEMP_DIR/global-hooks"
    run ./scripts/validate-git-hooks.sh
    echo "$output"
    [ "$status" -eq 0 ]
    [[ "$output" == *"Global git hooks path is set"* ]]
    [[ "$output" == *"SKIP_GLOBAL_HOOKS_CHECK"* ]]
}

@test "global hooksPath remediation never recommends disabling the tracked hooks" {
    ship_githooks
    git config --global core.hooksPath "$TEST_TEMP_DIR/global-hooks"
    run ./scripts/validate-git-hooks.sh
    echo "$output"
    [ "$status" -eq 0 ]
    # Following Option 2 must leave the repository valid, not trip the next run.
    [[ "$output" == *"core.hooksPath .githooks"* ]]
    [[ "$output" != *"core.hooksPath .git/hooks"* ]]

    git config --local core.hooksPath .githooks
    run ./scripts/validate-git-hooks.sh
    echo "$output"
    [ "$status" -eq 0 ]
}

@test "remediation points at .git/hooks only when no tracked hooks exist" {
    git config --global core.hooksPath "$TEST_TEMP_DIR/global-hooks"
    run ./scripts/validate-git-hooks.sh
    echo "$output"
    [ "$status" -eq 0 ]
    [[ "$output" == *"core.hooksPath .git/hooks"* ]]
}

@test "configured .githooks whose hooks lost the executable bit warns without failing" {
    ship_githooks
    chmod -x .githooks/pre-commit
    git config --local core.hooksPath .githooks
    run ./scripts/validate-git-hooks.sh
    echo "$output"
    [ "$status" -eq 0 ]
    [[ "$output" == *"no executable hook"* ]]
}
