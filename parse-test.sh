#!/bin/bash
TIMEFORMAT=%R

./scripts/discover-commands.sh 2>/dev/null | grep -v "^Discovering\|^Command\|^─\|^\$" > cmds.txt

echo "Testing single awk pass to format stream"
time (
  # We use jq just to parse properly since json can have quotes inside command
  jq -r '[.file, .line, .command, .type] | @tsv' cmds.txt > /dev/null
)
