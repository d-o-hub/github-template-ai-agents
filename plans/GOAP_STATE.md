# GOAP State: Codacy Skill Improvements

## Goal

Enrich existing skills with Codacy integration patterns from codacy/codacy-skills, without creating new skills.

## Status

IN_PROGRESS

## Sub-Goals

### 1. SKILL_TEMPLATE metadata convention

- **Priority**: P0, Deps: none
- **Task**: Add `metadata` (author/version) frontmatter to SKILL_TEMPLATE.md
- **Status**: completed
- **Agent**: implementer

### 2. Enrich codacy/SKILL.md

- **Priority**: P1, Deps: 1
- **Task**: Add git-aware scoping (--staged/--diff/--pr), config operations (--import, config --merge), discover command, expanded command reference
- **Status**: completed
- **Agent**: implementer

### 3. Enrich static-analysis/SKILL.md

- **Priority**: P1, Deps: 1
- **Task**: Add Codacy git-aware scoping section (--staged, --diff, --pr for pre-commit analysis)
- **Status**: completed
- **Agent**: implementer

### 4. Enrich code-review-assistant/SKILL.md

- **Priority**: P1, Deps: 1
- **Task**: Add Codacy PR review workflow steps (codacy pull-request, coverage delta, quality gate)
- **Status**: completed
- **Agent**: implementer

### 5. Enrich cicd-pipeline/SKILL.md

- **Priority**: P1, Deps: 1
- **Task**: Add coverage generation and Codacy upload steps for GitHub Actions, GitLab CI
- **Status**: completed
- **Agent**: implementer

### 6. Validate all changes

- **Priority**: P0, Deps: 2,3,4,5
- **Task**: Run validate-skills.sh, check line counts, verify frontmatter
- **Status**: completed
- **Agent**: test-runner

## Execution Strategy

Hybrid

- Phase 1 (Sequential): SKILL_TEMPLATE update (foundational)
- Phase 2 (Parallel/Swarm): 4 skill enrichments in parallel
- Phase 3 (Sequential): Validation

## Quality Gates

- All skills under 250 lines
- All have valid frontmatter
- validate-skills.sh passes
- No broken cross-references
