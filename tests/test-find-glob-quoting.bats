#!/usr/bin/env bats
# BATS regression guard: unquoted globs in `find -path` / `find -name` patterns.
#
# Background: scripts/generate-skills-reference.sh originally had
#   ! -path "$SKILLS_DIR"/_*/* -print0
# where only $SKILLS_DIR was quoted. The /_*/* suffix sat outside the quotes,
# so the shell could glob-expand it against the working directory before find
# ever saw the literal pattern, silently changing the exclude logic
# (Codacy/ShellCheck finding; fixed in commit 0df4cd5). This guard fails any
# repo shell script that repeats the pattern: a -path/-name argument whose
# glob metacharacters are not fully inside quotes.
#
# Scope: shell scripts (*.sh) and BATS tests (*.bats). Workflow `run:` blocks
# are separately covered by the workflow lint/actionlint checks in CI.

setup() {
    REPO_ROOT="$(cd "$(dirname "$BATS_TEST_FILENAME")/.." && pwd)"
}

# has_unquoted_glob <token>
# Returns 0 if <token> has a glob metacharacter (*, ?, [) outside any quote
# pair; returns 1 if every glob is quoted or there are no globs. Handles
# single/double quotes and backslash escapes.
has_unquoted_glob() {
    local tok="$1"
    local c quote=""
    local -i i n=${#tok}
    for ((i = 0; i < n; i++)); do
        c="${tok:i:1}"
        if [ -n "$quote" ]; then
            if [ "$c" = "$quote" ]; then
                quote=""
            elif [ "$quote" = '"' ] && [ "$c" = '\' ]; then
                # skip the character escaped inside double quotes
                i=$((i + 1))
            fi
            continue
        fi
        if [ "$c" = "'" ] || [ "$c" = '"' ]; then
            quote="$c"
        elif [ "$c" = '\' ]; then
            # skip a backslash-escaped character outside quotes
            i=$((i + 1))
        elif [ "$c" = '*' ] || [ "$c" = '?' ] || [ "$c" = '[' ]; then
            return 0
        fi
    done
    return 1
}

# scan_find_patterns <file>
# Prints "<file>:<line>: <token>" for every unquoted -path/-name glob token.
# Backslash continuations are joined into logical lines first. Returns 0 when
# the file is clean, 1 when a violation was printed.
scan_find_patterns() {
    local file="$1"
    local logical="" next_line="" tok prev=""
    local -a words=()
    local -i ln=0 flagged=0
    while IFS= read -r next_line || [ -n "$next_line" ]; do
        ln=$((ln + 1))
        next_line="${next_line%$'\r'}"
        next_line="${next_line#"${next_line%%[![:space:]]*}"}"
        next_line="${next_line%"${next_line##*[![:space:]]}"}"
        if [ -n "$logical" ]; then
            logical="$logical $next_line"
        else
            logical="$next_line"
        fi
        if [[ "$logical" == *\\ ]]; then
            # backslash continuation: drop it and keep joining
            logical="${logical%\\}"
            continue
        fi
        # Skip comment-only lines (not executed shell).
        if [[ "$logical" != \#* ]] &&
            [[ "$logical" == *"find"* ]] &&
            [[ "$logical" == *"-path"* || "$logical" == *"-name"* ]]; then
            words=()
            read -r -a words <<< "$logical"
            prev=""
            for tok in "${words[@]}"; do
                if [ "$prev" = "-path" ] || [ "$prev" = "-name" ]; then
                    if has_unquoted_glob "$tok"; then
                        printf '%s:%s: %s\n' "$file" "$ln" "$tok"
                        flagged=1
                    fi
                fi
                prev="$tok"
            done
        fi
        logical=""
    done < "$file"
    [ "$flagged" -eq 0 ]
}

@test "repo shell scripts have no unquoted find -path/-name glob patterns" {
    local f out
    local -a failures=()
    while IFS= read -r -d '' f; do
        out=$(scan_find_patterns "$f") || true
        if [ -n "$out" ]; then
            failures+=("$out")
        fi
    done < <(find "$REPO_ROOT" -type f \
        \( -name '*.sh' -o -name '*.bats' \) \
        -not -path '*/.git/*' \
        -not -path '*/node_modules/*' \
        -print0)
    if [ "${#failures[@]}" -gt 0 ]; then
        printf 'Unquoted find pattern(s) found (quote the whole -path/-name argument):\n'
        printf '%s\n' "${failures[@]}"
        return 1
    fi
}

@test "detector flags an unquoted glob suffix (regression case)" {
    local tmp="$BATS_TEST_TMPDIR/unquoted"
    local prefix
    mkdir -p "$tmp"
    # Build the offending pattern from parts so this file does not contain the
    # literal bug: the repo-wide scan above includes this test file itself.
    prefix='-path "$SKILLS_DIR"'
    prefix="${prefix}/_*/*"
    printf '%s\n' \
        '#!/usr/bin/env bash' \
        "$(printf 'f')ind . ${prefix} -print0" \
        > "$tmp/bad.sh"
    run scan_find_patterns "$tmp/bad.sh"
    [ "$status" -eq 1 ]
    [[ "$output" == *"bad.sh:"* ]]
    [[ "$output" == *'"$SKILLS_DIR"/_*/*'* ]]
}

@test "detector accepts fully quoted and glob-free patterns" {
    local tmp="$BATS_TEST_TMPDIR/quoted"
    mkdir -p "$tmp"
    cat > "$tmp/good.sh" <<'EOF'
#!/usr/bin/env bash
find . -type f -name "*.md" -not -path "$SKILLS_DIR/_*/*" -print0
find . -type d -name '*.cache' -prune
find . -name SKILL.md -print
EOF
    run scan_find_patterns "$tmp/good.sh"
    [ "$status" -eq 0 ]
    [ -z "$output" ]
}
