#!/usr/bin/env bash
# persist-ci-status.sh - Commit .github/ci-status/ artifacts and sync them to the default branch.
#
# Tries a direct push to `main` first. Because the repo's branch ruleset requires a PR
# for `main` (the GITHUB_TOKEN cannot bypass it), direct pushes are rejected — historically
# this was masked by `continue-on-error: true`, leaving ci-status.json stale for weeks
# (e.g. last_run 2026-06-18 while main kept merging). This script falls back to pushing to
# a `ci/ci-status-update` branch and opening (or re-pointing) an `automerge`-labeled PR so
# the template's auto-merge-non-deps workflow merges it once required checks pass.
set -euo pipefail

BRANCH="${CI_STATUS_SYNC_BRANCH:-ci/ci-status-update}"
LABEL="${CI_STATUS_SYNC_LABEL:-automerge}"
TITLE="${CI_STATUS_TITLE:-ci: update ci status artifacts [skip ci]}"
BODY="${CI_STATUS_BODY:-Automated CI status artifacts update. Merged by the template automerge workflow.}"

git config user.name "github-actions[bot]"
git config user.email "github-actions[bot]@users.noreply.github.com"

git add .github/ci-status/
if git diff --staged --quiet; then
  printf 'No changes to CI status artifacts; nothing to persist.\n'
  exit 0
fi

git commit -m "$TITLE"

if git push origin HEAD:main; then
  printf 'Pushed CI status artifacts directly to main.\n'
  exit 0
fi

printf 'Direct push to main rejected by branch ruleset; opening an automerge PR instead.\n' >&2

git push --force origin "HEAD:$BRANCH" 2>&1 | sed 's/^/  /'

pr_number="$(gh pr list --base main --head "$BRANCH" --state open --json number --jq '.[0].number // empty' 2>/dev/null || true)"
if [[ -n "$pr_number" ]]; then
  gh pr edit "$pr_number" --title "$TITLE" --body "$BODY" --add-label "$LABEL" >/dev/null 2>&1 || true
  printf 'Updated existing CI status PR #%s.\n' "$pr_number"
  exit 0
fi

pr_url="$(gh pr create --base main --head "$BRANCH" --title "$TITLE" --body "$BODY" --label "$LABEL" 2>/dev/null || true)"
if [[ -n "$pr_url" ]]; then
  # perf: replace external basename subshell with native bash expansion
  pr_number="${pr_url##*/}"
  printf 'Created CI status PR #%s.\n' "$pr_number"
else
  printf 'WARNING: could not create/update CI status PR for branch %s.\n' "$BRANCH" >&2
  exit 1
fi
