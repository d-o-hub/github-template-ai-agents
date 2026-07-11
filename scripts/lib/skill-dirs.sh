#!/usr/bin/env bash
# lib/skill-dirs.sh - Shared CLI skill directory and optional skill lists.
# Source from setup-skills.sh, validate-skills.sh, and related tools.
#
# shellcheck shell=bash

# CLI folders that receive per-skill symlinks to .agents/skills/
# Qwen Code, Gemini CLI, OpenCode, and Jules read .agents/skills/ directly.
# Consumed by scripts/setup-skills.sh and scripts/validate-skills.sh via source.
# shellcheck disable=SC2034
CLI_SKILL_DIRS=(
  ".claude/skills"
)

# Domain / platform packs skipped unless LINK_OPTIONAL=true.
# Core skills (workflow, quality, docs) are always linked when present.
SKILLS_OPTIONAL=(
  "cloudflare-worker-api"
  "codeberg-api"
  "document-rendering-and-locators"
  "durable-objects"
  "eu-ai-act-compliance"
  "pwa-offline-sync"
  "reader-ui-ux"
  "secure-invite-and-access"
  "turso-db"
)

# Names that must never be symlinked into CLI skill dirs (eval artifacts, etc.)
SKILL_NAME_SKIP_GLOBS=(
  "_*"
  "*-workspace"
  "skills-evaluation"
)

# Return 0 if skill_name should be skipped (not a real skill package).
skill_name_is_skipped() {
  local skill_name="$1"
  local pattern
  for pattern in "${SKILL_NAME_SKIP_GLOBS[@]}"; do
    # shellcheck disable=SC2254
    case "$skill_name" in
      $pattern) return 0 ;;
    esac
  done
  return 1
}

# Return 0 if skill_name is in SKILLS_OPTIONAL.
skill_name_is_optional() {
  local skill_name="$1"
  local opt
  for opt in "${SKILLS_OPTIONAL[@]}"; do
    if [[ "$skill_name" == "$opt" ]]; then
      return 0
    fi
  done
  return 1
}
