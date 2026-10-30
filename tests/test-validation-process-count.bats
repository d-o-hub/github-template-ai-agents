#!/usr/bin/env bats
# Structural performance guard: validation must not start one interpreter per
# skill.
#
# Replacing a python fork per skill with a single batch read cut
# validate-skills.sh from 4.3s to 0.2s. A wall-clock budget would flake on slow
# CI runners, but the cause - process starts - is deterministic, so this test
# counts them. A regression to the old shape (56 skills x 2 readers) fails here
# on any machine, however fast.

setup_file() {
    export REPO_ROOT="$(cd "$(dirname "$BATS_TEST_FILENAME")/.." && pwd)"
    export REAL_PYTHON3="$(command -v python3 || true)"
    export REAL_GREP="$(command -v grep || true)"
    # Three runs do the work: the batched frontmatter read, the aggregated
    # structure/evals pass, and the rules pass. The allowance leaves room for a
    # single per-file fallback while still rejecting a per-skill loop, which
    # would start at least 56 interpreters. Overridable so the bound can be
    # shown to fail.
    export MAX_PYTHON_STARTS="${MAX_PYTHON_STARTS:-6}"
    # One pass over every reference target replaced a grep|cut pair per
    # file x name pair (5,760 forks). A couple of starts is headroom.
    export MAX_GREP_STARTS="${MAX_GREP_STARTS:-3}"
}

@test "validate-skills.sh starts a bounded number of python interpreters" {
    [ -n "$REAL_PYTHON3" ] || skip "python3 not installed"

    local counter="$BATS_FILE_TMPDIR/python-starts.log"
    local shim_dir="$BATS_FILE_TMPDIR/bin"
    mkdir -p "$shim_dir"
    : > "$counter"

    cat > "$shim_dir/python3" <<SHIM
#!/usr/bin/env bash
printf 'start\n' >> "$counter"
exec "$REAL_PYTHON3" "\$@"
SHIM
    chmod +x "$shim_dir/python3"

    run env PATH="$shim_dir:$PATH" "$REPO_ROOT/scripts/validate-skills.sh"

    # The shim must not turn the guard into a false pass: validation still runs.
    [ "$status" -eq 0 ]
    [[ "$output" == *"All skills valid"* ]]

    local starts
    starts=$(wc -l < "$counter")
    echo "python starts: $starts (limit $MAX_PYTHON_STARTS)"
    [ "$starts" -gt 0 ]
    [ "$starts" -le "$MAX_PYTHON_STARTS" ]
}

@test "check-skill-references.sh scans in one grep pass" {
    [ -n "$REAL_GREP" ] || skip "grep not installed"

    local counter="$BATS_FILE_TMPDIR/grep-starts.log"
    local shim_dir="$BATS_FILE_TMPDIR/bin-grep"
    mkdir -p "$shim_dir"
    : > "$counter"

    cat > "$shim_dir/grep" <<SHIM
#!/usr/bin/env bash
printf 'start\n' >> "$counter"
exec "$REAL_GREP" "\$@"
SHIM
    chmod +x "$shim_dir/grep"

    run env PATH="$shim_dir:$PATH" "$REPO_ROOT/scripts/check-skill-references.sh"
    [ "$status" -eq 0 ]

    local starts
    starts=$(wc -l < "$counter")
    echo "grep starts: $starts (limit $MAX_GREP_STARTS)"
    [ "$starts" -gt 0 ]
    [ "$starts" -le "$MAX_GREP_STARTS" ]
}
