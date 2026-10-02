# ADR-042: Round 11 Remediates the Audit Layer, Not the Gates

## Status

Accepted (2026-10-02)

## Context

After Rounds 8 and 9 closed the routing defects in the skill catalog, a
read-only audit of the remaining layers found that `main` is green by every
gate that exists — `doctor.sh`, `loc_gate.sh`, `validate-skills.sh`,
`check-plan-numbering.sh`, `check-adr-compliance.sh`, `validate-links.sh`
(311 links, 0 broken), `generate-skills-reference.sh --check`,
`shellcheck --severity=error`, and a `ci-status.json` that honestly reads
`passing` — while the layer *around* those gates has accumulated six defects
that no gate can see:

1. **A security-prefix rule hides a skill from two generators.**
   `"secret"` is in `SENSITIVE_PREFIXES` (`scripts/lib/paths.py:162`), and
   `validate_safe_path(..., check_forbidden=True)` is applied to canonical
   skill directory names at `scripts/run-evals.py:111,125` and
   `scripts/generate-skills-readme.py:62`. `.agents/skills/secrets-management/evals/evals.json`
   exists, yet `run-evals.py --skill secrets-management` reports "not found
   or has no evals.json", and `.agents/skills/README.md` publishes 53 of 54
   skills. `AGENTS.md` calls that same command a mandatory monthly
   obligation, so the mandatory path has a blind spot.

2. **The AGENTS.md table generator crashes before its own fallback.**
   `scripts/update-agents-md.sh:38` runs a `grep | cut | awk` pipeline under
   `set -euo pipefail`; when the header is absent (as it is today) `grep`
   exits 1, `pipefail` propagates, and `set -e` aborts before the fallback at
   `:40-43` can run. `scripts/post-commit-docs-sync.sh:47-51` then swallows
   the failure with `|| true`, so nothing regenerates and the table drifts
   silently: `AGENTS.md:184-200` omits `codacy` and lists `triz-solver`
   twice.

3. **Folded skill names survive in live agent configuration.**
   Round 8 (ADR-038) folded ten skills, and `LESSON-036` enumerated five
   documentation locations a merge must touch — but only the *generated*
   catalogs are validated. Six live references to folded names remain in
   `.gemini/commands/*.toml`, `.opencode/agents|commands/*.md` and
   `.claude/agents/*.md`, plus a self-contradictory `Not for …
   testdata-builders` in `testing-strategy/SKILL.md:4` that propagated into
   six generated catalogs.

4. **The lessons triple-write has drifted and nothing checks it.**
   Measured across `LESSON-001…046`, `agents-docs/LESSONS.md` is missing
   LESSON-029…035, 037 and 043…045, and `agents-docs/lessons.jsonl` is
   missing LESSON-020…035 and 043…045, while `self-learning-rules.md`
   carries titles and bodies for all of them.
   `rg -l 'lessons.jsonl' scripts/ tests/ .github/` returns nothing: the
   three-file invariant has no validator.

5. **Round-10 knowledge is stranded.** The 2026-10-02 roast+merge pass
   produced LESSON-043 and the matching metrics entry in a working tree
   parked on the `ci/ci-status-update` bot branch, one commit behind a
   duplicate of already-merged #956. The PRs it describes are all merged or
   closed; only the records are missing.

6. **Plan-directory leftovers read as open work.** `plans/unresolved-comments.md`
   (its one item already closed), `plans/PR-resolution-summary.md:72` (flatly
   contradicted by `plans/pre-existing-issues.md:23-24`),
   `plans/followup-actionlint-false-positives.md` ("Pending" since June),
   and the superseded `→ IN FLIGHT` / `→ PENDING` graph at
   `plans/GOAP_STATE.md:42-43` all predate their own resolutions.

## Decision

1. **Canonical names under `.agents/skills/` stop being matched against
   substring prefixes** — not against the denylist. `SENSITIVE_PREFIXES`
   over-blocks on purpose (`tokenizer`, `token_secret_backup`), which is free
   for a file path and fatal for a skill name; exact credential names
   (`.git`, `.env`), hidden names, and key/certificate formats (`.pem`,
   `id_rsa`) stay refused, as does any name that is not a single path
   segment. `validate_safe_path` is untouched, so file-level callers keep full
   coverage. Every `SKILL.md` directory must then be discoverable, and a
   regression test asserts it.

2. **`update-agents-md.sh` gets its fallback back** by making the section-end
   probe tolerate a grep miss. The generator does **not** take ownership of
   the table's shape: `infer_category()` heuristics do not reproduce the
   curated category grouping, so emitting its one-row-per-skill table would
   flatten a hand-maintained surface. The curated grouping stays; a
   name-existence validator replaces the regeneration guarantee, which is the
   part that was actually broken.

3. **The folded-name class gets the validator LESSON-036 implied.** Agent
   configs, command files and `Not for` clauses are checked against the real
   skill inventory, so the next consolidation cannot leave six live routing
   breaks behind again.

4. **The lessons triple-write gains a drift check** beside
   `check-plan-numbering.sh`, wired into `quality_gate.sh`.

5. **Resolved plan items are archived with evidence, never deleted**, and
   Round-10's records are landed on `main` through the normal PR path. A new
   lesson takes the next free id rather than the one its working tree
   happened to carry: the stranded lesson was numbered 043, which
   `self-learning-rules.md` had already given to *Ghost Dirs Trip
   Validators*, so it lands as 046.

6. **Deferred, deliberately:** regenerating `plans/monthly-eval-schedule.md`
   from disk and running the overdue month; de-path-filtering `quality-gate`
   so `plans/`-only PRs stop certifying as `unknown`; rebuilding
   `agents-docs/SCRIPTS.md`; and cutting `0.2.15` with its sonar anchor fix.
   These are each independently valuable and each larger than the six
   defects above; bundling them would defeat one-concern-per-PR.

## Consequences

- The mandatory monthly eval path stops silently skipping a skill, and the
  generated skills README stops under-reporting the catalog.
- Drift in `AGENTS.md` fails a gate instead of being absorbed by `|| true`,
  while the curated grouping is not at the mercy of heuristic categories.
- A future skill consolidation must update agent configs as well as docs, or
  CI says so.
- Lessons become an auditable triple-write rather than three files that
  happen to share a topic.
- Round 12 inherits four named items rather than an unstated backlog.

## Observed while implementing, not decided here

`lib/eval_executors.py:95` applies the same denylist to *files inside* a skill
directory, so `privacy-first` eval #2 (`pyproject.toml`) and
`security-code-auditor` eval #2 (`.env.example`) are refused as paths: both
evals report their fixture "missing" even when it exists. Those entries were
added deliberately as overwrite protection, so relaxing them is a security
trade-off rather than a rename fix, and it needs its own decision.
