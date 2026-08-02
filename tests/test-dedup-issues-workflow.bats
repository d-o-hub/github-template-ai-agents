#!/usr/bin/env bats
# BATS tests for dedup-issues.yml workflow
# Validates: opt-in gating (ADR-032), manual dispatch escape hatch,
#            grace-period marker consistency, least-privilege permissions

setup() {
    REPO_ROOT="$(cd "$(dirname "$BATS_TEST_FILENAME")/.." && pwd)"
    WORKFLOW_FILE="$REPO_ROOT/.github/workflows/dedup-issues.yml"
}

@test "dedup workflow file exists" {
    [ -f "$WORKFLOW_FILE" ]
}

@test "dedup workflow is gated behind MAINTAINER_AUTOMATION (auto-close job)" {
    # Mutating automation is disabled by default for template adopters (ADR-032)
    grep -q "vars.MAINTAINER_AUTOMATION == 'true'" "$WORKFLOW_FILE"
}

@test "dedup detection job is gated on the automatic issues trigger" {
    # The third-party LLM + rule-based detection must not label issues on
    # every open/reopen unless the maintainer opted in (ADR-032)
    grep -q "github.event_name == 'issues' && github.event.issue.user.type != 'Bot'" "$WORKFLOW_FILE"
}

@test "dedup manual workflow_dispatch with issue_number stays available" {
    # Explicit human action remains an escape hatch even when automation is off
    grep -q "github.event_name == 'workflow_dispatch' && github.event.inputs.issue_number != ''" "$WORKFLOW_FILE"
}

@test "dedup auto-close job requires the automation gate on schedule" {
    # auto-close must not run on the daily schedule without the opt-in variable
    grep -q "github.event_name == 'schedule'" "$WORKFLOW_FILE"
    grep -q "vars.MAINTAINER_AUTOMATION == 'true'" "$WORKFLOW_FILE"
}

@test "dedup grace-period marker is consistent between detection and auto-close" {
    # The detection job posts 'auto-closed after 3 days' and the auto-close
    # job searches for the same string to find the flag timestamp.
    detection_marker=$(grep -o "auto-closed after 3 days" "$WORKFLOW_FILE" | wc -l)
    [ "$detection_marker" -ge 1 ]
    # auto-close search must reference the exact same marker text
    grep -q "c.body.includes('auto-closed after 3 days')" "$WORKFLOW_FILE"
}

@test "dedup workflow does NOT request pull-requests write permission" {
    # Cross-referenced PRs are never auto-closed (ADR-032); the permission
    # would be an unused write grant that ships to every adopter.
    ! grep -q "pull-requests: write" "$WORKFLOW_FILE"
}

@test "dedup workflow does NOT close cross-referenced PRs" {
    # A PR referencing a flagged issue may be a legitimate implementation in
    # flight; only the duplicate issue itself is ever closed (ADR-032).
    ! grep -q "pulls.update" "$WORKFLOW_FILE"
    ! grep -q "pulls.get" "$WORKFLOW_FILE"
}

@test "dedup workflow has the yamllint truthy disable comment" {
    grep -q "yamllint disable-line rule:truthy" "$WORKFLOW_FILE"
}

@test "dedup workflow triggers on issues, schedule, and manual dispatch" {
    grep -q "types: \[opened, reopened\]" "$WORKFLOW_FILE"
    grep -q "schedule:" "$WORKFLOW_FILE"
    grep -q "workflow_dispatch:" "$WORKFLOW_FILE"
}

@test "dedup workflow has issues write permission" {
    # Still needed: detection labels and auto-close mutates issues
    grep -q "issues: write" "$WORKFLOW_FILE"
}
