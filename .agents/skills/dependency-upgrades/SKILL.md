---
name: dependency-upgrades
version: "0.1.0"
category: devops
description: Perform routine dependency version bumps and vulnerability-driven upgrades. Use when updating packages, lockfiles, or base images — even if they just say "bump lodash" or "fix this CVE". Not for migration-refactoring (framework migrations).
license: MIT
---

# Dependency Upgrades

Routine bumps and CVE-driven upgrades: one dependency per change, verified
by CI, with a rollback path.

## When to Use

- Bumping a package, action version, or base image
- Vulnerability alert (CVE, Dependabot, audit finding)
- Lockfile refresh or stale pins

## Steps

1. **Scope one upgrade** — one dependency per PR/branch so failures
   attribute cleanly. Group only provably-coupled pairs.
2. **Read the changelog** — note breaking changes and migration notes
   before bumping, not after CI fails.
3. **Bump + lock** — update the manifest and regenerate the lockfile with
   the project's canonical tool; never hand-edit lockfiles.
4. **Verify** — full relevant test suite plus the quality gate; for
   security bumps, confirm the CVE is actually remediated (audit clean).
5. **Record rollback** — pin the previous version in the PR body so revert
   is one commit.

## Rules

- Never bump major versions together with unrelated changes.
- Never ignore a lockfile diff — read it; unexpected transitive churn is
  a signal, not noise.
- Never merge a security upgrade red (failing checks void the point).

## Rationalizations

| Rationalization | Reality |
|-----------------|---------|
| "It's just a patch bump, skip the tests" | Patch releases introduce regressions regularly; the suite is cheaper than the incident. |
| "Dependabot already tested it" | Bot CI covers the bot's matrix, not your integration paths; run your gates. |

## Red Flags

- [ ] Major bump bundled with feature work
- [ ] Hand-edited lockfile
- [ ] CVE upgrade merged with failing checks

## See Also

- `migration-refactoring` — Framework and language migrations
- `test-runner` — Execute tests after the bump
- `git-github-workflow` — Ship the upgrade end-to-end

## References

- `evals/evals.json` — upgrade cases incl. breaking-change negative
