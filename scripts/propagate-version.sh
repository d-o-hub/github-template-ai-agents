#!/usr/bin/env bash
# Propagate VERSION to all files that reference it.
# Single source of truth: VERSION file
# Exit 0 = success, Exit 1 = error
set -euo pipefail

REPO_ROOT="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
cd "$REPO_ROOT"

# Read version from single source of truth
if [[ ! -f "VERSION" ]]; then
    echo "Error: VERSION file not found" >&2
    exit 1
fi

VERSION=$(tr -d '[:space:]' < VERSION)

if [[ -z "$VERSION" ]]; then
    echo "Error: VERSION file is empty" >&2
    exit 1
fi

# Security: Strictly validate semantic version format to prevent sed injection
if [[ ! "$VERSION" =~ ^[0-9]+\.[0-9]+\.[0-9]+$ ]]; then
    echo "Error: VERSION must be a strict semantic version (e.g., 1.2.3)" >&2
    exit 1
fi

echo "Propagating version $VERSION..."

# `sed -i` is a GNU extension (BSD sed demands `-i ''`), and `\+` is a GNU basic-regex escape
# that BSD sed does not accept, so every edit here runs `sed -E` — extended syntax, portable
# between both — into a temp file, then copies it back through `cat >` to keep the tracked
# file's inode, mode and ownership.
_substitute() {
    local expr="$1"
    local file="$2"
    local tmp
    tmp=$(mktemp)
    trap 'rm -f -- "$tmp"' RETURN
    sed -E "$expr" "$file" > "$tmp"
    cat -- "$tmp" > "$file"
}

# Files that contain version badges or references
# Pattern: version-0.X.Y in badges, Template version: X.Y.Z in text
FILES_TO_UPDATE=(
    "README.md"
    "QUICKSTART.md"
    "agents-docs/MIGRATION.md"
    ".template/CHANGELOG-TEMPLATE.md"
    "agents-docs/VERSION.md"
    "analysis/SWARM_ANALYSIS.md"
)

UPDATED=0

for file in "${FILES_TO_UPDATE[@]}"; do
    if [[ ! -f "$file" ]]; then
        echo "Warning: $file not found, skipping"
        continue
    fi

    # perf: read file content once to eliminate multiple grep subshells
    content=$(<"$file")

    # Update version badges: version-0.X.Y -> version-NEW_VERSION
    if [[ "$content" == *"version-"[0-9]* ]]; then
        _substitute "s/version-[0-9]+\.[0-9]+\.[0-9]+/version-${VERSION}/g" "$file"
        UPDATED=1
        echo "  Updated version badge in $file"
    fi

    # Update "Template version: X.Y.Z" text
    if [[ "$content" == *"Template version:"* ]]; then
        _substitute "s/Template version: [0-9]+\.[0-9]+\.[0-9]+/Template version: ${VERSION}/g" "$file"
        UPDATED=1
        echo "  Updated template version in $file"
    fi

    # Update "**Version:** X.Y.Z" text
    if [[ "$content" =~ \*\*Version:\*\*\ [0-9]+\.[0-9]+\.[0-9]+ ]]; then
        _substitute 's/\*\*Version:\*\* [0-9]+\.[0-9]+\.[0-9]+/**Version:** '"${VERSION}"'/g' "$file"
        UPDATED=1
        echo "  Updated **Version:** text in $file"
    fi

    # Update "| \`VERSION\` | \`X.Y.Z\` |" text in tables. In ERE an unescaped `|` is
    # alternation, so the match-side pipes go into bracket expressions — portable on both GNU
    # and BSD sed, unlike `\|`, whose meaning there is undefined. The replacement-side pipes
    # are literal and need no escaping.
    if [[ "$content" =~ \|\ \`VERSION\`\ \|\ \`[0-9]+\.[0-9]+\.[0-9]+\`\ \| ]]; then
        _substitute 's/[|] `VERSION` [|] `[0-9]+\.[0-9]+\.[0-9]+` [|]/| `VERSION` | `'"${VERSION}"'` |/g' "$file"
        UPDATED=1
        echo "  Updated table VERSION text in $file"
    fi
done

# Update CHANGELOG.md - add unreleased section if missing
if [[ -f "CHANGELOG.md" ]]; then
    # perf: replace grep subshell with native bash regex match
    content=$(<CHANGELOG.md)
    if [[ ! "$content" =~ (^|$'\n')##\ \[Unreleased\] ]]; then
        # `sed "1a\…"` is another GNU-only form. Rebuild the file instead: keep the first line,
        # insert the heading under it, and preserve whatever followed. The empty-body branch is
        # deliberate — the old GNU append left a blank line at EOF, which markdownlint rejects
        # as MD012, so a one-line changelog must end after the heading.
        if [[ "$content" == *$'\n'* ]]; then
            header="${content%%$'\n'*}"
            body="${content#*$'\n'}"
        else
            header="$content"
            body=""
        fi
        if [[ -n "$body" ]]; then
            printf '%s\n\n## [Unreleased]\n\n%s\n' "$header" "$body" > CHANGELOG.md
        else
            printf '%s\n\n## [Unreleased]\n' "$header" > CHANGELOG.md
        fi
        echo "  Added [Unreleased] section to CHANGELOG.md"
        UPDATED=1
    fi
fi

if [[ $UPDATED -eq 0 ]]; then
    echo "  No updates needed"
else
    echo "Version $VERSION propagated successfully"
fi
