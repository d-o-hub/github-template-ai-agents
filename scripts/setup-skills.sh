#!/usr/bin/env bash
# Creates symlinks from CLI-specific folders -> .agents/skills/ (canonical source)
# Run once after cloning: ./scripts/setup-skills.sh
# Note: OpenCode reads skills directly from .agents/skills/ - no symlinks needed.
set -euo pipefail

REPO_ROOT="$(cd "$(dirname "${BASH_SOURCE[0]}")/.."; pwd)"
SKILLS_SRC="$REPO_ROOT/.agents/skills"

# CLI folders that should contain symlinks to canonical skills
# (OpenCode reads directly from .agents/skills/ - not included here)
# (Qwen CLI also reads directly from .agents/skills/ - directory created for consistency)
SKILLS_OPTIONAL=(
  "eu-ai-act-compliance"
  "durable-objects"
)

CLI_SKILL_DIRS=(
  ".claude/skills"
  ".qwen/skills"
)

if [[ ! -d "$SKILLS_SRC" ]]; then
  printf "No skills found at .agents/skills/ - nothing to symlink.\n"
  exit 0
fi

printf "Setting up skill symlinks from .agents/skills/...\n"

for cli_dir in "${CLI_SKILL_DIRS[@]}"; do
  target_dir="$REPO_ROOT/$cli_dir"
  mkdir -p -- "$target_dir"

  # Performance optimization: Pre-calculate relative path base once per target dir
  # to avoid O(N) subshell calls in the inner loop.
  rel_base=$(realpath --relative-to="$target_dir" "$SKILLS_SRC")

  for skill_path in "$SKILLS_SRC"/*/; do
    [ -d "$skill_path" ] || continue

    # Performance optimization: Use Bash parameter expansion instead of basename
    skill_name="${skill_path%/}"
    skill_name="${skill_name##*/}"

    # Check if skill is optional
    is_optional=false
    for opt in "${SKILLS_OPTIONAL[@]}"; do
      if [[ "$skill_name" == "$opt" ]]; then
        is_optional=true
        break
      fi
    done

    if [[ "$is_optional" == true ]] && [[ "${LINK_OPTIONAL:-false}" != "true" ]]; then
      printf "  skip (optional): %s/%s\n" "$cli_dir" "$skill_name"
      continue
    fi

    link="$target_dir/$skill_name"
    # Performance optimization: Use pre-calculated base
    rel="$rel_base/$skill_name"

    if [[ -L "$link" ]]; then
      printf "  skip (exists): %s/%s\n" "$cli_dir" "$skill_name"
    elif [[ -d "$link" ]]; then
      printf "  WARN: real dir exists at %s/%s - skipping\n" "$cli_dir" "$skill_name"
    else
      ln -s -- "$rel" "$link"
      printf "  linked: %s/%s -> %s\n" "$cli_dir" "$skill_name" "$rel"
    fi
  done
done

printf "\n"
printf "Skill symlinks created. Run scripts/validate-skills.sh to verify.\n"
