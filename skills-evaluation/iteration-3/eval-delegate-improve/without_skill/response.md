# How quality_gate.sh Scopes Linting to Changed Files

## Overview

The scoping pipeline has three stages: (1) get changed files, (2) filter by language extension, (3) pass through a lint cache to skip unchanged files. Here's the full walkthrough.

---

## Stage 1: `_changed_files_z()` — Determine the Set of Changed Files

**Location**: `scripts/quality_gate.sh:310-338`

This function produces a null-delimited list of files that have changed, using a cascading fallback:

### Priority 1 — CI PR context (line 314-316)
```bash
if [[ -n "${GITHUB_BASE_REF:-}" ]]; then
    source_files=$(git diff --name-only "origin/${GITHUB_BASE_REF}...HEAD" 2>/dev/null || true)
fi
```
When running in a GitHub Actions PR workflow, `GITHUB_BASE_REF` is set to the target branch (e.g., `main`). The three-dot diff (`origin/main...HEAD`) gives you only the commits on the PR branch — not the full divergence from main. This is the most precise source of changed files.

### Priority 2 — Local working tree changes (line 319-321)
```bash
if [[ -z "$source_files" ]]; then
    source_files=$(git diff --name-only HEAD 2>/dev/null || true)
fi
```
Falls back to comparing the working tree against HEAD. This captures both staged and unstaged modifications. **Note**: this does NOT include untracked (new) files — only files git already knows about.

### Priority 3 — All tracked files (line 324-326)
```bash
if [[ -z "$source_files" ]]; then
    source_files=$(git ls-files 2>/dev/null || true)
fi
```
If the diff returns nothing (first commit, clean tree, shallow clone edge case), it lints every tracked file in the repo. This is the "full repo" safety net.

### Priority 4 — `find` fallback (line 329-332)
```bash
if [[ -z "$source_files" ]]; then
    find . -type f -not -path "./.git/*" -not -path "./target/*" -not -path "*/node_modules/*" -print0 2>/dev/null || true
    return
fi
```
If git isn't available at all, it falls back to `find` with hardcoded exclusions for `.git/`, `target/` (Rust), and `node_modules/`. This path returns early with null-delimited output from `find -print0`.

### Final output conversion (line 335-337)
```bash
local IFS=$'\n'
printf '%s\0' $source_files
```
Converts newline-delimited git output to null-delimited for safe downstream processing with `grep -z`.

---

## Stage 2: Extension Filtering — Extract Files Per Language

The quality gate doesn't pass all changed files to every linter. Instead, each language block filters `_changed_files_z` by extension.

### Shell scripts (line 410-411)
```bash
TMP_SH_LIST=$(mktemp)
_changed_files_z | grep -z '\.sh$' > "$TMP_SH_LIST" 2>/dev/null || true
```
Pipes the null-delimited output into `grep -z '\.sh$'` to extract only `.sh` files. The `|| true` prevents `set -e`-style failures when grep finds no matches (grep exits 1 on no match).

### Markdown (line 432-433)
```bash
TMP_MD_LIST=$(mktemp)
_changed_files_z | grep -z '\.md$' > "$TMP_MD_LIST" 2>/dev/null || true
```
Same pattern, filtering for `.md` files.

### What's NOT scoped
Rust, TypeScript/JavaScript checks (lines 342-404) run their linters and type-checkers **globally** — `cargo fmt --check`, `cargo clippy`, `pnpm lint`, `pnpm typecheck`. These tools operate on the whole project by design (Rust's workspace model, TS project references), so per-file scoping doesn't apply the same way.

---

## Stage 3: `lint_batch_if_changed` — Cache-Aware Deduplication

**Location**: `scripts/lib/lint_cache.sh:141-237`

Called only for shell and markdown linters, this function receives:
1. A null-delimited file list (`$TMP_SH_LIST` or `$TMP_MD_LIST`)
2. A tool ID (`"shellcheck"` or `"markdownlint"`)
3. A config file path (`.shellcheckrc` or `.markdownlint-cli2.jsonc`)
4. The actual command to run

### How it works

For each file in the list (line 179-216):

1. **Compute a cache key** — `$CACHE_DIR/${tool_id}_${safe_file}` where `safe_file` replaces `/`, `.`, and space with `_` (line 182-183). Cache lives in `.git/lint-cache/`.

2. **Fast-path timestamp check** (line 186-192) — If the cache file exists AND is newer than the source file AND newer than the config file, skip. This avoids expensive SHA-256 hashing (~3.5ms per call vs ~0.01ms for stat).

3. **Content hash check** (line 198-209) — If timestamp check is inconclusive, compute `sha256` of the file content and the config file. The cache stores `"${file_hash}:${config_hash}"`. If the stored hash matches, the file hasn't changed.

4. **Only cache misses proceed to linting** (line 211-212) — Misses accumulate in `$tmp_misses`.

5. **Batch execution** (line 223) — `xargs -0 -r "$@" < "$tmp_misses"` runs the linter once with all changed files as arguments. This is efficient: shellcheck/markdownlint process multiple files in a single invocation.

6. **Cache update on success** (line 225-229) — If linting passes, the new hash is written to the cache. On failure, the cache entry is removed so the file is re-linted next time.

---

## Key Gaps / Things That May Need Changing

1. **New (untracked) files are invisible in Priority 2** — `git diff --name-only HEAD` only shows modifications to tracked files. If you create a new `.sh` file and stage it but don't commit, it won't appear in `git diff --name-only HEAD` (only in `git diff --name-only --cached`). Untracked new files are entirely missed unless you reach Priority 3 (`git ls-files`).

2. **Renamed files may double-lint** — Git's rename detection sometimes shows both old and new paths. Both get linted, which is usually fine but wastes time.

3. **The `_changed_files_z` function is called multiple times** — Once for shell, once for markdown (lines 411, 433). Each call re-runs `git diff`. A single call with extension filtering would be more efficient.

4. **Rust/TS linters are not scoped at all** — The whole-repo approach is standard for those ecosystems, but if you wanted incremental checks (e.g., `cargo clippy` only on changed crates), that's a significant architectural change.

5. **The `find` fallback (Priority 4) uses hardcoded exclusions** — `.git/*`, `target/*`, `*/node_modules/*`. If the repo adds other large directories (e.g., `dist/`, `.next/`), this needs updating.

6. **Cache key collision risk** — The `safe_file` sanitization (`${file//[\/\. ]/_}`) could collide for files like `a.b.sh` and `a_b.sh` → both produce `a_b_sh`. Low risk in practice but worth noting.

---

## Data Flow Summary

```
_changed_files_z()
  ├─ git diff origin/main...HEAD  (CI PR)
  ├─ git diff HEAD               (local)
  ├─ git ls-files                 (fallback)
  └─ find . -type f               (no git)
       │
       ▼
  ┌────────────────────────────┐
  │  grep -z '\.sh$'           │ → TMP_SH_LIST
  │  grep -z '\.md$'           │ → TMP_MD_LIST
  └────────────────────────────┘
       │
       ▼
  lint_batch_if_changed($TMP_*, tool_id, config, command...)
       │
       ├─ Cache hit (timestamp + hash) → skip
       ├─ Cache miss → xargs -0 command
       └─ On success → update cache
```
