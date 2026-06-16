#!/usr/bin/env bash
# analyze-codebase.sh - Autonomous codebase analysis and self-learning
#
# Performs real (non-stub) checks across the repository:
#   1. TODO/FIXME/XXX/HACK density
#   2. Orphan cache detection (tracked build artifacts that should be gitignored)
#   3. Skill health summary (frontmatter, version field, category)
#   4. Required-files presence (.agents/skills, AGENTS.md, plans/, etc.)
#   5. Tracking-state freshness (.commandcode/taste/, .mimocode/)
#
# Output:
#   - Human-readable summary on stdout
#   - Machine-readable Markdown report at reports/codebase-analysis-<date>.md
#
# Exit codes:
#   0 = clean (or warnings only)
#   1 = at least one error detected
#
# Source-of-truth constants come from .agents/config.sh.
set -uo pipefail

REPO_ROOT="${REPO_ROOT:-$(cd "$(dirname "${BATS_SOURCE[0]:-${0}}")/.." 2>/dev/null && pwd)}"
if [[ -z "${REPO_ROOT}" || ! -d "$REPO_ROOT/.agents" ]]; then
    REPO_ROOT="$(pwd)"
fi

CONFIG="$REPO_ROOT/.agents/config.sh"
if [[ -f "$CONFIG" ]]; then
    # shellcheck disable=SC1090
    source "$CONFIG"
fi

REPORTS_DIR="$REPO_ROOT/reports"
DATE="$(date -u +%Y-%m-%d)"
REPORT_FILE="$REPORTS_DIR/codebase-analysis-${DATE}.md"

FIX_MODE=false
VERBOSE=false
FAILED=0
WARNINGS=0

usage() {
    cat <<'EOF'
Usage: ./scripts/analyze-codebase.sh [OPTIONS]

Options:
  --fix      Apply automated fixes where safe (creates .gitignore entries, etc.)
  --verbose  Print every detection to stdout
  -h, --help Show this help

Exit codes:
  0  No errors (warnings allowed)
  1  One or more errors detected
EOF
}

while [[ $# -gt 0 ]]; do
    case "$1" in
        --fix) FIX_MODE=true; shift ;;
        --verbose) VERBOSE=true; shift ;;
        -h|--help) usage; exit 0 ;;
        *) usage >&2; exit 2 ;;
    esac
done

cd "$REPO_ROOT" || exit 1

log()      { printf '  %s\n' "$*"; }
section()  { printf '\n%s\n' "== $* =="; }
ok()       { printf '  \u2713 %s\n' "$*"; }
warn()     { printf '  ! %s\n' "$*"; WARNINGS=$((WARNINGS + 1)); }
fail()     { printf '  \u2717 %s\n' "$*" >&2; FAILED=$((FAILED + 1)); }

# --- 1. TODO/FIXME density ---
check_todo_density() {
    section "TODO/FIXME density"
    local pattern='(TODO|FIXME|XXX|HACK)\b'
    local file_count
    file_count=$(grep -RIl --exclude-dir=.git --exclude-dir=node_modules \
        --exclude-dir=target --exclude-dir=dist --exclude-dir=build \
        --exclude='*.lock' --exclude='*.min.js' \
        -E "$pattern" . 2>/dev/null | wc -l)

    if [[ "$file_count" -eq 0 ]]; then
        ok "No TODO/FIXME markers found"
        return
    fi

    local marker_count
    marker_count=$(grep -RI --exclude-dir=.git --exclude-dir=node_modules \
        --exclude-dir=target --exclude-dir=dist --exclude-dir=build \
        --exclude='*.lock' --exclude='*.min.js' \
        -E "$pattern" . 2>/dev/null | wc -l)

    warn "$marker_count TODO/FIXME marker(s) across $file_count file(s)"

    if [[ "$VERBOSE" == "true" ]]; then
        grep -RIl --exclude-dir=.git --exclude-dir=node_modules \
            --exclude-dir=target --exclude-dir=dist --exclude-dir=build \
            -E "$pattern" . 2>/dev/null | head -20 | sed 's/^/    /'
    fi
}

# --- 2. Orphan cache detection ---
check_orphan_cache() {
    section "Orphan cache detection"
    local tracked
    tracked=$(git ls-files 2>/dev/null | grep -E '\.(pyc|pyo|o|obj|class)$|\.DS_Store$|Thumbs\.db$' || true)

    if [[ -z "$tracked" ]]; then
        ok "No tracked build artifacts or OS files"
        return
    fi

    fail "Tracked cache/OS files detected ($(printf '%s\n' "$tracked" | wc -l)):"
    printf '%s\n' "$tracked" | sed 's/^/    /'

    if [[ "$FIX_MODE" == "true" && -f .gitignore ]]; then
        local additions=()
        local f
        while IFS= read -r f; do
            [[ -z "$f" ]] && continue
            case "$f" in
                *.pyc|*.pyo)
                    [[ " ${additions[*]:-} " == *" *.pyc "* ]] || additions+=("*.pyc")
                    ;;
                *.o|*.obj|*.class) additions+=("*.o") ;;
                .DS_Store) additions+=(".DS_Store") ;;
                Thumbs.db) additions+=("Thumbs.db") ;;
            esac
        done <<< "$tracked"
        local pat
        for pat in "${additions[@]:-}"; do
            if ! grep -qxF "$pat" .gitignore 2>/dev/null; then
                printf '%s\n' "$pat" >> .gitignore
                log "  added '$pat' to .gitignore"
            fi
        done
    fi
}

# --- 3. Skill health summary ---
check_skill_health() {
    section "Skill health"
    if [[ ! -d .agents/skills ]]; then
        fail ".agents/skills directory missing"
        return
    fi

    local total=0
    local with_version=0
    local with_license=0
    local missing_desc=0

    shopt -s nullglob
    for f in .agents/skills/*/SKILL.md; do
        [[ -L "$f" ]] && continue
        total=$((total + 1))
        grep -q '^version:' "$f" 2>/dev/null && with_version=$((with_version + 1))
        grep -q '^license:' "$f" 2>/dev/null && with_license=$((with_license + 1))
        grep -q '^description:' "$f" 2>/dev/null || missing_desc=$((missing_desc + 1))
    done
    shopt -u nullglob

    log "  total skills:   $total"
    log "  with version:   $with_version"
    log "  with license:   $with_license"

    if [[ "$missing_desc" -gt 0 ]]; then
        fail "$missing_desc skill(s) missing required description field"
    else
        ok "all skills have description"
    fi
}

# --- 4. Required files present ---
check_required_files() {
    section "Required files"
    local required=(AGENTS.md ".agents/skills" "agents-docs" plans scripts .github)
    local miss=0
    for entry in "${required[@]}"; do
        if [[ -e "$entry" ]]; then
            ok "$entry present"
        else
            fail "$entry missing"
            miss=$((miss + 1))
        fi
    done
    if [[ "$miss" -eq 0 ]]; then
        ok "all required files/directories present"
    fi
}

# --- 5. Tracking-state freshness ---
check_tracking_state() {
    section "Tracking state"
    if [[ -d .commandcode ]]; then
        local taste_files
        taste_files=$(find .commandcode -type f 2>/dev/null | wc -l)
        log "  .commandcode: $taste_files file(s)"
    else
        warn ".commandcode/ missing (taste/learnings state)"
    fi
    if [[ -d .mimocode ]]; then
        local mim_files
        mim_files=$(find .mimocode -type f 2>/dev/null | wc -l)
        log "  .mimocode: $mim_files file(s)"
    else
        warn ".mimocode/ missing"
    fi
}

# --- Write report ---
write_report() {
    mkdir -p "$REPORTS_DIR"
    {
        printf '# Codebase Analysis — %s\n\n' "$DATE"
        printf '> Generated by `./scripts/analyze-codebase.sh`\n\n'
        printf '## Summary\n\n'
        printf -- '- Errors:   %d\n' "$FAILED"
        printf -- '- Warnings: %d\n' "$WARNINGS"
        printf '\n## Checks\n\n'
        printf 'See the human-readable output for full details.\n'
    } > "$REPORT_FILE"
    log ""
    log "Report written to ${REPORT_FILE#$REPO_ROOT/}"
}

main() {
    log "Codebase analysis (date: $DATE)"
    check_required_files
    check_skill_health
    check_todo_density
    check_orphan_cache
    check_tracking_state
    write_report

    log ""
    if [[ "$FAILED" -ne 0 ]]; then
        printf '\u2717 Analysis: %d error(s), %d warning(s)\n' "$FAILED" "$WARNINGS" >&2
        exit 1
    fi
    printf '\u2713 Analysis: 0 errors, %d warning(s)\n' "$WARNINGS"
}

main
