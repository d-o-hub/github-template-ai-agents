#!/usr/bin/env bash
# Normalize timestamps in .agents/metrics.jsonl to YYYY-MM-DDTHH:MM:SSZ

set -euo pipefail

METRICS_FILE=".agents/metrics.jsonl"
TEMP_FILE="${METRICS_FILE}.tmp"

if [ ! -f "$METRICS_FILE" ]; then
    printf "Metrics file %s not found. Skipping.\n" "$METRICS_FILE"
    # Replacing exit 0 with return 0 or just finishing
else
    printf "Normalizing timestamps in %s...\n" "$METRICS_FILE"

    python3 -c '
import sys
import json
from datetime import datetime, timezone

for line in sys.stdin:
    if not line.strip():
        continue
    try:
        data = json.loads(line)
        ts_str = data.get("timestamp")
        if ts_str:
            # Normalize to UTC
            if ts_str.endswith("Z"):
                dt = datetime.fromisoformat(ts_str[:-1] + "+00:00")
            else:
                dt = datetime.fromisoformat(ts_str)

            dt_utc = dt.astimezone(timezone.utc)
            data["timestamp"] = dt_utc.strftime("%Y-%m-%dT%H:%M:%SZ")

        print(json.dumps(data))
    except Exception as e:
        sys.stderr.write(f"Error processing line: {line.strip()} - {e}\n")
        print(line.strip())
' < "$METRICS_FILE" > "$TEMP_FILE"

    mv "$TEMP_FILE" "$METRICS_FILE"
    printf "Done. Normalized %s\n" "$METRICS_FILE"
fi
