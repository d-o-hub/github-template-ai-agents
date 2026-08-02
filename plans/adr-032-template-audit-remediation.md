# ADR-032: Reusable-template audit remediation

## Status

Accepted — doc layer and code layer both applied (2026-08-01).

## Context

A read-only audit (2026-08-01, thread T-019fbe33) assessed this repository as
a reusable template for arbitrary projects and agent CLIs. Verdict: **a capable
maintainer harness, but not yet safe or reliable as a universal drop-in
template.** Three layers — (1) agent instructions, (2) quality/CI framework,
(3) this template's own maintenance infrastructure — are documented as
profiles but not isolated operationally.

Top findings:

1. **Critical** — `quality_gate.sh:456-465` exits `0` in PR context whenever
   generated-document drift is detected, *before* evaluating the accumulated
   `FAILED` flag. A PR with drift plus any real validator/test failure reports
   success.
2. **Critical** — `agents-docs/MIGRATION.md` documented copying only four
   scripts, but `validate-skills.sh` sources `scripts/lib/skill-validation.sh`
   and `quality_gate.sh` invokes a dozen more helpers — the installed gate
   failed immediately at runtime.
3. **High** — mutating GitHub workflows ship **enabled by default**:
   `dependabot-auto-merge.yml` resolves *all* unresolved review threads
   (including human objections) and enables auto-merge; `patch-release-on-label.yml`
   directly commits, tags, pushes, and publishes a release on a labeled merge;
   `release-drafter.yml` force-pushes a branch and merges with
   `gh pr merge --admin`; `dedup-issues.yml` auto-closes flagged issues **and
   cross-referenced open PRs** at a 0.4 heuristic threshold.
4. **High** — language "auto-detection" is misleading: Python/Go are detected
   but no ecosystem checks run; JS checks only run via `pnpm`; missing tools
   silently skip and the gate still prints "All Quality Gates PASSED".
5. **High** — Light/adopter policy leaks maintainer governance: universal
   metrics mandate, ADR-008 PR rules, "fix ALL pre-existing issues", monthly
   DORA, CI-status gating.
6. **Medium** — `bootstrap.sh:18` and `doctor.sh:39` require `.git` to be a
   directory, rejecting valid linked Git worktrees.
7. **Medium** — `.claude/settings.json` registers a SessionStart hook at
   `.claude/hooks/session-start.sh`, which does not exist; the real hook is
   `hooks/session-start.sh`.
8. **Medium** — `generate-skills-reference.sh` corrupts literal-block YAML
   descriptions (`description: |`) and the drift check treats the corrupted
   output as authoritative; `AGENTS_REGISTRY.md` omitted `agentic-abstention`
   and `voice-profiles`.

## Decision

### Applied in this workspace (docs layer)

- **`agents-docs/MIGRATION.md`**: replaced placeholder URLs with the real
  template repo; replaced dead `task-decomposition` references with
  `goap-agent`; changed the copy recipe to copy the **entire** `scripts/`
  tree (including `scripts/lib/`) plus `.githooks` and lint configs; hook
  installation now uses `core.hooksPath=.githooks` (matches `bootstrap.sh`);
  removed obsolete "uncomment the language section" instructions (the gate
  auto-detects) and the `realpath` prerequisite/troubleshooting; scoped the
  commit example (`feat(tooling): ...`) and replaced the hardcoded
  `0.2.10` version with a `VERSION` reference.
- **`agents-docs/WORKFLOW.md`**: removed documented `SKIP_LINT`/`SKIP_LINKS`
  (not implemented — only `SKIP_TESTS`, `SKIP_CLIPPY`,
  `SKIP_GLOBAL_HOOKS_CHECK` exist); scoped "fix ALL pre-existing issues" to
  **Full mode**, with Light mode fixing only change-related issues.
- **`QUICKSTART.md` / `README.md`**: replaced placeholder clone URLs; made the
  "5 minutes" claim honest (optional tools auto-skipped, `doctor.sh` reports
  gaps); fixed the misleading `pip install pre-commit` troubleshooting row.
- **`AGENTS.md` / `GEMINI.md` / `QWEN.md`**: added profile
  scoping — metrics, DORA, CI-status gating are Full-profile/maintainer
  concerns and optional for Light-mode adopters. (`JULES.md` was later
  removed entirely; Jules agents read `AGENTS.md` and `.jules/*.md`
  directly.)
- **`agents-docs/skills-reference.md` / `agents-docs/AGENTS_REGISTRY.md`**:
  repaired the two corrupted skill rows and added the two missing registry
  entries with canonical descriptions (sourced from `llms-full.txt`).

### Ready to apply in the full template repository (code layer)

1. **Fix PR drift precedence in `scripts/quality_gate.sh` (critical).**
   Evaluate `FAILED` before the drift branch; treat drift as warning-only and
   never exit `0` when `FAILED=1`:

   ```bash
   if [[ "$DRIFT_DETECTED" == "true" ]]; then
       if [[ "$GITHUB_EVENT" == "$GITHUB_EVENT_PR" ]]; then
           printf '%s\n' "⚠ Quality Gate: drift detected (warning only during PR)"
           # fall through to the final FAILED decision below — do NOT exit 0
       elif [[ "$ON_MAIN_BRANCH" == "true" ]]; then
           printf '%s\n' "✗ Quality Gate FAILED (drift on main branch)"
       fi
   fi
   # ... final decision:
   if [[ $FAILED -eq 1 ]]; then exit 1; fi
   ```

   Add a BATS test combining drift with an unrelated validator failure.

2. **Ship mutating workflows disabled by default.** Gate
   `dependabot-auto-merge.yml`, `patch-release-on-label.yml`,
   `release-drafter.yml`, `dedup-issues.yml` behind a repository variable
   (e.g. `MAINTAINER_AUTOMATION=true`) or `workflow_dispatch`. Never resolve
   human-authored review threads; never close cross-referenced PRs; remove
   `--admin` from `gh pr merge`; require a protected-environment approval
   before tag/release publication.

3. **Support linked worktrees** in `bootstrap.sh` and `doctor.sh`:

   ```bash
   git rev-parse --is-inside-work-tree >/dev/null 2>&1 || fail "not inside a git repository"
   ```

4. **Fix the Claude hook path**: point `.claude/settings.json` at
   `$CLAUDE_PROJECT_DIR/hooks/session-start.sh`, or add a maintained wrapper
   under `.claude/hooks/`. Add a validation that every configured hook resolves
   to an executable tracked file.

5. **Fix the frontmatter parser** in `scripts/generate-skills-reference.sh`
   (accept `|`, `|-`, `|+`, `>`, `>-`, `>+` block scalars) and regenerate
   `skills-reference.md`; converge all skill registries onto one
   machine-readable inventory and have CI compare canonical skill names against
   every committed registry.

6. **Make language checks truthful**: run Python/Go checks or fail with an
   actionable missing-tool message; select the JS package manager from
   lockfiles; distinguish passed/failed/skipped so missing tooling is never
   reported as "all gates passed".

7. **Add onboarding tests**: execute the exact documented MIGRATION commands in
   a clean fixture repo in CI; cover worktrees, paths with spaces, and
   symlink-disabled platforms.

## Implementation status (2026-08-01)

- **Critical drift fix applied**: `scripts/quality_gate.sh` now falls through to
  the final `FAILED` decision during PR drift instead of exiting 0
  unconditionally. Verified: drift-only PR → exit 0; drift + validator failure
  → exit 2; main-branch drift → exit 1. Added BATS regression test
  (`tests/test-quality-gate-drift.bats` test 7) — all 7 drift tests pass.
- **Mutating workflows now opt-in**: `dependabot-auto-merge.yml`,
  `patch-release-on-label.yml`, `release-drafter.yml`, and `dedup-issues.yml`
  are gated behind the repository variable `MAINTAINER_AUTOMATION=true`.
  Additionally: dependabot workflow no longer auto-resolves review threads;
  release-drafter no longer uses `gh pr merge --admin`; patch-release guards
  against existing tags; dedup-issues never closes cross-referenced PRs and its
  comment reflects the opt-in gate. The dedup **detection** job (third-party
  LLM + rule-based labeling) is gated on the automatic `issues` trigger too;
  an explicit manual `workflow_dispatch` with an `issue_number` remains
  available. All four files parse as valid YAML.
- **Linked worktrees supported**: `scripts/bootstrap.sh` and `scripts/doctor.sh`
  use `git rev-parse --is-inside-work-tree` instead of `[[ -d .git ]]`.
- **Claude hook path fixed**: `.claude/settings.json` now points SessionStart at
  `$CLAUDE_PROJECT_DIR/hooks/session-start.sh`.

- **Frontmatter parser fix applied**: `scripts/generate-skills-reference.sh`
  accepts `|`, `|-`, `|+`, `>`, `>-`, `>+` block scalars and regenerates
  `skills-reference.md` byte-identically to the committed file (verified by
  round-trip).

Remaining (not yet applied): single-inventory convergence across all
registries plus CI comparison of canonical skill names (decision 5),
Python/Go/JS language checks (decision 6), and onboarding fixture tests in CI
(decision 7).

## Consequences

- **Positive**: adoption no longer installs a broken gate or inherits
  destructive automation; discovery registries are correct; docs match
  implemented behavior.
- **Drift risk (resolved for skills-reference)**: `skills-reference.md` was
  hand-repaired here, but the generator fix (decision 5) has now landed and
  regeneration reproduces the committed file exactly. `AGENTS_REGISTRY.md`
  remains hand-maintained until the single-inventory convergence (decision 5)
  lands — CI comparison of canonical skill names against every committed
  registry is still the guardrail.
- **Maintainer surface**: metrics/DORA/CI-status remain the Full profile's
  responsibility; the `log-metric.sh` protocol and `.agents/metrics/` layout
  are unchanged.
- **Remaining work**: decision 5's single-inventory convergence, decision 6
  language checks, and decision 7 onboarding CI tests remain open.
