# ADR-041: The CI Test Job Must Be Self-Contained

## Status

Accepted (2026-10-02; complements ADR-040 — a fail-closed status artifact is
worthless if the job it classifies never ran honestly)

## Context

Main went red on 2026-09-28 with run `36450276199` (the merge of #947) and
stayed red while `ci-status.json` still reported the 2026-09-27 run as
`unknown`. Diagnosis found four coupled defects:

1. **The test job's dependencies were gated on an optional manifest.**
   `ci.yml` wrapped `pip install ruff black pytest` *and*
   `pytest tests/ -v` in `if: hashFiles('requirements.txt')`. The repository
   has no root `requirements.txt`, so **root pytest never ran in CI** and every
   corpus BATS test whose Python heredoc does `import yaml`
   (`tests/test-skill-frontmatter-policy.bats:40`,
   `tests/test-generate-skill-catalog.bats:66`) failed on a missing PyYAML.
   Locally, clean main passes 273/273 BATS — the failure existed only in CI.

2. **A test that never ran had been asserting a downgrade.**
   `tests/test_workflow_versions.py` (added by #947) hardcoded
   `CODEQL_NEW_SHA = cdf488f…`, which is codeql-action **v4.37.9**, while main
   actually runs `1c5b675…` = **v4.38.1**. Satisfying it — as #943, #951 and
   #953 all attempted — would have *downgraded* the action.

3. **The version labels on main were lies.** `security-scan.yml` said
   `# v4.36` next to a v4.38.1 SHA; `yaml-lint.yml` said `# v1` next to a
   v1.76.0 SHA. Dependabot does not repair this: per its own fixtures it will
   *leave an incorrect comment as-is* rather than fail the update
   (<https://github.com/dependabot/dependabot-core/blob/main/github_actions/spec/fixtures/workflow_files/pinned_sources_version_comments.yml>).

4. **Bot-authored PRs got no CI at all.** PRs opened by `app/github-actions`
   (#952, #946) emit no `pull_request` workflow runs because events from the
   default `GITHUB_TOKEN` do not trigger workflows
   (<https://docs.github.com/en/actions/security-for-github-actions/security-guides/security-hardening-for-github-actions>),
   so their branches are unvalidated by construction.

SHA pinning itself is correct and stays: GitHub's *Secure use reference*
calls a full-length commit SHA "the only way to use an action as an immutable
release" (<https://docs.github.com/en/actions/reference/security/secure-use>).
The defect was never the pin — it was the unverifiable label and the test that
froze a single SHA as "the correct one".

## Decision

1. **The test job installs its own test dependencies unconditionally.**
   `pip install pytest pyyaml` runs regardless of any manifest, and
   `pytest tests/ -v` runs unconditionally. A test suite's own assumptions are
   never gated on an optional file; a root `requirements.txt` is *not* added,
   which also keeps the Trivy/SCA surface unchanged.

2. **Pins are validated by label↔SHA agreement, not by a blessed SHA.**
   `CODEQL_SHA_TO_VERSION` / `ACTIONLINT_SHA_TO_VERSION` map a pinned SHA to
   its real upstream version; tests assert that every pin carries a `# vX.Y.Z`
   comment, that all comments agree, and that the comment equals the map's
   value. A Dependabot bump now fails loudly with instructions to add one map
   entry, instead of silently asserting an obsolete SHA. Verifying a version
   needs no network in CI, only the map; verifying a *release* does, and that
   remains Dependabot's job.

3. **Labels are corrected without bumping SHAs.** `security-scan.yml` keeps
   `1c5b675` but is relabelled `# v4.38.1`; `yaml-lint.yml` keeps `320fcdd9`
   relabelled `# v1.76.0`. The move to `2892aa5` (v4.38.2) belongs to
   Dependabot #944 so the bump keeps its own review and attribution.

4. **`ci.yml` gains `workflow_dispatch`** so bot PR branches can be validated
   with `gh workflow run ci.yml --ref <branch>` before merge.

## Consequences

- The CI status artifact can only say `passing` once a test job that actually
  executes pytest and a PyYAML-complete BATS suite has succeeded — the
  fail-closed semantics of ADR-040 finally have something honest to classify.
- Anyone bumping an action must touch a map in the same commit. That is
  deliberate friction: the previous design's friction landed on `main` being
  permanently red instead.
- Adding a new Python-grammar BATS test can no longer be broken by CI simply
  not having the interpreter module the test imports.
