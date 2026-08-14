# Pre-existing Issues

Tracked follow-ups that are not currently blocking main. Update this file when
issues are resolved or new deferred work is accepted.

## Resolved (2026-08-11)

### CI status artifact freshness

**Status:** Resolved by #786 (`fix/ci-ci-status-persist-ruleset-safe`).

`ci-status.json` had been frozen at `last_run: 2026-06-18` for ~7 weeks because the
`ci.yml` `Persist CI data to main` step did a bare `git push origin main`, which the
`Main Branch Protection` ruleset rejects (GH013), and `continue-on-error: true` masked
the failure. The persist step now delegates to `scripts/persist-ci-status.sh`, which
tries a direct push and falls back to a `ci/ci-status-update` branch opened as an
`automerge`-labeled PR (merged by auto-merge-non-deps once required checks pass);
`continue-on-error` is removed so failures surface. ADR-028's "external dependency" framing
no longer applies and should be revisited in a follow-up.

## Resolved (2026-07-15)

- Skill `version:` frontmatter: all current skills include `version:` (was 31
  missing; fixed earlier). Do not re-open based on historical quality-gate logs.
- Catalog / symlink drift: addressed by ADR-030 (`setup-skills` prune + catalog
  generators).

## Open / deferred

### validate-links empty / malformed input

**Status:** Hardened under ADR-030 (early empty-list guards + lib helpers).
Re-open only if a concrete hang is reproduced with a minimal reproducer.

### Mega-script headroom

Scripts near the 500-line limit (`quality_gate.sh`, `self-fix-loop.sh`,
`swarm-worktree-web-research.sh`) remain candidates for further extraction
when the next feature would push them over the limit.
