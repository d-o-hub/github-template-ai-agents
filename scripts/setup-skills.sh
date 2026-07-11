#!/usr/bin/env bash
# Creates and reconciles symlinks from CLI-specific folders -> .agents/skills/
# Run once after cloning: ./scripts/setup-skills.sh
# Note: Qwen, OpenCode, Gemini, Jules read skills directly from .agents/skills/
#       — no symlinks for those tools.
set -euo pipefail

REPO_ROOT="$(cd "$(dirname "${BASH_SOURCE[0]}")/.."; pwd)"
SKILLS_SRC="$REPO_ROOT/.agents/skills"

# shellcheck source=scripts/lib/skill-dirs.sh
source "$REPO_ROOT/scripts/lib/skill-dirs.sh"

# Portable relative path computation (works on macOS/BSD without GNU realpath)
_portable_relpath() {
    local target="$1" base="$2"
    target=$(cd "$target" 2>/dev/null && pwd || echo "$target")
    base=$(cd "$base" 2>/dev/null && pwd || echo "$base")

    local common_part="$base" result=""
    while [[ "${target#$common_part}" == "${target}" ]]; do
        common_part="$(dirname "$common_part")"
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

if [[ ! -d "$SKILLS_SRC" ]]; then
  printf "No skills found at .agents/skills/ - nothing to symlink.\n"
  exit 0
fi

printf "Setting up skill symlinks from .agents/skills/...\n"

for cli_dir in "${CLI_SKILL_DIRS[@]}"; do
  target_dir="$REPO_ROOT/$cli_dir"
  mkdir -p -- "$target_dir"

  rel_base=$(_portable_relpath "$SKILLS_SRC" "$target_dir")

  # --- Reconcile: remove broken, workspace, stale, and unrequested optional links ---
  shopt -s nullglob
  for existing in "$target_dir"/*; do
    name="${existing##*/}"

    # Always remove eval workspaces and known skip patterns
    if skill_name_is_skipped "$name"; then
      rm -f -- "$existing" 2>/dev/null || true
      printf "  pruned (skip pattern): %s/%s\n" "$cli_dir" "$name"
      continue
    fi

    # Remove broken symlinks
    if [[ -L "$existing" ]] && [[ ! -e "$existing" ]]; then
      rm -f -- "$existing"
      printf "  pruned (broken): %s/%s\n" "$cli_dir" "$name"
      continue
    fi

    # Remove optional skills when LINK_OPTIONAL is not true
    if skill_name_is_optional "$name" && [[ "${LINK_OPTIONAL:-false}" != "true" ]]; then
      if [[ -L "$existing" ]]; then
        rm -f -- "$existing"
        printf "  pruned (optional): %s/%s\n" "$cli_dir" "$name"
      fi
      continue
    fi

    # Remove links that no longer map to a canonical skill directory
    if [[ -L "$existing" ]] && [[ ! -d "$SKILLS_SRC/$name" ]]; then
      rm -f -- "$existing"
      printf "  pruned (no canonical skill): %s/%s\n" "$cli_dir" "$name"
      continue
    fi
  done
  shopt -u nullglob

  # --- Create missing links for core (and optional when requested) skills ---
  for skill_path in "$SKILLS_SRC"/*/; do
    [ -d "$skill_path" ] || continue

    skill_name="${skill_path%/}"
    skill_name="${skill_name##*/}"

    if skill_name_is_skipped "$skill_name"; then
      continue
    fi

    if skill_name_is_optional "$skill_name" && [[ "${LINK_OPTIONAL:-false}" != "true" ]]; then
      printf "  skip (optional): %s/%s\n" "$cli_dir" "$skill_name"
      continue
    fi

    link="$target_dir/$skill_name"
    rel="$rel_base/$skill_name"

    if [[ -L "$link" ]]; then
      # Repair wrong target if needed
      current=$(readlink -- "$link" 2>/dev/null || true)
      if [[ "$current" != "$rel" ]]; then
        ln -sfn -- "$rel" "$link"
        printf "  relinked: %s/%s -> %s\n" "$cli_dir" "$skill_name" "$rel"
      else
        printf "  skip (exists): %s/%s\n" "$cli_dir" "$skill_name"
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
printf "Skill symlinks reconciled. Run scripts/validate-skills.sh to verify.\n"
printf "Tip: LINK_OPTIONAL=true ./scripts/setup-skills.sh links domain skill packs.\n"
