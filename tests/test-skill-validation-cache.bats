#!/usr/bin/env bats
# BATS tests: the batched frontmatter pre-read must not change validation output.
#
# validate-skills.sh reads every SKILL.md in one interpreter start
# (load_skill_frontmatter) instead of forking python per skill. That speedup is
# only acceptable if the cached path prints exactly what the per-file path
# printed, including failure text and the order of skills. These tests diff the
# two modes so a future change to one cannot silently drift from the other.

setup_file() {
    export REPO_ROOT="$(cd "$(dirname "$BATS_TEST_FILENAME")/.." && pwd)"
}

# Print a full validation transcript for every SKILL.md under a repository.
#   $1 = repository path
#   $2 = preload mode: "cache" pre-reads every file, "direct" forks per file
validation_transcript() {
    local repo="$1" preload="$2"
    bash -c '
        cd "$1" || exit 1
        export REPO_ROOT="$1"
        source scripts/lib/skill-validation.sh
        mapfile -t files < <(find .agents/skills -name SKILL.md | LC_ALL=C sort)
        if [[ "$2" == cache ]]; then
            load_skill_frontmatter "${files[@]}"
        fi
        for f in "${files[@]}"; do
            printf "== %s\n" "$f"
            validate_skill_file "$f" 2>&1
            printf "rc=%s\n" "$?"
        done
    ' _ "$repo" "$preload"
}

# A miniature repository with one valid skill and two that must fail, so the
# parity check exercises the warning and error paths rather than only clean
# files.
make_fixture_repo() {
    local sandbox="$1"
    mkdir -p "$sandbox/scripts/lib" "$sandbox/.agents/skills"
    cp "$REPO_ROOT/scripts/lib/skill-validation.sh" "$sandbox/scripts/lib/"
    cp "$REPO_ROOT/scripts/lib/skill_frontmatter.py" "$sandbox/scripts/lib/"
    printf '0.10.0\n' > "$sandbox/VERSION"

    mkdir -p "$sandbox/.agents/skills/01-ok"
    cat > "$sandbox/.agents/skills/01-ok/SKILL.md" <<'MD'
---
name: ok
category: testing
description: A fixture skill that passes every frontmatter check.
version: "0.1.0"
template_version: 0.9.0
---

# OK
MD

    mkdir -p "$sandbox/.agents/skills/02-missing-version"
    cat > "$sandbox/.agents/skills/02-missing-version/SKILL.md" <<'MD'
---
name: missing-version
category: testing
description: A fixture skill without a version field.
---

# Missing Version
MD

    mkdir -p "$sandbox/.agents/skills/03-broken"
    cat > "$sandbox/.agents/skills/03-broken/SKILL.md" <<'MD'
---
name: broken
category: testing
description: -
---

# Broken
MD
}

@test "cache and per-file validation agree on this repository's skills" {
    local direct cached
    direct="$(validation_transcript "$REPO_ROOT" direct)"
    cached="$(validation_transcript "$REPO_ROOT" cache)"

    [ -n "$direct" ]
    [ "$direct" = "$cached" ]
}

@test "cache and per-file validation agree on failing skills" {
    local sandbox="$BATS_FILE_TMPDIR/fixture-repo"
    make_fixture_repo "$sandbox"

    local direct cached
    direct="$(validation_transcript "$sandbox" direct)"
    cached="$(validation_transcript "$sandbox" cache)"

    # The fixtures must actually bite, or this test would compare two clean runs.
    [[ "$direct" == *"Missing 'version:' field"* ]]
    [[ "$direct" == *"frontmatter: unexpected YAML collection indicator"* ]]
    [[ "$direct" == *"rc=1"* ]]
    [ "$direct" = "$cached" ]
}

@test "a path that cannot round-trip through the batch record falls back safely" {
    # The batch protocol is tab separated, so a path containing a tab cannot be
    # keyed back correctly. It must miss the cache and be re-read per file
    # rather than silently reporting another skill's result.
    local sandbox="$BATS_FILE_TMPDIR/tab-repo"
    make_fixture_repo "$sandbox"
    local tab_dir="$sandbox/.agents/skills/tabbed"$'\t'"skill"
    mkdir -p "$tab_dir"
    cat > "$tab_dir/SKILL.md" <<'MD'
---
name: tabbed
category: testing
description: A fixture skill whose path holds a tab character.
version: "0.1.0"
template_version: 0.8.0
---

# Tabbed
MD

    local direct cached
    direct="$(validation_transcript "$sandbox" direct)"
    cached="$(validation_transcript "$sandbox" cache)"

    [[ "$direct" == *"is >1 minor behind current 0.10.0"* ]]
    [ "$direct" = "$cached" ]
}
