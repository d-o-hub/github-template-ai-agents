#!/usr/bin/env bats
# BATS tests for skipped-check reporting in the quality gate.
# A green gate must never imply a check ran when the tool or npm script was
# absent, so every skip is recorded in SKIPPED_CHECKS and printed.

setup() {
    REPO_ROOT="$(cd "$(dirname "$BATS_TEST_FILENAME")/.." && pwd)"
    LIB="$REPO_ROOT/scripts/lib/lang-checks.sh"
    BASH_BIN="$(command -v bash)"
    cd "$REPO_ROOT" || exit 1
}

# Run run_language_checks with only the shell or markdown language detected and
# an empty PATH so the optional linter is definitely unavailable.
run_lang_checks_without_path() {
    local language="$1"
    EMPTY_BIN="$(mktemp -d)"
    run env PATH="$EMPTY_BIN" "$BASH_BIN" -c "
        set -uo pipefail
        RED=''; GREEN=''; BLUE=''; YELLOW=''; NC=''; FAILED=0
        DETECTED_LANGUAGES=('$language')
        source '$LIB'
        run_language_checks
        printf 'SKIPS=%s\n' \"\${SKIPPED_CHECKS[*]}\"
    "
    rm -rf "$EMPTY_BIN"
}

@test "lang-checks: missing shellcheck is reported as a skip, not a pass" {
    run_lang_checks_without_path shell
    [ "$status" -eq 0 ]
    [[ "$output" == *"shellcheck is not installed"* ]]
    [[ "$output" == *"SKIPS=shell:shellcheck"* ]]
    [[ "$output" != *"shellcheck passed"* ]]
}

@test "lang-checks: missing markdownlint-cli2 is reported as a skip, not a pass" {
    run_lang_checks_without_path markdown
    [ "$status" -eq 0 ]
    [[ "$output" == *"markdownlint-cli2 is not installed"* ]]
    [[ "$output" == *"SKIPS=markdown:markdownlint-cli2"* ]]
    [[ "$output" != *"markdownlint-cli2 passed"* ]]
}

@test "lang-checks: package manager follows the repository lockfile" {
    TMP_DIR="$(mktemp -d)"
    cd "$TMP_DIR" || exit 1
    printf '{"scripts":{"test":"true"}}\n' > package.json

    run "$BASH_BIN" -c "source '$LIB'; _detect_package_manager"
    [ "$output" = "npm" ]

    touch pnpm-lock.yaml
    run "$BASH_BIN" -c "source '$LIB'; _detect_package_manager"
    [ "$output" = "pnpm" ]

    rm -f pnpm-lock.yaml
    touch yarn.lock
    run "$BASH_BIN" -c "source '$LIB'; _detect_package_manager"
    [ "$output" = "yarn" ]

    cd "$REPO_ROOT" || exit 1
    rm -rf "$TMP_DIR"
}

@test "lang-checks: package.json scripts are detected by name" {
    TMP_DIR="$(mktemp -d)"
    cd "$TMP_DIR" || exit 1
    printf '{"scripts":{"test":"true","lint":"true"}}\n' > package.json

    run "$BASH_BIN" -c "source '$LIB'; _has_package_script lint && echo has-lint; _has_package_script typecheck || echo no-typecheck"
    [[ "$output" == *"has-lint"* ]]
    [[ "$output" == *"no-typecheck"* ]]

    cd "$REPO_ROOT" || exit 1
    rm -rf "$TMP_DIR"
}

@test "minimal_quality_gate.sh flags a missing shellcheck instead of a clean pass" {
    # The skip branch only exists where shellcheck is absent; CI installs it, so
    # there this assertion is genuinely unreachable rather than failing.
    command -v shellcheck >/dev/null 2>&1 && skip "shellcheck installed; skip branch unreachable"

    run ./scripts/minimal_quality_gate.sh
    [ "$status" -eq 0 ]
    [[ "$output" == *"skipped shell:shellcheck"* ]]
    [[ "$output" == *"Minimal quality gate PASSED (skipped checks"* ]]
}

@test "lang-checks: SKIP_LINT records lint checks as skips, not passes" {
    EMPTY_BIN="$(mktemp -d)"
    run env PATH="$EMPTY_BIN" SKIP_LINT=true "$BASH_BIN" -c "
        set -uo pipefail
        RED=''; GREEN=''; BLUE=''; YELLOW=''; NC=''; FAILED=0
        for language in shell markdown; do
            DETECTED_LANGUAGES=(\"\$language\")
            SKIPPED_CHECKS=()
            source '$LIB'
            run_language_checks
            printf 'SKIPS=%s\n' \"\${SKIPPED_CHECKS[*]}\"
        done
    "
    rm -rf "$EMPTY_BIN"

    [ "$status" -eq 0 ]
    [[ "$output" == *"SKIP_LINT=true"* ]]
    [[ "$output" == *"shell:shellcheck"* ]]
    [[ "$output" == *"markdown:markdownlint-cli2"* ]]
    [[ "$output" != *"shellcheck passed"* ]]
}

@test "quality_gate.sh reports links:validate-links as a skip under SKIP_LINKS" {
    # One real gate run in this repository: the flag must reach the summary
    # rather than quietly reporting a link check that never happened.
    run env SKIP_GLOBAL_HOOKS_CHECK=true SKIP_LINKS=true SKIP_LINT=true \
        ./scripts/quality_gate.sh

    [ "$status" -eq 0 ]
    [[ "$output" == *"links:validate-links"* ]]
    [[ "$output" == *"SKIP_LINKS=true"* ]]
}

@test "make test reports a skipped check when bats is missing" {
    command -v make >/dev/null 2>&1 || skip "make not available"

    TEMP_DIR="$(mktemp -d)"
    mkdir -p "$TEMP_DIR/tests" "$TEMP_DIR/bin"
    cp Makefile "$TEMP_DIR/Makefile"
    printf '#!/usr/bin/env bats\n' > "$TEMP_DIR/tests/sample.bats"
    ln -s "$(command -v make)" "$TEMP_DIR/bin/make"

    # PATH holds make only, so the recipe must take the missing-bats branch.
    run env PATH="$TEMP_DIR/bin" make -C "$TEMP_DIR" test
    [ "$status" -eq 0 ]
    [[ "$output" == *"test: SKIPPED (bats is not installed"* ]]

    rm -rf "$TEMP_DIR"
}

@test "secretlint_gate.sh signals a skip with exit 3 when npx is missing" {
    [[ -f .secretlintrc.json ]] || skip "no .secretlintrc.json in this repository"

    EMPTY_BIN="$(mktemp -d)"
    run env PATH="$EMPTY_BIN" "$BASH_BIN" ./scripts/secretlint_gate.sh
    rm -rf "$EMPTY_BIN"

    [ "$status" -eq 3 ]
    [[ "$output" == *"skipped secret:secretlint"* ]]
    [[ "$output" != *"secretlint passed"* ]]
}

# Build a minimal repository the real quality gate can run in: helper scripts
# stub to success, package.json declares no lint/typecheck/test scripts, and the
# secretlint helper signals "could not run" (exit 3). Every JS check and the
# secret scan are therefore skips regardless of where the suite runs.
make_gate_fixture() {
    local s
    GATE_FIXTURE=$(mktemp -d)
    mkdir -p "$GATE_FIXTURE/.git" "$GATE_FIXTURE/scripts/lib" "$GATE_FIXTURE/.agents/skills"
    cp scripts/quality_gate.sh scripts/generate-llms-txt.sh "$GATE_FIXTURE/scripts/"
    cp scripts/lib/*.sh "$GATE_FIXTURE/scripts/lib/"
    chmod +x "$GATE_FIXTURE/scripts/"*.sh

    for s in validate-git-hooks.sh validate-github-actions-shas.sh validate-workflows.sh \
        validate-skills.sh validate-links.sh loc_gate.sh wasm_size_gate.sh \
        check-adr-compliance.sh check-plan-numbering.sh; do
        printf '#!/usr/bin/env bash\ntrue\n' > "$GATE_FIXTURE/scripts/$s"
        chmod +x "$GATE_FIXTURE/scripts/$s"
    done

    # A helper gate that cannot run signals exit 3. The gate must turn that into
    # a reported skip; treating it as success is the false green this contract
    # exists to prevent.
    printf '#!/usr/bin/env bash\nexit 3\n' > "$GATE_FIXTURE/scripts/secretlint_gate.sh"
    chmod +x "$GATE_FIXTURE/scripts/secretlint_gate.sh"
    touch "$GATE_FIXTURE/.secretlintrc.json"

    printf '# Test Project\n\n> Test description\n' > "$GATE_FIXTURE/README.md"
    touch "$GATE_FIXTURE/VERSION" "$GATE_FIXTURE/AGENTS.md"
    printf '{"name":"fixture","scripts":{"build":"echo build"}}\n' > "$GATE_FIXTURE/package.json"
    touch "$GATE_FIXTURE/package-lock.json"
}

cleanup_gate_fixture() {
    cd "$REPO_ROOT" || exit 1
    rm -rf "$GATE_FIXTURE"
}

@test "quality_gate.sh prints a skipped-check summary for absent npm scripts" {
    command -v npm >/dev/null 2>&1 || skip "npm not available for the JS fixture"
    make_gate_fixture

    cd "$GATE_FIXTURE" || exit 1
    run env SKIP_GLOBAL_HOOKS_CHECK=true GITHUB_REF=refs/heads/main \
        GITHUB_EVENT_NAME=push GITHUB_EVENT=push ./scripts/quality_gate.sh

    [ "$status" -eq 0 ]
    [[ "$output" == *"Skipped checks"* ]]
    [[ "$output" == *"typescript:lint"* ]]
    [[ "$output" == *"secret:secretlint"* ]]

    cleanup_gate_fixture
}

@test "quality_gate.sh fails under QUALITY_GATE_STRICT_SKIPS when a check is skipped" {
    command -v npm >/dev/null 2>&1 || skip "npm not available for the JS fixture"
    make_gate_fixture

    cd "$GATE_FIXTURE" || exit 1
    run env SKIP_GLOBAL_HOOKS_CHECK=true GITHUB_REF=refs/heads/main \
        GITHUB_EVENT_NAME=push GITHUB_EVENT=push \
        QUALITY_GATE_STRICT_SKIPS=true ./scripts/quality_gate.sh

    # Same fixture as the test above, which passes: only strict mode differs.
    [ "$status" -eq 2 ]
    [[ "$output" == *"Strict skip mode"* ]]
    [[ "$output" != *"All Quality Gates PASSED"* ]]

    cleanup_gate_fixture
}
