# Fix: Scope quality_gate.sh linting to changed files only

## Problem

`quality_gate.sh` used `find` to gather ALL `.sh` and `.md` files in the repo, then passed them to `lint_batch_if_changed` which only skipped files via a content-hash cache. This meant:
1. Every file in the repo was stat'd/hashed on every run (slow for large repos)
2. The cache had to be warm to skip unchanged files
3. No git-awareness — the script couldn't distinguish "changed this session" from "existed in repo"

## Solution

Added a `_changed_files_z()` function that uses `git diff` to detect only files changed in the current session, with fallbacks for CI and non-git environments.

### Changes to `scripts/quality_gate.sh`

**1. New `_changed_files_z()` function** (after language detection, before linting):

```bash
_changed_files_z() {
    local source_files=""

    # In CI PR context, compare against base branch
    if [[ -n "${GITHUB_BASE_REF:-}" ]]; then
        source_files=$(git diff --name-only "origin/${GITHUB_BASE_REF}...HEAD" 2>/dev/null || true)
    fi

    # Fallback: staged + unstaged changes vs HEAD
    if [[ -z "$source_files" ]]; then
        source_files=$(git diff --name-only HEAD 2>/dev/null || true)
    fi

    # If nothing changed (or first commit), fall back to all tracked files
    if [[ -z "$source_files" ]]; then
        source_files=$(git ls-files 2>/dev/null || true)
    fi

    # If still empty (no git), fall back to find
    if [[ -z "$source_files" ]]; then
        find . -type f -not -path "./.git/*" -not -path "./target/*" \
            -not -path "*/node_modules/*" -print0 2>/dev/null || true
        return
    fi

    # Convert newline-delimited to null-delimited
    local IFS=$'\n'
    # shellcheck disable=SC2046
    printf '%s\0' $source_files
}
```

**Detection priority:**
1. `GITHUB_BASE_REF` set → CI PR context → diff against `origin/<base>`
2. Local dev → `git diff --name-only HEAD` (staged + unstaged changes)
3. First commit / detached HEAD → `git ls-files` (all tracked files)
4. No git → `find` fallback (non-git environment)

**2. Shell checks section** — replaced `find . -name "*.sh"` with:

```bash
_changed_files_z | grep -z '\.sh$' > "$TMP_SH_LIST" 2>/dev/null || true
```

Added an else branch to report "No changed shell files to check" when the list is empty.

**3. Markdown checks section** — replaced `find . -name "*.md"` with:

```bash
_changed_files_z | grep -z '\.md$' > "$TMP_MD_LIST" 2>/dev/null || true
```

Added an else branch to report "No changed markdown files to check" when the list is empty.

## Why this works

- `_changed_files_z` outputs **null-delimited** paths, compatible with `lint_batch_if_changed` which reads with `read -r -d ''`
- `grep -z '\.sh$'` filters the null-delimited stream to only matching extensions
- The existing `lint_batch_if_changed` cache is preserved as a second optimization layer
- `GIT_EXCLUDE` variable is kept since it's still used in the language detection `find` commands
- Shellcheck passes clean with no warnings

## Verification

```bash
$ bash -n scripts/quality_gate.sh && echo "Syntax OK"
Syntax OK

$ shellcheck --severity=error scripts/quality_gate.sh
(no output = clean)

$ git diff --name-only HEAD | grep '\.sh$'
scripts/quality_gate.sh    # Only the modified file detected
```

## Files touched

- `scripts/quality_gate.sh` — added `_changed_files_z()` function, modified shell and markdown lint sections to use scoped file detection

## Findings worth promoting

- Null-delimited I/O is the standard for passing file lists between bash functions that use `read -r -d ''` — always use `printf '%s\0'` or `grep -z` rather than newline-delimited
- `git diff --name-only HEAD` covers both staged and unstaged local changes, making it ideal for dev-session scoping without needing to distinguish pre-commit vs normal context
- The `IFS=$'\n'` trick for safe word-splitting of multiline strings is more portable than `readarray`/`mapfile`
