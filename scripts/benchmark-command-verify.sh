#!/usr/bin/env bash
# Benchmark for command verification system

set -euo pipefail

ITERATIONS=5
echo "Running benchmark for $ITERATIONS iterations..."

# Measure Discovery
start_time=$(date +%s%N)
for i in $(seq 1 $ITERATIONS); do
    ./scripts/discover-commands.sh > /dev/null
done
end_time=$(date +%s%N)
duration=$(( (end_time - start_time) / 1000000 / ITERATIONS ))
echo "Average Discovery Time: ${duration}ms"

# Measure Verification (with cache)
./scripts/verify-commands.sh --silent > /dev/null
start_time=$(date +%s%N)
for i in $(seq 1 $ITERATIONS); do
    ./scripts/verify-commands.sh --silent > /dev/null
done
end_time=$(date +%s%N)
duration=$(( (end_time - start_time) / 1000000 / ITERATIONS ))
echo "Average Verification Time (Cached): ${duration}ms"
