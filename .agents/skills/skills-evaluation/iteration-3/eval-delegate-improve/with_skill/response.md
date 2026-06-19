# Quality Gate Detection Logic Walkthrough

**Status**: success
**Summary**: Analyzed quality_gate.sh's changed-file detection and scoping logic for linting.

## Overview

The `quality_gate.sh` script uses a tiered detection strategy to determine which files to lint, falling back through increasingly broad scopes. Here's how it works:

## Detection Logic Flow

### 1. Changed File Detection (`_changed_files_z()`)

**Lines 310-338** define the core detection function with a 4-tier fallback:

```
Tier 1: CI PR Context (lines 314-316)
├─ Checks: GITHUB_BASE_REF is set
├─ Command: git diff --name-only "origin/${GITHUB_BASE_REF}...HEAD"
└─ Result: Only files changed in the PR

Tier 2: Local Changes (lines 319-321)
├─ Condition: Tier 1 returned empty
├─ Command: git diff --name-only HEAD
└─ Result: Staged + unstaged changes vs HEAD

Tier 3: All Tracked Files (lines 324-326)
├─ Condition: Tier 2 returned empty (first commit or no changes)
├─ Command: git ls-files
└─ Result: All git-tracked files

Tier 4: Find All Files (lines 329-331)
├─ Condition: Tier 3 returned empty (no git repo)
├─ Command: find . -type f -not -path "./.git/*" ...
└─ Result: All non-ignored files on disk
```

### 2. Output Format

- **Lines 335-337**: Converts newline-delimited output to null-delimited (`\0`) for safe `xargs`/`grep -z` processing
- The function uses `printf '%s\0'` with `$source_files` to handle filenames with spaces

### 3. Language Detection (lines 266-306)

Detects languages by checking for marker files:
- `Cargo.toml` → Rust
- `package.json` → TypeScript/JavaScript
- `requirements.txt`/`pyproject.toml`/`setup.py` → Python
- `go.mod` → Go
- `*.sh` files → Shell
- `*.md` files → Markdown

### 4. Scoped Linting (lines 407-447)

**Shell linting (lines 407-426)**:
```bash
_changed_files_z | grep -z '\.sh$' > "$TMP_SH_LIST"
```
- Pipes null-delimited output through `grep -z` to filter `.sh` files
- Uses `lint_batch_if_changed` from `lint_cache.sh` for cached linting

**Markdown linting (lines 428-447)**:
```bash
_changed_files_z | grep -z '\.md$' > "$TMP_MD_LIST"
```
- Same pattern for `.md` files

### 5. Key Observations

**What's NOT scoped to changed files**:
- `cargo fmt --check` (line 346) - checks all Rust files
- `cargo clippy` (line 354) - checks all targets
- `pnpm lint` (line 379) - runs full linter
- `pnpm typecheck` (line 386) - checks all TypeScript

**What IS scoped**:
- `shellcheck` - only changed `.sh` files
- `markdownlint-cli2` - only changed `.md` files

## Potential Improvements

1. **Add scope detection for other languages**: Extend `_changed_files_z` usage to Rust/TypeScript/Python linters
2. **Cache tier selection**: The tier logic could be memoized to avoid repeated git commands
3. **Exclude patterns**: Add configurable exclusion patterns beyond `./.git/*`
4. **Change detection accuracy**: Consider using `git merge-base` for more accurate PR diff detection
5. **Untracked files**: Current logic doesn't include untracked files in local mode (Tier 2)

## Files Referenced

- `scripts/quality_gate.sh` - Main quality gate script
- `scripts/lib/lint_cache.sh` - Lint caching library (sourced at line 26)
