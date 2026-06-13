#!/usr/bin/env bash
set -euo pipefail

if ! command -v gh &> /dev/null || ! command -v jq &> /dev/null; then
    printf "Error: GitHub CLI (gh) and jq are required.\n" >&2
    exit 1
fi

CI_MODE="${1:-}"

if [[ "$CI_MODE" == "--ci" ]]; then
    printf "Running in CI mode - skipping interactive prompts\n"
    printf "Skipping label deletion in CI mode.\n"
else
    # Interactive mode check disabled for MCP
    confirm="n"
    if [[ "$confirm" =~ ^[yY](es)?$ ]]; then
        printf "Deleting all existing labels...\n"
        label_names=$(gh label list --json name --jq ".[].name")
        if [[ -n "$label_names" ]]; then
            printf "%s\n" "$label_names" | while IFS= read -r label; do
                if [[ -n "$label" ]]; then
                    printf "Deleting label: %s\n" "$label"
                    gh label delete --yes -- "$label" || true
                    sleep 0.2
                fi
            done
        fi
    fi
fi

create_label() {
    local color="$1"
    local desc="$2"
    local name="$3"
    sleep 1
    if ! gh label create --color "$color" --description "$desc" --force -- "$name"; then
        printf "Attempt 1 failed for %s. Retrying in 5s...\n" "$name" >&2
        sleep 5
        gh label create --color "$color" --description "$desc" --force -- "$name"
    fi
}

printf "Creating labels...\n"
create_label "d73a4a" "Something isn't working" "bug"
create_label "a2eeef" "New feature request" "feature"
create_label "0075ca" "Improvements or additions to documentation" "documentation"
create_label "d876e3" "Further information is requested" "question"
create_label "8b949e" "Open-ended conversation or design discussion" "discussion"
create_label "b60205" "Security-related issue" "security"
create_label "b60205" "Critical, needs immediate attention" "priority: high"
create_label "fbca04" "Important but not urgent" "priority: medium"
create_label "0e8a16" "Low urgency, can wait" "priority: low"
create_label "e4e669" "Cannot proceed due to dependency/blocker" "blocked"
create_label "1d76db" "Currently being worked on" "status: in progress"
create_label "dbab09" "Waiting for review" "status: needs review"
create_label "e4e669" "Needs categorization or investigation" "status: needs triage"
create_label "cccccc" "Duplicate of another issue/PR" "status: duplicate"
create_label "ffffff" "Not planned to be fixed or implemented" "status: wontfix"
create_label "0366d6" "Code improvements without behavior change" "refactor"
create_label "5319e7" "Performance-related improvement" "performance"
create_label "f4c542" "Related to automated/manual tests" "tests"
create_label "fef2c0" "Maintenance task, tooling update, cleanup" "chore"
create_label "cfd3d7" "Dependency updates or changes" "deps"
create_label "d4c5f9" "CI status tracking PR - exempt from stale automation" "ci-status"

printf "Label creation completed!\n"
