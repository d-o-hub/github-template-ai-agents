#!/usr/bin/env bash
# Enforces Maximum Lines of Code (LOC) per file based on AGENTS.md standards.
set -euo pipefail

REPO_ROOT="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
cd "$REPO_ROOT"

# Limits are read, never invented. A hardcoded 150 fallback here silently overrode the
# documented MAX_LINES_AGENTS_MD=200 and failed valid AGENTS.md files.
MAX_SOURCE=''
MAX_SKILL=''
MAX_AGENTS=''

readonly AGENTS_MD_FILE='AGENTS.md'
readonly CONFIG_FILE='.agents/config.sh'

# apply_declared_limits - fill only the limits still unset, so calling it on AGENTS.md
# first gives the documented constants block precedence over .agents/config.sh.
apply_declared_limits() {
    local content="$1" pair var label re
    for pair in 'MAX_SOURCE:MAX_LINES_PER_SOURCE_FILE' \
                'MAX_SKILL:MAX_LINES_PER_SKILL_MD' \
                'MAX_AGENTS:MAX_LINES_AGENTS_MD'; do
        var="${pair%%:*}"
        label="${pair#*:}"
        if [[ -z "${!var}" ]]; then
            re="${label}=([0-9]+)"
            if [[ "$content" =~ $re ]]; then
                printf -v "$var" '%s' "${BASH_REMATCH[1]}"
            fi
        fi
    done
}

# Optimization: native Bash regex matching avoids per-constant grep forks.
if [[ -f "$AGENTS_MD_FILE" ]]; then
    apply_declared_limits "$(<"$AGENTS_MD_FILE")"
fi
if [[ -f "$CONFIG_FILE" ]]; then
    apply_declared_limits "$(<"$CONFIG_FILE")"
fi

FAILED=0

echo "Checking LOC limits..."

# 1. Check AGENTS.md
if [[ -f "$AGENTS_MD_FILE" ]]; then
    if [[ -z "$MAX_AGENTS" ]]; then
        # Undeclared is not "unbounded": say the cap was skipped instead of guessing one.
        echo "WARNING: no MAX_LINES_AGENTS_MD in $AGENTS_MD_FILE or $CONFIG_FILE; skipping the AGENTS.md cap" >&2
    else
        LOC=$(wc -l < "$AGENTS_MD_FILE")
        # Security: Use 10# to force decimal interpretation (handles leading zeros like 08)
        if (( 10#$LOC > 10#$MAX_AGENTS )); then
            echo "ERROR: $AGENTS_MD_FILE has $LOC lines (max $MAX_AGENTS)" >&2
            FAILED=1
        fi
    fi
fi

# 2. Check SKILL.md files
# Optimization: Use xargs wc -l and awk for single-pass validation to avoid per-file process forks
# Note: SKILL.md line count is a WARNING (not failure) to allow pre-existing skills over the limit
if [[ -z "${MAX_SKILL_OVERRIDE:-$MAX_SKILL}" ]]; then
    echo "WARNING: no MAX_LINES_PER_SKILL_MD declared in $AGENTS_MD_FILE or $CONFIG_FILE; skipping the SKILL.md cap" >&2
elif ! find .agents/skills -name "SKILL.md" -not -path "*/node_modules/*" -print0 | \
    xargs -0 wc -l -- | \
    awk -v max="${MAX_SKILL_OVERRIDE:-$MAX_SKILL}" -- '
    BEGIN { warn = 0; if (max ~ /^0[0-9]+/) max = substr(max, 2) }
    $NF == "total" { next }
    $1 + 0 > max + 0 {
        count = $1
        $1 = ""
        sub(/^[[:space:]]+/, "")
        print "WARNING: " $0 " has " count " lines (max " max ")"
        warn = 1
    }
    END { if (warn) exit(0) }'; then
    :
fi

# 3. Check source files (excluding common artifacts and ignored dirs)
# Targeted extensions: .py, .rs, .ts, .js, .go, .sh
# Optimization: Batch processing with xargs and awk for ~10x performance gain
# Exclude: .git, target, node_modules (at any level), dist, build, .agents/skills
#
# Enumeration stays filesystem-based rather than `git ls-files`: this gate must
# also run in plain directories (the LOC tests copy it into a non-repo tmpdir).
# On top of the fixed list, git-ignored paths are subtracted so that ignored
# tool/session/cache dirs cannot fail a repository's own gate. Tracked files are
# unreachable here because --others only reports paths absent from the index.
PRUNE_ARGS=()
if git rev-parse --is-inside-work-tree >/dev/null 2>&1; then
    while IFS= read -r -d '' ignored_path; do
        if [[ "$ignored_path" == */ ]]; then
            PRUNE_ARGS+=(-not -path "./${ignored_path}*")
        else
            PRUNE_ARGS+=(-not -path "./${ignored_path}")
        fi
    done < <(git ls-files --others --ignored --exclude-standard --directory -z 2>/dev/null || true)
fi

if [[ -z "${MAX_SOURCE_OVERRIDE:-$MAX_SOURCE}" ]]; then
    echo "WARNING: no MAX_LINES_PER_SOURCE_FILE declared in $AGENTS_MD_FILE or $CONFIG_FILE; skipping the source cap" >&2
elif ! find . -type f \( -name "*.py" -o -name "*.rs" -o -name "*.ts" -o -name "*.js" -o -name "*.go" -o -name "*.sh" \) \
    -not -path "./.git/*" \
    -not -path "./target/*" \
    -not -path "*/node_modules/*" \
    -not -path "./dist/*" \
    -not -path "./build/*" \
    -not -path "./.agents/skills/*" \
    "${PRUNE_ARGS[@]+"${PRUNE_ARGS[@]}"}" -print0 | \
    xargs -0 wc -l -- | \
    awk -v max="${MAX_SOURCE_OVERRIDE:-$MAX_SOURCE}" -- '
    BEGIN { err = 0; if (max ~ /^0[0-9]+/) max = substr(max, 2) }
    $NF == "total" { next }
    $1 + 0 > max + 0 {
        count = $1
        $1 = ""
        sub(/^[[:space:]]+/, "")
        print "ERROR: " $0 " has " count " lines (max " max ")"
        err = 1
    }
    END { if (err) exit(err) }'; then
    FAILED=1
fi

if [[ $FAILED -ne 0 ]]; then
    echo "LOC check failed."
    exit 1
fi

echo "LOC check passed."
exit 0
