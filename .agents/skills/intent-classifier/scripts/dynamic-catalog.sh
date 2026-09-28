#!/usr/bin/env bash
# dynamic-catalog.sh - DEPRECATED shim; delegates to the canonical generator.
#
# This script used to write the intent-classifier catalog itself, in a private
# format with a 100-character description budget. That was a landmine: the
# catalog is a ROUTING table, and the discriminators intent-classifier needs --
# the "Not for <sibling>" guard and the secondary trigger phrases -- live at the
# TAIL of each description, exactly where a blind character slice lands.
# Measured against the live tree, 52 of 54 descriptions were cut mid-sentence
# and the guards went from 50/50 present to 2/50, silently re-breaking routing
# for any agent that followed this script instead of the canonical one.
#
# The canonical generator is scripts/generate-skill-catalog.sh. It owns the
# output file, carries the 1024-char budget with word-boundary elision and
# guard retention, and is covered by tests/test-generate-skill-catalog.bats.
#
# This shim is kept only so the previously documented command keeps working.
# It can no longer produce a worse catalog: it has no catalog logic of its own.
#
# Usage: .agents/skills/intent-classifier/scripts/dynamic-catalog.sh [SKILLS_DIR]

set -euo pipefail

# Get repository root for portable paths
REPO_ROOT="$(cd "$(dirname "${BASH_SOURCE[0]}")/../../../../" && pwd)"
CANONICAL_GENERATOR="$REPO_ROOT/scripts/generate-skill-catalog.sh"
CATALOG_FILE="$REPO_ROOT/.agents/skills/intent-classifier/references/skill-catalog.md"

if [[ ! -x "$CANONICAL_GENERATOR" ]]; then
    printf 'Error: canonical catalog generator not found or not executable: %s\n' \
        "$CANONICAL_GENERATOR" >&2
    exit 1
fi

# Pin the output to the canonical catalog path, matching the target this shim
# always wrote to, and forward a legacy positional skills-dir argument through
# the environment variable the canonical generator already reads.
export OUTPUT_FILE="$CATALOG_FILE"
if [[ $# -ge 1 ]]; then
    export SKILLS_DIR="$1"
fi

# Deprecation notice on stderr so the canonical generator's stdout stays
# machine-parseable for anything that consumes it.
printf 'dynamic-catalog.sh is deprecated; delegating to %s\n' "$CANONICAL_GENERATOR" >&2

exec "$CANONICAL_GENERATOR"
