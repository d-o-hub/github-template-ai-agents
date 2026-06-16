#!/usr/bin/env bash
# SHA-pin GitHub Actions across all workflow files.
# Usage: ./scripts/sha-pin-actions.sh [workflow-file]
# If no file is given, processes all .github/workflows/*.yml

set -euo pipefail

REPO_ROOT="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"

resolve_sha() {
  local owner_repo=$1 tag=$2
  git ls-remote "https://github.com/${owner_repo}.git" "refs/tags/${tag}" "refs/tags/${tag}^{}" 2>/dev/null \
    | awk '
        $2 ~ /\^\{\}$/ { print $1; found=1; exit }
        first == "" { first=$1 }
        END { if (!found && first != "") print first }
      '
}

pin_file() {
  local file=$1 tmpfile
  tmpfile=$(mktemp)
  echo "Processing $file ..."
  while IFS= read -r line; do
    if [[ $line =~ ^[[:space:]]*uses:[[:space:]]*([^#[:space:]]+)@([^#[:space:]]+) ]]; then
      action="${BASH_REMATCH[1]}"
      tag="${BASH_REMATCH[2]}"
      if [[ ! $tag =~ ^[0-9a-f]{40}$ ]]; then
        sha=$(resolve_sha "$action" "$tag")
        if [[ -z $sha || ! $sha =~ ^[0-9a-f]{40}$ ]]; then
          echo "Error: could not resolve $action@$tag" >&2
          exit 1
        fi
        echo "${line//@$tag/@$sha  # pinned from $tag}"
      else
        echo "$line"
      fi
    else
      echo "$line"
    fi
  done < "$file" > "$tmpfile"
  if ! diff -q "$file" "$tmpfile" >/dev/null 2>&1; then
    mv "$tmpfile" "$file"
    echo "  -> Updated"
  else
    rm "$tmpfile"
    echo "  -> No changes"
  fi
}

if [[ $# -eq 0 ]]; then
  for f in "$REPO_ROOT"/.github/workflows/*.yml; do
    pin_file "$f"
  done
else
  file="$1"
  if [[ ! -f $file ]]; then
    echo "Error: file not found: $file" >&2
    exit 1
  fi
  pin_file "$file"
fi
