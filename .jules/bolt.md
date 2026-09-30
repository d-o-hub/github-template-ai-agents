## 2025-02-28 - Replace `while read` loop with `mapfile`
Learning: In bash scripts, reading a file line-by-line using a `while IFS= read -r -d ''` loop with NUL-delimited input generates immense overhead from looping in bash interpreter logic.
Action: Whenever reading multiple items into an array from a NUL-delimited output, replace the while loop entirely with `mapfile -d '' array < input` (requires Bash 4.4+) which parses directly in C and eliminates bash execution overhead.
