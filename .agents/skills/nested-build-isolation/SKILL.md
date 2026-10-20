---
name: nested-build-isolation
description: Diagnose and safely isolate nested build, test, and coverage subprocesses (e.g., Cargo running inside cargo test, cargo llvm-cov, or cargo nextest) that fail due to inherited environment variables, target directory collisions, compiler flags, or generated .profraw litter. Use this skill when subprocess builds fail only under coverage/instrumentation, produce inaccurate coverage summaries, or inherit outer toolchain settings. Not for ordinary single-process test failures, unit test debugging without nested subprocesses, or non-nested build issues.
version: "0.1.0"
category: testing
template_version: "0.2"
license: MIT
---

# Nested Build Isolation

Isolate nested build, test, and coverage subprocesses when invoked inside an
outer build, coverage runner, or instrumentation session.

> **Source Attribution:** Adapted from the `do-harness` nested-build-isolation
> skill for portable use across software repositories.

## Quick Start Checklist

- [ ] Identify the outer runner (`cargo test`, `cargo llvm-cov`, `cargo nextest`).
- [ ] Inspect env vars passed to child processes (`CARGO_TARGET_DIR`, `RUSTFLAGS`).
- [ ] Centralize child process environment sanitization in a dedicated helper.
- [ ] Direct child process target and output files to isolated temporary dirs.
- [ ] Parse coverage metrics from structured reports (e.g. JSON report output).
- [ ] Verify tests pass both standalone and under outer instrumentation.

## Core Principles

### 1. Identify Outer Environment Before Patching Tests

When a test spawning a subprocess fails, determine if it fails only under an
outer instrumentation or test runner session (such as `cargo llvm-cov` or
`cargo nextest`). Subprocesses inherit outer environment variables, compiler
flags, and target paths that cause unexpected build failures or collisions.

### 2. Centralize Child Process Environment Sanitization

Do not scatter ad hoc environment unsets (`env::remove_var` or command
`env_remove`) across individual tests. Create a centralized helper function to
sanitize child process environments consistently.

Key variables to strip or isolate for nested Rust/Cargo invocations:

- `CARGO_TARGET_DIR` — Prevent target directory lock contention.
- `RUSTFLAGS` / `CARGO_ENCODED_RUSTFLAGS` — Strip outer instrumentation flags.
- `LLVM_PROFILE_FILE` — Avoid filename collisions in nested binaries.
- `CARGO_MAKEFLAGS` / `CARGO_FLAGS` — Avoid outer jobserver inheritance.

### 3. Stable Report Parsing Over Unstructured Stdout

Tool stdout summary text (e.g., human-readable progress tables) is subject to
formatting changes across tool versions and environment settings. Prefer
generating and parsing machine-readable coverage reports (such as `cargo
llvm-cov --json` or LCOV reports) to obtain deterministic measurements.

### 4. Non-Negotiable Quality Safeguards

- **Never Fix by Deleting or Skipping:** Do not "fix" an instrumented-only
  test failure by deleting the test, adding `#[ignore]`, or removing assertions.
- **Never Disable Sensors:** Do not disable coverage or telemetry sensors to
  force a passing result.
- **Unmeasured Is Not Passed:** Treat skipped, quarantined, or unmeasured
  test runs as unmeasured—never fabricate coverage numbers.

## Rationalizations

| Rationalization | Reality |
| | |
| "The nested test fails under `cargo llvm-cov`, so I'll add `#[ignore]`." | Ignoring tests masks environment leaks and degrades test confidence. |
| "I can parse line coverage from stdout summary tables." | Stdout format varies across tool releases; JSON reports provide stable contracts. |
| "Unsetting `RUSTFLAGS` in one test function is sufficient." | Centralized sanitization helpers ensure consistent isolation across all tests. |

## Red Flags

- [ ] Adding `#[ignore]` or skipping tests under coverage/instrumentation
- [ ] Removing sensors or disabling coverage checks to suppress build errors
- [ ] Parsing coverage percentages from stdout/stderr text rather than JSON
- [ ] Scattering ad hoc `env_remove` calls across tests instead of a helper

## Detailed References

- For Cargo environment variables, helper implementations, and report
  parsing examples, see [references/cargo-isolation.md](references/cargo-isolation.md).

## See Also

- `test-runner` — Executing and debugging test suites.
- `testing-strategy` — High-level test architecture and coverage planning.
