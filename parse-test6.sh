#!/bin/bash
TIMEFORMAT=%R

./scripts/discover-commands.sh 2>/dev/null | grep -v "^Discovering\|^Command\|^─\|^\$" > cmds.txt

echo "Testing complete refactored verification with missing cache"
time (
  count=0

  jq -r '[.file, .line, .command, .type] | @tsv' cmds.txt > /tmp/cmds.tsv

  while IFS=$'\t' read -r file line cmd type; do
    [ -z "$cmd" ] && continue

    # Fast path cache key generation via Bash parameter expansion
    safe_file="${file#./}"
    safe_file="${safe_file//\//_}"
    cache_file=".cache/command-validations/commands/${safe_file}_line_${line}.json"

    # Mock validation
    category="safe"

    # Mock saving to cache. Avoid jq subshell. Since we control category and cmd is arbitrary but needs escaping.
    # However we know cmd doesn't strictly need pure jq if we just encode it using jq efficiently,
    # but the safest way without a subshell per line is:
    # Well, we can't avoid jq for escaping arbitrary command strings safely, but maybe we can?

    # Actually, we CAN use a subshell because saving to cache only happens on MISS, which is rare.
    # On cache HIT (common case), we don't save.

    ((count++))
  done < /tmp/cmds.tsv
)
