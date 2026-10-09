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

@test "setup uses exactly the historical optional names without demoting pack skills" {
  # The manifest is sourced from the code directory, not REPO_ROOT's fixture.
  source "$BATS_TEST_DIRNAME/../scripts/lib/optional_skills.sh"
  [ "${#SKILLS_OPTIONAL[@]}" -eq 8 ]
  for skill in "${SKILLS_OPTIONAL[@]}" secure-invite-and-access dependency-upgrades; do
    mkdir -p "$REPO_ROOT/.agents/skills/$skill"
    printf '# Fixture\n' > "$REPO_ROOT/.agents/skills/$skill/SKILL.md"
  done
  run env REPO_ROOT="$REPO_ROOT" LINK_OPTIONAL=false bash "$BATS_TEST_DIRNAME/../scripts/setup-skills.sh"
  [ "$status" -eq 0 ]
  for cli in .claude .qwen; do
    for skill in "${SKILLS_OPTIONAL[@]}"; do
      [ ! -L "$REPO_ROOT/$cli/skills/$skill" ]
    done
    [ -L "$REPO_ROOT/$cli/skills/secure-invite-and-access" ]
    [ -L "$REPO_ROOT/$cli/skills/dependency-upgrades" ]
  done
  run env REPO_ROOT="$REPO_ROOT" LINK_OPTIONAL=true bash "$BATS_TEST_DIRNAME/../scripts/setup-skills.sh"
  [ "$status" -eq 0 ]
  for cli in .claude .qwen; do
    for skill in "${SKILLS_OPTIONAL[@]}"; do
      [ -L "$REPO_ROOT/$cli/skills/$skill" ]
    done
  done
}

@test "copied setup script loads its copied manifest" {
  mkdir -p "$REPO_ROOT/scripts/lib"
  cp "$BATS_TEST_DIRNAME/../scripts/setup-skills.sh" "$REPO_ROOT/scripts/"
  cp "$BATS_TEST_DIRNAME/../scripts/lib/optional_skills.sh" "$REPO_ROOT/scripts/lib/"
  run env REPO_ROOT="$REPO_ROOT" bash "$REPO_ROOT/scripts/setup-skills.sh"
  [ "$status" -eq 0 ]
  [ -L "$REPO_ROOT/.qwen/skills/real-skill" ]
}
