#!/usr/bin/env bash
# Normalize non-conventional commit messages in a range.
# Use this after pulling a Jules session branch and before pushing a PR.
# Usage: normalize-commits.sh --from <base> --to <head> [--type <type>] [--scope <scope>] [--dry-run]
set -euo pipefail

TYPE=""
SCOPE=""
FROM_REF=""
TO_REF="HEAD"
DRY_RUN=false
BODY_MAX=100

usage() {
    printf 'Usage: %s --from <base> --to <head> [--type <type>] [--scope <scope>] [--dry-run]\n' "${0##*/}" >&2
    exit 1
}

while [[ $# -gt 0 ]]; do
    case $1 in
        --type)   TYPE="$2"; shift 2 ;;
        --scope)  SCOPE="$2"; shift 2 ;;
        --from)   FROM_REF="$2"; shift 2 ;;
        --to)     TO_REF="$2"; shift 2 ;;
        --dry-run) DRY_RUN=true; shift ;;
        -h|--help) usage ;;
        *) printf 'Unknown option: %s\n' "$1" >&2; usage ;;
    esac
done

if [[ -z "$FROM_REF" ]] || [[ -z "$TYPE" ]]; then
    usage
fi

if ! git rev-parse --verify --quiet "$FROM_REF^{commit}" >/dev/null; then
    printf 'Error: --from ref %s is not a valid commit\n' "$FROM_REF" >&2
    exit 1
fi
if ! git rev-parse --verify --quiet "$TO_REF^{commit}" >/dev/null; then
    printf 'Error: --to ref %s is not a valid commit\n' "$TO_REF" >&2
    exit 1
fi

if [[ -n "$SCOPE" ]]; then
    PREFIX="${TYPE}(${SCOPE})"
else
    PREFIX="${TYPE}"
fi

CONVENTIONAL_RE='^(feat|fix|docs|style|refactor|perf|test|ci|chore)(\([a-z0-9-]+\))?!?:\ .{1,150}$'

TMP_DIR=$(mktemp -d)
trap 'rm -rf "$TMP_DIR"' EXIT

REPORT="$TMP_DIR/non-conventional.txt"
: > "$REPORT"

mapfile -t COMMITS < <(git rev-list --reverse "$FROM_REF..$TO_REF")

if [[ ${#COMMITS[@]} -eq 0 ]]; then
    printf 'No commits in range %s..%s\n' "$FROM_REF" "$TO_REF"
    exit 0
fi

printf 'Checking %d commit(s) in %s..%s\n' "${#COMMITS[@]}" "$FROM_REF" "$TO_REF"

NEEDS_FIX=0
for sha in "${COMMITS[@]}"; do
    SUBJECT=$(git log -1 --pretty=%s "$sha")
    SHORT=${sha:0:8}
    if [[ "$SUBJECT" =~ $CONVENTIONAL_RE ]]; then
        printf '  ok  %s %s\n' "$SHORT" "$SUBJECT"
        continue
    fi
    NEEDS_FIX=$((NEEDS_FIX + 1))
    BODY=$(git log -1 --pretty=%b "$sha")
    printf '  bad %s %s\n' "$SHORT" "$SUBJECT" | tee -a "$REPORT" >/dev/null
    if [[ -n "$BODY" ]]; then
        printf '%s\n' "$BODY" | head -3 | sed 's/^/        /' | tee -a "$REPORT" >/dev/null
    fi
done

if [[ $NEEDS_FIX -eq 0 ]]; then
    printf '\nAll commits already conventional. Nothing to do.\n'
    exit 0
fi

printf '\n%d non-conventional commit(s) found.\n' "$NEEDS_FIX"

if $DRY_RUN; then
    printf '\n--dry-run: would rewrite with prefix "%s: " and truncate subjects to 72 chars.\n' "$PREFIX"
    exit 0
fi

printf '\nRewriting history with filter-branch...\n'
printf 'This rewrites SHAs in %s..%s. Make sure the branch is not protected.\n' "$FROM_REF" "$TO_REF"

if ! command -v python3 >/dev/null 2>&1; then
    printf 'Error: python3 is required for filter-branch (no inline shell eval).\n' >&2
    printf 'Install python3 or run manually with git rebase -i.\n' >&2
    exit 1
fi

FILTER_SCRIPT="$TMP_DIR/filter.py"
cat > "$FILTER_SCRIPT" <<PYEOF
import sys, re

PREFIX = "${PREFIX}: "
BODY_MAX = ${BODY_MAX}
CONV = re.compile(r"^(feat|fix|docs|style|refactor|perf|test|ci|chore)(\([a-z0-9-]+\))?!?: .{1,150}$")

body = sys.stdin.read()
lines = body.split("\n")
subject = lines[0] if lines else ""
rest = lines[1:]

if CONV.match(subject):
    sys.stdout.write(body)
    sys.exit(0)

clean = re.sub(r"\s+", " ", subject).strip(" .")
if not clean:
    clean = "normalize non-conventional commit"
if len(clean) > 72:
    cut = clean[:72]
    if " " in cut:
        cut = cut.rsplit(" ", 1)[0]
    clean = cut

new_subject = PREFIX + clean
out = [new_subject]
for line in rest:
    line = line.rstrip()
    if not line:
        out.append("")
        continue
    if len(line) > BODY_MAX:
        chunks = []
        while len(line) > BODY_MAX:
            cut = line[:BODY_MAX]
            if " " in cut:
                cut = cut.rsplit(" ", 1)[0]
            chunks.append(cut)
            line = line[len(cut):].lstrip()
        if line:
            chunks.append(line)
        out.extend(chunks)
    else:
        out.append(line)

sys.stdout.write("\n".join(out).rstrip("\n") + "\n")
PYEOF

FILTER_BRANCH_SQUELCH_WARNING=1 git filter-branch -f --msg-filter "python3 $FILTER_SCRIPT" -- "$FROM_REF..$TO_REF"

printf '\nDone. Validate with:\n'
printf '  ./scripts/validate-commit-message.sh <(git log -1 --pretty=%%B)\n'
printf '\nThen force-push (Jules session branches only):\n'
printf '  git push --force-with-lease origin <branch>\n'
