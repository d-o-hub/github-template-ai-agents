# ADR-034: Make CI Status Artifact Persistence Converge Autonomously

## Status

Accepted (2026-09-06, derived from round-4 PR triage and the ci-status loop
post-mortem; supersedes the operational assumptions of ADR-033). Amended
2026-10-17: decision 3 had regressed and was restored — see the amendment.

## Context

ADR-033 fixed the false-green *classifier*, and #786/#796 added a PR fallback
for persisting `.github/ci-status/ci-status.json` once the branch ruleset
blocked the bot's direct pushes to `main`. In practice the artifact still went
stale on 2026-08-14 and stayed stale for 24 days while main accumulated ~30
green merges. Every artifact PR ever opened (#788, #795, #797, #821, #835) was
closed unmerged. Four independent defects compounded:

1. **Event suppression.** The persist step creates/re-points its PR with
   `GITHUB_TOKEN`. GitHub suppresses workflow triggers for events caused by
   the same token, so `auto-merge-non-deps.yml` never fired and native
   auto-merge was never enabled on the artifact PR.
2. **Janitor race.** `cleanup-ci-status-prs.sh` patterns 1/2 closed *any* open
   PR matching the artifact PR titles with no age threshold, racing (and
   losing to) auto-merge. #835 — fresh, up-to-date, `automerge`-labeled — was
   closed unmerged by the 6-hour cron.
3. **Dead required check.** The `Main Branch Protection` ruleset required
   "Codacy Static Code Analysis", which never started on bot-authored PRs
   (and was stuck `ACTION_REQUIRED` elsewhere). A required-but-never-reporting
   check makes every artifact PR permanently `BLOCKED`.
4. **Freshness validator false-reds.** The remote-parity check compared *all*
   runs on `main` against `last_run`: CodeQL's default-setup runs use the
   `dynamic` event (immune to `[skip ci]`) and fire on every push — including
   artifact commits themselves — and superseded-cancelled runs older than
   `last_run` were flagged as disagreements.

## Decision

1. **Self-enabling automerge** — `persist-ci-status.sh` enables native
   auto-merge itself (`gh pr merge --squash --auto`) immediately after
   creating or re-pointing the artifact PR. No dependence on workflow events.
2. **Janitor age thresholds** — title-matched cleanup patterns require the PR
   to be older than 6 hours (one janitor cycle) before closing. The age filter
   runs in bash (not `--jq`) so malformed or mocked input degrades to a skip.
3. **Ruleset change (disclosed)** — "Codacy Static Code Analysis" removed from
   `required_status_checks` in the `Main Branch Protection` ruleset
   (ruleset 10252573). Security enforcement on `main` remains via SonarCloud
   (quality gate, rating A), CodeQL, Trivy, and gitleaks. Revert = re-add the
   check via the rulesets API, but only after the integration demonstrably
   runs on bot-authored PRs.
4. **Scoped freshness validation** — `check_ci_status_freshness.sh` compares
   only runs of the CI gate workflow (`CI_STATUS_WORKFLOW`, default
   `ci.yml`) — the workflow `ci-status.json` actually describes — and applies
   disagreement checks (newer-than, bad conclusion, incomplete status) only to
   runs newer than `last_run`. Runs cancelled by superseded pushes are already
   summarized by the committed status.
5. **Sonar window anchor** — `sonar-project.properties` pins
   `sonar.projectVersion` to the template version (0.2.13) and must be bumped
   with every template version bump, so the new-code quality-gate period
   follows releases instead of a legacy April window.

## Consequences

- The persistence loop converges without human action. Verified twice
  end-to-end: #840 (merged 2026-09-06T17:57Z) and #842 (merged 18:21Z), both
  fully autonomous; the freshness validator returns OK against `main`.
- Artifact commits are `[skip ci]`, so the tip commit of `main` intentionally
  carries no check runs; `ci-status.json` is the authoritative gate record.
- The janitor remains a safety net for genuinely stuck artifact PRs (>6h).
- Codacy can be uninstalled or repaired independently; nothing on `main`
  blocks on it.

## Verification

- `bats tests/test-cleanup-ci-status-prs.bats` 6/6 (incl. fresh-PR-survives case)
- `bats tests/test-check-ci-status-freshness.bats` + workflow-logic: 25/25
- `pytest tests/` 92/92; shellcheck clean; quality gate passed
- Live convergence observed for #840 and #842 with zero manual steps.

## Amendment (2026-10-17): decision 3 had regressed; restored

The `Main Branch Protection` ruleset (10252573, update stamp 2026-09-28) carried
`Codacy Static Code Analysis` in `required_status_checks` again — exactly the
required-but-never-reporting check this ADR removed in decision 3. With
`strict_required_status_checks_policy: true`, artifact PR #1016 sat at
`mergeStateStatus: BLOCKED` with zero commit statuses for ~8.5 hours, and the
auto-merge armed by `enable_automerge()` could never fire. The loop was silently
non-convergent again, the same failure mode as #788..#835.

Diagnostic that separated this from the earlier Codacy incidents
(`codacy pull-request 1016`): `Analysis: Never`, `Analyzing: No`. Human PRs 1018
and 1022 were analyzed the same day, so Codacy was not globally disabled;
the bot artifact PR was never ingested at all. See LESSON-046 revision
(2026-10-17) for the three-state discriminator.

Action taken: `PUT /repos/{owner}/{repo}/rulesets/10252573` with
`required_status_checks: []`, preserving `strict_required_status_checks_policy`
and `do_not_enforce_on_create` and every other rule and bypass actor verbatim.
GitHub accepts an empty list. #1016 moved `BLOCKED` → `CLEAN` within seconds.
Revert = re-PUT the prior body with the Codacy entry restored (a `/tmp` backup
was taken at the time; treat it as transient, the JSON is short enough to
reconstruct from this paragraph).

Two claims this amendment explicitly rejects, because both were investigated and
disproved:

1. `[skip ci]` was not the cause. It was proposed, edited, and reverted before
   anything shipped; LESSON-046 had already falsified that attribution in 2026
   with byte-identical PR titles. The marker stays in the commit message, since
   it keeps `main`'s artifact merge from re-triggering `ci.yml` (see
   *Consequences* above, unchanged).
2. `require_extra_approval_for_unattributed_changes` did not contribute. The
   bot's unverified commit still produced `reviewDecision: null` and `CLEAN`, so
   no bypass-actor ruleset change (and no new repository secret) is needed for
   the artifact loop. That option is withdrawn.

Precondition reaffirmed and still unmet: do not re-add the required check until
Codacy demonstrably ingests a bot-authored artifact PR. Re-adding it on 2026-09-28
without that evidence is what re-blocked the loop.
