#!/usr/bin/env bats

setup() {
  export REPO_ROOT="$BATS_TMPDIR/setup-skills-repo"
  rm -rf "$REPO_ROOT"
  mkdir -p "$REPO_ROOT/.agents/skills/real-skill"
  mkdir -p "$REPO_ROOT/.agents/skills/real-skill-workspace/iteration-1"
  printf '%s\n' '---' 'name: real-skill' 'description: x' '---' > "$REPO_ROOT/.agents/skills/real-skill/SKILL.md"
  mkdir -p "$REPO_ROOT/.claude/skills" "$REPO_ROOT/.qwen/skills"
  # dangling + workspace + orphan links
  ln -s "../../.agents/skills/missing-skill" "$REPO_ROOT/.claude/skills/missing-skill"
  ln -s "../../.agents/skills/real-skill-workspace" "$REPO_ROOT/.claude/skills/real-skill-workspace"
  ln -s "../../.agents/skills/real-skill" "$REPO_ROOT/.claude/skills/real-skill"
}

@test "setup-skills.sh prunes dangling and workspace links" {
  run env REPO_ROOT="$REPO_ROOT" bash "$BATS_TEST_DIRNAME/../scripts/setup-skills.sh"
  echo "$output"
  [ "$status" -eq 0 ]
  [ ! -e "$REPO_ROOT/.claude/skills/missing-skill" ]
  [ ! -L "$REPO_ROOT/.claude/skills/real-skill-workspace" ]
  [ -L "$REPO_ROOT/.claude/skills/real-skill" ]
}
