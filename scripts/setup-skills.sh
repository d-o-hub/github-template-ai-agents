#!/usr/bin/env bash
# Creates symlinks from CLI-specific folders -> .agents/skills/ (canonical source)
# Run once after cloning: ./scripts/setup-skills.sh
# Note: OpenCode reads skills directly from .agents/skills/ - no symlinks needed.
#
# Behavior:
# - Only links directories that contain SKILL.md
# - Skips *-workspace eval artifacts (gitignored local workspaces)
# - Prunes dangling and orphaned symlinks on every run
# - Optional skills require LINK_OPTIONAL=true
set -euo pipefail

# Allow REPO_ROOT override for tests/fixtures
REPO_ROOT="${REPO_ROOT:-$(cd "$(dirname "${BASH_SOURCE[0]}")/.."; pwd)}"
SKILLS_SRC="$REPO_ROOT/.agents/skills"

# CLI folders that should contain symlinks to canonical skills
# (OpenCode reads directly from .agents/skills/ - not included here)
SKILLS_OPTIONAL=(
  "eu-ai-act-compliance"
  "durable-objects"
)

CLI_SKILL_DIRS=(
  ".claude/skills"
  ".qwen/skills"
)

# Portable relative path computation (works on macOS/BSD without GNU realpath)
_portable_relpath() {
    local target="$1" base="$2"
    target=$(cd "$target" 2>/dev/null && pwd || echo "$target")
    base=$(cd "$base" 2>/dev/null && pwd || echo "$base")

    local common_part="$base" result=""
    while [[ "${target#$common_part}" == "${target}" ]]; do
        # perf: replace external dirname subshell with native bash expansion
        local next_part="${common_part%/*}"
        if [[ "$next_part" == "$common_part" ]]; then
            common_part="."
        elif [[ -z "$next_part" ]]; then
            common_part="/"
        else
            common_part="$next_part"
        fi
        result="..${result:+/$result}"
    done

    local forward="${target#$common_part}"
    forward="${forward#/}"
    if [[ -n "$result" ]] && [[ -n "$forward" ]]; then
        printf '%s/%s\n' "$result" "$forward"
    elif [[ -n "$result" ]]; then
        printf '%s\n' "$result"
    elif [[ -n "$forward" ]]; then
        printf '%s\n' "$forward"
    else
        printf '.\n'
    fi
}

# True if skill dir should be linked for agents
_is_linkable_skill() {
    local skill_name="$1"
    local skill_path="$2"
    # Skip eval workspaces and non-skill dirs
    [[ "$skill_name" == *-workspace ]] && return 1
    [[ ! -f "$skill_path/SKILL.md" ]] && return 1
    return 0
}

_is_optional_skill() {
    local skill_name="$1"
    local opt
    for opt in "${SKILLS_OPTIONAL[@]}"; do
        if [[ "$skill_name" == "$opt" ]]; then
            return 0
        fi
    done
    return 1
}

# Remove dangling/orphaned symlinks and workspace links
_prune_skill_links() {
    local target_dir="$1"
    local cli_dir="$2"
    local link name

    shopt -s nullglob
    for link in "$target_dir"/*; do
        [[ -L "$link" ]] || continue
        name="${link##*/}"

        # Always drop workspace links (not shipped skills)
        if [[ "$name" == *-workspace ]]; then
            rm -f -- "$link"
            printf "  pruned (workspace): %s/%s\n" "$cli_dir" "$name"
            continue
        fi

        # Dangling: target missing
        if [[ ! -e "$link" ]]; then
            rm -f -- "$link"
            printf "  pruned (dangling): %s/%s\n" "$cli_dir" "$name"
            continue
        fi

        # Orphaned: no SKILL.md at canonical path (renamed/removed skill)
        if [[ ! -f "$SKILLS_SRC/$name/SKILL.md" ]]; then
            rm -f -- "$link"
            printf "  pruned (orphan): %s/%s\n" "$cli_dir" "$name"
            continue
        fi
    done
    shopt -u nullglob
}

if [[ ! -d "$SKILLS_SRC" ]]; then
  printf "No skills found at .agents/skills/ - nothing to symlink.\n"
  exit 0
fi

printf "Setting up skill symlinks from .agents/skills/...\n"

for cli_dir in "${CLI_SKILL_DIRS[@]}"; do
  target_dir="$REPO_ROOT/$cli_dir"
  mkdir -p -- "$target_dir"

  # Prune first so renames/removals do not leave dead names for agents
  _prune_skill_links "$target_dir" "$cli_dir"

  # Pre-calculate relative path base once per target dir
  rel_base=$(_portable_relpath "$SKILLS_SRC" "$target_dir")

  for skill_path in "$SKILLS_SRC"/*/; do
    [ -d "$skill_path" ] || continue

    skill_name="${skill_path%/}"
    skill_name="${skill_name##*/}"

    if ! _is_linkable_skill "$skill_name" "$skill_path"; then
      continue
    fi

    if _is_optional_skill "$skill_name" && [[ "${LINK_OPTIONAL:-false}" != "true" ]]; then
      printf "  skip (optional): %s/%s\n" "$cli_dir" "$skill_name"
      continue
    fi

    link="$target_dir/$skill_name"
    rel="$rel_base/$skill_name"

    if [[ -L "$link" ]]; then
      # Refresh if target differs
      current="$(readlink -- "$link" 2>/dev/null || true)"
      if [[ "$current" == "$rel" ]]; then
        printf "  skip (exists): %s/%s\n" "$cli_dir" "$skill_name"
      else
        ln -sfn -- "$rel" "$link"
        printf "  relinked: %s/%s -> %s\n" "$cli_dir" "$skill_name" "$rel"
      fi
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
