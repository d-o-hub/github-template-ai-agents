#!/bin/bash
# scripts/cleanup-ci-status-prs.sh
# This script closes stale CI status update PRs and deletes their associated branches.
# It requires the GitHub CLI (gh) to be installed and authenticated.

set -e

REPO=$(gh repo view --json nameWithOwner --jq '.nameWithOwner' 2>/dev/null || echo "d-o-hub/github-template-ai-agents")
STALE_PR_NUMBERS=("398" "399" "400" "402" "403")

echo "Cleaning up stale CI status PRs for $REPO..."

for PR_NUM in "${STALE_PR_NUMBERS[@]}"; do
  echo "Checking PR #$PR_NUM..."

  # Get PR info
  PR_INFO=$(gh pr view "$PR_NUM" --repo "$REPO" --json state,headRefName 2>/dev/null || true)

  if [[ -z "$PR_INFO" ]]; then
    echo "  PR #$PR_NUM not found or inaccessible. Skipping."
    continue
  fi

  STATE=$(echo "$PR_INFO" | jq -r '.state')
  BRANCH=$(echo "$PR_INFO" | jq -r '.headRefName')

  if [[ "$STATE" == "OPEN" ]]; then
    echo "  Closing PR #$PR_NUM..."
    gh pr close "$PR_NUM" --repo "$REPO"
  else
    echo "  PR #$PR_NUM is already $STATE."
  fi

  if [[ -n "$BRANCH" ]]; then
    echo "  Deleting branch $BRANCH..."
    gh api -X DELETE "repos/$REPO/git/refs/heads/$BRANCH" 2>/dev/null || echo "  Branch $BRANCH already deleted or not found."
  fi
done

# Also search for any other open PRs with the same title pattern
echo "Searching for any other open CI status update PRs..."
OTHER_PRS=$(gh pr list --repo "$REPO" --state open --search "ci: update ci status artifacts" --json number,headRefName --jq '.[] | "\(.number) \(.headRefName)"')

if [[ -z "$OTHER_PRS" ]]; then
  echo "No other stale PRs found."
else
  echo "$OTHER_PRS" | while read -r num branch; do
    if [[ -z "$num" ]]; then continue; fi
    echo "  Closing PR #$num..."
    gh pr close "$num" --repo "$REPO"
    echo "  Deleting branch $branch..."
    gh api -X DELETE "repos/$REPO/git/refs/heads/$branch" 2>/dev/null || echo "  Branch $branch already deleted or not found."
  done
fi

echo "Cleanup complete."
