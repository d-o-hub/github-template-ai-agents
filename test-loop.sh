#!/bin/bash
TIMEFORMAT=%R
export DISCOVERED_COMMANDS=$(./scripts/discover-commands.sh 2>/dev/null | grep -v "^Discovering\|^Command\|^─\|^\$")
echo "Lines: $(echo "$DISCOVERED_COMMANDS" | wc -l)"
time (
  count=0
  while IFS= read -r cmd_entry; do
      [ -z "$cmd_entry" ] && continue
      cmd=$(echo "$cmd_entry" | jq -r '.command' 2>/dev/null || echo "")
      ((count++))
  done <<< "$DISCOVERED_COMMANDS"
  echo "Counted $count"
)
