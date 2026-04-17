## 2025-05-15 - [Bash performance optimization]
**Learning:** Performance in Bash scripts is significantly degraded by excessive process spawning (subshells) in loops. Replacing multiple calls to `grep`, `sed`, `cut`, and `wc` with a single-pass `while read` loop and internal parameter expansion can reduce execution time by 40-50% for metadata-heavy operations.
**Action:** Avoid calling external utilities inside loops that iterate over many files; prefer native Bash features and single-pass file processing.

## 2026-04-17 - [Single-pass AWK vs Piped Subshells]
**Learning:** Refactoring a Bash script to use single-pass `awk` parsing and Bash built-in parameter expansion instead of multiple piped external utilities (`grep`, `sed`, `cut`, `tr`, `basename`) within loops can yield dramatic performance gains. In this codebase, optimizing `scripts/update-agents-registry.sh` resulted in a ~50x speedup (from 1.0s to 0.02s) for scanning ~60 files.
**Action:** Always prefer `awk` for complex text extraction in loops over multiple piped commands. Ensure `awk` logic handles edge cases like multiline fields and field order by using state machines rather than simple `getline` loops.
