# ADR-045: Dependency-Bot PRs Must Not Be Gated on Human Bookkeeping

## Status

Accepted (2026-11-27)

## Context

Dependabot PR #1121 (`ci: bump the github-actions group`, 6 action updates) was
correct and could not merge. Three checks were red, and none of them failed
because the change was wrong:

1. `test_codeql_version_label_matches_pinned_sha` rejected the new pin because
   its SHA was missing from `CODEQL_SHA_TO_VERSION`. The PR had updated every
   `# vX.Y.Z` comment correctly (`v4.39.3` → `v4.39.4`); only a hand-written map
   in a test file disagreed. ADR-041 chose this deliberately ("a Dependabot bump
   now fails loudly with instructions to add one map entry"), which converts a
   mechanical dependency bump into a manual chore for every adopter, on a file
   named after a specific action.
2. `lint-pr-title` failed the same PR for a 60 365-character body. Dependabot
   writes machine-generated release notes and no bot can shorten them, so
   `MAX_PR_BODY_LENGTH` rejected every bot PR that touches a grouped ecosystem.
   The lesson this gate encodes (LESSON-031) was about human authors.
3. `main` itself was red: `Quality Gate` died on `E: Unable to locate package
   bats`. The retry loop `for i in {1..3}; do apt-get update && break || sleep 5;
   done` ends on the `sleep` branch when every refresh fails, so it reports
   success and the install runs against a stale index. A red `main` blocks every
   PR, bot or not.

The pattern: gates that depend on facts a bot cannot supply (a reviewed SHA
list, a short body) or on an environment detail (`bats` from one package source)
turn an automated pipeline into a manual one.

## Decision

1. **Pin version maps are caches, not allowlists.** `CODEQL_SHA_TO_VERSION` and
   `ACTIONLINT_SHA_TO_VERSION` stay as the offline path for reviewed pins. A pin
   missing from a map is resolved against upstream by
   `scripts/lib/action_pins.py`, which peels annotated tags to the commit and is
   what `_assert_pin_label` uses. A bot bump whose label is right passes; a bump
   that leaves the previous label behind still fails. When upstream is
   unreachable the test skips with the reason rather than asserting a false
   failure.
2. **Machine-generated bodies are exempt from the squash-body limit.** The
   `lint-pr-title` job waives `MAX_PR_BODY_LENGTH` when the PR author is a bot
   (`user.type == "Bot"` or a `[bot]` login), and says so in the log. The squash
   subject — the part that must stay conventional — is still linted, which is
   the invariant ADR-008 protects.
3. **Tool installation fails loudly and has a source fallback.**
   `scripts/install-bats.sh` makes a failed `apt-get update` fatal, tries the apt
   package, then installs the pinned bats-core release. `ci.yml` calls it from
   both jobs that need `bats`.

## Consequences

- A dependency-bot PR can merge on its own merits. Nothing in the pipeline asks
  a bot to edit a test fixture.
- The label↔SHA check keeps its teeth: an incorrect comment still fails, and the
  cache keeps the common path offline. An unreviewed pin costs two API calls on
  the run that introduces it.
- Adopters inherit no repository-specific allowlist semantics. Pointing the
  helper at a different action is a one-line change, and a repo that prunes the
  cache still validates every pin.
- The body gate keeps its human discipline. A bot PR that squashes will carry a
  long machine-generated body into the commit message; maintainers who care can
  set the squash message explicitly at merge time.
- Local `bats` behaviour is unchanged: the helper short-circuits when `bats` is
  already on `PATH`, so the quality gate on a developer machine does not need
  root.
