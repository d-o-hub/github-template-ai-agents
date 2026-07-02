# GOAP State: Codacy Skills Enrichment (PR #661 Replacement)

## Goal

Enrich existing skills with Codacy best practices from upstream `codacy/codacy-skills` and add skill rules.

## Current State

- PR #661 closed (analysis-only, zero implementation)
- 6 upstream skills fetched and compared
- Local skills already have substantial Codacy integration
- `skill-rules.json` now has 12 rules (9 original + 3 Codacy)

## World State (Updated)

- `codacy/SKILL.md`: v2.0.0 — has metadata ✓
- `static-analysis/SKILL.md`: v1.3.0 — has metadata ✓
- `code-review-assistant/SKILL.md`: v1.1.0 — has metadata ✓
- `cicd-pipeline/SKILL.md`: v0.2.10 — has metadata ✓
- `skill-rules.json`: 12 rules including Codacy ✓
- `SKILL_TEMPLATE.md`: has `metadata.author` field ✓

## Operations (Plan)

### Phase 1: Parallel Metadata Enrichment (3 agents)

- [x] Agent 1: Add `metadata` block to `static-analysis/SKILL.md` frontmatter
- [x] Agent 2: Add `metadata` block to `code-review-assistant/SKILL.md` frontmatter
- [x] Agent 3: Add `metadata` block to `cicd-pipeline/SKILL.md` frontmatter

### Phase 2: Skill Rules (1 agent)

- [x] Agent 4: Add Codacy rules to `skill-rules.json`

### Phase 3: Validation & Commit

- [ ] Run `validate-skills.sh` on all 4 modified skills
- [ ] Verify all files under 250 lines
- [ ] Verify `skill-rules.json` is valid JSON
- [ ] Commit and create PR

## Status

- [x] Phase 1: Parallel Metadata Enrichment — completed
- [x] Phase 2: Skill Rules — completed
- [ ] Phase 3: Validation & Commit — in_progress
