#!/bin/bash
TIMEFORMAT=%R

./scripts/discover-commands.sh 2>/dev/null | grep -v "^Discovering\|^Command\|^─\|^\$" > cmds.txt

echo "Testing awk cache path and JSON format generation"
time (
  count=0

  # Stream everything as TSV with jq
  jq -r '[.file, .line, .command, .type] | @tsv' cmds.txt > /tmp/cmds.tsv

  # Then read with bash loop
  while IFS=$'\t' read -r file line cmd type; do
    [ -z "$cmd" ] && continue

    # Calculate cache path via parameter expansion
    safe_file="${file#./}"
    safe_file="${safe_file//\//_}"
    cache_file=".cache/command-validations/commands/${safe_file}_line_${line}.json"

    # Generate JSON manually safely (command is already safe or can be encoded)
    # Actually jq -R is safer for generating json strings

    ((count++))
  done < /tmp/cmds.tsv
)
