# How `quality_gate.sh` Detects Files for Linting

## Language Detection (lines 265-306)

The script first determines which language ecosystems are present by checking for marker files in the repo root:

| Language | Marker |
|---|---|
| Rust | `Cargo.toml` |
| TypeScript/JS | `package.json` |
| Python | `requirements.txt`, `pyproject.toml`, or `setup.py` |
| Go | `go.mod` |
| Shell | any `*.sh` found via `find` (excluding `.git/`) |
| Markdown | any `*.md` found via `find` (excluding `.git/`) |

Detected languages are stored in the `DETECTED_LANGUAGES` array. Linting only runs for detected languages.

## Changed Files Detection: `_changed_files_z()` (lines 310-338)

This function determines **which files to actually lint**, using a cascading fallback:

1. **CI PR context** (`GITHUB_BASE_REF` set): `git diff --name-only "origin/${GITHUB_BASE_REF}...HEAD"` — files changed between the PR base branch and HEAD.
2. **Fallback**: `git diff --name-only HEAD` — all staged + unstaged changes vs HEAD.
3. **If nothing changed** (or first commit): `git ls-files` — all tracked files.
4. **If still empty** (no git repo): `find . -type f -not -path "./.git/*" ...` — all files on disk.

Output is null-delimited (`\0`) for safe handling of filenames with spaces.

## Scoped Linting per Language

Only changed files matching the relevant extension are linted:

- **Shell** (lines 407-426): `_changed_files_z | grep -z '\.sh$'` → passed to `lint_batch_if_changed` with `shellcheck --severity=error`
- **Markdown** (lines 429-447): `_changed_files_z | grep -z '\.md$'` → passed to `lint_batch_if_changed` with `markdownlint-cli2`
- **Rust** (lines 343-373): Runs `cargo fmt --check`, `cargo clippy`, and `cargo test` on the whole project (not file-scoped).
- **TypeScript/JS** (lines 376-404): Runs `pnpm lint`, `pnpm typecheck`, and `pnpm test` on the whole project (not file-scoped).

## Lint Cache Integration

Shell and markdown checks use `lint_batch_if_changed` from `scripts/lib/lint_cache.sh`, which caches per-file results in `.git/lint-cache/` and skips re-linting unchanged files.

## Key Behavior Summary

- **In CI PRs**: Only files changed in the PR are linted (shell/markdown). Rust/TS run full project checks.
- **Locally**: Changes vs HEAD are linted. If no changes, all tracked files are linted.
- **First commit / no git**: All files on disk are linted.
- **Shell/markdown**: File-scoped (only changed files). **Rust/TypeScript**: Project-wide (always).
