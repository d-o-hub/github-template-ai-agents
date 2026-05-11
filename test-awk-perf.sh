#!/bin/bash
TIMEFORMAT=%R

# Use temp file correctly
./scripts/discover-commands.sh 2>/dev/null | grep -v "^Discovering\|^Command\|^─\|^\$" > cmds.txt

echo "Lines: $(wc -l < cmds.txt)"

echo "Testing caching via single awk pass"

time (
  # Suppose we want to extract everything needed to do caching in verify-commands
  awk -F'"' '{
    cmd = $14
    file = $8
    line = $11
    sub(/[:,]/, "", line)

    # Simple substitution equivalent to sed s|^./|| and tr / _
    safe_file = file
    sub(/^\.\//, "", safe_file)
    gsub(/\//, "_", safe_file)

    cache_path = ".cache/command-validations/commands/" safe_file "_line_" line ".json"

    # output space separated or tab separated list
    print cache_path "\t" cmd "\t" file
  }' cmds.txt > /dev/null
)
