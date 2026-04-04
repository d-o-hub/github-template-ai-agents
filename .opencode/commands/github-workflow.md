---
description: Complete GitHub workflow - push, create branch/PR, monitor Actions with pre-existing issue detection, auto-merge/rebase when checks pass
subtask: false
---

#!/usr/bin/env bash
# GitHub Workflow Skill - Command wrapper
# Complete workflow: push → branch → PR → monitor → merge

set -euo pipefail

REPO_ROOT="$(cd "$(dirname "${BASH_SOURCE[0]}")/../.." && pwd)"
SKILL_SCRIPT="$REPO_ROOT/.agents/skills/github-workflow/run.sh"

if [[ ! -x "$SKILL_SCRIPT" ]]; then
    echo "Error: github-workflow skill not found at $SKILL_SCRIPT" >&2
    exit 1
fi

exec "$SKILL_SCRIPT" "$@"
