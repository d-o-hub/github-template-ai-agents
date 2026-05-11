#!/bin/bash
TIMEFORMAT=%R

echo "Testing jq overhead inside verify-commands.sh"

export DISCOVERED_COMMANDS=$(./scripts/discover-commands.sh 2>/dev/null | grep -v "^Discovering\|^Command\|^─\|^\$" | head -n 100)

echo "Parsing 100 commands with jq in a loop:"
time (
  while IFS= read -r cmd_entry; do
      [ -z "$cmd_entry" ] && continue
      cmd=$(echo "$cmd_entry" | jq -r '.command' 2>/dev/null || echo "")
  done <<< "$DISCOVERED_COMMANDS"
)

echo "Parsing 100 commands using pure jq process:"
time (
  echo "$DISCOVERED_COMMANDS" | jq -r '.command' >/dev/null
)
