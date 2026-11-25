#!/usr/bin/env bash
# lib/phase-pr.sh - Phase 3 CREATE PR agent function for the Git-GitHub workflow
# skill. Sourced by ../../run.sh.
# shellcheck disable=SC2086,SC2154,SC2164
# Verbatim phase code from the former single-file run.sh. The sourcing run.sh
# defines the config/state globals, logging helpers, readonly error codes, and
# the strict shell options used below; that cross-file contract is invisible
# here, so SC2154 (never-assigned globals), SC2086 (unquoted expansions of those
# readonly constants), and SC2164 (cd guarded by the caller's errexit) are
# suppressed with this documented reason.
# Agent 3: CREATE PR
agent_create_pr() {
    agent "AGENT 3: CREATE PR"
    log "═══════════════════════════════════════════════════════════════════"
    
    if ! command -v gh &>/dev/null; then
        error "GitHub CLI required for PR creation"
        return $E_PR_FAILED
    fi
    
    if [[ "$DRY_RUN" == true ]]; then
        log "[DRY-RUN] Would push and create PR"
        PR_NUMBER="DRY-RUN-123"
        return 0
    fi
    
    cd "$REPO_ROOT"
    
    # Push branch
    log "Pushing branch $BRANCH_NAME..."
    if ! git push -u origin "$BRANCH_NAME" 2>&1; then
        error "Failed to push branch"
        return $E_PR_FAILED
    fi
    
    # Check for existing PR
    local existing_pr=$(gh pr list --head "$BRANCH_NAME" --json number --jq '.[0].number' 2>/dev/null || echo "")
    
    if [[ -n "$existing_pr" && "$existing_pr" != "null" ]]; then
        PR_NUMBER="$existing_pr"
        log "Using existing PR #$PR_NUMBER"
    else
        # Create PR body
        local pr_body="## Summary

$MESSAGE

## Changes

$(git log --oneline origin/main..HEAD 2>/dev/null | sed 's/^/- /' | head -20)

## Workflow

- **Branch:** \`$BRANCH_NAME\`
- **Commit:** \`${COMMIT_SHA:0:8}\`
- **Type:** $(echo "$MESSAGE" | grep -oE '^(feat|fix|docs|refactor|test|ci|chore)' || echo "workflow")

## Checklist

- [x] All changes committed
- [x] Quality gate passed
- [x] PR created
- [ ] All GitHub Actions passing
- [ ] Ready for merge"

        log "Creating pull request..."
        local pr_output
        if ! pr_output=$(gh pr create \
            --title "$MESSAGE" \
            --body "$pr_body" \
            --base "main" \
            --head "$BRANCH_NAME" 2>&1); then
            error "Failed to create PR: $pr_output"
            return $E_PR_FAILED
        fi
        
        PR_NUMBER=$(echo "$pr_output" | grep -oE '[0-9]+$' || echo "")
        if [[ -z "$PR_NUMBER" ]]; then
            PR_NUMBER=$(gh pr view --json number --jq '.number' 2>/dev/null || echo "")
        fi
    fi
    
    PR_URL=$(gh pr view "$PR_NUMBER" --json url --jq '.url' 2>/dev/null || echo "")
    success "PR #$PR_NUMBER created: $PR_URL"
    
    return 0
}
