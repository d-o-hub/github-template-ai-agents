# Changelog

All notable changes to this project will be documented in this file.

The format is based on [Keep a Changelog](https://keepachangelog.com/en/1.0.0/),
and this project adheres to [Semantic Versioning](https://semver.org/spec/v2.0.0.html).

## [Unreleased]

### Fixed

- Eval fixtures now resolve. Eleven eval cases across four skills named a
  `files[]` path that was never committed — `src/routes/admin.ts`,
  `migrations/20260101_add_settings.sql`, `src/db.py`, `pyproject.toml` — so
  `run-evals.py` reported them as missing inputs and the catalogue showed
  4 of 54 skills failing. Each now points at a real fixture under
  `evals/files/`, following the agentskills.io convention that `files` names
  input fixtures relative to the skill root. Two cases that named a
  credential-shaped path (`pyproject.toml`, `.env.example`) are refused by
  `scripts/lib/paths.py` before the eval runs; those declare `"files": []` and
  describe the artefact in `prompt` instead. No denylist behaviour changed.
- `skill-creator`'s schema reference no longer teaches a dangling fixture. Its
  `evals.json` example used `"files": ["path/to/input/file.md"]`, a path that
  does not exist, so every skill authored from it inherited a failing eval.
  The example now uses `"files": []`, and the reference documents that fixtures
  live under `evals/files/` and must be committed.
- Eval suite: 54/54 skills pass, 71 evals pass, 0 fail (was 50/54 and 11
  failures).
- Eval fixture content is scanner-safe. The new fixtures are deliberately not
  live vulnerable code: the SQL-injection fixture implements the safe form and
  documents the injectable one, the credential fixture uses unremarkable
  literals, and the migration stays portable SQL. A realistic provider key was
  tried first and reverted — GitHub push protection blocks the push outright,
  and live vulnerable fixtures would be a permanent security finding in every
  repository that inherits this template.
- Eval fixtures are excluded from Codacy analysis (`**/evals/files/**` in
  `.codacy.yml`), the same treatment `tests/**` already gets. They are eval input
  data rather than code the template ships or executes — `run-evals.py` only
  checks that the path resolves. Per-rule suppression in
  `sonar-project.properties` was tried first and measured not to reach Codacy's
  own engines.

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
- `scripts/eval-skills.sh` verifies that every path in a non-empty
  `evals[].files` exists under the skill root. The agentskills.io convention is
  that `files` names real input fixtures, but nothing checked it, so a case
  could name a path that was never committed and the harness reported it as a
  missing input — indistinguishable from a real regression. Covered by
  `tests/eval-skills.bats`.
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
