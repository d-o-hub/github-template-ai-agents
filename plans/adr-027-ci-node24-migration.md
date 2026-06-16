# ADR-027: CI Node 24 Migration

> **Status**: Accepted
> **Type**: ADR
> **Created**: 2026-06-16
> **Owner**: agent
> **Related**: adr-011-adopt-p0-primitives-from-do-gist-hub

## Context

GitHub Actions began deprecating Node.js 20 runtimes, forcing affected actions to
run on Node.js 24 via `FORCE_JAVASCRIPT_ACTIONS_TO_NODE24` fallback. This produces
deprecation warnings across all workflows and will become a hard failure once
GitHub removes the fallback entirely (target: September 16, 2026).

## Decision

### 1. Migrate All Actions to Node 24-Native Major Versions

Audit every third-party and official action across all workflow files. Bump each
to the lowest major version that declares `using: node24` in its `action.yml`.

**Core actions:**

| Action | Minimum node24 version |
|--------|----------------------|
| `actions/checkout` | `@v6` |
| `actions/setup-node` | `@v6` |
| `actions/github-script` | `@v9` |
| `actions/stale` | `@v10` |
| `actions/labeler` | `@v6` |

Verify via: `curl -s https://raw.githubusercontent.com/{owner}/{repo}/{tag}/action.yml | grep "using:"`

### 2. Monthly Action Runtime Audit

Created `.github/workflows/audit-actions.yml` — a scheduled monthly workflow
that scans all `uses:` references across `.github/workflows/`, fetches each
action's `action.yml`, and flags any action still using `node16` or `node20`.
On failure, it opens/updates a GitHub issue with a remediation checklist.

**Known exceptions (documented in workflow comments):**
- `gitleaks/gitleaks-action` — latest v2.x still uses `node20`; no v3 release
- `ludeeus/action-shellcheck` — docker-based action, no Node runtime
- `wagoid/commitlint-github-action` — docker-based action, no Node runtime

### 3. SHA-Pin All Actions

All workflow files must use commit-SHA-pinned `uses:` references with a
version comment, e.g.:
`uses: actions/checkout@11bd71901bbe5b1630ceea73d27597364c9af683  # pinned from v4`

Use `scripts/sha-pin-actions.sh` (bash, live-resolving) or
`scripts/pin-actions-to-sha.py` (Python, hardcoded mapping).

## Tradeoffs

### Pros

- Eliminates all Node 20 deprecation warnings permanently
- Self-healing audit catches regressions monthly
- SHA pinning prevents supply-chain attacks via tag mutability

### Cons

- Major-version bumps may introduce breaking input/output changes
- Monthly audit consumes GitHub Actions minutes
- Exception list must be maintained as blocked actions upgrade

## Consequences

### CI Health

- Zero deprecation warnings on all workflow runs
- New actions must be verified for node24 compatibility before merge

### Maintenance

- Run `./scripts/sha-pin-actions.sh` after adding new workflow files
- Review audit-actions.yml exceptions quarterly

## Rejected Alternatives

### Keep `FORCE_JAVASCRIPT_ACTIONS_TO_NODE24` indefinitely

**Rejected because**: GitHub will remove Node 20 from runners on September 16,
2026. The env var is a temporary migration bridge, not a permanent fix.

### Pin to exact patch tags (e.g., `@v6.0.2`)

**Rejected because**: Major-version tags (`@v6`) receive security patches
automatically. We accept minor risk of breaking minor releases for reduced
maintenance.

### Skip SHA pinning; rely on Dependabot

**Rejected because**: Dependabot only bumps tags, not SHAs. SHA pinning is a
defense-in-depth layer.

## References

- `.github/workflows/audit-actions.yml` — monthly Node runtime audit
- `.github/workflows/track-gitleaks-release.yml` — gitleaks upgrade tracker
- `scripts/sha-pin-actions.sh` — live SHA pinning script
- `scripts/pin-actions-to-sha.py` — static SHA pinning script
- `agents-docs/ci-maintenance.md` — CI maintenance rules
- `plans/adr-011-adopt-p0-primitives-from-do-gist-hub.md`

---

*Created: 2026-06-16. Status: Accepted.*
