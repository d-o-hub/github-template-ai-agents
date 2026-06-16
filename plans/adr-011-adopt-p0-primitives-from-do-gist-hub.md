# ADR-011: Adopt P0 Generic Primitives from do-gist-hub

- **Status:** accepted
- **Date:** 2026-06-16
- **Deciders:** @d-o-hub
- **Related:** Issue #581, ADR-027

## Context

`do-gist-hub` (bootstrapped from this template ~12 months ago) developed 9 P0 generic primitives that are near-zero-coupling to the gist/Android domain and would meaningfully strengthen this template. A full bidirectional impact analysis was performed (see Issue #581).

The following gaps were confirmed via codebase scan:

| Primitive | Status |
|-----------|--------|
| `scripts/sha-pin-actions.sh` (live-resolving SHA pinner) | Missing |
| `.github/workflows/audit-actions.yml` (monthly action audit) | Missing |
| `.github/workflows/track-gitleaks-release.yml` (release tracker) | Missing |
| `plans/adr-027-ci-node24-android-hardening.md` (Node 24 migration ADR) | Missing |
| `agents-docs/handoff-schema.json` | Already present (compatible) |
| `agents-docs/ci-maintenance.md` | Partially present (5 of 7 rules) |
| Composability convention | Already present in `scripts/quality_gate.sh` |

Additionally, the `FORCE_JAVASCRIPT_ACTIONS_TO_NODE24` removal deadline is **September 16, 2026** (~13 weeks), making the Node 24 migration ADR time-sensitive.

## Decision

Adopt all 6 P0 items in Sprint 1 (this PR):

1. **`scripts/sha-pin-actions.sh`** — Bash script that resolves floating tags to commit SHAs via `git ls-remote`. Complements the existing Python `pin-actions-to-sha.py` for environments without Python.
2. **`.github/workflows/audit-actions.yml`** — Monthly cron workflow that scans all `uses:` references, fetches each action's `action.yml`, flags deprecated Node runtimes, and opens/updates a tracking issue.
3. **`.github/workflows/track-gitleaks-release.yml`** — Weekly tracker that polls upstream gitleaks releases and opens a tracking issue when a major version with `node24` is available.
4. **`plans/adr-027-ci-node24-android-hardening.md`** — ADR documenting Node 24 migration, adapted for this template (trimming Android-specific sections).
5. **`agents-docs/handoff-schema.json`** — Already present; no changes needed.
6. **`agents-docs/ci-maintenance.md`** — Enhance with rules 6-7 from fork (periodic action audit, Playwright system deps).

## Consequences

**Positive:**
- SHA-pinning self-heals with live resolution
- Monthly action audit prevents silent runtime deprecation rot
- Node 24 migration deadline is tracked and documented
- Template gains a self-healing action-pin lifecycle (audit + tracker pair)

**Negative / trade-offs:**
- Two additional scheduled workflows consume GitHub Actions minutes
- New scripts require maintenance and validation
- ADR-027 references Android-specific patterns that must be trimmed for this template

## Alternatives Considered

- **Python-only SHA pinning** — Rejected: the existing `pin-actions-to-sha.py` uses hardcoded SHAs and doesn't resolve live. The bash script complements it.
- **Skip audit/tracker workflows** — Rejected: the self-healing lifecycle is the killer feature.
- **Whole ADR-027 as-is** — Rejected: Android-specific sections don't apply to this template.

## References

- Issue #581: <https://github.com/d-o-hub/github-template-ai-agents/issues/581>
- Source files at `do-gist-hub`: <https://github.com/d-o-hub/do-gist-hub>
