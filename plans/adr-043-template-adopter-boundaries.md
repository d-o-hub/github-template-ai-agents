# ADR-043: Keep Template-Maintainer Policy Separate from Adopter Defaults

## Status

Accepted (2026-10-05)

## Context

This repository is a reusable GitHub template. The initial audit found that
maintainer-only behavior is easy to inherit as if it were product-repository
policy: committed CI-status state points at the template repository, metrics
and DORA artifacts are not covered by the adopter cleanup path, optional skill
packs are not represented consistently in the symlink manifest, and
`AGENTS.md` mixes universal safety rules with Full-profile maintenance work.

The same audit confirmed that all 54 canonical skills have meaningful catalog,
routing, workflow, or adopter value. No skill has sufficient evidence for
repository-level deletion.

## Decision

1. Keep every canonical skill; use optional packs and documented pruning for
   adopter-specific scope.
2. Make adopter boundaries explicit in `AGENTS.md`, `ADOPTION_PROFILES.md`,
   tool overrides, versioning guidance, and CI-status documentation.
3. Maintain one optional-skill manifest consumed by setup and validation.
4. Make skill/eval validators describe their actual static behavior and share
   the same minimum eval-case contract.
5. Preserve impactful automated PRs. Keep PR #989 open; inspect its missing
   Codacy check and request reanalysis without weakening branch protection.
   The live requirement was deliberately restored on 2026-09-28, so ADR-034's
   earlier snapshot is historical, not authority to remove it.
6. Fix CI-status cleanup identity and dry-run age filtering without weakening
   the stale-PR safety threshold.

## Consequences

- New repositories receive project-neutral guidance and an explicit cleanup
  path for copied state.
- Maintainers retain the full orchestration, metrics, and skill catalog.
- Optional-pack behavior becomes predictable across symlinks and validators.
- Static skill checks no longer imply behavioral evaluation.
- The template still requires deliberate adopter customization of install and
  test commands; package-manager behavior is not inferred unsafely.

## Validation

- `validate-skills.sh`, `eval-skills.sh`, `run-evals.py`, and the full quality
  gate pass.
- Generated catalogs and the hand-maintained AGENTS inventory agree.
- Clean-clone guidance contains no inherited template CI/telemetry state after
  the documented reset.
- Open issue count remains zero; impactful PR #989 is not closed as no-impact.
