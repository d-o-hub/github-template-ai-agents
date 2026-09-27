# ADR-036: Roast-Review-Merge Round 6 — PRs #900, #905, #906

Status: Accepted (user approved `go` with goap-swarm orchestration, 2026-09-25)
Date: 2026-09-25
Main HEAD at start: `802d457` (post-#899), CI status file `passing`.

## Context

Open PRs: 3 (#900, #905, #906). Open issues: 0.
Closed recently: #901/#903/#904/#896 (superseded), #894/#897/#898/#899 merged.
Template constraints: `VERSION=0.0.0` pinned, conventional commits (ADR-008),
`quality_gate.sh` zero-warning gate, 500-line source / 250-line SKILL.md limits,
`plans/pre-existing-issues.md` debt (31 skills missing `version:`, validate-links
empty-input hang).

- #900 `fix(security): block .curlrc and .wgetrc` (+4/-1): full CI green,
  Codacy/Sonar pass, `mergeStateStatus=CLEAN`. Real incremental coverage;
  test literals redundant vs generated loop; impact wording over-claims;
  `duplicate-pr-guard` mislabeled `superseded-candidate` (vs closed #903).
- #906 `fix(security): harden token/app-secret prefixes` (+16/-1): Codacy/Sonar
  pass but NO full CI run (6 checks only). Canonical replacement for closed
  #903 (12 meaningful test names). Needs consumer regression, narrowed OAuth
  claim, fail-closed `startswith()` policy doc, ready_for_review retrigger.
  Same 2 files as #900 → must sequence after #900 with rebase.
- #905 `perf: replace comm subshells with bash assoc arrays` (+70/-10):
  Codacy FAIL (1 medium ErrorProne), rest green. Real isolated gain
  (2.21s→1.14s) but end-to-end API-dominated (47–53s). Unused `nl` (SC2034),
  misnamed `pr_files_arrays`, `awk` still forks, zero BATS regression.

Official-docs baselines: OWASP Path Traversal + WSTG; Python `pathlib`
`resolve()` + `relative_to` confinement; ShellCheck SC2034 wiki; Codacy
ErrorProne / SonarCloud Quality Gate; bash assoc-array vs `comm` fork cost.

## Decision

1. Fix-then-merge ALL 3 (none qualifies for no-impact close), order #900 → #906 → #905.
2. Narrow security narrative to honest low-severity filename-policy scope
   (`validate_safe_path` already confines to base; blocks repo-local
   overwrites/probes, not arbitrary reads).
3. Keep `.jules/bolt.md` in #905 (user decision).
4. Include pre-existing debt in this run (skill `version:` backfill +
   validate-links investigation) as separate commit/PR.
5. Zero-fail/zero-warning gate per PR: address ALL comments incl. bots
   (Jules, Sonar, Codacy, duplicate-guard, owner reviews); `bash -n`,
   `shellcheck --severity=error`, BATS + pytest, `quality_gate.sh`,
   `gh pr checks` green, `gh pr update-branch --rebase` before each merge,
   squash-merge + delete branch.
6. Execute as GOAP swarm: goap-agent orchestrator, sequential merges
   (file-overlap dependency), parallelizable fix-prep; skills:
   `code-review-assistant`, `static-analysis`, `shell-script-quality`,
   `security-code-auditor`, `test-runner`, `git-github-workflow`,
   `github-pr-sentinel`, `template-version-management`; synthesize via `learn`.

## Consequences

- Positive: honest security framing, Codacy fail cleared, BATS coverage for
  duplicate-scanner, debt reduced, template hygiene kept (`VERSION` pinned).
- Negative: #906 needs full CI retrigger (ready_for_review); #900/#906
  sequential rebase risk; Jules may re-sync and clobber fix pushes
  (Round-5 lesson: merge promptly after fixes).
- Risks: GitHub API flakiness (Round-5 outage precedent) → verify via
  step-level conclusions, retry max 3 per AGENTS.md constants.
