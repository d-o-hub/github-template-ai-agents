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

## 2026-04-19 - [Subshell elimination and shared state]
**Learning:** Significant performance gains (up to 75%) in Bash scripts can be achieved by sharing state between functions and scripts to avoid redundant file processing. For example, exposing a global variable like `SKILL_LINE_COUNT` from a validation function eliminates the need for callers to fork `wc -l` subshells. Additionally, skipping expensive `realpath` resolutions for simple relative paths (without '..') avoids the ~2.5ms fork overhead per call, which is critical in high-frequency validation loops.
**Action:** Design library functions to populate global "result" variables for common metadata. Only use `realpath` or `readlink -f` when path normalization is strictly required for security or logical correctness.

## 2026-05-22 - [Optimizing Bash cache keys and hash extraction]
**Learning:** Significant performance gains in Bash scripts (up to 350x for string manipulation) can be achieved by replacing external utility pipes (`tr`, `cut`) and subshells (`$(cat ...)`) with native Bash parameter expansion and built-ins (`read`). In `lint_cache.sh`, replacing `echo | tr` with `${file//[\/\. ]/_}` and `cat` with `read` eliminated hundreds of subshells during quality gate execution.
**Action:** Always prefer `${var//pattern/string}` for character replacement and `read -r var < file` for reading small config/cache files over `tr`, `sed`, or `cat` subshells.

## 2026-05-23 - [AWK-to-Bash Streaming Optimization]
**Learning:** For scripts that must process thousands of lines in Bash (e.g., Markdown validation), using `awk` to pre-filter and format only relevant lines into a colon-delimited stream (`LINE_NUM:STATE:CONTENT`) before piping to a `while read` loop can reduce execution time by ~50%. This avoids the high overhead of Bash's line-by-line processing for thousands of irrelevant lines while preserving complex validation logic in Bash.
**Action:** Use `awk` to stream a "sparse" version of a large file to Bash when the validation logic is too complex for pure `awk` but the number of relevant lines is small.

## 2026-05-24 - [Variable accumulation vs Line-by-line I/O]
**Learning:** In Bash scripts, accumulating text in a variable and writing it to a file once with `printf` is significantly faster than using `>>` append redirection in a loop. For a GitHub Action workflow validator, this optimization, combined with reducing `mktemp` calls, yielded a ~7x speedup (from 2.5s to 0.34s) when processing multiple files with script blocks.
**Action:** Avoid line-by-line file appends in loops. Use Bash variables to buffer content and perform a single write operation. Reuse temporary files across loop iterations instead of creating new ones.

## 2026-05-25 - [Optimizing LOC gate via batched wc]
**Learning:** Replacing an O(N) process-forking loop (calling `wc -l` for every file) with a single batched `xargs -0 wc -l` call and an `awk` validation pass yielded an ~8.8x speedup (from 0.44s to 0.05s) for ~100 files. Handling the `total` line in `awk` and using `print0` for space-safety is essential for robustness.
**Action:** Always prefer `xargs wc -l | awk` over `while read ...; do < /dev/null wc -l; done` for line-count validation across multiple files.

## 2026-05-26 - [Batched AWK-to-Bash Streaming]
**Learning:** Transitioning from per-file `awk` pre-filtering within a Bash loop to a single batched `awk` call for all files further reduces execution time by ~50% in this codebase (from ~0.44s to ~0.23s for 50 files). This eliminates the process fork overhead for every file while still allowing complex validation logic (like relative path resolution and security checks) to remain in Bash.
**Action:** Always prefer batching multiple files into a single `awk` process when pre-filtering lines for a Bash loop. Use a file-transition marker (e.g., `FNR == 1`) in `awk` to help the Bash loop track file boundaries.

## 2026-05-03 - Pairwise Similarity & Project Hygiene
**Learning:** Pairwise string similarity checks ($O(N^2)$) are highly sensitive to redundant slicing and full `SequenceMatcher.ratio()` calls on dissimilar pairs. Project hygiene standards require avoiding "magic numbers" for thresholds and ensuring no temporary benchmark files remain in the repository. Structural fixes prefer repo-local temporary files over `/tmp` for better sandbox consistency.
**Action:** Pre-truncate strings once before loops; use `real_quick_ratio()` for $O(1)$ early exits. Stash all thresholds in named constants. Implement "structural fixes" by moving `/tmp` file usage to `$REPO_ROOT/.temp_file` with robust `trap` cleanup. Maintain strict linting by ensuring zero unused variables or functions in optimized modules.
