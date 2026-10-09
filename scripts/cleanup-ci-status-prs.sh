#!/usr/bin/env bash
# scripts/cleanup-ci-status-prs.sh
# Close stale GitHub Actions PRs and delete their branches. --dry-run uses
# exactly the same snapshot and selector, but never calls a mutation endpoint.
set -euo pipefail

REPO_ROOT="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
readonly TITLE_MIN_AGE_SECONDS=21600  # 6 hours: do not race artifact auto-merge
readonly GENERIC_MIN_AGE_SECONDS=86400  # 24 hours for other auto/* and ci/* PRs
readonly PR_LIST_LIMIT=1000
readonly CI_BRANCH='ci/ci-status-update'
readonly CI_TITLE='ci: update ci status artifacts'
readonly LLM_BRANCH='auto/regenerate-llms-txt'
readonly LLM_TITLE='ci: regenerate llms.txt and llms-full.txt'

DRY_RUN=false
case "${1:-}" in
  --dry-run) DRY_RUN=true; shift ;;
  '') ;;
  *) printf 'Usage: %s [--dry-run]\n' "$0" >&2; exit 1 ;;
esac
if (( $# > 0 )); then
  printf 'Usage: %s [--dry-run]\n' "$0" >&2
  exit 1
fi

cd "$REPO_ROOT"
gh auth status >/dev/null || { printf 'ERROR: gh not authenticated\n' >&2; exit 1; }
REPO=$(gh repo view --json nameWithOwner --jq '.nameWithOwner') || {
  printf 'ERROR: Cannot determine repository name.\n' >&2
  exit 1
}
[[ -n "$REPO" ]] || { printf 'ERROR: Empty repository name.\n' >&2; exit 1; }

# Fetch once, without a search/author filter: GraphQL represents the Actions
# app as app/github-actions, whereas other responses use github-actions[bot].
# Do not turn an API/auth/JSON error into a successful empty cleanup.
printf 'Searching for stale automated PRs...\n'
PR_JSON=$(gh pr list --repo "$REPO" --state open --limit "$PR_LIST_LIMIT" \
  --json number,title,headRefName,author,createdAt) || {
  printf 'ERROR: Cannot list automated PRs.\n' >&2
  exit 1
}
CANDIDATES=$(jq -rs \
  --arg ci_branch "$CI_BRANCH" --arg ci_title "$CI_TITLE" \
  --arg llm_branch "$LLM_BRANCH" --arg llm_title "$LLM_TITLE" \
  --argjson title_age "$TITLE_MIN_AGE_SECONDS" --argjson generic_age "$GENERIC_MIN_AGE_SECONDS" '
  # jq parsing is portable; date -d is not available on BSD/macOS. A calendar
  # round-trip rejects dates that mktime would otherwise silently normalize.
  def checked_epoch:
    . as $ts |
    if test("^[0-9]{4}-[0-9]{2}-[0-9]{2}T[0-9]{2}:[0-9]{2}:[0-9]{2}Z$") then
      try (fromdateiso8601 as $epoch |
           if ($epoch | todateiso8601) == $ts then $epoch else "invalid" end)
      catch "invalid"
    else "invalid" end;
  if length != 1 or (.[0] | type) != "array" then error("Expected one PR array") else
    .[0] | unique_by(.number)[] |
    select((.number | type) == "number" and .number > 0 and .number == (.number | floor)) |
    select((.headRefName | type) == "string" and (.title | type) == "string" and
           (.createdAt | type) == "string") |
    select(.author.login == "app/github-actions" or .author.login == "github-actions[bot]") |
    select((.headRefName | startswith("auto/")) or (.headRefName | startswith("ci/"))) |
    [.number, .headRefName, (.createdAt | checked_epoch),
      (if (.headRefName == $ci_branch and
           (.title == $ci_title or .title == ($ci_title + " [skip ci]"))) or
          (.headRefName == $llm_branch and
           (.title == $llm_title or .title == ($llm_title + " [skip ci]")))
       then $title_age else $generic_age end)] | @tsv
  end' <<< "$PR_JSON") || {
  printf 'ERROR: Cannot parse automated PRs.\n' >&2
  exit 1
}

# Only accept GitHub UTC timestamps. Missing, invalid, normalized calendar dates
# and future dates are retained, never interpreted as ancient PRs.
filter_stale() {
  local now num branch ts_epoch threshold
  now=$(date -u +%s) || { printf 'ERROR: Cannot read current time.\n' >&2; return 1; }
  [[ "$now" =~ ^[1-9][0-9]*$ ]] || { printf 'ERROR: Invalid current time.\n' >&2; return 1; }
  while IFS=$'\t' read -r num branch ts_epoch threshold; do
    [[ "$num" =~ ^[1-9][0-9]*$ ]] || continue
    if [[ ! "$ts_epoch" =~ ^-?[0-9]+$ ]]; then
      printf 'WARNING: Retaining PR #%s: invalid createdAt.\n' "$num" >&2
      continue
    fi
    if (( ts_epoch <= 0 || ts_epoch > now )); then
      printf 'WARNING: Retaining PR #%s: invalid or future createdAt.\n' "$num" >&2
      continue
    fi
    if (( now - ts_epoch >= threshold )); then
      printf '%s\t%s\n' "$num" "$branch"
    fi
  done
}

SELECTED_PRS=$(filter_stale <<< "$CANDIDATES")
while IFS=$'\t' read -r num branch; do
  [[ -n "$num" ]] || continue
  if [[ "$DRY_RUN" == true ]]; then
    printf 'DRY RUN: Would close PR #%s (branch: %s) and delete its branch.\n' "$num" "$branch"
  else
    printf 'Closing PR #%s (branch: %s)...\n' "$num" "$branch"
    # A failed close may already have closed the PR but failed branch deletion.
    # Report it rather than retrying the same PR or hiding a permissions error.
    if ! gh pr close "$num" --repo "$REPO" --delete-branch; then
      printf 'ERROR: Cleanup failed for PR #%s; inspect PR/branch state before retrying.\n' "$num" >&2
      exit 1
    fi
  fi
done <<< "$SELECTED_PRS"

printf 'Cleanup complete.\n'
