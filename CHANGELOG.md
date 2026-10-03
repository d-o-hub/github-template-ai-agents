# Changelog

All notable changes to this project will be documented in this file.

The format is based on [Keep a Changelog](https://keepachangelog.com/en/1.0.0/),
and this project adheres to [Semantic Versioning](https://semver.org/spec/v2.0.0.html).

## [Unreleased]

### Fixed

- Skill directories are no longer hidden from the eval and catalog generators by
  the sensitive-prefix denylist. `run-evals.py --skill secrets-management`
  reported the skill as "not found" although its `evals.json` existed, and
  `.agents/skills/README.md` published 53 of 54 skills — on the path `AGENTS.md`
  calls a mandatory monthly obligation. Only substring-prefix matching is
  dropped; exact credential names, hidden names, and key/certificate formats
  stay refused, and traversal is unaffected.
- `quality-gate` no longer runs behind a path filter. A plans-only or
  docs-only PR left it skipped, which ADR-040's fail-closed artifact recorded as
  `unknown`, so `CI Success` failed and merging such a PR turned `main` red.
  The now-unreferenced change-detection job is removed rather than left as
  decoration.
- Lesson records agree again across `LESSONS.md`, `lessons.jsonl` and
  `self-learning-rules.md` (46/46), with the ids that existed only in the
  runtime index given records of their own.
- Live agent configuration no longer routes to skills that ADR-038 deleted.
  `task-decomposition`, `triz-analysis`, `agent-coordination`, `testdata-builders`
  and `anti-ai-slop` were still named by Gemini commands, OpenCode agents and
  commands, Claude agents, and a self-contradictory `Not for` line in
  `testing-strategy` that shipped into six generated catalogs.

### Changed

- `scripts/update-agents-md.sh` is replaced by
  `scripts/check-agents-md-skills.sh`. The old script exited 1 on every
  invocation — its section-end probe was a `grep | cut | awk` pipeline under
  `set -euo pipefail` — and its only caller hid that behind `|| true`. Repairing
  the crash alone would have been worse: its output shape
  (`| Skill | Description | Category |`, with heuristic categories) does not
  match the hand-curated `Category | Skills` table it would have overwritten.
  The `AGENTS.md` table is now verified rather than generated; adopters who
  relied on regeneration should edit the table by hand.

### Added

- `scripts/check-skill-references.sh` with `scripts/lib/folded-skills.tsv`:
  fails when a live agent or skill surface names a folded skill, exempting
  lines that document the fold as history.
- `scripts/check-lessons-consistency.sh`: cross-checks the lesson catalog
  against both of its indexes and accepts the archive as a legitimate home for
  a superseded lesson.
- Both checks, plus the `AGENTS.md` table check, run in `quality_gate.sh`.

### Removed

- `scripts/update-agents-md.sh` (see Changed). Use
  `./scripts/check-agents-md-skills.sh` to verify the table.

### Notes

- ADR-038 promised a changelog note for adopters who referenced the skill names
  it removed. The ten folded names and their successors are listed in
  `scripts/lib/folded-skills.tsv` and enforced by
  `scripts/check-skill-references.sh`; run that script to see the mapping for
  your own references.
