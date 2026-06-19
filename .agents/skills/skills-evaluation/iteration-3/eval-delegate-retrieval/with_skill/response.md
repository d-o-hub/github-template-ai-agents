# How quality_gate.sh Detects Files for Linting

## Summary

The `quality_gate.sh` script detects files for linting through two primary mechanisms: **language auto-detection** and **changed file scoping**. It first identifies which language ecosystems are present in the repository, then for shell and markdown linting, it scopes checks to only changed files (not the entire codebase).

## 1. Language Auto-Detection (Lines 265-306)

The script detects project languages by looking for specific marker files:

| Language       | Marker Files                                      |
|----------------|---------------------------------------------------|
| Rust           | `Cargo.toml`                                      |
| TypeScript/JS  | `package.json`                                    |
| Python         | `requirements.txt`, `pyproject.toml`, `setup.py`  |
| Go             | `go.mod`                                          |
| Shell          | Any `*.sh` files (excluding `.git/`)              |
| Markdown       | Any `*.md` files (excluding `.git/`)              |

For shell and markdown, detection uses `find` with a quit-on-first-match to check for existence, not to enumerate files.

## 2. Changed File Scoping (Lines 309-338)

The `_changed_files_z()` function determines which files to lint for shell and markdown checks:

1. **CI PR context**: Compares against base branch using `git diff --name-only "origin/${GITHUB_BASE_REF}...HEAD"`
2. **Fallback**: Uses staged + unstaged changes vs HEAD: `git diff --name-only HEAD`
3. **If nothing changed**: Uses all tracked files: `git ls-files`
4. **If still empty**: Uses `find` excluding `.git/`, `target/`, and `node_modules/`

Output is null-delimited for safe processing with `grep -z`.

## 3. Linting Execution with Caching

For shell scripts (lines 407-426):
```bash
_changed_files_z | grep -z '\.sh$' > "$TMP_SH_LIST"
lint_batch_if_changed "$TMP_SH_LIST" "shellcheck" ".shellcheckrc" shellcheck --severity=error
```

For markdown files (lines 429-447):
```bash
_changed_files_z | grep -z '\.md$' > "$TMP_MD_LIST"
lint_batch_if_changed "$TMP_MD_LIST" "markdownlint" ".markdownlint-cli2.jsonc" markdownlint-cli2
```

The `lint_batch_if_changed` function (from `scripts/lib/lint_cache.sh`) implements a file-hash cache in `.git/lint-cache/` to skip unchanged files. It computes SHA256 hashes of both the source file and config file, storing them as `file_hash:config_hash` in cache files named `{tool_id}_{safe_filename}`.

## 4. Other Checks (Not File-Specific)

The script also runs these checks (not scoped to changed files):
- **Rust**: `cargo fmt --check`, `cargo clippy`, `cargo test`
- **TypeScript/JS**: `pnpm lint`, `pnpm typecheck`, `pnpm test`
- **LOC limits**: Checks all source files against line limits
- **WASM size**: Checks all `.wasm` files
- **Various validators**: GitHub Actions, skills, links, ADRs, etc.

## Key Insight

The script uses a **two-tier detection strategy**:
1. **Global detection** (language presence) to determine which linting categories to run
2. **Scoped detection** (changed files) to limit shell and markdown linting to only modified files, improving performance

This design balances thoroughness (checking all relevant languages) with efficiency (only linting changed files where possible).