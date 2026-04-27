#!/usr/bin/env bash
set -euo pipefail

# Check if GitHub CLI and jq are installed
if ! command -v gh &> /dev/null || ! command -v jq &> /dev/null; then
    echo "Error: GitHub CLI (gh) and jq are required."
    echo "Install gh: https://cli.github.com/"
    echo "Install jq: https://stedolan.github.io/jq/"
    exit 1
fi

# Check if running in CI mode
CI_MODE="${1:-}"

if [ "$CI_MODE" == "--ci" ]; then
    echo "Running in CI mode - skipping interactive prompts"
    # In CI, we don't delete existing labels to avoid race conditions
    # Labels should be managed separately or initialized once
    echo "Skipping label deletion in CI mode."
else
    # Interactive mode - prompt for confirmation
    read -r -p "Delete ALL existing labels? (y/N) " confirm

    # More robust confirmation check
    if [[ "$confirm" == "y" ]] || [[ "$confirm" == "Y" ]] || [[ "$confirm" == "yes" ]] || [[ "$confirm" == "YES" ]]; then
        echo "Deleting all existing labels..."

        # Get all label names and delete them
        # Use -r for raw output to avoid quoted strings, and -- to prevent arg injection
        label_names=$(gh label list --json name --jq '.[].name' -r)

        if [[ -n "$label_names" ]]; then
            echo "$label_names" | while IFS= read -r label; do
                if [[ -n "$label" ]]; then
                    echo "Deleting label: $label"
                    # Place flags before -- to ensure they are correctly parsed
                    gh label delete --yes -- "$label" || echo "Failed to delete: $label"
                fi
            done
            echo "Label deletion completed."
        else
            echo "No labels found to delete."
        fi
    else
        echo "Skipping label deletion."
    fi
fi

# Create new labels (use --force to avoid errors if label already exists)
# Place flags before -- to ensure they are correctly parsed
echo "Creating labels..."

gh label create --color d73a4a --description "Something isn't working" --force -- "bug"
gh label create --color a2eeef --description "New feature request" --force -- "feature"
gh label create --color 0075ca --description "Improvements or additions to documentation" --force -- "documentation"
gh label create --color d876e3 --description "Further information is requested" --force -- "question"
gh label create --color 8b949e --description "Open-ended conversation or design discussion" --force -- "discussion"
gh label create --color b60205 --description "Security-related issue" --force -- "security"
gh label create --color b60205 --description "Critical, needs immediate attention" --force -- "priority: high"
gh label create --color fbca04 --description "Important but not urgent" --force -- "priority: medium"
gh label create --color 0e8a16 --description "Low urgency, can wait" --force -- "priority: low"
gh label create --color e4e669 --description "Cannot proceed due to dependency/blocker" --force -- "blocked"
gh label create --color 1d76db --description "Currently being worked on" --force -- "status: in progress"
gh label create --color dbab09 --description "Waiting for review" --force -- "status: needs review"
gh label create --color e4e669 --description "Needs categorization or investigation" --force -- "status: needs triage"
gh label create --color cccccc --description "Duplicate of another issue/PR" --force -- "status: duplicate"
gh label create --color ffffff --description "Not planned to be fixed or implemented" --force -- "status: wontfix"
gh label create --color 0366d6 --description "Code improvements without behavior change" --force -- "refactor"
gh label create --color 5319e7 --description "Performance-related improvement" --force -- "performance"
gh label create --color f4c542 --description "Related to automated/manual tests" --force -- "tests"
gh label create --color fef2c0 --description "Maintenance task, tooling update, cleanup" --force -- "chore"
gh label create --color cfd3d7 --description "Dependency updates or changes" --force -- "deps"

echo "Label creation completed!"
