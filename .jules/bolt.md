## 2025-05-15 - [Bash performance optimization]
**Learning:** Performance in Bash scripts is significantly degraded by excessive process spawning (subshells) in loops. Replacing multiple calls to `grep`, `sed`, `cut`, and `wc` with a single-pass `while read` loop and internal parameter expansion can reduce execution time by 40-50% for metadata-heavy operations.
**Action:** Avoid calling external utilities inside loops that iterate over many files; prefer native Bash features and single-pass file processing.

## 2026-04-17 - [Single-pass AWK vs Piped Subshells]
**Learning:** Refactoring a Bash script to use single-pass `awk` parsing and Bash built-in parameter expansion instead of multiple piped external utilities (`grep`, `sed`, `cut`, `tr`, `basename`) within loops can yield dramatic performance gains. In this codebase, optimizing `scripts/update-agents-registry.sh` resulted in a ~50x speedup (from 1.0s to 0.02s) for scanning ~60 files.
**Action:** Always prefer `awk` for complex text extraction in loops over multiple piped commands. Ensure `awk` logic handles edge cases like multiline fields and field order by using state machines rather than simple `getline` loops.

## 2025-05-20 - [Optimizing symlink and path validation]
**Learning:** Nested loops calling `readlink -f` or `realpath` for every iteration significantly slow down Bash scripts due to subshell overhead. In `validate-skills.sh`, checking 147 symlink targets was the primary bottleneck. Skipping redundant target verification (unless in CI) and replacing `basename` with Bash parameter expansion reduced execution time by >70% (1.17s to 0.33s).
**Action:** Use `[[ -e ]]` on symlinks first to check target existence without subshells. Cache the existence of external utilities like `realpath`. Inline path resolution logic to avoid function call overhead in tight loops.

## 2026-04-18 - [Eliminating redundant realpath and basename subshells]
**Learning:** Significant performance gains in Bash validation scripts can be achieved by caching results of expensive path resolutions like `realpath` and `readlink -f` outside of high-frequency loops. Additionally, replacing `basename` and `dirname` with native Bash parameter expansion (${var##*/}, ${var%/*}) eliminates process spawning overhead for every file or link being validated. In this codebase, these optimizations reduced `validate-links.sh` execution time by ~57% and `validate-skills.sh` by ~43%.
**Action:** Always cache the resolved repository root and other common paths at the script's top level. Prefer native Bash string manipulation over calling external utilities in loops that iterate over the entire skills directory.
