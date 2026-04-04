---
description: Execute atomic commit workflow using the atomic-commit skill
subtask: false
---

#!/usr/bin/env bash
# Thin wrapper for atomic-commit skill
# Delegates to: .agents/skills/atomic-commit/run.sh

set -euo pipefail

REPO_ROOT="$(cd "$(dirname "${BASH_SOURCE[0]}")/../.." && pwd)"
SKILL_SCRIPT="$REPO_ROOT/.agents/skills/atomic-commit/run.sh"

if [[ ! -x "$SKILL_SCRIPT" ]]; then
    echo "Error: atomic-commit skill not found at $SKILL_SCRIPT" >&2
    exit 1
fi

exec "$SKILL_SCRIPT" "$@"
