#!/bin/bash
TIMEFORMAT=%R

# Setup
./scripts/discover-commands.sh 2>/dev/null | grep -v "^Discovering\|^Command\|^─\|^\$" > cmds.txt
echo "Lines: $(wc -l < cmds.txt)"

echo "Testing get_cache_path overhead loop (jq)"
time (
  while IFS= read -r cmd_entry; do
    [ -z "$cmd_entry" ] && continue
    file=$(echo "$cmd_entry" | jq -r '.file // "unknown"')
    line=$(echo "$cmd_entry" | jq -r '.line // 0')
    safe_file=$(echo "$file" | sed 's|^./||' | tr '/' '_')
  done < cmds.txt
)

echo "Testing single awk pass to get all cache paths"
time (
  awk -F'"' '{
    file = $8
    line = $11
    sub(/[:,]/, "", line)
    safe_file = file
    sub(/^\.\//, "", safe_file)
    gsub(/\//, "_", safe_file)
    print safe_file "_line_" line ".json"
  }' cmds.txt > /dev/null
)
