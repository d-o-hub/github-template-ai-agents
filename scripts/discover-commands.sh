#!/usr/bin/env bash
# Discover all commands in markdown files
# Outputs JSON or SARIF structure

set -euo pipefail

REPO_ROOT="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
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

extract() {
    local file="$1"
    local rel="${file#$REPO_ROOT/}"
    local ln=0
    local in_block=0
    local btype=""

    while IFS= read -r line || [[ -n "$line" ]]; do
        ln=$((ln + 1))
        if [[ "$line" =~ ^\`\`\`([a-zA-Z]*) ]]; then
            if [[ $in_block -eq 0 ]]; then
                in_block=1
                btype="${BASH_REMATCH[1]}"
            else
                in_block=0
                btype=""
            fi
            continue
        fi

        if [[ $in_block -eq 1 ]]; then
            if [[ "$btype" == "bash" ]] || [[ "$btype" == "sh" ]] || [[ "$btype" == "shell" ]] || [[ "$btype" == "console" ]]; then
                [[ -z "$line" || "$line" =~ ^[[:space:]]*# ]] && continue
                local cmd
                cmd=$(echo "$line" | sed 's/^[[:space:]]*//;s/[[:space:]]*$//')
                [[ -z "$cmd" ]] && continue
                echo "{\"command\":\"$(echo "$cmd" | sed 's/"/\\"/g')\",\"file\":\"$rel\",\"line\":$ln,\"type\":\"code-block\"}"
            fi
        fi
    done < "$file"
}

results_file=$(mktemp)
find "$REPO_ROOT" -type f -name "*.md" \
    -not -path "*/node_modules/*" \
    -not -path "*/.git/*" \
    -not -path "*/.cache/*" \
    -print0 | while IFS= read -r -d '' f; do
        extract "$f"
    done > "$results_file"

if [[ "$FORMAT" == "sarif" ]]; then
    echo '{"version":"2.1.0","runs":[{"tool":{"driver":{"name":"CmdDisc"}},"results":['
    first=1
    while read -r line; do
        [ -z "$line" ] && continue
        [ $first -eq 0 ] && echo ","
        cmd=$(echo "$line" | grep -o '"command":"[^"]*"' | cut -d'"' -f4)
        file=$(echo "$line" | grep -o '"file":"[^"]*"' | cut -d'"' -f4)
        ln_no=$(echo "$line" | grep -o '"line":[0-9]*' | cut -d':' -f2)
        echo "{\"ruleId\":\"CMD\",\"message\":{\"text\":\"$cmd\"},\"locations\":[{\"physicalLocation\":{\"artifactLocation\":{\"uri\":\"$file\"},\"region\":{\"startLine\":$ln_no}}}]}"
        first=0
    done < "$results_file"
    echo ']}]}'
else
    cat "$results_file"
fi

rm -f "$results_file"
