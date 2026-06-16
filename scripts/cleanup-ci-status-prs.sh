#!/usr/bin/env bash
# scripts/cleanup-ci-status-prs.sh
# This script closes stale CI status update PRs and deletes their associated branches.
# It requires the GitHub CLI (gh) to be installed and authenticated.

set -e

REPO=$(gh repo view --json nameWithOwner --jq '.nameWithOwner' 2>/dev/null || printf "%s\n" "d-o-hub/github-template-ai-agents")

# Fail fast if gh is not authenticated
gh auth status >/dev/null 2>&1 || { printf "ERROR: gh not authenticated\n" >&2; exit 1; }

# Close stale automated PRs that should have been auto-merged but weren't.
# These are authored by bots and use fixed branches (auto/*, ci/*).
# Pattern 1: CI status update PRs from github-actions[bot]
# Pattern 2: LLM context regeneration PRs from github-actions[bot]
# Pattern 3: Any bot-authored PR on auto/* or ci/* branches older than 1 day
#   (stale threshold: 86400s = 24h; cleanup runs every 6h, so worst case ~30h)

close_prs() {
  local description="$1"
  local prs_input="$2"

  if [[ -z "$prs_input" ]]; then
    return 0
  fi

  printf "Found %s:\n" "$description"
  printf "%s\n" "$prs_input"

  local old_ifs="$IFS"
  IFS=$'\n'
  set -f
  local prs_array=($prs_input)
  set +f
  IFS="$old_ifs"

  for line in "${prs_array[@]}"; do
    local num="${line%% *}"
    local branch="${line#* }"
    if [[ -z "$num" ]]; then continue; fi
    printf "%s\n" "  Closing PR #$num (branch: $branch)..."
    gh pr close "$num" --repo "$REPO" --delete-branch 2>/dev/null || {
      printf "%s\n" "    Retrying close without branch delete for PR #$num..."
      gh pr close "$num" --repo "$REPO" || true
      gh api -X DELETE "repos/$REPO/git/refs/heads/$branch" 2>/dev/null || true
    }
  done
}

printf "%s\n" "Searching for stale automated PRs..."

# CI status update PRs
CI_PRS=$(gh pr list --repo "$REPO" --author "github-actions[bot]" --state open \
  --search "ci: update ci status artifacts" \
  --json number,headRefName --jq '.[] | "\(.number) \(.headRefName)"' 2>/dev/null || true)
close_prs "stale CI status update PRs" "$CI_PRS"

# LLM context regeneration PRs
LLM_PRS=$(gh pr list --repo "$REPO" --author "github-actions[bot]" --state open \
  --search "ci: regenerate llms.txt" \
  --json number,headRefName --jq '.[] | "\(.number) \(.headRefName)"' 2>/dev/null || true)
close_prs "stale LLM context regeneration PRs" "$LLM_PRS"

# Any remaining bot PRs on auto/* or ci/* branches older than 24 hours
STALE_BOT_PRS=$(gh pr list --repo "$REPO" --state open \
  --json number,headRefName,author,createdAt \
  --jq '[.[] | select(
    (.author.login == "github-actions[bot]" or .author.login == "app/github-actions") and
    ((.headRefName | startswith("auto/")) or (.headRefName | startswith("ci/"))) and
    ((now - (.createdAt | fromdateiso8601)) > 86400)
  )] | .[] | "\(.number) \(.headRefName)"' 2>/dev/null || true)
close_prs "stale bot PRs on auto/ci branches (>24h old)" "$STALE_BOT_PRS"

printf "%s\n" "Cleanup complete."
