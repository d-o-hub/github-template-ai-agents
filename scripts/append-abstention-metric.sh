#!/usr/bin/env bash
# Usage: ./scripts/append-abstention-metric.sh <agent> <task> <reason> <step> <signals> [resume_hint]
# Example: ./scripts/append-abstention-metric.sh buffy "search config" empty_result_repeated:search_files 2 "empty_result,empty_result"

set -euo pipefail

AGENT="${1:?agent name required}"
TASK="${2:?task description required}"
REASON="${3:?abstention_reason required}"
STEP="${4:?stopped_at_step required}"
SIGNALS_RAW="${5:?infeasibility_signals required (comma-separated)}"
RESUME_HINT="${6:-}"

TIMESTAMP="$(date -u +"%Y-%m-%dT%H:%M:%SZ")"

# Build signals JSON array
SIGNALS_JSON=$(echo "$SIGNALS_RAW" | python3 -c "
import sys, json
parts = sys.stdin.read().strip().split(',')
print(json.dumps([p.strip() for p in parts]))
")

ENTRY=$(python3 -c "
import json, sys
d = {
    'timestamp': '$TIMESTAMP',
    'agent': '$AGENT',
    'task': '$TASK',
    'abstained': True,
    'abstention_reason': '$REASON',
    'stopped_at_step': int('$STEP'),
    'infeasibility_signals': json.loads('$SIGNALS_JSON'),
}
if '$RESUME_HINT':
    d['resume_hint'] = '$RESUME_HINT'
print(json.dumps(d))
")

echo "$ENTRY" >> ".agents/metrics/metrics-$AGENT.jsonl"
echo "Appended abstention metric for agent=$AGENT reason=$REASON step=$STEP"
