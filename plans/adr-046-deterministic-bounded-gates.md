# ADR-046: Template Gates Must Be Deterministic and Time-Bounded

## Status

Accepted (2026-11-27)

## Context

Three gates failed for reasons unrelated to the change under test. Each one is a
template-portability defect: an adopter inherits the same behaviour with no
local cause to find.

1. `tests/test_ci_status_tristate.py::test_validator_accepts_the_committed_artifact`
   ran `check_ci_status_freshness.sh`, which probes `gh` and compares the
   committed artifact against **live** runs of `ci.yml`. It therefore failed
   whenever the newest run was still `in_progress` (reproduced immediately after
   the 2026-11-27 merges) or whenever `main` was red and the artifact had not
   been refreshed yet. The assertion is about coherence, but it measured
   whatever state GitHub happened to be in.
2. `scripts/secretlint_gate.sh` invoked an unpinned
   `npx -p secretlint -p @secretlint/secretlint-rule-preset-recommend ...`.
   With no TTY, npm's "install these packages?" prompt never resolves, so the
   gate hung — an eight-minute stall observed locally — instead of failing.
   The `@secretlint/secretlint-rule-preset-recommend` package is also deprecated
   in secretlint v14, which bundles the preset.
3. `scripts/check-forbidden-paths.sh` applies a deliberately over-blocking
   `secret*` filename prefix. Editing `scripts/secretlint_gate.sh` — the
   repository's own secret scanner — failed the changeset guard, telling the
   author that a sensitive path was entering the repository.

The same session also showed a fourth variant: `lint-pr-title` cannot be
re-evaluated by a workflow rerun, because a rerun replays the original event
payload. That one needs a better failure message, not a code change.

## Decision

1. **A test may not depend on live repository state.** The freshness validator
   accepts `CI_STATUS_PATH` (artifact under test) and `CI_STATUS_GH_RUNS_JSON`
   (the `gh run list` payload). The committed-artifact test injects an empty run
   list and stays offline; two new tests inject a newer failed run and a newer
   in-progress run, so the parity branch keeps its teeth and is covered
   deterministically. Requesting `gh` remains the default when neither variable
   is set.
2. **Gate tooling is pinned and bounded.** `secretlint_gate.sh` pins
   `SECRETLINT_VERSION` (overridable), passes `--yes` so npm never prompts, wraps
   the run in `timeout` where that binary exists (`SECRETLINT_TIMEOUT_SECONDS`,
   default 600), and installs only `secretlint`, since v14 bundles the preset the
   config names.
3. **The forbidden-path guard names its own tooling.** A narrow
   `SCANNER_ALLOWLIST` in `check-forbidden-paths.sh` exempts
   `secretlint_gate.sh` by exact filename, with the rationale in the code. The
   runtime `validate_safe_path()` denylist in `scripts/lib/paths.py` is
   untouched, so path validation still over-blocks.
4. **Guidance moves into the failure message.** The body-length branch of
   `commitlint.yml` states that a rerun replays the original payload and that a
   push or a close/reopen is what re-lints an edited body.

## Consequences

- `pytest tests/` no longer changes outcome with the state of GitHub. The suite
  passes offline and passes on a red `main`.
- The parity check is exercised by three tests instead of one, and each asserts a
  different verdict (coherent, newer failure, newer in-progress run).
- The secret scan runs in seconds on a warm npm cache instead of hanging, and a
  stalled fetch cannot block a local gate indefinitely.
- One exact filename is exempt from a security guard. The exemption is visible,
  tested from both directions (scanner allowed, `secret-notes.txt` still
  blocked), and does not reach the runtime path validator.
- Adopters who prune `tests/` or the guard inherit no live-state assumptions and
  no interactive prompts.
