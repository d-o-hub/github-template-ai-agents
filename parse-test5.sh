#!/bin/bash
TIMEFORMAT=%R

./scripts/discover-commands.sh 2>/dev/null | grep -v "^Discovering\|^Command\|^─\|^\$" > cmds.txt

echo "Testing complete refactored verification script performance"
time (
  count=0

  # Stream everything as TSV with jq
  jq -r '[.file, .line, .command, .type] | @tsv' cmds.txt > /tmp/cmds.tsv

  while IFS=$'\t' read -r file line cmd type; do
    [ -z "$cmd" ] && continue

    # Fast path cache key generation via Bash parameter expansion
    safe_file="${file#./}"
    safe_file="${safe_file//\//_}"
    cache_file=".cache/command-validations/commands/${safe_file}_line_${line}.json"

    # Mocking cache result reading. Let's just do an if check
    if [ -f "$cache_file" ]; then
      # Need to extract category. Read line, extract manually.
      # A cache file looks like: {"valid":true, "category":"safe", "command":"..."}
      # To avoid jq subshell, we can use bash string manipulation since the format is strictly controlled by us.
      cached_result=$(<"$cache_file")

      # Extract category using parameter expansion or simple awk/grep
      if [[ "$cached_result" =~ \"category\":\"([^\"]+)\" ]]; then
          cached_cat="${BASH_REMATCH[1]}"
      else
          cached_cat="unknown"
      fi

    fi

    ((count++))
  done < /tmp/cmds.tsv
)
