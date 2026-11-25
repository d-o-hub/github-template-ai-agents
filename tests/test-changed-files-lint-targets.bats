#!/usr/bin/env bats
# BATS tests for _changed_files_z in scripts/lib/lang-checks.sh — the file set handed to the
# changed-file linters. A deletion is not a lint target: shellcheck exits 123 through xargs
# when handed a path that does not exist, which failed the gate for legitimate removals.

setup_file() {
    export REPO_ROOT="$(cd "$(dirname "$BATS_TEST_FILENAME")/.." && pwd)"
    export LIB="$REPO_ROOT/scripts/lib/lang-checks.sh"
}

setup() {
    cd "$REPO_ROOT" || exit 1
    TEMP_DIR=$(mktemp -d)
    cd "$TEMP_DIR" || exit 1
    git init -q .
    git config user.email tester@invalid
    git config user.name Tester
    printf '#!/usr/bin/env bash\necho keep\n' > keep.sh
    printf '#!/usr/bin/env bash\necho gone\n' > gone.sh
    git add -A
    git commit -q -m init
    git branch -M main
}

teardown() {
    cd "$REPO_ROOT" || exit 1
    rm -rf -- "$TEMP_DIR"
}

# Emit the changed set as one path per line, using the library from the real repository.
run_changed() {
    run bash -c 'source "$1"; _changed_files_z | tr "\0" "\n"' _ "$LIB"
}

@test "a staged deletion is not offered as a lint target" {
    git rm -q gone.sh
    run_changed
    echo "$output"
    [[ "$output" != *"gone.sh"* ]]
}

@test "modified and added files are still offered" {
    printf '#!/usr/bin/env bash\necho modified\n' > keep.sh
    printf '#!/usr/bin/env bash\necho new\n' > added.sh
    git add added.sh
    run_changed
    echo "$output"
    [[ "$output" == *"keep.sh"* ]]
    [[ "$output" == *"added.sh"* ]]
}

@test "shellcheck exits 0 when the only shell change is a deletion" {
    git rm -q gone.sh
    run bash -c 'source "$1"; _changed_files_z | grep -z "\.sh$" | xargs -0 shellcheck --severity=error' \
        _ "$LIB"
    echo "$output"
    [ "$status" -eq 0 ]
}

@test "the base-branch comparison excludes deletions too" {
    # The PR branch compares against origin/<base>, so the remote ref has to exist and the
    # deleted file has to exist on the base: add-and-delete inside one branch nets to no diff.
    printf '#!/usr/bin/env bash\necho feature\n' > feat.sh
    git add feat.sh
    git commit -q -m add-feat
    git init -q --bare "$TEMP_DIR/origin.git"
    git remote add origin "$TEMP_DIR/origin.git"
    git push -q -u origin main
    git checkout -q -b feature
    git rm -q feat.sh
    git commit -q -m remove-feat
    # `env`, not a prefix on `source`: assignment prefixes are reverted for sourced
    # functions, so GITHUB_BASE_REF would silently fall through to the HEAD branch.
    run env GITHUB_BASE_REF=main bash -c 'source "$1"; _changed_files_z | tr "\0" "\n"' _ "$LIB"
    echo "$output"
    [[ "$output" != *"feat.sh"* ]]
}
