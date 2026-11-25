#!/usr/bin/env bash
# ============================================================================
# check-forbidden-paths.sh — Fail-closed guard against committing paths the
# forbidden-path vocabulary names (scripts/lib/paths.py).
#
# Credentials that must never enter a commit (.env variants, sops files,
# service-account keys, SSH keys, database histories, state/backup files) do
# enter them: an agent (or a person) stages a file locally and nothing between
# "git add" and "git commit" ever looks at the *name*. This guard reads each
# changed path and fails the changeset when the path's file name matches the
# shared forbidden/sensitive vocabulary.
#
# Vocabulary + matching semantics: scripts/lib/paths.py — imported at runtime,
# never duplicated here. A file name is forbidden when (paths.py rules,
# case-insensitive):
#   * it is in FORBIDDEN_PATHS            (`.env`, `.sops.yaml`, `id_rsa`, …)
#   * it starts with a SENSITIVE_PREFIX   (`.env*`, `service_account*`, `token*`, …)
#   * it ends with a SENSITIVE_SUFFIX     (`*.pem`, `*.tfstate`, `credentials.json`, …)
#   * it starts with an SSH_KEY_PREFIX and is not a `.pub` public key
#
# The decision applies to the changed path's FILE NAME (leaf), not to every
# path component. paths.py itself applies these arms per component
# (`validate_safe_path`), but FORBIDDEN_PATHS also names framework directory
# words (`scripts`, `.claude`, `agents-docs`, `plans`, …) and its own comments
# document why prefix matching must not reach curated trees
# (`.agents/skills/secrets-management` trips the `secret` prefix); a
# per-component commit guard would flag every infrastructure commit this
# repository makes — including the commits that add this guard. Leaf-level
# application keeps every credential class above blocked at any depth while
# leaving the template's own directory layout commitable.
#
# Strictness is deliberate: names the vocabulary forbids fail even when a
# match looks routine (`.gitignore`, `VERSION`, `package.json` edits). The
# guard is the stop sign, the reviewer decides. There is no skip variable by
# design; a change that genuinely must commit a forbidden name needs a human
# decision (see `scripts/AGENTS.md` "Protected Scripts" for the same spirit).
#
# Changed-file semantics mirror scripts/lib/lang-checks.sh `_changed_files_z`:
#   * a commit is pending (staged changes exist): staged files only — the
#     commit is the guarded object, unstaged files are not entering it
#   * otherwise: working tree vs HEAD plus untracked files, so a forbidden
#     path is caught before it is ever staged
#   * CI (`GITHUB_BASE_REF`): the PR's base-branch comparison
#   * `--diff-filter=d` everywhere: deleting a forbidden path is a
#     remediation, not a violation
#
# Exit codes:
#   0  pass (nothing forbidden, or nothing changed)
#   1  violation found, or fail-closed input (vocabulary missing/empty/
#      unimportable, git failing on a live work tree)
#   3  the guard cannot legitimately run (python3 missing — the vocabulary
#      cannot be consumed; or no git work tree — there is no changeset to
#      guard). quality_gate.sh maps this to a visible skip.
# ============================================================================

set -euo pipefail

REPO_ROOT="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
VOCAB_FILE="$REPO_ROOT/scripts/lib/paths.py"

cd "$REPO_ROOT"

# --- Fail-closed and skip entries -------------------------------------------

fail_closed() {
    printf '  ✗ %s\n' "$1" >&2
    printf '    (fail closed: %s)\n' "$2" >&2
    exit 1
}

skip_entry() {
    printf '  ⚠ skipped %s: %s\n' "$1" "$2" >&2
    exit 3
}

# --- Guarded inputs ----------------------------------------------------------

# The vocabulary is the single source of forbidden names. A missing file is a
# vanished vocabulary and must not read as a pass.
if [[ ! -f "$VOCAB_FILE" ]]; then
    fail_closed "forbidden-path vocabulary missing: scripts/lib/paths.py" \
        "no vocabulary means no protection"
fi

if ! command -v python3 &>/dev/null; then
    skip_entry "forbidden-path check" "python3 is not installed (cannot consume scripts/lib/paths.py)"
fi

if ! git rev-parse --is-inside-work-tree &>/dev/null; then
    skip_entry "forbidden-path check" "not inside a git work tree (no changeset to guard)"
fi

# --- Changed-file collection (mirrors lib/lang-checks.sh) -------------------

changed_raw=""

collect_or_fail() {
    local desc="$1"
    shift
    local out
    out=""
    if ! out=$("$@" 2>/dev/null); then
        fail_closed "git could not enumerate ${desc}" "a guarded repository must be observable"
    fi
    printf '%s\n' "$out"
}

if [[ -n "${GITHUB_BASE_REF:-}" ]]; then
    # CI: the changeset is the PR diff, as in lang-checks.sh.
    changed_raw=$(collect_or_fail "diff against origin/${GITHUB_BASE_REF}...HEAD" \
        git diff --name-only --diff-filter=d "origin/${GITHUB_BASE_REF}...HEAD")
else
    git diff --cached --quiet &>/dev/null && staged_rc=0 || staged_rc=$?
    if (( staged_rc > 1 )); then
        fail_closed "git diff --cached failed (status ${staged_rc})" \
            "the staged set is the guarded object"
    fi
    if (( staged_rc == 1 )); then
        # A commit is pending: the staged files are exactly what will be
        # committed, so the guard reads only them (--diff-filter=d drops
        # staged deletions).
        changed_raw=$(collect_or_fail "staged files" \
            git diff --cached --name-only --diff-filter=d)
    else
        # No pending commit: guard the working tree vs HEAD, plus untracked
        # files so a forbidden path fails before it is ever staged.
        changed_raw="$(collect_or_fail "diff vs HEAD" git diff --name-only --diff-filter=d HEAD)
$(collect_or_fail "untracked files" git ls-files --others --exclude-standard)"
    fi
fi

mapfile -t changed_files < <(printf '%s\n' "$changed_raw" | LC_ALL=C sort -u | grep -v '^$' || true)

# --- Vocabulary check -------------------------------------------------------
# The file list travels through a temp file (not argv) so an arbitrarily large
# diff cannot hit ARG_MAX; the program arrives on stdin, so no -c quoting
# gymnastics are needed. Findings also land in a temp file rather than a
# `$( ... )` capture: an `|| rc=$?` inside the substitution would set the
# status in the subshell only and a crashed python would silently read as a
# pass (SC2030/SC2031, the same false-green class as LESSON "subshell VAR+=").
# Python always runs — even with an empty changeset — so the vocabulary is
# validated on every invocation: a vanished/empty vocabulary fails closed
# rather than passing behind a "nothing changed" shortcut. Python writes
# findings as `path<TAB>rule<TAB>token`; exit 2 = vocabulary problem and is
# fail-closed here.

paths_tmp=$(mktemp)
findings_tmp=$(mktemp)
trap 'rm -f "$paths_tmp" "$findings_tmp"' EXIT
printf '%s\n' "${changed_files[@]}" > "$paths_tmp"

py_rc=0
python3 - "$VOCAB_FILE" "$paths_tmp" > "$findings_tmp" <<'PY' || py_rc=$?
import importlib.util
import os
import sys

vocab_path, paths_path = sys.argv[1], sys.argv[2]

spec = importlib.util.spec_from_file_location("gate_forbidden_vocab", vocab_path)
if spec is None or spec.loader is None:
    print(f"VOCAB_ERROR: cannot build import spec for {vocab_path}")
    sys.exit(2)
module = importlib.util.module_from_spec(spec)
try:
    spec.loader.exec_module(module)
except Exception as exc:  # noqa: BLE001 - any import failure is fail-closed
    print(f"VOCAB_ERROR: cannot import {vocab_path}: {exc}")
    sys.exit(2)

def load(name):
    value = getattr(module, name, None)
    if not value:
        # An empty or absent exported name is a vanished vocabulary: the
        # guard must fail closed rather than check against nothing.
        print(f"VOCAB_ERROR: vocabulary yielded no '{name}' in {vocab_path}")
        sys.exit(2)
    return value

forbidden = load("FORBIDDEN_PATHS_LOWER")
prefixes = tuple(load("SENSITIVE_PREFIXES"))
suffixes = tuple(load("SENSITIVE_SUFFIXES"))
ssh_prefixes = tuple(load("SSH_KEY_PREFIXES"))

with open(paths_path, "r", encoding="utf-8", errors="replace") as handle:
    paths = [line.rstrip("\n") for line in handle if line.strip()]

for path in paths:
    name = os.path.basename(path).lower()
    if name in forbidden:
        print(f"{path}\tforbidden path\t{name}")
        continue
    for prefix in prefixes:
        if name.startswith(prefix):
            print(f"{path}\tsensitive prefix\t{prefix}")
            break
    else:
        for suffix in suffixes:
            if name.endswith(suffix):
                print(f"{path}\tsensitive suffix\t{suffix}")
                break
        else:
            if not name.endswith(".pub"):
                for prefix in ssh_prefixes:
                    if name.startswith(prefix):
                        print(f"{path}\tssh key prefix\t{prefix}")
                        break
sys.exit(0)
PY

if (( py_rc == 2 )); then
    fail_closed "the forbidden-path vocabulary failed to load: $(head -1 "$findings_tmp")" \
        "a vanished vocabulary must not read as a pass"
elif (( py_rc != 0 )); then
    fail_closed "vocabulary check crashed (python exit ${py_rc})" \
        "the guard cannot verify the changeset, so it does not pass"
fi

# --- Verdict ----------------------------------------------------------------

if ((${#changed_files[@]} == 0)); then
    # The vocabulary was validated above; an empty changeset has nothing to
    # guard, which is a genuine pass rather than a skipped check.
    printf '  ✓ No changed files to check (nothing staged, modified, or untracked)\n'
    exit 0
fi

if [[ ! -s "$findings_tmp" ]]; then
    printf '  ✓ %d changed file(s) clean against the forbidden-path vocabulary\n' \
        "${#changed_files[@]}"
    exit 0
fi

violation_count=0
printf '  ✗ forbidden or sensitive path(s) in the changeset:\n'
while IFS=$'\t' read -r path rule token || [[ -n "$path" ]]; do
    printf '    %s — file name matches %s (rule: %s)\n' "$path" "$token" "$rule"
    violation_count=$((violation_count + 1))
done < "$findings_tmp"
printf '  %d violation(s). Names come from scripts/lib/paths.py: remove the\n' \
    "$violation_count"
printf '  file from the changeset, or stop this commit and review why the\n'
printf '  forbidden/sensitive path is entering the repository.\n'
exit 1
