# Pre-existing Issues

Tracked follow-ups that are not currently blocking main. Update this file when
issues are resolved or new deferred work is accepted.

## Resolved (2026-07-15)

- Skill `version:` frontmatter: all current skills include `version:` (was 31
  missing; fixed earlier). Do not re-open based on historical quality-gate logs.
- Catalog / symlink drift: addressed by ADR-030 (`setup-skills` prune + catalog
  generators).

## Open / deferred

### validate-links empty / malformed input

**Status:** Hardened under ADR-030 (early empty-list guards + lib helpers).
Re-open only if a concrete hang is reproduced with a minimal reproducer.

### CI status artifact freshness

**Status:** External dependency (ADR-028). When `ci-status.json` is older than
the freshness window, wait for the update workflow on `main` rather than
hand-editing the artifact. Adopters who do not want CI-status automation can
disable those workflows (see `agents-docs/ADOPTION_PROFILES.md`).

### Mega-script headroom

Scripts near the 500-line limit (`quality_gate.sh`, `self-fix-loop.sh`,
`swarm-worktree-web-research.sh`) remain candidates for further extraction
when the next feature would push them over the limit.
