#!/bin/bash
TIMEFORMAT=%R

./scripts/discover-commands.sh 2>/dev/null | grep -v "^Discovering\|^Command\|^─\|^\$" > cmds.txt

echo "Testing streaming bash read"
time (
  count=0
  # Instead of using jq per line in the loop, we format it outside the loop
  # and stream the extracted fields
  while IFS=$'\t' read -r file line cmd type; do
    [ -z "$cmd" ] && continue
    # simulate some work
    ((count++))
  done < <(jq -r '[.file, .line, .command, .type] | @tsv' < cmds.txt)
  echo "Counted $count"
)
