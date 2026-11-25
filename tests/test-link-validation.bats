#!/usr/bin/env bats
# BATS tests for scripts/validate-links.sh and its helpers in scripts/lib/link-validation.sh:
# the traversal verdict, and which files the scan reads and resolves links against.
#
# The traversal verdict used to depend entirely on realpath: when the binary was absent, or
# present without `-m` support (BSD/older macOS), RESOLVED_ROOT came back empty and the check
# was skipped, so a link climbing out of the repository was accepted as valid. The escaping
# link used below resolves to a file that really exists, so the old raw `-e` check passed it.

setup_file() {
    export REPO_ROOT="$(cd "$(dirname "$BATS_TEST_FILENAME")/.." && pwd)"
    export LIB="$REPO_ROOT/scripts/lib/link-validation.sh"
}

setup() {
    cd "$REPO_ROOT" || exit 1
    BASE=$(mktemp -d)
    BASE=$(cd "$BASE" && pwd -P)
    SANDBOX="$BASE/repo"
    OUTSIDE="$BASE/outside"
    mkdir -p "$SANDBOX/.agents/skills/demo/references" "$OUTSIDE"
    printf 'secret\n' > "$OUTSIDE/secret.md"
    printf 'guide\n' > "$SANDBOX/.agents/skills/demo/references/guide.md"
    SKILL_DIR="$SANDBOX/.agents/skills/demo"
    # demo -> skills -> .agents -> repo -> $BASE: four levels leave the repository.
    ESCAPING_LINK='../../../../outside/secret.md'
}

teardown() {
    cd "$REPO_ROOT" || exit 1
    rm -rf -- "$BASE"
}

# call_check <has_realpath> <resolved_root_mode> <link>
# resolved_root_mode: "" for the empty value BSD realpath produces, "set" for a resolved root.
call_check() {
    local has_realpath="$1" root_mode="$2" link="$3"
    local resolved_root=""
    if [[ "$root_mode" == "set" ]]; then
        resolved_root="$SANDBOX"
    fi
    run bash -c '
        source "$1"
        REPO_ROOT="$2"
        HAS_REALPATH="$3"
        RESOLVED_ROOT="$4"
        check_link "$5" "$6" "demo/SKILL.md" 1
    ' _ "$LIB" "$SANDBOX" "$has_realpath" "$resolved_root" "$SKILL_DIR" "$link"
}

@test "an escaping link is rejected when realpath is unavailable" {
    call_check 0 "" "$ESCAPING_LINK"
    echo "$output"
    [ "$status" -eq 1 ]
    [[ "$output" == *"Path traversal detected"* ]]
}

@test "an escaping link is rejected when realpath exists but cannot resolve" {
    # BSD realpath is on PATH but has no -m, so the root never gets resolved.
    call_check 1 "" "$ESCAPING_LINK"
    echo "$output"
    [ "$status" -eq 1 ]
    [[ "$output" == *"Path traversal detected"* ]]
}

@test "an escaping link is rejected when realpath fully works" {
    call_check 1 set "$ESCAPING_LINK"
    echo "$output"
    [ "$status" -eq 1 ]
    [[ "$output" == *"Path traversal detected"* ]]
}

@test "a link that rounds through .. inside the repository still passes" {
    call_check 0 "" "references/../references/guide.md"
    echo "$output"
    [ "$status" -eq 0 ]
}

@test "an ordinary link still passes and a missing one is still reported" {
    call_check 0 "" "references/guide.md"
    [ "$status" -eq 0 ]
    call_check 0 "" "references/gone.md"
    echo "$output"
    [ "$status" -eq 1 ]
    [[ "$output" == *"Broken link"* ]]
    [[ "$output" != *"traversal"* ]]
}

@test "_resolve_lexical collapses dots and keeps an escape visible" {
    run bash -c '
        source "$1"
        _resolve_lexical "/repo/.agents/skills/x/../references/a.md"
        printf "\n"
        _resolve_lexical "/repo/x/../../../outside/a.md"
    ' _ "$LIB"
    echo "$output"
    [[ "${lines[0]}" == "/repo/.agents/skills/references/a.md" ]]
    [[ "${lines[1]}" == "/../outside/a.md" ]]
}

# ---------------------------------------------------------------------------------------------
# Scope of scripts/validate-links.sh.
#
# The skill scan used to be one SKILL.md per skill, so a link in references/ or sdks/ was never
# followed even though the gate printed "All reference links valid". Widening the file list is
# only useful if resolution also follows what a renderer does: relative links resolve against the
# containing file's directory. For SKILL.md those two directories are the same, so its verdicts
# are unchanged — tests below pin both halves of that claim.
# ---------------------------------------------------------------------------------------------

# make_repo <name> — a throwaway repository with one demo skill, its own copy of the script.
# Layout is fixed so each test mutates exactly one thing.
make_repo() {
    local repo="$BATS_TEST_TMPDIR/$1"
    mkdir -p "$repo/scripts/lib" "$repo/.agents/skills/demo/references" \
        "$repo/.agents/skills/demo/templates" "$repo/.agents/skills/demo/evals"
    cp "$REPO_ROOT/scripts/validate-links.sh" "$repo/scripts/validate-links.sh"
    cp "$REPO_ROOT/scripts/lib/link-validation.sh" "$repo/scripts/lib/link-validation.sh"
    printf 'guide\n' > "$repo/.agents/skills/demo/references/guide.md"
    printf 'schema\n' > "$repo/.agents/skills/demo/references/schemas.md"
    printf '#!/usr/bin/env bash\n' > "$repo/.agents/skills/demo/templates/run.sh"

    cat > "$repo/.agents/skills/demo/SKILL.md" <<'EOF'
---
name: demo
description: A demo skill
---

# Demo

See [the guide](references/guide.md) to start.

## References

- `references/guide.md` - The guide
- `references/schemas.md` - The schemas
EOF

    # A companion document: sibling links, and a skill-root-relative link that is the bug class
    # this scan used to miss.
    cat > "$repo/.agents/skills/demo/references/patterns.md" <<'EOF'
# Patterns

| Reference | When to use |
|---|---|
| [references/guide.md](guide.md) | sibling, resolves |
EOF
    REPO="$repo"
}

run_validator() {
    run bash -c 'cd "$1" && ./scripts/validate-links.sh' _ "$REPO"
}

@test "a well-formed skill passes the widened scan" {
    make_repo good
    run_validator
    echo "$output"
    [ "$status" -eq 0 ]
}

@test "SKILL.md links still resolve from the skill root" {
    make_repo skillroot
    rm "$REPO/.agents/skills/demo/references/guide.md"
    run_validator
    echo "$output"
    [ "$status" -eq 1 ]
    [[ "$output" == *"in: $REPO/.agents/skills/demo/SKILL.md"* ]]
}

@test "a broken link in a companion file under references/ is caught" {
    # `gone.md` is referenced by nothing else, so this only fails if references/patterns.md is
    # actually scanned.
    make_repo companion
    printf '\nSee [the missing page](gone.md).\n' >> "$REPO/.agents/skills/demo/references/patterns.md"
    run_validator
    echo "$output"
    [ "$status" -eq 1 ]
    [[ "$output" == *"Broken link at line"* ]]
    [[ "$output" == *"in: $REPO/.agents/skills/demo/references/patterns.md"* ]]
}

@test "a skill-root-relative link written inside a subdirectory file is rejected" {
    # The real defect: agent-browser/references/PATTERNS.md pointed at references/commands.md,
    # which exists from the skill root but resolves to references/references/commands.md.
    make_repo relativize
    printf '\nSee [the guide](references/guide.md).\n' >> "$REPO/.agents/skills/demo/references/patterns.md"
    run_validator
    echo "$output"
    [ "$status" -eq 1 ]
    # The reported path is the skill-root-relative form, which is exactly what must not resolve.
    [[ "$output" == *"Broken link at line"*"references/guide.md"* ]]
    [[ "$output" == *"in: $REPO/.agents/skills/demo/references/patterns.md"* ]]
}

@test "an example link inside a fenced code block is not a reference" {
    make_repo fenced
    {
        printf '## Sample\n\n'
        printf '```markdown\n'
        printf '[Issues](../../issues)\n'
        printf '```\n'
    } >> "$REPO/.agents/skills/demo/references/patterns.md"
    run_validator
    echo "$output"
    [ "$status" -eq 0 ]
}

@test "an example link inside an inline code span is not a reference" {
    make_repo inline
    printf '\nWrap every badge in `[![...](img)](url)`.\n' >> "$REPO/.agents/skills/demo/references/patterns.md"
    run_validator
    echo "$output"
    [ "$status" -eq 0 ]
}

@test "an eval fixture is out of scope" {
    make_repo evals
    printf '# Bad input\n\n[Good File](references/good-file.md)\n' \
        > "$REPO/.agents/skills/demo/evals/bad-references-input.md"
    run_validator
    echo "$output"
    [ "$status" -eq 0 ]
}

@test "an unclosed fence does not leak into the next file" {
    # Fence state resets at FNR == 1. Without that reset, one unbalanced block in patterns.md
    # would suppress every later file in the same awk run, and the scan would quietly go green.
    make_repo unbalanced
    printf '\n```text\nnever closed\n' >> "$REPO/.agents/skills/demo/references/patterns.md"
    rm "$REPO/.agents/skills/demo/references/schemas.md"
    run_validator
    echo "$output"
    [ "$status" -eq 1 ]
    [[ "$output" == *"Broken link at line"* ]]
    [[ "$output" == *"in: $REPO/.agents/skills/demo/SKILL.md"* ]]
}

@test "the References format rule still applies to SKILL.md" {
    make_repo format
    # Swap the required bullet form for a plain markdown link, leaving the rest of the file alone.
    awk '{ if ($0 ~ /^- `references\/guide.md`/) print "- [the guide](references/guide.md)"; else print }' \
        "$REPO/.agents/skills/demo/SKILL.md" > "$REPO/.agents/skills/demo/SKILL.md.tmp"
    mv "$REPO/.agents/skills/demo/SKILL.md.tmp" "$REPO/.agents/skills/demo/SKILL.md"
    run_validator
    echo "$output"
    [ "$status" -eq 1 ]
    [[ "$output" == *"Invalid reference format"* ]]
}

@test "the References format rule does not fire on companion files" {
    # Companion files are prose, not the SKILL.md authoring contract: a bullet naming a sibling
    # reference is normal there and must not be judged by PROPER_REF_REGEX.
    make_repo format-companion
    {
        printf '\n## Reference Files\n\n'
        printf -- '- [the guide](guide.md) - a plain bullet link\n'
    } >> "$REPO/.agents/skills/demo/references/patterns.md"
    run_validator
    echo "$output"
    [ "$status" -eq 0 ]
}

@test "companion files are really in scope in this repository" {
    # Guards the gap itself: if the file list narrows back to SKILL.md, the pass/fail below
    # stops being reported and the suite catches the regression rather than the gate looking green.
    cd "$REPO_ROOT" || return 1
    run bash -c './scripts/validate-links.sh'
    echo "$output"
    [ "$status" -eq 0 ]
    [[ "$output" == *".agents/skills/agent-browser/references/PATTERNS.md: All links valid"* ]]
    [[ "$output" == *".agents/skills/turso-db/sdks/"* ]]
}

