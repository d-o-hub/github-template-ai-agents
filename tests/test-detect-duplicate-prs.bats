#!/usr/bin/env bats

setup() {
    # Mock gh: three open PRs.
    #   101 (created Sep 1) and 102 (created Sep 5): byte-identical diffs over src/a.sh+src/b.sh
    #   103 (created Sep 3): distinct diff over docs/x.md (not near-duplicate of anything)
    cat <<'MOCK' > "$BATS_TMPDIR/gh"
#!/usr/bin/env bash
if [ "$1" = "pr" ] && [ "$2" = "list" ]; then
    printf '101\t2026-09-01T00:00:00Z\n'
    printf '102\t2026-09-05T00:00:00Z\n'
    printf '103\t2026-09-03T00:00:00Z\n'
elif [ "$1" = "pr" ] && [ "$2" = "diff" ]; then
    if [[ "$*" == *"--name-only"* ]]; then
        case "$3" in
            101) printf 'src/a.sh\nsrc/b.sh\n';;
            102) printf 'src/a.sh\nsrc/b.sh\n';;
            103) printf 'docs/x.md\n';;
        esac
    else
        case "$3" in
            101) printf 'diff --git a/src/a.sh b/src/a.sh\n@@\n-x\n+y\n';;
            102) printf 'diff --git a/src/a.sh b/src/a.sh\n@@\n-x\n+y\n';;
            103) printf 'diff --git a/docs/x.md b/docs/x.md\n@@\n-doc\n+doc2\n';;
        esac
    fi
elif [ "$1" = "pr" ] && [ "$2" = "view" ]; then
    printf '{"comments":[{"body":"no marker here"}]}'
elif [ "$1" = "pr" ] && [ "$2" = "close" ]; then
    echo "CLOSED $3" >> "$BATS_TMPDIR/actions.log"
elif [ "$1" = "pr" ] && [ "$2" = "comment" ]; then
    echo "COMMENTED $3" >> "$BATS_TMPDIR/actions.log"
elif [ "$1" = "pr" ] && [ "$2" = "edit" ]; then
    echo "LABELED $3" >> "$BATS_TMPDIR/actions.log"
fi
exit 0
MOCK
    chmod +x "$BATS_TMPDIR/gh"
    export PATH="$BATS_TMPDIR:$PATH"
    rm -f "$BATS_TMPDIR/actions.log"
}

actions() {
    cat "$BATS_TMPDIR/actions.log" 2>/dev/null || true
}

@test "exact duplicates: closes the older PR, keeps the newest survivor" {
    run ./scripts/detect-duplicate-prs.sh
    [ "$status" -eq 0 ]
    [[ "$output" == *"Closed duplicate PR #101 (exact match, survivor #102)"* ]]
    [[ "$(actions)" == *"CLOSED 101"* ]]
    [[ "$(actions)" != *"CLOSED 102"* ]]
    [[ "$(actions)" != *"CLOSED 103"* ]]
}

@test "near duplicates: labels and comments the older PR without closing it" {
    # Make 101 and 202 share files but differ in diff content by overriding the mock.
    cat <<'MOCK' > "$BATS_TMPDIR/gh"
#!/usr/bin/env bash
if [ "$1" = "pr" ] && [ "$2" = "list" ]; then
    printf '201\t2026-09-01T00:00:00Z\n'
    printf '202\t2026-09-05T00:00:00Z\n'
elif [ "$1" = "pr" ] && [ "$2" = "diff" ]; then
    if [[ "$*" == *"--name-only"* ]]; then
        case "$3" in
            201) printf 'src/feat.sh\nsrc/other.sh\n';;
            202) printf 'src/feat.sh\nsrc/other.sh\nsrc/new.sh\n';;
        esac
    else
        case "$3" in
            201) printf 'diff --git a/src/feat.sh b/src/feat.sh\n@@\n-a\n+b\n';;
            202) printf 'diff --git a/src/feat.sh b/src/feat.sh\n@@\n-a\n+c\n';;
        esac
    fi
elif [ "$1" = "pr" ] && [ "$2" = "view" ]; then
    printf '{"comments":[]}'
elif [ "$1" = "pr" ] && [ "$2" = "comment" ]; then
    echo "COMMENTED $3" >> "$BATS_TMPDIR/actions.log"
elif [ "$1" = "pr" ] && [ "$2" = "edit" ]; then
    echo "LABELED $3" >> "$BATS_TMPDIR/actions.log"
elif [ "$1" = "pr" ] && [ "$2" = "close" ]; then
    echo "CLOSED $3" >> "$BATS_TMPDIR/actions.log"
fi
exit 0
MOCK
    chmod +x "$BATS_TMPDIR/gh"
    run ./scripts/detect-duplicate-prs.sh
    [ "$status" -eq 0 ]
    [[ "$output" == *"Flagged PR #201 as superseded-candidate (overlaps #202)"* ]]
    [[ "$(actions)" == *"COMMENTED 201"* ]]
    [[ "$(actions)" == *"LABELED 201"* ]]
    [[ "$(actions)" != *"CLOSED 201"* ]]
}

@test "distinct PRs: no actions taken" {
    cat <<'MOCK' > "$BATS_TMPDIR/gh"
#!/usr/bin/env bash
if [ "$1" = "pr" ] && [ "$2" = "list" ]; then
    printf '301\t2026-09-01T00:00:00Z\n'
    printf '302\t2026-09-02T00:00:00Z\n'
elif [ "$1" = "pr" ] && [ "$2" = "diff" ]; then
    if [[ "$*" == *"--name-only"* ]]; then
        case "$3" in
            301) printf 'src/one.sh\n';;
            302) printf 'docs/two.md\n';;
        esac
    else
        case "$3" in
            301) printf 'diff --git a/src/one.sh b/src/one.sh\n@@\n-1\n+2\n';;
            302) printf 'diff --git a/docs/two.md b/docs/two.md\n@@\n-1\n+2\n';;
        esac
    fi
elif [ "$1" = "pr" ] && [ "$2" = "view" ]; then
    printf '{"comments":[]}'
elif [ "$1" = "pr" ] && [ "$2" = "close" ]; then
    echo "CLOSED $3" >> "$BATS_TMPDIR/actions.log"
elif [ "$1" = "pr" ] && [ "$2" = "comment" ]; then
    echo "COMMENTED $3" >> "$BATS_TMPDIR/actions.log"
elif [ "$1" = "pr" ] && [ "$2" = "edit" ]; then
    echo "LABELED $3" >> "$BATS_TMPDIR/actions.log"
fi
exit 0
MOCK
    chmod +x "$BATS_TMPDIR/gh"
    run ./scripts/detect-duplicate-prs.sh
    [ "$status" -eq 0 ]
    [[ "$(actions)" == "" ]]
    [[ "$output" == *"Done. closed=0 flagged=0"* ]]
}

@test "dry run reports without acting" {
    run env DRY_RUN=true ./scripts/detect-duplicate-prs.sh
    [ "$status" -eq 0 ]
    [[ "$output" == *"[DRY RUN] would close duplicate PR #101"* ]]
    [[ "$(actions)" == "" ]]
}

@test "idempotent: PRs already flagged are skipped" {
    cat <<'MOCK' > "$BATS_TMPDIR/gh"
#!/usr/bin/env bash
if [ "$1" = "pr" ] && [ "$2" = "list" ]; then
    printf '401\t2026-09-01T00:00:00Z\n'
    printf '402\t2026-09-05T00:00:00Z\n'
elif [ "$1" = "pr" ] && [ "$2" = "diff" ]; then
    if [[ "$*" == *"--name-only"* ]]; then
        case "$3" in
            401) printf 'src/feat.sh\nsrc/other.sh\n';;
            402) printf 'src/feat.sh\nsrc/other.sh\nsrc/new.sh\n';;
        esac
    else
        case "$3" in
            401) printf 'diff --git a/src/feat.sh b/src/feat.sh\n@@\n-a\n+b\n';;
            402) printf 'diff --git a/src/feat.sh b/src/feat.sh\n@@\n-a\n+c\n';;
        esac
    fi
elif [ "$1" = "pr" ] && [ "$2" = "view" ]; then
    printf '{"comments":[{"body":"<!-- duplicate-pr-guard --> earlier guard comment"}]}'
elif [ "$1" = "pr" ] && [ "$2" = "comment" ]; then
    echo "COMMENTED $3" >> "$BATS_TMPDIR/actions.log"
elif [ "$1" = "pr" ] && [ "$2" = "edit" ]; then
    echo "LABELED $3" >> "$BATS_TMPDIR/actions.log"
elif [ "$1" = "pr" ] && [ "$2" = "close" ]; then
    echo "CLOSED $3" >> "$BATS_TMPDIR/actions.log"
fi
exit 0
MOCK
    chmod +x "$BATS_TMPDIR/gh"
    run ./scripts/detect-duplicate-prs.sh
    [ "$status" -eq 0 ]
    [[ "$output" == *"Skipping PR #401 (already flagged by a previous run)"* ]]
    [[ "$(actions)" == "" ]]
}
