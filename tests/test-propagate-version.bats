#!/usr/bin/env bats
# Tests for scripts/propagate-version.sh
#
# Each test builds a throwaway repo under $BATS_TEST_TMPDIR and copies the real script into
# it, because the script derives REPO_ROOT from its own location. Nothing here may write to
# the repository's own README.md / CHANGELOG.md.

setup_file() {
    export REPO_ROOT="$(cd "$(dirname "$BATS_TEST_FILENAME")/.." && pwd)"
}

# make_repo <name> [version] — minimal tree with every path the script reads.
make_repo() {
    repo="$BATS_TEST_TMPDIR/repo-$1"
    rm -rf "$repo"
    mkdir -p "$repo/scripts" "$repo/agents-docs" "$repo/.template" "$repo/analysis"
    cp "$REPO_ROOT/scripts/propagate-version.sh" "$repo/scripts/propagate-version.sh"
    chmod +x "$repo/scripts/propagate-version.sh"
    if [ "$#" -ge 2 ]; then
        printf '%s' "$2" > "$repo/VERSION"
    else
        printf '1.2.3\n' > "$repo/VERSION"
    fi
    printf '%s\n' "$repo"
}

@test "propagate-version.sh exists and is executable" {
    [ -x "$REPO_ROOT/scripts/propagate-version.sh" ]
}

@test "version badge, template version, and **Version:** references are all rewritten" {
    repo=$(make_repo badges)
    printf '%s\n' '# T' \
        '![v](https://img.shields.io/badge/version-0.9.9-blue)' \
        '**Version:** 0.9.9' \
        'Template version: 0.9.9 once and Template version: 0.9.9 twice.' > "$repo/README.md"

    run bash "$repo/scripts/propagate-version.sh"

    [ "$status" -eq 0 ]
    grep -qF 'badge/version-1.2.3-blue' "$repo/README.md"
    grep -qF '**Version:** 1.2.3' "$repo/README.md"
    [ "$(grep -cF 'Template version: 1.2.3' "$repo/README.md")" -eq 1 ]
    # Every occurrence on the line is replaced, not just the first.
    [ "$(grep -oF 'Template version: 1.2.3' "$repo/README.md" | wc -l)" -eq 2 ]
    ! grep -q '0\.9\.9' "$repo/README.md"
}

@test "table VERSION row keeps its surrounding backticks" {
    repo=$(make_repo table)
    # The old GNU BRE rewrite emitted `| \`X\` | \`1.2.3\` |`; an ERE port that loses the
    # backticks silently breaks the markdown code span, so assert them literally.
    printf '%s\n' '| `VERSION` | `0.5.5` |' '| Other | `nope` |' > "$repo/agents-docs/MIGRATION.md"

    run bash "$repo/scripts/propagate-version.sh"

    [ "$status" -eq 0 ]
    grep -qF '| `VERSION` | `1.2.3` |' "$repo/agents-docs/MIGRATION.md"
    grep -qF '| Other | `nope` |' "$repo/agents-docs/MIGRATION.md"
}

@test "[Unreleased] is inserted below the title line" {
    repo=$(make_repo unrel)
    printf '%s\n' '# Changelog' '## [0.1.0] - 2026-01-01' '- initial' > "$repo/CHANGELOG.md"

    run bash "$repo/scripts/propagate-version.sh"

    [ "$status" -eq 0 ]
    [ "$(sed -n '1p' "$repo/CHANGELOG.md")" = '# Changelog' ]
    [ "$(sed -n '3p' "$repo/CHANGELOG.md")" = '## [Unreleased]' ]
    grep -qF '## [0.1.0] - 2026-01-01' "$repo/CHANGELOG.md"
    [[ "$output" == *"Added [Unreleased] section to CHANGELOG.md"* ]]
}

@test "an existing [Unreleased] heading is never duplicated" {
    repo=$(make_repo dupe)
    printf '%s\n' '# Changelog' '' '## [Unreleased]' '' '## [0.1.0]' > "$repo/CHANGELOG.md"
    before=$(cat "$repo/CHANGELOG.md")

    run bash "$repo/scripts/propagate-version.sh"

    [ "$status" -eq 0 ]
    [ "$(grep -cF '## [Unreleased]' "$repo/CHANGELOG.md")" -eq 1 ]
    [ "$(cat "$repo/CHANGELOG.md")" = "$before" ]
    [[ "$output" == *"No updates needed"* ]]
}

@test "a [Unreleased] heading on line one is recognized" {
    repo=$(make_repo firstline)
    printf '%s\n' '## [Unreleased]' '' '## [0.1.0]' > "$repo/CHANGELOG.md"

    run bash "$repo/scripts/propagate-version.sh"

    [ "$status" -eq 0 ]
    [ "$(grep -cF '## [Unreleased]' "$repo/CHANGELOG.md")" -eq 1 ]
}

@test "a single-line changelog gains no trailing blank line" {
    repo=$(make_repo single)
    printf '# Changelog\n' > "$repo/CHANGELOG.md"

    run bash "$repo/scripts/propagate-version.sh"

    [ "$status" -eq 0 ]
    # The GNU `sed 1a` append ended the file with "\n\n", which markdownlint rejects as MD012.
    [ "$(cat "$repo/CHANGELOG.md")" = '# Changelog

## [Unreleased]' ]
    [ "$(wc -l < "$repo/CHANGELOG.md")" -eq 3 ]
}

@test "a second run changes nothing" {
    repo=$(make_repo idempotent)
    printf '%s\n' '![v](https://img.shields.io/badge/version-0.9.9-blue)' > "$repo/README.md"
    printf '%s\n' '# Changelog' '## [0.1.0]' > "$repo/CHANGELOG.md"
    bash "$repo/scripts/propagate-version.sh" > /dev/null
    cp -r "$repo" "$repo.after"

    run bash "$repo/scripts/propagate-version.sh"

    [ "$status" -eq 0 ]
    diff -r "$repo" "$repo.after"
}

@test "a listed file that does not exist warns without failing the run" {
    repo=$(make_repo missingfile)
    printf '%s\n' '**Version:** 0.0.1' > "$repo/README.md"
    rm -f "$repo/QUICKSTART.md" "$repo/analysis/SWARM_ANALYSIS.md"

    run bash "$repo/scripts/propagate-version.sh"

    [ "$status" -eq 0 ]
    [[ "$output" == *"Warning: QUICKSTART.md not found, skipping"* ]]
    grep -qF '**Version:** 1.2.3' "$repo/README.md"
}

@test "files outside the propagation list are never modified" {
    repo=$(make_repo scope)
    printf '%s\n' 'notes **Version:** 0.0.0' > "$repo/untouched.md"

    run bash "$repo/scripts/propagate-version.sh"

    [ "$status" -eq 0 ]
    grep -qF 'notes **Version:** 0.0.0' "$repo/untouched.md"
}

@test "absent, empty, and non-semver VERSION all exit 1" {
    repo=$(make_repo noversion)
    rm -f "$repo/VERSION"
    run bash "$repo/scripts/propagate-version.sh"
    [ "$status" -eq 1 ]
    [[ "$output" == *"VERSION file not found"* ]]

    repo=$(make_repo emptyversion '')
    run bash "$repo/scripts/propagate-version.sh"
    [ "$status" -eq 1 ]
    [[ "$output" == *"VERSION file is empty"* ]]

    repo=$(make_repo badversion '1.2')
    run bash "$repo/scripts/propagate-version.sh"
    [ "$status" -eq 1 ]
    [[ "$output" == *"strict semantic version"* ]]
}

@test "surrounding whitespace in VERSION is tolerated" {
    repo=$(make_repo ws '  1.2.3  ')
    printf '%s\n' 'Template version: 0.0.1' > "$repo/QUICKSTART.md"

    run bash "$repo/scripts/propagate-version.sh"

    [ "$status" -eq 0 ]
    grep -qF 'Template version: 1.2.3' "$repo/QUICKSTART.md"
}

@test "the rewrite does not depend on GNU-only sed extensions" {
    script="$REPO_ROOT/scripts/propagate-version.sh"
    # Only non-comment lines: the file explains, in prose, exactly which extensions it avoids.
    code=$(grep -vE '^[[:space:]]*#' "$script")
    if grep -Eq 'sed[[:space:]]+-i' <<< "$code"; then
        echo "in-place sed is a GNU extension (BSD sed requires -i '')"
        return 1
    fi
    if grep -Eq 'sed[^|]*"1a' <<< "$code"; then
        echo "sed append-with-escape is GNU-only"
        return 1
    fi
    if grep -Fq '\+' <<< "$code"; then
        echo "BRE \\+ is a GNU extension; use sed -E and +"
        return 1
    fi
    grep -Eq 'sed -E' <<< "$code"
}
