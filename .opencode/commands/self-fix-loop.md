---
description: Self-learning fix loop - commit, push, monitor CI, auto-fix failures using swarm agents with skills on demand, loop until all checks pass
subtask: false
---

#!/usr/bin/env bash
# Self-Fix Loop - Command wrapper
# Automated commit, push, monitor, fix, retry cycle using swarm agents

set -euo pipefail

REPO_ROOT="$(cd "$(dirname "${BASH_SOURCE[0]}")/../.." && pwd)"
SKILL_SCRIPT="$REPO_ROOT/scripts/self-fix-loop.sh"

if [[ ! -x "$SKILL_SCRIPT" ]]; then
    echo "Error: self-fix-loop script not found at $SKILL_SCRIPT" >&2
    exit 1
fi

exec "$SKILL_SCRIPT" "$@"
