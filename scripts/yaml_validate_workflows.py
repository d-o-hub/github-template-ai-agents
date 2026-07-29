#!/usr/bin/env python3
"""yaml_validate_workflows.py - CI guard against YAML scalar-dedent regressions.

Catches the F8-class bug (history: PR #746; ADR-010 addendum "Lessons from the
F7 / F8 debug cycle"): orphan content placed at LOWER indent than a
`script: |` block scalar's first-content line terminates the scalar
mid-stream and produces an invalid workflow file at GitHub Actions load
time. The result is a workflow conclusion of `failure` with no JS ever
executing, and log retrieval returns 404 for every failed run.

This guard loads every `.github/workflows/*.yml` via `yaml.safe_load`.
Empirically verified 2026-07-29 that:

  1. `yaml.safe_load` raises a ScannerError on synthesized F8-regression
     YAML (orphan JS at 0-space is invalid as top-level YAML).
  2. `yaml.safe_load` succeeds on every workflow in this repo, including
     the post-F8 `auto-merge-non-deps.yml`.

Why no custom heuristic for `script: |` indent:

  - Literal-block scalars (`|`) treat `#` as a string character, not a
    YAML comment - complicates "find first content line" detection.
  - Folded scalars (`>`) use different parsing rules and must be excluded.
  - Multiple block scalars in one file (`if: |` AND `script: |`) require
    explicit state-machine reset between them.
  - `yaml.safe_load` already covers the bug class with cleaner errors and
    no false-positive risk - adding a custom heuristic on top would
    add maintenance surface without value.

Exit codes:

  0 - all workflow YAML files parse successfully.
  1 - at least one file failed yaml.safe_load.
"""

from __future__ import annotations

import glob
import sys

import yaml


WORKFLOW_GLOB = ".github/workflows/*.yml"

F8_LESSON_HINT = (
    "This usually indicates a structural YAML error - most commonly orphan "
    "content placed at lower indent than a `script: |` block scalar's "
    "first-content line. See ADR-010 addendum 'Lessons from the F7 / F8 "
    "debug cycle' for the canonical example."
)


def main() -> int:
    files = sorted(glob.glob(WORKFLOW_GLOB))
    if not files:
        print(f"No workflow files matched {WORKFLOW_GLOB!r}.")
        return 0

    failures: list[tuple[str, str]] = []
    for path in files:
        try:
            yaml.safe_load(open(path))
        except yaml.YAMLError as err:
            # First line only - PyYAML tracebacks are noisy and unhelpful.
            first = str(err).splitlines()[0] if str(err) else "<empty error>"
            failures.append((path, first))

    if failures:
        print(f"FAIL: {len(failures)} workflow YAML file(s) failed to parse:")
        for path, err in failures:
            print(f"  - {path}: {err}")
        print()
        print(F8_LESSON_HINT)
        return 1

    print(f"PASS: {len(files)} workflow YAML file(s) parsed successfully.")
    return 0


if __name__ == "__main__":
    sys.exit(main())
