#!/bin/bash
TIMEFORMAT=%R

./scripts/discover-commands.sh 2>/dev/null | grep -v "^Discovering\|^Command\|^─\|^\$" > cmds.txt

echo "Testing awk streaming with cache validation inside awk"
time (
  count=0

  # Just parse it cleanly using awk
  # The output of discover-commands is already JSON lines. Let's use jq to convert to TSV.
  # We know this takes about ~0.035s.
  jq -r '[.file, .line, .command, .type] | @tsv' cmds.txt > /tmp/cmds.tsv

  # Then read with bash loop
  while IFS=$'\t' read -r file line cmd type; do
    [ -z "$cmd" ] && continue
    # simulate some work

    # Calculate cache path via parameter expansion (Bolt learned this!)
    safe_file="${file#./}"
    safe_file="${safe_file//\//_}"
    cache_file=".cache/command-validations/commands/${safe_file}_line_${line}.json"

    ((count++))
  done < /tmp/cmds.tsv
  echo "Counted $count"
)
