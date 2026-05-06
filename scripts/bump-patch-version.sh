#!/usr/bin/env bash
# Automatically bumps the patch version, updates CHANGELOG-TEMPLATE.md with recent commits,
# and propagates the version.
set -euo pipefail

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
REPO_ROOT="$(dirname "$SCRIPT_DIR")"
cd "$REPO_ROOT"

if [ ! -f "VERSION" ]; then
    echo "Error: VERSION file not found"
    exit 1
fi

CURRENT_VERSION=$(cat VERSION | tr -d "[:space:]")

# Strictly validate semantic version format
if [[ ! "$CURRENT_VERSION" =~ ^([0-9]+)\.([0-9]+)\.([0-9]+)$ ]]; then
    echo "Error: VERSION must be a strict semantic version (e.g., 1.2.3)" >&2
    exit 1
fi

MAJOR="${BASH_REMATCH[1]}"
MINOR="${BASH_REMATCH[2]}"
PATCH="${BASH_REMATCH[3]}"

NEW_PATCH=$((PATCH + 1))
NEW_VERSION="${MAJOR}.${MINOR}.${NEW_PATCH}"
CURRENT_DATE=$(date +"%Y-%m-%d")

echo "Bumping version from $CURRENT_VERSION to $NEW_VERSION"

# Write new version
echo "$NEW_VERSION" > VERSION

# Generate changelog summary from git log
# Fetch recent commits to use for the changelog (e.g. last 15, ignoring merge commits and version bumps)
echo "Fetching recent commits..."
COMMITS=$(git log --no-merges --oneline -n 15 | grep -iv "bump version" | grep -iv "chore: release" | awk '{$1="-"; print $0}' || true)

if [ -z "$COMMITS" ]; then
    COMMITS="- Assorted internal updates and fixes."
fi

# Prepare the new changelog entry
NEW_ENTRY="## [$NEW_VERSION] - $CURRENT_DATE\n\n### Changed\n$COMMITS\n"

# Insert the new entry into CHANGELOG-TEMPLATE.md right after ## [Unreleased]
if grep -q "^## \[Unreleased\]" CHANGELOG-TEMPLATE.md; then
    # Use awk to insert after Unreleased section
    awk -v new_entry="$NEW_ENTRY" '
    /^## \[Unreleased\]/ {
        print
        print ""
        printf "%s", new_entry
        next
    }
    {print}
    ' CHANGELOG-TEMPLATE.md > CHANGELOG-TEMPLATE.md.tmp
    mv CHANGELOG-TEMPLATE.md.tmp CHANGELOG-TEMPLATE.md
    echo "Updated CHANGELOG-TEMPLATE.md"
else
    echo "Warning: ## [Unreleased] not found in CHANGELOG-TEMPLATE.md"
fi

# Propagate the new version using the existing script
echo "Running scripts/propagate-version.sh..."
"$SCRIPT_DIR/propagate-version.sh"

echo "Version successfully bumped to $NEW_VERSION!"
