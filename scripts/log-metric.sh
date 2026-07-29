#!/usr/bin/env bash
# log-metric.sh — Append a task metric entry to the correct per-agent metrics file.
#
# Usage:
#   ./scripts/log-metric.sh '<json-object>'
#
# Example:
#   ./scripts/log-metric.sh '{"timestamp":"2026-07-29T12:00:00Z","agent":"buffy","task":"fix CI","skill_used":"shell-script-quality","status":"completed","tokens_used":1200,"duration_seconds":60}'
#
# The script extracts the "agent" field from the JSON payload to determine
# the target file: .agents/metrics/metrics-{agent}.jsonl
#
# This replaces the old single-file .agents/metrics.jsonl pattern, eliminating
# merge conflicts between agents (LESSON-035).

set -euo pipefail

REPO_ROOT="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
METRICS_DIR="$REPO_ROOT/.agents/metrics"

JSON_PAYLOAD="${1:-}"
if [[ -z "$JSON_PAYLOAD" ]]; then
    printf 'log-metric.sh: missing JSON payload argument\n' >&2
    printf 'Usage: ./scripts/log-metric.sh '"'"'{"timestamp":"...","agent":"...","task":"..."}'"'"'\n' >&2
    exit 1
fi

# Validate JSON
if ! printf '%s\n' "$JSON_PAYLOAD" | python3 -c 'import json, sys; json.loads(sys.stdin.read())' 2>/dev/null; then
    if command -v jq &>/dev/null; then
        if ! printf '%s\n' "$JSON_PAYLOAD" | jq empty 2>/dev/null; then
            printf 'log-metric.sh: invalid JSON payload\n' >&2
            exit 1
        fi
    else
        printf 'log-metric.sh: invalid JSON payload (python3 unavailable for validation)\n' >&2
        exit 1
    fi
fi

# Extract agent name from JSON
AGENT=$(printf '%s\n' "$JSON_PAYLOAD" | python3 -c 'import json, sys; d=json.loads(sys.stdin.read()); print(d.get("agent","unknown"))' 2>/dev/null || echo "unknown")

if [[ -z "$AGENT" ]] || [[ "$AGENT" == "unknown" ]]; then
    printf 'log-metric.sh: could not extract "agent" field from payload\n' >&2
    exit 1
fi

# Sanitize agent name for filename (replace / and spaces)
AGENT_SAFE="${AGENT//\//-}"
AGENT_SAFE="${AGENT_SAFE// /-}"

mkdir -p "$METRICS_DIR"
METRICS_FILE="$METRICS_DIR/metrics-$AGENT_SAFE.jsonl"

echo "$JSON_PAYLOAD" >> "$METRICS_FILE"
printf 'Appended metric for agent=%s to %s\n' "$AGENT" "$METRICS_FILE"
