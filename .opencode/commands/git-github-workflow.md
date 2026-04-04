---
description: Unified atomic git workflow with GitHub integration - commits all changes, checks issues, creates PR, validates ALL Actions including pre-existing, uses swarm coordination with web research on failures. Post-merge validation of all files and docs.
subtask: false
---

#!/usr/bin/env bash
# Git-GitHub Workflow Skill - Command wrapper
# Unified workflow with swarm coordination

set -euo pipefail

REPO_ROOT="$(cd "$(dirname "${BASH_SOURCE[0]}")/../.." && pwd)"
SKILL_SCRIPT="$REPO_ROOT/.agents/skills/git-github-workflow/run.sh"

if [[ ! -x "$SKILL_SCRIPT" ]]; then
    echo "Error: git-github-workflow skill not found at $SKILL_SCRIPT" >&2
    exit 1
fi

exec "$SKILL_SCRIPT" "$@"
