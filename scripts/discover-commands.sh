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
        *) echo "Unknown option: $1" >&2; exit 1 ;;
    esac
done
extract_commands() {
    local file="$1"
    local rel_path="${file#$REPO_ROOT/}"
    local line_num=0
    local in_code_block=0
    local btype=""
    while IFS= read -r line || [[ -n "$line" ]]; do
        line_num=$((line_num + 1))
        if [[ "$line" =~ ^\`\`\`([a-zA-Z]*) ]]; then
            if [[ $in_code_block -eq 0 ]]; then
                in_code_block=1
                btype="${BASH_REMATCH[1]}"
            else
                in_code_block=0
                btype=""
            fi
            continue
        fi
        if [[ $in_code_block -eq 1 ]]; then
            if [[ "$btype" == "bash" ]] || [[ "$btype" == "sh" ]] || [[ "$btype" == "shell" ]] || [[ "$btype" == "console" ]]; then
                [[ -z "$line" || "$line" =~ ^[[:space:]]*# ]] && continue
                local cmd=$(echo "$line" | sed 's/^[[:space:]]*//;s/[[:space:]]*$//')
                [[ -z "$cmd" ]] && continue
                jq -n --arg cmd "$cmd" --arg file "$rel_path" --argjson line "$line_num" --arg type "code-block" \
                    '{command: $cmd, file: $file, line: $line, type: $type}' -c
            fi
        fi
    done < "$file"
}
results_file=$(mktemp)
find "$REPO_ROOT" -type f -name "*.md" -not -path "*/node_modules/*" -not -path "*/.git/*" -not -path "*/.cache/*" -print0 | while IFS= read -r -d '' md_file; do
    extract_commands "$md_file"
done > "$results_file"
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
