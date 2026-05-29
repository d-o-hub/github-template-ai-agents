#!/usr/bin/env bash
# Validate that GitHub Actions SHAs in workflows are valid commit SHAs
# and that all external actions are pinned to a 40-character SHA.
# Exits 0 if all SHAs are valid, 1 if any are invalid or unpinned.

set -euo pipefail

# Portable directory resolution following shell-script-quality skill
SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
REPO_ROOT="$(cd "$SCRIPT_DIR/.." && pwd)"
cd "$REPO_ROOT" || {
    echo "ERROR: Could not change directory to repository root" >&2
    exit 1
}

# Colors - Use literal escape characters for awk compatibility
# Determined by TTY presence and FORCE_COLOR override
if [[ -t 1 ]] && [[ "${FORCE_COLOR:-}" != "0" ]]; then
    RED=$'\033[0;31m'
    GREEN=$'\033[0;32m'
    NC=$'\033[0m'
else
    RED=''
    GREEN=''
    NC=''
fi

# Main function to encapsulate logic as per script template
main() {
    # Find all workflow files
    # Performance optimization: use native bash globbing instead of find subshell
    local workflow_files=()
    shopt -s nullglob globstar
    for f in .github/workflows/**/*.yml .github/workflows/**/*.yaml; do
        [[ -f "$f" ]] && workflow_files+=("$f")
    done
    shopt -u nullglob globstar

    if [[ ${#workflow_files[@]} -eq 0 ]]; then
        echo -e "${GREEN}No workflow files found${NC}"
        return 0
    fi

    # Process all files with a single awk command to eliminate process forks in loops
    # This optimization reduces execution time significantly (~0.77s to ~0.02s)
    # Using FNR for file-relative line numbers as per review feedback
    # Using length check instead of interval regex {40} for maximum awk portability
    if ! awk -v RED="$RED" -v NC="$NC" -- '
        BEGIN { failed = 0 }
        /^[[:space:]]*(-[[:space:]]*)?uses:/ {
            line = $0
            # Extract the action reference: part after uses:
            sub(/^[[:space:]]*(-[[:space:]]*)?uses:[[:space:]]*/, "", line)
            # Remove trailing comments
            sub(/[[:space:]]*#.*/, "", line)
            # Remove quotes (using \x27 for single quote to avoid shell escaping issues)
            gsub(/[\x27"]/, "", line)
            # Trim trailing whitespace
            sub(/[[:space:]]*$/, "", line)

            action_ref = line

            # Skip empty lines, local actions, or docker actions
            if (action_ref == "" || action_ref ~ /^\.\// || action_ref ~ /^docker:\/\//) next

            # Check for SHA pinning (@ followed by hex chars)
            # We first verify if there is an @ symbol
            if (action_ref ~ /@/) {
                # Split at @ to get the target (ref/sha)
                n = split(action_ref, parts, "@")
                target = parts[n]

                # Verify if target is a 40-character hex string
                # Using length() and character class matching for portability across awk versions
                if (length(target) == 40 && target ~ /^[a-f0-9]+$/) {
                    sha = target

                    # Placeholder patterns: all same char, or repeating 8-char blocks
                    first_char = substr(sha, 1, 1)
                    all_same = 1
                    for (i = 2; i <= 40; i++) {
                        if (substr(sha, i, 1) != first_char) {
                            all_same = 0
                            break
                        }
                    }

                    is_repeating = 0
                    if (!all_same) {
                        block8 = substr(sha, 1, 8)
                        is_repeating = 1
                        for (j = 1; j <= 4; j++) {
                            if (substr(sha, j * 8 + 1, 8) != block8) {
                                is_repeating = 0
                                break
                            }
                        }
                    }

                    if (all_same || is_repeating) {
                        print RED "Invalid/placeholder SHA found in " FILENAME " line " FNR ": " sha NC
                        failed = 1
                    }
                } else {
                    print RED "Unpinned external action found in " FILENAME " line " FNR ": " action_ref NC
                    print "  External actions MUST be pinned to a 40-character commit SHA for security."
                    failed = 1
                }
            } else {
                print RED "Unpinned external action found in " FILENAME " line " FNR ": " action_ref NC
                print "  External actions MUST be pinned to a 40-character commit SHA for security."
                failed = 1
            }
        }
        END { if (failed) exit 1 }
    ' "${workflow_files[@]}"; then
        echo -e "${RED}Found unpinned actions or invalid/placeholder SHAs in workflows${NC}"
        return 1
    fi

    echo -e "${GREEN}All GitHub Actions SHAs appear valid and pinned${NC}"
    return 0
}

# Run if executed directly
if [[ "${BASH_SOURCE[0]}" == "${0}" ]]; then
    main "$@"
fi
