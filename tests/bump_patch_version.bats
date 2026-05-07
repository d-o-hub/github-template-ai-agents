#!/usr/bin/env bats

setup() {
    # Create isolated test environment
    export TEST_TEMP_DIR="$(mktemp -d)"
    cd "$TEST_TEMP_DIR"

    # Initialize fake git repo
    git init >/dev/null 2>&1
    git config user.name "Test User"
    git config user.email "test@example.com"

    # Create required files
    echo "1.2.3" > VERSION
    cat << 'MARKDOWN' > CHANGELOG-TEMPLATE.md
# Changelog

## [Unreleased]

## [1.2.3] - 2026-01-01
MARKDOWN

    mkdir -p scripts

    # Copy the script to test
    cp "${BATS_TEST_DIRNAME}/../scripts/bump_patch_version.sh" "scripts/"

    # Mock propagate-version.sh
    cat << 'MOCK' > scripts/propagate-version.sh
#!/usr/bin/env bash
echo "Mock propagate version executed"
MOCK
    chmod +x scripts/propagate-version.sh

    # Commit some fake commits so git log works
    touch dummy1 && git add dummy1 && git commit -m "feat: add amazing new feature" >/dev/null 2>&1
    touch dummy2 && git add dummy2 && git commit -m "fix: resolve critical bug" >/dev/null 2>&1
    touch dummy3 && git add dummy3 && git commit -m "chore: some internal update" >/dev/null 2>&1
}

teardown() {
    rm -rf "$TEST_TEMP_DIR"
}

@test "bump_patch_version increments version and updates changelog correctly" {
    run ./scripts/bump_patch_version.sh

    [ "$status" -eq 0 ]

    # Assert version was bumped to 1.2.4
    run cat VERSION
    [ "$output" = "1.2.4" ]

    # Assert changelog contains new entry with correct sections
    run grep -A 15 "## \[1.2.4\]" CHANGELOG-TEMPLATE.md

    # Check if we have the headers we expect
    echo "$output" | grep "### Added"
    echo "$output" | grep "\- feat: add amazing new feature"
    echo "$output" | grep "### Fixed"
    echo "$output" | grep "\- fix: resolve critical bug"
    echo "$output" | grep "### Changed"
    echo "$output" | grep "\- chore: some internal update"
}
