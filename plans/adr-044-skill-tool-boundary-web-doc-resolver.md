# ADR-044: Keep Application Code Out of Skill Directories (Web Doc Resolver Extraction)

## Status

Accepted (2026-11-25)

## Context

The `do-web-doc-resolver` skill directory carried two unrelated payloads: the
skill itself (`SKILL.md`, seven `references/` files, `evals/evals.json`) and a
complete Python application — the `scripts` package with its CLI, the 24-file
pytest suite, `pyproject.toml`, `requirements.txt`, and packaging metadata.
75 of the directory's 84 tracked files were application code duplicated from
the independently published upstream product
(<https://github.com/d-oit/do-web-doc-resolver>).

The embedding leaked into every quality surface: `scripts/loc_gate.sh` prunes
`./.agents/skills/*` for skill content, which also exempted the app from the
per-file source cap (its upstream test suite carries a 1,765-line test module);
CI special-cased `.agents/skills/*/pyproject.toml` to install and test the app;
and the Codacy exclusions enumerated application paths inside the skill tree.
A skill is routing and guidance for agents, not a distribution channel for a
product — and an app is not exempt from standards merely because of where it
happens to be checked in.

## Decision

1. Skill directories under `.agents/skills/` remain the only canonical content
   dirs for skills: `SKILL.md`, `references/`, and `evals/` travel with the
   skill; application code does not.
2. The resolver application moves to `tools/web-doc-resolver/` as vendored tool
   application space — mirrored upstream product code, referenced by the skill.
   `tools/` is hereby the home for embedded tool applications that skills
   describe and invoke but do not contain.
3. The skill names the tool with a repo-relative path:
   `../../../tools/web-doc-resolver/` from the skill directory (three levels
   up to the repo root). Commands in the skill's references run from the tool
   directory, and each affected reference states that location.
4. `scripts/loc_gate.sh` prunes `./tools/web-doc-resolver/*` via an operator
   directive comment: vendored tool space answers to its upstream standards,
   not this repo's per-file cap. The prune is scoped to that one directory;
   any other `tools/` path remains subject to `MAX_LINES_PER_SOURCE_FILE`,
   and widening the prune is a new ADR-level decision, not documentation drift.
5. CI dependency install and pytest discovery enumerate both
   `.agents/skills/*/` and `tools/*/` so a skill-embedded or extracted app is
   exercised the same way at either location.
6. Codacy exclusion paths that pointed into the skill tree
   (`scripts/providers/docling.py`, `tests/integration/**`,
   `tests/test_optional_visual_dependencies.py`) repoint at
   `tools/web-doc-resolver/` with their rationale comments unchanged.

## Consequences

- The skill loads as pure content in every runtime that snapshots or symlinks
  `.agents/skills/`; no runtime accidentally ships Python sources with routing
  guidance.
- The app stays byte-identical to upstream structure, so future
  backports/syncs are `git mv`-free directory compares against
  `tools/web-doc-resolver/`.
- The LOC gate's `tools/web-doc-resolver` exemption means repo maintainers are
  not the size police for vendored code, and the gate stays loud for every
  other `tools/` path — a future `tools/` addition must either comply or
  extend this ADR's scoped directive.
- Workflows and validators that enumerate app markers (`pyproject.toml`,
  `requirements.txt`) must include both directory roots, or an extraction like
  this one silently drops the app's tests from CI.
- Adopters pruning skills lose nothing application-shaped from `.agents/skills/`;
  adopters that want the resolver tool must also copy `tools/web-doc-resolver/`.

## Validation

- `./scripts/validate-skills.sh`, `check-skill-references.sh`,
  `check-adr-compliance.sh`, and `check-agents-md-skills.sh` pass.
- `./scripts/loc_gate.sh` passes with the vendored prune and would fail without
  it (`tools/web-doc-resolver/tests/test_resolve.py`, 1,765 lines).
- App smoke: `python -m pytest tests/ -v -m "not live"` from
  `tools/web-doc-resolver/` (import surface unchanged: tests import
  `scripts.*` relative to the tool root).
- Full `SKIP_GLOBAL_HOOKS_CHECK=true ./scripts/quality_gate.sh` and
  `bats tests/*.bats` pass after the extraction and reference retarget.
