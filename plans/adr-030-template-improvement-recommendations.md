# ADR-030: Template improvement recommendations implementation

## Status

Accepted

## Context

A codebase analysis identified drift and adopter friction: broken skill
symlinks after renames, incomplete skill catalog generation for YAML block
scalars, stale intent-classifier catalog and plan registry, heavy default
process (GOAP/ADR/TRIZ for all work), oversized SessionStart injection,
near-limit scripts/skills, duplicated TRIZ references, thin analysis
reports, and unclear optional vs core surface area for adopters.

## Decision

Implement the recommendation set as one coordinated change:

1. **Skills linking**: `setup-skills.sh` links only SKILL.md dirs, skips
   `*-workspace`, prunes dangling/orphan links; `doctor.sh` warns on them.
2. **Catalogs**: Fix block-scalar parsing in `generate-available-skills.sh`;
   auto-generate intent-classifier skill catalog from live frontmatter.
3. **Adoption**: Document minimal vs full workflow profiles and skill packs;
   document light-mode process for day-one adopters.
4. **Hygiene**: Thin SessionStart; align AGENTS.md line-limit guidance to 200;
   share TRIZ reference content; persist full analysis reports; metrics
   template + rotation note; Makefile clean targets for local workspaces.
5. **Size**: Reduce `ui-ux-optimize` SKILL.md under 250 lines; harden
   `validate-links.sh` empty-input path and extract helpers to lib.

CI status staleness remains an external dependency (ADR-028). Adopters may
disable maintainer-only workflows per `agents-docs/ADOPTION_PROFILES.md`.

## Consequences

- Agents discover only real skills; catalogs stay accurate when regenerated.
- New repos can adopt a light profile without deleting half the template.
- Local eval workspaces no longer pollute agent skill trees after setup.
- Follow-up: further splits of mega-scripts (`quality_gate`, `self-fix-loop`)
  as they approach 500 lines again.
