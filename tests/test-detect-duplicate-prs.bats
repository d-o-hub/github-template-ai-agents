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

@test "self-heals: creates missing label and retries when labeling fails" {
    cat <<'MOCK' > "$BATS_TMPDIR/gh"
#!/usr/bin/env bash
if [ "$1" = "pr" ] && [ "$2" = "list" ]; then
    printf '501\t2026-09-01T00:00:00Z\n'
    printf '502\t2026-09-05T00:00:00Z\n'
elif [ "$1" = "pr" ] && [ "$2" = "diff" ]; then
    if [[ "$*" == *"--name-only"* ]]; then
        case "$3" in
            501) printf 'src/feat.sh\nsrc/other.sh\n';;
            502) printf 'src/feat.sh\nsrc/other.sh\nsrc/new.sh\n';;
        esac
    else
        case "$3" in
            501) printf 'diff --git a/src/feat.sh b/src/feat.sh\n@@\n-a\n+b\n';;
            502) printf 'diff --git a/src/feat.sh b/src/feat.sh\n@@\n-a\n+c\n';;
        esac
    fi
elif [ "$1" = "pr" ] && [ "$2" = "view" ]; then
    printf '{"comments":[]}'
elif [ "$1" = "pr" ] && [ "$2" = "comment" ]; then
    echo "COMMENTED $3" >> "$BATS_TMPDIR/actions.log"
elif [ "$1" = "pr" ] && [ "$2" = "edit" ]; then
    # Simulate a repo missing the label: --add-label fails until it is created.
    if [ -f "$BATS_TMPDIR/label-exists" ]; then
        echo "LABELED $3" >> "$BATS_TMPDIR/actions.log"
    else
        exit 1
    fi
elif [ "$1" = "label" ] && [ "$2" = "create" ]; then
    touch "$BATS_TMPDIR/label-exists"
    echo "CREATED-LABEL" >> "$BATS_TMPDIR/actions.log"
elif [ "$1" = "pr" ] && [ "$2" = "close" ]; then
    echo "CLOSED $3" >> "$BATS_TMPDIR/actions.log"
fi
exit 0
MOCK
    chmod +x "$BATS_TMPDIR/gh"
    rm -f "$BATS_TMPDIR/label-exists"
    run ./scripts/detect-duplicate-prs.sh
    [ "$status" -eq 0 ]
    [[ "$output" == *"Flagged PR #501 as superseded-candidate (overlaps #502)"* ]]
    [[ "$(actions)" == *"COMMENTED 501"* ]]
    [[ "$(actions)" == *"CREATED-LABEL"* ]]
    [[ "$(actions)" == *"LABELED 501"* ]]
    [[ "$(actions)" != *"CLOSED 501"* ]]
}

@test "subset duplicates: closes the older PR when every shared file patch is identical" {
    cat <<'MOCK' > "$BATS_TMPDIR/gh"
#!/usr/bin/env bash
if [ "$1" = "pr" ] && [ "$2" = "list" ]; then
    printf '601\t2026-09-01T00:00:00Z\n'
    printf '602\t2026-09-05T00:00:00Z\n'
elif [ "$1" = "pr" ] && [ "$2" = "diff" ]; then
    case "$3" in
        601) printf 'diff --git a/src/a.sh b/src/a.sh\n@@\n-a\n+b\ndiff --git a/src/b.sh b/src/b.sh\n@@\n-b\n+c\n';;
        602) printf 'diff --git a/src/a.sh b/src/a.sh\n@@\n-a\n+b\ndiff --git a/src/b.sh b/src/b.sh\n@@\n-b\n+c\ndiff --git a/src/new.sh b/src/new.sh\n@@\n-n\n+m\n';;
    esac
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
    [[ "$output" == *"Closed subset duplicate PR #601 (contained in survivor #602)"* ]]
    [[ "$(actions)" == *"CLOSED 601"* ]]
    [[ "$(actions)" != *"CLOSED 602"* ]]
    [[ "$(actions)" != *"COMMENTED 601"* ]]
}

@test "divergent patch on a shared file: subset does not close, falls back to flag" {
    cat <<'MOCK' > "$BATS_TMPDIR/gh"
#!/usr/bin/env bash
if [ "$1" = "pr" ] && [ "$2" = "list" ]; then
    printf '701\t2026-09-01T00:00:00Z\n'
    printf '702\t2026-09-05T00:00:00Z\n'
elif [ "$1" = "pr" ] && [ "$2" = "diff" ]; then
    case "$3" in
        701) printf 'diff --git a/src/a.sh b/src/a.sh\n@@\n-a\n+b\ndiff --git a/src/b.sh b/src/b.sh\n@@\n-b\n+c\n';;
        702) printf 'diff --git a/src/a.sh b/src/a.sh\n@@\n-a\n+DIFFERENT\ndiff --git a/src/b.sh b/src/b.sh\n@@\n-b\n+c\ndiff --git a/src/new.sh b/src/new.sh\n@@\n-n\n+m\n';;
    esac
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
    [[ "$output" == *"Flagged PR #701 as superseded-candidate (overlaps #702)"* ]]
    [[ "$(actions)" != *"CLOSED 701"* ]]
}

@test "task siblings: flags the older PR re-run of the same Jules task" {
    cat <<'MOCK' > "$BATS_TMPDIR/gh"
#!/usr/bin/env bash
if [ "$1" = "pr" ] && [ "$2" = "list" ]; then
    printf '801\t2026-09-01T00:00:00Z\n'
    printf '802\t2026-09-05T00:00:00Z\n'
elif [ "$1" = "pr" ] && [ "$2" = "diff" ]; then
    # Disjoint files: no file-overlap signal, only the task id ties them.
    case "$3" in
        801) printf 'diff --git a/src/one.sh b/src/one.sh\n@@\n-1\n+2\n';;
        802) printf 'diff --git a/docs/two.md b/docs/two.md\n@@\n-3\n+4\n';;
    esac
elif [ "$1" = "pr" ] && [ "$2" = "view" ]; then
    if [ "$5" = "body" ]; then
        printf 'PR created automatically by Jules for task [777777777777777777](https://jules.google.com/task/777777777777777777) started by @d-o-hub'
    else
        printf '{"comments":[]}'
    fi
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
    [[ "$output" == *"Flagged PR #801 as superseded-candidate (same Jules task as #802)"* ]]
    [[ "$(actions)" == *"COMMENTED 801"* ]]
    [[ "$(actions)" == *"LABELED 801"* ]]
    [[ "$(actions)" != *"CLOSED 801"* ]]
    [[ "$(actions)" != *"COMMENTED 802"* ]]
}

@test "empty: no open PRs does nothing" {
    cat <<'MOCK' > "$BATS_TMPDIR/gh"
#!/usr/bin/env bash
if [ "$1" = "pr" ] && [ "$2" = "list" ]; then
    exit 0
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
    [[ "$output" == *"No open PRs; nothing to do."* ]]
    [[ "$(actions)" == "" ]]
}

@test "blank: single PR with empty diff takes no action" {
    cat <<'MOCK' > "$BATS_TMPDIR/gh"
#!/usr/bin/env bash
if [ "$1" = "pr" ] && [ "$2" = "list" ]; then
    printf '910\t2026-09-01T00:00:00Z\n'
elif [ "$1" = "pr" ] && [ "$2" = "diff" ]; then
    case "$3" in
        910) printf '';;
    esac
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
    [[ "$output" == *"Done. closed=0 flagged=0"* ]]
    [[ "$(actions)" == "" ]]
}

@test "spaces in filenames: subset closes the older PR" {
    cat <<'MOCK' > "$BATS_TMPDIR/gh"
#!/usr/bin/env bash
if [ "$1" = "pr" ] && [ "$2" = "list" ]; then
    printf '931\t2026-09-01T00:00:00Z\n'
    printf '932\t2026-09-05T00:00:00Z\n'
elif [ "$1" = "pr" ] && [ "$2" = "diff" ]; then
    case "$3" in
        931) printf 'diff --git a/src/my file.sh b/src/my file.sh\n@@\n-a\n+b\n';;
        932) printf 'diff --git a/src/my file.sh b/src/my file.sh\n@@\n-a\n+b\ndiff --git a/src/other.sh b/src/other.sh\n@@\n-c\n+d\n';;
    esac
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
    [[ "$output" == *"Closed subset duplicate PR #931 (contained in survivor #932)"* ]]
    [[ "$(actions)" == *"CLOSED 931"* ]]
    [[ "$(actions)" != *"CLOSED 932"* ]]
}

@test "quotes in filenames: subset closes without word-splitting" {
    cat <<'MOCK' > "$BATS_TMPDIR/gh"
#!/usr/bin/env bash
if [ "$1" = "pr" ] && [ "$2" = "list" ]; then
    printf '935\t2026-09-01T00:00:00Z\n'
    printf '936\t2026-09-05T00:00:00Z\n'
elif [ "$1" = "pr" ] && [ "$2" = "diff" ]; then
    case "$3" in
        935)
            qfile="src/a'b\"c.sh"
            printf 'diff --git a/%s b/%s\n@@\n-a\n+b\n' "$qfile" "$qfile"
            ;;
        936)
            qfile="src/a'b\"c.sh"
            printf 'diff --git a/%s b/%s\n@@\n-a\n+b\n' "$qfile" "$qfile"
            printf 'diff --git a/src/other.sh b/src/other.sh\n@@\n-c\n+d\n'
            ;;
    esac
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
    [[ "$output" == *"Closed subset duplicate PR #935 (contained in survivor #936)"* ]]
    [[ "$(actions)" == *"CLOSED 935"* ]]
    [[ "$(actions)" != *"CLOSED 936"* ]]
}

@test "glob chars in filenames: no pathname expansion, subset closes" {
    cat <<'MOCK' > "$BATS_TMPDIR/gh"
#!/usr/bin/env bash
if [ "$1" = "pr" ] && [ "$2" = "list" ]; then
    printf '941\t2026-09-01T00:00:00Z\n'
    printf '942\t2026-09-05T00:00:00Z\n'
elif [ "$1" = "pr" ] && [ "$2" = "diff" ]; then
    case "$3" in
        941)
            g1='src/star*.sh'
            g2='src/qmark?.sh'
            g3='src/bracket[ab].sh'
            printf 'diff --git a/%s b/%s\n@@\n-a\n+b1\n' "$g1" "$g1"
            printf 'diff --git a/%s b/%s\n@@\n-a\n+b2\n' "$g2" "$g2"
            printf 'diff --git a/%s b/%s\n@@\n-a\n+b3\n' "$g3" "$g3"
            ;;
        942)
            g1='src/star*.sh'
            g2='src/qmark?.sh'
            g3='src/bracket[ab].sh'
            printf 'diff --git a/%s b/%s\n@@\n-a\n+b1\n' "$g1" "$g1"
            printf 'diff --git a/%s b/%s\n@@\n-a\n+b2\n' "$g2" "$g2"
            printf 'diff --git a/%s b/%s\n@@\n-a\n+b3\n' "$g3" "$g3"
            printf 'diff --git a/src/extra.sh b/src/extra.sh\n@@\n-c\n+d\n'
            ;;
    esac
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
    [[ "$output" == *"Closed subset duplicate PR #941 (contained in survivor #942)"* ]]
    [[ "$(actions)" == *"CLOSED 941"* ]]
    [[ "$(actions)" != *"CLOSED 942"* ]]
}

@test "b-slash path component: no crash, consistent handling closes subset" {
    cat <<'MOCK' > "$BATS_TMPDIR/gh"
#!/usr/bin/env bash
if [ "$1" = "pr" ] && [ "$2" = "list" ]; then
    printf '943\t2026-09-01T00:00:00Z\n'
    printf '944\t2026-09-05T00:00:00Z\n'
elif [ "$1" = "pr" ] && [ "$2" = "diff" ]; then
    case "$3" in
        943)
            spfile='src/a b/c.sh'
            printf 'diff --git a/%s b/%s\n@@\n-a\n+b\n' "$spfile" "$spfile"
            ;;
        944)
            spfile='src/a b/c.sh'
            printf 'diff --git a/%s b/%s\n@@\n-a\n+b\n' "$spfile" "$spfile"
            printf 'diff --git a/src/other.sh b/src/other.sh\n@@\n-c\n+d\n'
            ;;
    esac
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
    [[ "$output" == *"Closed subset duplicate PR #943 (contained in survivor #944)"* ]]
    [[ "$(actions)" == *"CLOSED 943"* ]]
    [[ "$(actions)" != *"CLOSED 944"* ]]
}

@test "tabs in filenames: exact duplicates still close without crash" {
    cat <<'MOCK' > "$BATS_TMPDIR/gh"
#!/usr/bin/env bash
if [ "$1" = "pr" ] && [ "$2" = "list" ]; then
    printf '945\t2026-09-01T00:00:00Z\n'
    printf '946\t2026-09-05T00:00:00Z\n'
elif [ "$1" = "pr" ] && [ "$2" = "diff" ]; then
    case "$3" in
        945)
            tabfile=$'src/a\tb.sh'
            printf 'diff --git a/%s b/%s\n@@\n-a\n+b\n' "$tabfile" "$tabfile"
            ;;
        946)
            tabfile=$'src/a\tb.sh'
            printf 'diff --git a/%s b/%s\n@@\n-a\n+b\n' "$tabfile" "$tabfile"
            ;;
    esac
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
    [[ "$output" == *"Closed duplicate PR #945 (exact match, survivor #946)"* ]]
    [[ "$(actions)" == *"CLOSED 945"* ]]
    [[ "$(actions)" != *"CLOSED 946"* ]]
}

@test "threshold boundary: 7 of 10 shared files flags at 0.7" {
    cat <<'MOCK' > "$BATS_TMPDIR/gh"
#!/usr/bin/env bash
if [ "$1" = "pr" ] && [ "$2" = "list" ]; then
    printf '951\t2026-09-01T00:00:00Z\n'
    printf '952\t2026-09-05T00:00:00Z\n'
elif [ "$1" = "pr" ] && [ "$2" = "diff" ]; then
    case "$3" in
        951)
            for f in s1 s2 s3 s4 s5 s6 s7 a1 a2 a3; do
                printf 'diff --git a/src/%s.sh b/src/%s.sh\n@@\n-%s\n+951-%s\n' "$f" "$f" "$f" "$f"
            done
            ;;
        952)
            for f in s1 s2 s3 s4 s5 s6 s7 b1 b2 b3; do
                printf 'diff --git a/src/%s.sh b/src/%s.sh\n@@\n-%s\n+952-%s\n' "$f" "$f" "$f" "$f"
            done
            ;;
    esac
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
    [[ "$output" == *"Flagged PR #951 as superseded-candidate (overlaps #952)"* ]]
    [[ "$(actions)" == *"COMMENTED 951"* ]]
    [[ "$(actions)" == *"LABELED 951"* ]]
    [[ "$(actions)" != *"CLOSED 951"* ]]
}

@test "threshold boundary: 6 of 10 shared files does not flag below 0.7" {
    cat <<'MOCK' > "$BATS_TMPDIR/gh"
#!/usr/bin/env bash
if [ "$1" = "pr" ] && [ "$2" = "list" ]; then
    printf '953\t2026-09-01T00:00:00Z\n'
    printf '954\t2026-09-05T00:00:00Z\n'
elif [ "$1" = "pr" ] && [ "$2" = "diff" ]; then
    case "$3" in
        953)
            for f in s1 s2 s3 s4 s5 s6 a1 a2 a3 a4; do
                printf 'diff --git a/src/%s.sh b/src/%s.sh\n@@\n-%s\n+953-%s\n' "$f" "$f" "$f" "$f"
            done
            ;;
        954)
            for f in s1 s2 s3 s4 s5 s6 b1 b2 b3 b4; do
                printf 'diff --git a/src/%s.sh b/src/%s.sh\n@@\n-%s\n+954-%s\n' "$f" "$f" "$f" "$f"
            done
            ;;
    esac
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
    [[ "$output" == *"Done. closed=0 flagged=0"* ]]
    [[ "$(actions)" == "" ]]
}

@test "dry run subset: reports without mutating" {
    cat <<'MOCK' > "$BATS_TMPDIR/gh"
#!/usr/bin/env bash
if [ "$1" = "pr" ] && [ "$2" = "list" ]; then
    printf '961\t2026-09-01T00:00:00Z\n'
    printf '962\t2026-09-05T00:00:00Z\n'
elif [ "$1" = "pr" ] && [ "$2" = "diff" ]; then
    case "$3" in
        961) printf 'diff --git a/src/a.sh b/src/a.sh\n@@\n-a\n+b\ndiff --git a/src/b.sh b/src/b.sh\n@@\n-b\n+c\n';;
        962) printf 'diff --git a/src/a.sh b/src/a.sh\n@@\n-a\n+b\ndiff --git a/src/b.sh b/src/b.sh\n@@\n-b\n+c\ndiff --git a/src/new.sh b/src/new.sh\n@@\n-n\n+m\n';;
    esac
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
    run env DRY_RUN=true ./scripts/detect-duplicate-prs.sh
    [ "$status" -eq 0 ]
    [[ "$output" == *"[DRY RUN] would close subset duplicate PR #961"* ]]
    [[ "$(actions)" == "" ]]
}

@test "dry run near: reports without mutating" {
    cat <<'MOCK' > "$BATS_TMPDIR/gh"
#!/usr/bin/env bash
if [ "$1" = "pr" ] && [ "$2" = "list" ]; then
    printf '971\t2026-09-01T00:00:00Z\n'
    printf '972\t2026-09-05T00:00:00Z\n'
elif [ "$1" = "pr" ] && [ "$2" = "diff" ]; then
    case "$3" in
        971) printf 'diff --git a/src/feat.sh b/src/feat.sh\n@@\n-a\n+b\n';;
        972) printf 'diff --git a/src/feat.sh b/src/feat.sh\n@@\n-a\n+c\n';;
    esac
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
    run env DRY_RUN=true ./scripts/detect-duplicate-prs.sh
    [ "$status" -eq 0 ]
    [[ "$output" == *"[DRY RUN] would flag PR #971 as superseded by #972"* ]]
    [[ "$(actions)" == "" ]]
}
