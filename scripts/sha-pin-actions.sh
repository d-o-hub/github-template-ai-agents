#!/usr/bin/env bash
# SHA-pin GitHub Actions across all workflow files.
# Usage: ./scripts/sha-pin-actions.sh [workflow-file]
# If no file is given, processes all .github/workflows/*.yml

set -euo pipefail

REPO_ROOT="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"

# Global variable to track temp files for cleanup
TEMP_FILES=()
cleanup() {
  if [[ ${#TEMP_FILES[@]} -gt 0 ]]; then
    rm -f -- "${TEMP_FILES[@]}"
  fi
}
trap cleanup EXIT ERR

resolve_sha() {
  local owner_repo="$1" tag="$2"
  # Security: Use -- to terminate option processing for git
  git ls-remote -- "https://github.com/${owner_repo}.git" "refs/tags/${tag}" "refs/tags/${tag}^{}" 2>/dev/null \
    | awk '
        $2 ~ /\^\{\}$/ { print $1; found=1; exit }
        first == "" { first=$1 }
        END { if (!found && first != "") print first }
      '
}

pin_file() {
  local file="$1" tmpfile
  # Security: Use -- to terminate option processing for mktemp
  tmpfile=$(mktemp --)
  TEMP_FILES+=("$tmpfile")

  printf "Processing %s ...\n" "$file"

  while IFS= read -r line || [[ -n "$line" ]]; do
    if [[ $line =~ ^([[:space:]]*(-[[:space:]]*)?uses:[[:space:]]*)([^#[:space:]]+)@([^#[:space:]]+) ]]; then
      uses_prefix="${BASH_REMATCH[1]}"
      action="${BASH_REMATCH[3]}"
      tag="${BASH_REMATCH[4]}"

      # Skip local actions and docker actions to avoid invalid network requests
      if [[ "$action" == ./* ]] || [[ "$action" == docker://* ]]; then
        printf "%s\n" "$line"
        continue
      fi

      if [[ ! $tag =~ ^[0-9a-f]{40}$ ]]; then
        sha=$(resolve_sha "$action" "$tag")
        if [[ -z "$sha" ]] || [[ ! "$sha" =~ ^[0-9a-f]{40}$ ]]; then
          printf "Error: could not resolve %s@%s\n" "$action" "$tag" >&2
          exit 1
        fi
        printf "%s%s@%s  # pinned from %s\n" "$uses_prefix" "$action" "$sha" "$tag"
      else
        printf "%s\n" "$line"
      fi
    else
      printf "%s\n" "$line"
    fi
  done < "$file" > "$tmpfile"

  # Security: Use -- for diff, mv, rm
  if ! diff -q -- "$file" "$tmpfile" >/dev/null 2>&1; then
    mv -- "$tmpfile" "$file"
    printf "  -> Updated\n"
  else
    rm -f -- "$tmpfile"
    printf "  -> No changes\n"
  fi
}

if [[ $# -eq 0 ]]; then
  # Use nullglob to handle cases with no matching workflow files
  shopt -s nullglob
  for f in "$REPO_ROOT"/.github/workflows/*.{yml,yaml}; do
    pin_file "$f"
  done
  shopt -u nullglob
else
  file="$1"
  if [[ ! -f "$file" ]]; then
    printf "Error: file not found: %s\n" "$file" >&2
    exit 1
  fi
  pin_file "$file"
fi
