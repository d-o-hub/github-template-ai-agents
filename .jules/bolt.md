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

## 2026-05-06 - [Subshell elimination in setup-skills]
**Learning:** Significant performance gains in repository setup scripts can be achieved by eliminating O(N) process forks in loops. Replacing `basename` with Bash parameter expansion and pre-calculating `realpath --relative-to` base paths outside of the skills iteration loop reduced `setup-skills.sh` execution time by ~27x (from ~0.8s to ~0.03s).
**Action:** Avoid calling external utilities like `realpath` or `basename` inside loops that iterate over many files or directories; pre-calculate static path components and use native Bash string manipulation.

## 2026-05-27 - [Batching file validation with awk]
**Learning:** Re-running `grep` and `basename` iteratively inside a bash loop to validate properties across multiple subdirectories (e.g. 50+ skill directories) incurs immense subshell overhead and significantly slows down scripts. Transitioning to a batched validation approach using single-pass `awk` parsing eliminates hundreds of process forks. In this codebase, it reduced the execution time of extra eval validation checks from ~1.5s to ~0.02s.
**Action:** Always prefer batched `awk` parsing across file arrays via `find -print0` and `xargs -0` or `awk ... "${files[@]}"` over multiple looped `grep` invocations to check properties within small text files. Use FNR to handle file transitions seamlessly.

## 2026-05-28 - [Batched file reading with AWK vs Loop with sed/grep/cut]
**Learning:** Extracting data across many small files inside a Bash `for` loop with external tools like `sed`, `grep`, and `cut` introduces immense subshell overhead and drastically slows down execution. By replacing the loop with a single `awk` process that processes an array of all files, execution time is greatly reduced. In this codebase, optimizing `scripts/update-agents-md.sh` resulted in a >10x speedup (from ~0.74s to ~0.06s).
**Action:** Use a single `awk` pass for scanning multiple files and formatting the results instead of spawning processes iteratively.

## 2024-05-10 - Replace bash while read loop with awk for SKILL.md parsing

**Learning:** Replaced an O(N) pure bash `while IFS= read` loop in `validate_skill_file` with a single highly optimized `awk` script. Bash's line-by-line interpretation overhead can make evaluating multiple medium-sized files noticeably slow. `awk` successfully extracted variables and flags correctly via colon-separated outputs. This resulted in an overall validation time reduction of around ~30% for scripts utilizing `validate_skill_file`.

## 2026-05-10 - [Python Regex search optimization in loops]
**Learning:** Performing a whole-document regex search (`re.search`) inside a loop that iterates over many small matches (like HTML tags) creates $O(N \cdot M)$ complexity. Moving the document-wide search outside the loop and pre-compiling regex patterns can achieve dramatic performance gains (e.g., ~325x speedup).
**Action:** Always hoist invariant regex searches out of loops. Pre-compile all regex patterns at the module level for reuse. Cache results of string operations (like `.lower()`) when used multiple times in a loop iteration.

## 2026-05-12 - [Eliminating redundant git diff and cat process forks]
**Learning:** Running an expensive process like `git diff` multiple times (e.g., once for processing and once for counting) significantly slows down shell scripts. Additionally, piping `cat` to another command inside a subshell creates unnecessary processes. In this codebase, avoiding the second `git diff` by storing the output in a variable and replacing `$(cat FILE | tr...)` with `$(tr... < FILE)` provided a small but measurable speedup, aligning with Bolt's philosophy.
**Action:** Always capture the output of expensive commands in a variable if the result needs to be used multiple times, and prefer file redirection (`<`) over `cat | `.

## 2026-05-13 - [Eliminate subshells in bash while read loops]
**Learning:** Reassigning variables using external command pipelines (e.g., `key=$(echo "$key" | tr -d ' ' | sed 's/export//g')`) within high-frequency `while read` loops introduces severe subshell overhead. Replacing these pipelines with native Bash parameter expansion (`key="${key// /}"; key="${key//export/}"`) drastically improves performance. In `scripts/validate-config.sh`, this optimization reduced execution time from ~27ms to ~6ms.
**Action:** Avoid spawning external subshells like `echo`, `tr`, and `sed` inside tight Bash loops. Prefer native Bash string manipulation (parameter expansion) whenever possible.

## 2026-05-30 - [Safe temp file usage and output redirection over subshells]
**Learning:** Process substitution (`< <(...)`) and `OUTPUT=$(...)` both spawn subshells, adding fork overhead. A fast and safe pattern in bash loops is generating the file list as a string via `find` and reading from it with `while ...; do ...; done <<< "$FILES"`, while replacing internal loop subshells (`OUTPUT=$(command)`) with standard file redirection (`command >"$TMP_OUT" 2>&1`) to capture output without forking.
**Action:** When capturing output in a loop, write to a temporary file (`mktemp`) and use `cat` instead of command substitution. Ensure the temporary file is removed afterwards, using a simple `rm -f "$TMP_OUT"` when safe.

## 2026-06-01 - [Pre-parsing JSON with jq to avoid nested subshells]

**Learning:** Using `jq` iteratively inside Bash loops introduces a massive performance bottleneck due to subshell forks. Pre-parsing JSON into delimited string arrays or files and reading them sequentially with `while read` significantly improves performance. Utilizing `jq -c` ensures compact JSON serialization, preventing multi-line corruption during text processing in bash loops.
**Action:** Replace iterative `jq` calls inside `while read` loops with a single pre-parsing `jq` command that outputs compact JSON (`-c`). Pre-parsing into NUL-delimited strings is the preferred, safest method, though tabs/pipes can be used as a less-preferred alternative when NUL isn't viable.

## 2023-10-27 - [scripts/archive-stale-plans.sh] Learning: [Optimization of archive-stale-plans.sh script] Action: [Replace subshells with Bash builtins inside loops]
When archiving files, subshells inside loops drastically slow down scripts. Replacing `basename`, `echo | sed`, and `date` with parameter expansion (`${file##*/}`), bash regex matching (`=~`), and lexical string comparisons against a pre-calculated ISO-8601 date, along with batched moves (`mv`), yields immense speedups (e.g., from ~2.5s down to ~0.06s for 200 files).

## 2024-05-22 - [Optimization] parameter expansion instead of subshell in loops
Learning: Using `$(basename "$var")` inside a `while read` loop for large inputs spawns an external process for every single line, leading to severe performance bottlenecks (O(N) subshell overhead).
Action: Replace it with native Bash parameter expansion `${var##*/}`. This achieves the same result locally within the current Bash process, reducing execution time from ~4.1s to ~0.04s for 1000 items.
## 2026-05-23 - [Optional Skills Implementation] Learning: Standardized a way to include specialized or regulatory skills as optional in the template by using a SKILLS_OPTIONAL array in setup scripts. Action: Use this pattern for future specialized skill contributions to keep the default context clean.
