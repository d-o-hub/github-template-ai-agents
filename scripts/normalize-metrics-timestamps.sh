#!/usr/bin/env bash
# Normalize timestamps in .agents/metrics.jsonl to YYYY-MM-DDTHH:MM:SSZ

set -euo pipefail

METRICS_FILE=".agents/metrics.jsonl"
TEMP_FILE="${METRICS_FILE}.tmp"

if [[ ! -f "$METRICS_FILE" ]]; then
    printf "Metrics file %s not found. Skipping.\n" "$METRICS_FILE"
else
    printf "Normalizing timestamps in %s...\n" "$METRICS_FILE"

    python3 -c '
import sys
import json
from datetime import datetime, timezone

for line in sys.stdin:
    line = line.strip()
    if not line:
        continue
    try:
        data = json.loads(line)
        ts_str = data.get("timestamp")
        if ts_str:
            # Replace Z with +00:00 for fromisoformat
            clean_ts = ts_str.replace("Z", "+00:00")
            dt = datetime.fromisoformat(clean_ts)

            # Convert to UTC and strip microseconds
            dt_utc = dt.astimezone(timezone.utc).replace(microsecond=0)
            # Format to exactly YYYY-MM-DDTHH:MM:SSZ
            data["timestamp"] = dt_utc.strftime("%Y-%m-%dT%H:%M:%SZ")

        print(json.dumps(data))
    except Exception as e:
        sys.stderr.write(f"Error processing line: {line} - {e}\n")
        print(line)
' < "$METRICS_FILE" > "$TEMP_FILE"

    mv "$TEMP_FILE" "$METRICS_FILE"
    printf "Done. Normalized %s\n" "$METRICS_FILE"
fi
