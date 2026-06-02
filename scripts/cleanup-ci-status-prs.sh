#!/bin/bash
# scripts/cleanup-ci-status-prs.sh
# This script closes stale CI status update PRs and deletes their associated branches.
# It requires the GitHub CLI (gh) to be installed and authenticated.

set -e

REPO=$(gh repo view --json nameWithOwner --jq '.nameWithOwner' 2>/dev/null || printf "%s\n" "d-o-hub/github-template-ai-agents")

printf "%s\n" "Searching for open CI status update PRs authored by github-actions[bot]..."
# We target PRs with the specific title and authored by the bot
PRS_TO_CLEAN=$(gh pr list --repo "$REPO" --author "github-actions[bot]" --state open --search "ci: update ci status artifacts" --json number,headRefName --jq '.[] | "\(.number) \(.headRefName)"' 2>/dev/null || printf "%s\n" "")

if [[ -z "$PRS_TO_CLEAN" ]]; then
  printf "%s\n" "No stale PRs found."
else
  printf "Found PRs to clean up:\n"
  printf "%s\n" "$PRS_TO_CLEAN"

  printf "%s\n" "$PRS_TO_CLEAN" | while read -r num branch; do
    if [[ -z "$num" ]]; then continue; fi
    printf "%s\n" "  Closing PR #$num and deleting branch $branch..."
    gh pr close "$num" --repo "$REPO" --delete-branch 2>/dev/null || {
      printf "%s\n" "    Manual cleanup for PR #$num..."
      gh pr close "$num" --repo "$REPO" || true
      gh api -X DELETE "repos/$REPO/git/refs/heads/$branch" 2>/dev/null || true
    }
  done
fi

printf "%s\n" "Cleanup complete."
