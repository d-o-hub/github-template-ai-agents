#!/usr/bin/env bats
# BATS tests for scripts/check-forbidden-paths.sh
#
# The guard consumes scripts/lib/paths.py at runtime, so every fixture copies
# the real vocabulary into a throwaway git sandbox. The changed-file branches
# (staged vs work tree vs CI base-ref) each get a dedicated test, and the two
# fail-closed contracts — vocabulary missing, vocabulary empty — are pinned
# because a vanished vocabulary must never read as a pass.

setup() {
    REPO_ROOT="$(cd "${BATS_TEST_DIRNAME}/.." && pwd)"
    SANDBOX="$(mktemp -d)"
    mkdir -p "$SANDBOX/scripts/lib" "$SANDBOX/config"
    cp "$REPO_ROOT/scripts/check-forbidden-paths.sh" "$SANDBOX/scripts/"
    cp "$REPO_ROOT/scripts/lib/paths.py" "$SANDBOX/scripts/lib/"
    printf 'readme\n' > "$SANDBOX/README.md"
    # Tracked from the baseline commit so the deletion-filter and
    # modified-tracked-file tests have real git state to work with.
    printf 'old\n' > "$SANDBOX/config/old.env"
    git init -q -b main "$SANDBOX"
    git -C "$SANDBOX" config user.name "gate-tests"
    git -C "$SANDBOX" config user.email "gate-tests@localhost"
    git -C "$SANDBOX" add -A
    git -C "$SANDBOX" commit -qm "baseline"
    SCRIPT="$SANDBOX/scripts/check-forbidden-paths.sh"
}

teardown() {
    [[ -n "${SANDBOX:-}" ]] && rm -rf -- "$SANDBOX"
    return 0
}

@test "passes when staged changes are all benign" {
    printf 'more\n' >> "$SANDBOX/README.md"
    git -C "$SANDBOX" add README.md

    run bash "$SCRIPT"

    [ "$status" -eq 0 ]
    [[ "$output" == *"✓ 1 changed file(s) clean"* ]]
    [[ "$output" != *"✗"* ]]
}

@test "CI mode falls back to the work tree when the base ref is unfetchable" {
    # No origin remote: the base-ref diff and its fetch both fail. The guard
    # must loudly fall back to the work-tree scan instead of blocking the
    # pipeline -- and still catch the forbidden path sitting untracked.
    printf 'SECRET=1\n' > "$SANDBOX/.env"

    run env GITHUB_BASE_REF=refnowhere bash "$SCRIPT"

    [ "$status" -eq 1 ]
    [[ "$output" == *"refnowhere unavailable; scanning the work tree"* ]]
    [[ "$output" == *".env"* ]]
    [[ "$output" == *"forbidden path"* ]]
}

@test "fails when a staged path names a forbidden file (.env)" {
    printf 'SECRET=1\n' > "$SANDBOX/.env"
    git -C "$SANDBOX" add .env

    run bash "$SCRIPT"

    [ "$status" -eq 1 ]
    [[ "$output" == *".env"* ]]
    [[ "$output" == *"file name matches .env"* ]]
    [[ "$output" == *"rule: forbidden path"* ]]
}

@test "a pending commit wins: unstaged junk does not fail the staged set" {
    printf 'more\n' >> "$SANDBOX/README.md"
    git -C "$SANDBOX" add README.md
    # This would fail on the work-tree branch; a pending commit must take
    # precedence because only the staged set is entering history.
    printf 'x\n' > "$SANDBOX/service-account.json"

    run bash "$SCRIPT"

    [ "$status" -eq 0 ]
    [[ "$output" == *"✓ 1 changed file(s) clean"* ]]
}

@test "work-tree branch flags an untracked sensitive file when nothing is staged" {
    printf 'x\n' > "$SANDBOX/keys.pem"

    run bash "$SCRIPT"

    [ "$status" -eq 1 ]
    [[ "$output" == *"keys.pem"* ]]
    [[ "$output" == *"sensitive suffix"* ]]
}

@test "work-tree branch flags a modified tracked file" {
    printf 'added\n' >> "$SANDBOX/config/old.env"

    run bash "$SCRIPT"

    [ "$status" -eq 1 ]
    [[ "$output" == *"config/old.env"* ]]
    [[ "$output" == *"sensitive suffix"* ]]
}

@test "matching is case-insensitive (.ENV.LOCAL hits forbidden .env.local)" {
    printf 'x\n' > "$SANDBOX/.ENV.LOCAL"

    run bash "$SCRIPT"

    [ "$status" -eq 1 ]
    [[ "$output" == *".ENV.LOCAL"* ]]
    [[ "$output" == *"file name matches .env.local"* ]]
}

@test "public SSH keys keep the paths.py .pub exception" {
    printf 'x\n' > "$SANDBOX/id_ed25519.pub"

    run bash "$SCRIPT"

    [ "$status" -eq 0 ]
    [[ "$output" != *"✗"* ]]
}

@test "a staged deletion of a tracked forbidden path is not flagged (diff-filter=d)" {
    git -C "$SANDBOX" rm -q config/old.env

    run bash "$SCRIPT"

    [ "$status" -eq 0 ]
    [[ "$output" == *"No changed files to check"* ]]
}

@test "a clean tree passes with zero changed files" {
    run bash "$SCRIPT"

    [ "$status" -eq 0 ]
    [[ "$output" == *"No changed files to check"* ]]
}

@test "missing vocabulary fails closed rather than passing silently" {
    rm "$SANDBOX/scripts/lib/paths.py"

    run bash "$SCRIPT"

    [ "$status" -eq 1 ]
    [[ "$output" == *"vocabulary missing"* ]]
    [[ "$output" == *"fail closed"* ]]
}

@test "an empty vocabulary fails closed even on a clean tree" {
    printf 'FORBIDDEN_PATHS = frozenset()\nFORBIDDEN_PATHS_LOWER = frozenset()\nSENSITIVE_PREFIXES = ()\nSENSITIVE_SUFFIXES = ()\nSSH_KEY_PREFIXES = ()\n' \
        > "$SANDBOX/scripts/lib/paths.py"

    run bash "$SCRIPT"

    [ "$status" -eq 1 ]
    [[ "$output" == *"yielded no 'FORBIDDEN_PATHS_LOWER'"* ]]
    [[ "$output" == *"fail closed"* ]]
}

@test "an unimportable vocabulary fails closed" {
    printf 'this is not python (\n' > "$SANDBOX/scripts/lib/paths.py"

    run bash "$SCRIPT"

    [ "$status" -eq 1 ]
    [[ "$output" == *"failed to load"* ]]
}

@test "not a git work tree is a visible skip, not a silent pass" {
    NO_REPO="$(mktemp -d)"
    mkdir -p "$NO_REPO/scripts/lib"
    cp "$REPO_ROOT/scripts/check-forbidden-paths.sh" "$NO_REPO/scripts/"
    cp "$REPO_ROOT/scripts/lib/paths.py" "$NO_REPO/scripts/lib/"

    run bash "$NO_REPO/scripts/check-forbidden-paths.sh"

    status_copy="$status"
    rm -rf -- "$NO_REPO"
    [ "$status_copy" -eq 3 ]
    [[ "$output" == *"not inside a git work tree"* ]]
}

@test "a missing python3 is a visible skip, not a silent pass" {
    # The only executable on PATH is dirname (the canonical REPO_ROOT idiom
    # needs it); python3, git and friends are gone, so the guard must report
    # the skip instead of green-lighting an unguardable changeset.
    STUB_BIN="$(mktemp -d)"
    ln -s "$(command -v dirname)" "$STUB_BIN/dirname"
    BASH_BIN="$(command -v bash)"

    run env PATH="$STUB_BIN" "$BASH_BIN" "$SCRIPT"

    status_copy="$status"
    rm -rf -- "$STUB_BIN"
    [ "$status_copy" -eq 3 ]
    [[ "$output" == *"python3 is not installed"* ]]
}

@test "CI base-ref branch checks the PR diff against the base" {
    REMOTE="$(mktemp -d)"
    git init -q --bare "$REMOTE/origin.git"
    git -C "$SANDBOX" remote add origin "$REMOTE/origin.git"
    git -C "$SANDBOX" push -q origin main
    # A forbidden path committed to the branch tip: nothing staged, nothing
    # unstaged, nothing untracked — only the base comparison can see it.
    printf 'SECRET=1\n' > "$SANDBOX/.env.local"
    git -C "$SANDBOX" add .env.local
    git -C "$SANDBOX" commit -qm "leak"

    run env GITHUB_BASE_REF=main bash "$SCRIPT"

    status_copy="$status"
    rm -rf -- "$REMOTE"
    [ "$status_copy" -eq 1 ]
    [[ "$output" == *".env.local"* ]]
    [[ "$output" == *"forbidden path"* ]]
}
