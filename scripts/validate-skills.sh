#!/usr/bin/env bash
# Validates all CLI skill symlinks point to existing .agents/skills/ directories.
# Used in pre-commit hook and CI. Exit 2 on failure (surfaced to agent).
set -euo pipefail

REPO_ROOT="$(cd "$(dirname "${BASH_SOURCE[0]}")/.."; pwd)"
SKILLS_SRC="$REPO_ROOT/.agents/skills"

CLI_SKILL_DIRS=(
  ".claude/skills"
  ".opencode/agent"
  ".gemini/skills"
)

FAILED=0

# If no skills exist, nothing to validate
if [ ! -d "$SKILLS_SRC" ] || [ -z "$(ls -A "$SKILLS_SRC" 2>/dev/null)" ]; then
  echo "No skills in .agents/skills/ - nothing to validate."
  exit 0
fi

for skill_path in "$SKILLS_SRC"/*/; do
  [ -d "$skill_path" ] || continue
  skill_name="$(basename "$skill_path")"

  for cli_dir in "${CLI_SKILL_DIRS[@]}"; do
    link="$REPO_ROOT/$cli_dir/$skill_name"
    if [ ! -L "$link" ]; then
      echo "MISSING symlink: $cli_dir/$skill_name" >&2
      FAILED=1
    elif [ ! -d "$link" ]; then
      echo "BROKEN symlink: $cli_dir/$skill_name -> $(readlink "$link")" >&2
      FAILED=1
    fi
  done
done

if [ $FAILED -ne 0 ]; then
  echo "" >&2
  echo "Run: ./scripts/setup-skills.sh to fix missing symlinks." >&2
  exit 2
fi

echo "All skill symlinks valid."