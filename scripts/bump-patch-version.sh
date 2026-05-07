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
COMMITS=$(git log --no-merges --oneline -n 15 | grep -iv "bump version" | grep -iv "chore: release" | python3 -c '
import sys
import re

logs = sys.stdin.readlines()
added = set()
fixed = set()
changed = set()

for line in logs:
    line = line.strip()
    if not line:
        continue
    # Strip emojis and non-ascii
    line = re.sub(r"[^\x00-\x7F]+", "", line).strip()

    # Check if starts with a commit hash and remove it
    line = re.sub(r"^[a-f0-9]{7,40}\s+", "", line).strip()

    if not line:
        continue

    if re.match(r"^feat(?:\([^)]+\))?:", line, re.IGNORECASE):
        added.add("- " + line)
    elif re.match(r"^fix(?:\([^)]+\))?:", line, re.IGNORECASE):
        fixed.add("- " + line)
    else:
        changed.add("- " + line)

output = ""
if added:
    output += "### Added\n" + "\n".join(sorted(added)) + "\n\n"
if fixed:
    output += "### Fixed\n" + "\n".join(sorted(fixed)) + "\n\n"
if changed:
    output += "### Changed\n" + "\n".join(sorted(changed)) + "\n\n"

print(output.strip())
' || true)

if [ -z "$COMMITS" ]; then
    COMMITS="### Changed\n- Assorted internal updates and fixes."
fi

# Prepare the new changelog entry
NEW_ENTRY="## [$NEW_VERSION] - $CURRENT_DATE\n\n$COMMITS\n"

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
