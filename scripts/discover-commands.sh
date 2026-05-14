#!/usr/bin/env bash
set -euo pipefail
SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
REPO_ROOT="$(cd "$SCRIPT_DIR/.." && pwd)"
cd "$REPO_ROOT"
OUTPUT_FILE=""
FORMAT="json"
while [[ $# -gt 0 ]]; do
    case $1 in
        --output|-o) OUTPUT_FILE="$2"; shift 2 ;;
        --format|-f) FORMAT="$2"; shift 2 ;;
        *) printf "Unknown option: %s\n" "$1" >&2; exit 1 ;;
    esac
done

# Use a single awk pass to extract all commands from all files
# This is much faster than a bash loop with per-file awk/sed and per-command jq calls
# We also exclude symlinked skill directories to avoid redundant processing
results_file=$(mktemp)
find "$REPO_ROOT" -type f -name "*.md" \
    -not -path "*/node_modules/*" \
    -not -path "*/.git/*" \
    -not -path "*/.cache/*" \
    -not -path "*/.claude/skills/*" \
    -not -path "*/.gemini/skills/*" \
    -not -path "*/.qwen/skills/*" \
    -print0 | \
    xargs -0 awk -v root="$REPO_ROOT/" '
    BEGIN {
        valid_types["bash"] = 1
        valid_types["sh"] = 1
        valid_types["shell"] = 1
        valid_types["console"] = 1
    }
    { sub(/\r$/, "") }
    FNR == 1 { in_block = 0; btype = "" }
    /^[[:space:]]*```/ {
        if (in_block) {
            in_block = 0
            btype = ""
        } else {
            in_block = 1
            # Extract language type from after the backticks
            if (match(substr($0, index($0, "```") + 3), /^[a-zA-Z]+/)) {
                btype = substr($0, index($0, "```") + 3, RLENGTH)
            } else {
                btype = ""
            }
        }
        next
    }
    in_block && valid_types[btype] {
        if ($0 ~ /^[[:space:]]*$/ || $0 ~ /^[[:space:]]*#/) next
        cmd = $0
        sub(/^[[:space:]]*/, "", cmd)
        sub(/[[:space:]]*$/, "", cmd)
        if (length(cmd) > 0) {
            if (index(FILENAME, root) == 1) {
                rel_path = substr(FILENAME, length(root) + 1)
            } else {
                rel_path = FILENAME
            }
            # Output 3 lines per record for robust jq consumption
            print rel_path
            print FNR
            print cmd
        }
    }' | \
    jq -R -n -c '
        def group3:
          [inputs] |
          range(0; length; 3) as $i |
          .[$i:$i+3];
        group3 | {command: .[2], file: .[0], line: .[1]|tonumber, type: "code-block"}
    ' > "$results_file"

if [[ "$FORMAT" == "sarif" ]]; then
    jq -s '
      {
        version: "2.1.0",
        runs: [{
          tool: { driver: { name: "CommandDiscovery" } },
          results: map({
            ruleId: "CMD001",
            message: { text: .command },
            locations: [{
              physicalLocation: {
                artifactLocation: { uri: .file },
                region: { startLine: .line }
              }
            }]
          })
        }]
      }
    ' "$results_file"
else
    cat "$results_file"
fi
rm -f "$results_file"
