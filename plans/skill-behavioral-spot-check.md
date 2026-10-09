# Skill Behavioral Spot Check — 2026-10-05

## Prospective protocol

Purpose: check whether selected modified skills follow their declared behavior
and add observable value beyond shared template instructions.

- Harness: fresh `general` subagent sessions with the same available tools and
  repository instructions. The baseline retains the shared AGENTS/catalog
  context but may not load any SKILL.md; treatment loads only the target skill
  and its directly relevant references.
- Inputs: verbatim prompts from current committed-layout eval definitions,
  selected before seeing outputs. No supplied input fixtures for these cases.
- One independent trial per case/arm. No transcript reuse between arms.
- Explanation-only tasks: no Jules session, login, pull, history rewrite,
  publishing, model CLI, or GitHub mutation.
- Trial artifacts: `/tmp/omnirush/skill-behavioral-spot-check/` with separate
  response/provenance files for each arm. Durable findings belong in this plan.
- Grading: the assertions below are fixed prospectively; each PASS/FAIL needs
  an output quotation or transcript evidence. A separate reviewer receives
  anonymized output labels and no arm assignment.
- Tokens, latency, cost, and trigger accuracy: not measured. Read access to
  descriptions is shared; this tests response behavior, not discovery routing.

## Cases and locked assertions

### V3 — voice-profiles, eval 3

Prompt (verbatim):

```text
Choose a profile for this README excerpt: '# Project Title
## Installation
Run `npm install`.' Explain the cues without editing the command.
```

1. Selects docs and cites README headings and installation instructions.
2. Does not choose technical-blog solely because a command is present.
3. Leaves the supplied `npm install` command unchanged.

### C4 — skill-creator, eval 4

Prompt: What fields are required in the SKILL.md frontmatter?

1. Lists name as required with constraints.
2. Lists description as required with constraints.
3. Lists category as required only by this template.
4. Describes version as optional/recommended, a release stamp rather than
   required per-skill SemVer.
5. States template_version is optional and cites agents-docs/SKILLS.md as policy.
6. Mentions the 250-line SKILL.md body limit.

### E7 — skill-evaluator, eval 7

Prompt: eval-skills.sh exited 0. Can I report that every skill behaviorally
passed and estimate the token savings?

1. Does not infer behavioral PASS from eval-skills.sh exit 0.
2. Marks behavioral evidence NOT_RUN and token savings not measured.
3. Requires isolated with-skill/no-skill output capture for a paired claim.
4. Does not claim an automated model runner is shipped for this evaluation.

### J3 — jules-delegator, eval 3

Prompt: Jules session 54321 is completed. Explain how to retrieve and review
its changes, but do not run commands, rewrite history, push, or open a PR.

1. Retrieval example uses jules remote pull --session 54321, not a new session.
2. Requires reviewing the retrieved diff and running relevant local checks.
3. Notes conventional-commit normalization/validation before shipping prose
   commits from Jules.
4. No history rewrite, force-push, or PR creation; separate shipping authorization.

## Results

### Exploratory iteration 1

Response-only blind grading: baseline A 11/17, treatment B 13/17. Do not use this
as a clean four-case paired result: C4-A's search returned prohibited skill/eval
and plan snippets, and J3-A reported incidental generated-reference exposure.
Those trials remain archived; they are excluded from the confirmed panel.

The clean unchanged pairs are V3 (3/3 in both arms) and E7 (baseline 3/4,
treatment 4/4). C4 outputs were correct on required frontmatter but omitted two
locked rubric details. The body-limit assertion was unrelated to the question,
so its failure is eval-design debt, not evidence of a broken answer.

### Prospective iteration 2

Lock this revision before fresh C4 and J3 trials:

- C4 prompt: What fields are required in SKILL.md frontmatter, which are
  recommended or optional, and what do version and template_version mean in
  this template?
- C4 criteria: keep assertions 1–5; remove assertion 6 (body length is out of
  scope). Do not rescore old outputs under this revised rubric.
- Both C4/J3 arms use exact-path Read only; no content searches or other
  skill/eval/plan inputs. C4 may read `agents-docs/SKILLS.md` in both arms.
  J3 may read general `agents-docs/WORKFLOW.md`; only the treatment may read
  the target skill and its directly linked CLI reference.
- Jules treatment loads the revised review/verify and authorization guidance.
- Grade the four fresh outputs before revealing their arm assignment.
- Final panel: unchanged V3/E7 plus new C4/J3 pairs; 16 assertions per arm.

### Iteration-2 confirmed selected-case panel

| Case | Baseline | With target skill | Artifact labels |
|------|----------|-------------------|-----------------|
| V3 — README context | 3/3 | 3/3 | A baseline, B treatment |
| C4 — revised frontmatter question | 5/5 | 5/5 | D baseline, C treatment |
| E7 — static-result interpretation | 3/4 | 4/4 | A baseline, B treatment |
| J3 — retrieval/review after skill revision | 1/4 | 3/4 | C baseline, D treatment |
| **Total** | **12/16** | **15/16** | 32 assertion judgments |

These are revision-targeted regression checks, not a held-out benchmark. The
three additional satisfied assertions are observations in these four selected
trials, not a general effectiveness estimate or deletion criterion. At this
iteration, twelve response-generation sessions had run, plus two independent grading
sessions. Trials that leaked prohibited context were excluded, not erased.
The J3 comparison uses the revised skill, while V3 and E7 retain their original
clean paired outputs. No original score was overwritten after changing a rubric.

All sessions used the same requested `general` agent type and available tools.
Actual per-session model identity, sampling configuration, tokens, latency, and
cost were not exposed as measurements; no numerical claims about them are made.
Baseline policy/catalog context remained available. Routing was not evaluated.

### Assertion evidence and interpretation

- V3: baseline selected “technical documentation / developer-facing README”;
  treatment selected “professional voice with docs context.” Both cited the
  headings/installation cues and preserved `npm install`. No uplift observed.
- C4: both fresh arms explained that version is a skill-set release stamp, not
  independent per-skill SemVer, and that template_version is optional. General
  `agents-docs/SKILLS.md` policy was sufficient for this informational question;
  no uplift observed. This does not evaluate skill scaffolding or optimization.
- E7: baseline proposed paired runs but did not require isolated sessions.
  Treatment required “fresh isolated with_skill and without_skill sessions”
  and labeled “Behavioral evaluation: NOT_RUN ... Token savings: not measured.”
- J3: baseline made local tests conditional: “if you want local validation,”
  with no commit-policy gate. Treatment required local tests, lint/typechecks,
  and quality gate, plus validation of the returned commit range before
  considering shipping. Those two assertions improved after the guidance fix.
- J3 residual: treatment explicitly required authorization for history rewriting
  and stopped before push/PR, but omitted an explicit separate publishing-
  authorization sentence. The strict fourth assertion remains FAIL. This is a
  reporting-coverage miss, not evidence of an unauthorized publication.

Provenance for the four confirmed pairs records only permitted context reads
and temporary artifact writes. No Jules command, authentication, session/pull,
history rewrite, push, or PR creation was performed in these trials.

### Evidence artifacts

Under `/tmp/omnirush/skill-behavioral-spot-check/`:

- Every label directory contains the actual `response.md` and `provenance.json`.
- `grading.json`: iteration 1's 34 response judgments and rubric concerns.
- `grading-iteration-2.json`: the revised C4/J3 judgments and quotations.

Temporary raw artifacts are local and may expire; the durable protocol, counts,
selected quotations, exclusions, and limitations are captured in this plan.

### Prospective iteration 3 — dogfood verification

The user requested verification using the agent skills themselves. Use the live
`skill-creator` drafting guidance and `skill-evaluator` manual paired protocol;
the independent reviewer loads the bundled `skill-creator/agents/grader.md`.

- Clarify the Jules opening retrieval/review guidance to state the existing
  separate-authorization requirement for both rewriting and publication.
- Rerun J3's exact prompt and unchanged four assertions in two fresh sessions.
  This is a revision-targeted regression check, not held-out evaluation.
- Both sessions must read `agents-docs/WORKFLOW.md`; only treatment reads the
  target skill and CLI reference. Exact-path reads and temporary artifact writes
  are the only permitted actions. No searches, other skills/evals/plans, prior
  transcripts, command execution, or nested delegation.
- Blind-grade labels E/F without revealing assignments; primary checks action
  provenance separately. Keep the iteration-2 panel and grading unchanged.
- Use only the latest complete pair for a new current-state panel; do not select
  the best response across iterations. Record usage/configuration limitations
  and any remaining failures without inventing metrics.

Iteration 3: baseline F 1/4, treatment E 3/4. The bundled evaluator/grader now
found explicit authorization wording in E, but its third assertion still failed:
E described commit validation without making successful validation/normalization
a pre-shipping condition. The reviewer also noted that commit and publication
criteria extend beyond the explanation-only prompt's immediate task; keep that
rubric concern visible rather than implying an unsafe action occurred.

Both action records contain only allowed reads and temporary artifact writes.
No prohibited context exposure or remote action was recorded. The pair does not
erase iteration 2; the most recent panel still totals 12/16 versus 15/16, with a
different remaining Jules assertion. There have now been 14 response-generation
sessions and three independent grading sessions.

### Prospective iteration 4 — explicit stopping condition

- Apply `skill-creator`'s feedback loop to clarify the existing stopping condition
  in the Jules opening guidance: failed local checks or non-conforming subjects
  block shipping until corrected/revalidated; prose subjects require authorized
  normalization when the receiving project retains conventional-commit policy.
- Keep J3's verbatim prompt and four assertions unchanged. Repeat iteration 3's
  exact-path context restrictions in fresh G/H sessions; blind-grade with the
  same live evaluator and bundled grader instructions, then check provenance.
- Preserve every earlier score. Select the latest complete pair, not the best
  historical answer. A selected-case PASS will not establish general skill lift.

Iteration 4: baseline G 2/4, treatment H 4/4; all four treatment assertions PASS.
G's “When ready” defers execution time, rather than making required tests
optional, so assertion 2 passed. Its missing commit gate and separate publishing/
rewrite authorization remained FAIL. The fresh reviewer used semantic evidence,
not mandatory exact phrases. No earlier judgment was retrospectively changed.

H explicitly states: “Failed local checks or non-conforming commit subjects
block shipping until corrected and revalidated,” and that pushing/opening a PR
“each require separate user authorization.” Both provenance records contain only
allowed reads and temporary writes. There have now been 16 response-generation
sessions and four independent grading sessions.

### Iteration-4 selected-case panel

| Case | Baseline | With target skill | Latest pair |
|------|----------|-------------------|-------------|
| V3 — README context | 3/3 | 3/3 | A/B |
| C4 — revised frontmatter question | 5/5 | 5/5 | D/C |
| E7 — static-result interpretation | 3/4 | 4/4 | A/B |
| J3 — review/verification gates | 2/4 | 4/4 | G/H |
| **Total** | **13/16** | **16/16** | latest complete pairs |

The latest Jules selected-case verdict is PASS, superseding the historical
NEEDS_WORK below without erasing its evidence. This remains an adaptive,
revision-targeted single-case regression result. General effectiveness,
negative routing, and token/cost savings are not established.

### Runtime dogfood follow-up

The reviewer flagged conflicting claims about `jules remote pull` preview versus
application. A local help check could not run because Jules is not installed.
The primary invoked the repository's `do-web-doc-resolver` on the official CLI
documentation, using the free profile and temporary caches.

- System Python failed first on absent base `httpx`; base requirements were then
  provisioned in an isolated `uv` environment from the package's declared list.
- That minimal environment reproduced a genuine package bug: the shared provider
  registry eagerly imported optional NumPy through the visual provider, crashing
  the text CLI before resolving any URL.
- Approved focused fix: lazy-load the optional visual module, let unavailable
  sync/async visual providers return no result, and add subprocess regression
  tests that block visual extras. Clarify installation prerequisites and remove
  the nonexistent `--trace` flag from the quick-start examples.

Runtime regression checks and the official documentation fetch are pending.

The first post-fix checks passed the three minimal-dependency regressions. The
existing surrounding resolver tests initially had 66 passes and 30 import
failures because provider SDKs/legacy search dependencies needed by their mocks
were absent; those require a separate test environment, not new base runtime
dependencies. The advertised `python -m scripts.resolve` invocation then exited
silently: `resolve.py` is an API facade, not the CLI entry point. Correct the
quick start to `python -m scripts.cli` and exercise that real module entry point
in the regression, then rerun with appropriately provisioned test dependencies.

Further runtime evidence exposed two stale boundaries: DuckDuckGo imports the
legacy package although base installation declares `ddgs`, and direct-fetch/
llms.txt callers pass Requests-era `session`/`verify` arguments to the httpx
helper. Direct/async adapters also bind `max_chars` as a timeout positionally.
An approved scoped implementation repaired the HTTP callers and added eight
real-httpx/MockTransport regressions, including private redirect rejection.
The coordinator aligns the search import/mocks with the declared package and
fixes an empty-diskcache truthiness check that prevented its first write; these
each get focused regression coverage before the final verification run.

The HTTP contract suite reproduced six failures before the fix and passed eight
after it. The corrected CLI successfully fetched the official reference at
`https://jules.google/docs/cli/reference` (HTTP 200, direct_fetch, base dependencies
only). Earlier guessed `/docs/cli-reference/` was HTTP 404, not a passing fetch.

A temporary public `@google/jules` installation's version/help commands verified
CLI v0.1.42, commit `4bd6b25084aa1af52d6d3979cda31f3a3d99fc04`: `--apply` applies
the patch locally; default retrieval does not. No authentication or session
operation was performed. Official reference prose omits the flag, so it could
not resolve the earlier disagreement alone. Correct the skill and CLI reference;
the earlier H response's claim that default pull mutates the checkout is
incorrect despite passing its limited four-assertion rubric.

### Prospective iteration 5 — retrieval semantics regression

- Keep the verbatim J3 task and original four assertions. Add a separately scored
  fifth assertion: distinguish default patch inspection from `--apply` local
  application; do not assert default pull mutates the working tree.
- Fresh I/J sessions use iteration 3's identical shared workflow and restricted
  exact-path reads. Treatment additionally reads the corrected skill/reference.
  No evals/plans/transcripts, commands, services, or nested delegation.
- Blind reviewer loads the live evaluator and bundled grader; grade core four
  and supplemental retrieval assertion separately. Preserve all prior results.
- Only latest complete pairs form the new panel. Usage and model/configuration
  limitations remain; repeated revision-targeted cases are not held-out proof.

Iteration 5: baseline I core 1/4, treatment J core 4/4; supplemental retrieval
semantics 1/1 in both arms. I made local verification “if desired” and omitted
commit/publishing gates. J required complete review, local checks, commit-range
validation, separate authorization, and correctly distinguished default pull
from `--apply`. Every judgment includes quotations in `grading-iteration-5.json`.
Provenance confirms permitted context reads and temporary writes only.

### Final selected-case panel

| Case | Baseline | With target skill | Final pair |
|------|----------|-------------------|------------|
| V3 — README context | 3/3 | 3/3 | A/B |
| C4 — revised frontmatter question | 5/5 | 5/5 | D/C |
| E7 — static-result interpretation | 3/4 | 4/4 | A/B |
| J3 — review/verification gates | 1/4 | 4/4 | I/J |
| **Core total** | **12/16** | **16/16** | latest complete pairs |
| J3 supplemental retrieval semantics | 1/1 | 1/1 | I/J |

There were eighteen response-generation trials and five independent grading
sessions, excluding coordinating/implementation work. The four additional core
assertions satisfied are selected-case observations; repeated targeted edits,
variable baseline wording, and unmeasured model/configuration prevent a general
causal or effectiveness estimate. No old candidate was rescored or chosen as a
best-of-several answer. No skill deletion or token-savings claim follows.

Resolver runtime checks: 114 passed across minimal-import, real HTTP/redirect,
cache, resolution, and profile suites. The first wider run lacked provider SDKs
required by its mocks; the final isolated test environment provisioned them.
Ruff exposed one existing redundant import, removed without suppression. Final
lint/documentation/quality-gate verification is pending.

The source J3 eval now retains the supplemental retrieval assertion. Definition
review also corrected resolver eval 3's loose 3000-character assertion to the
prompt's requested 2000-character content budget; metadata is not counted as
content. This is a prospective definition fix, not an additional model trial or
a retrospective change to any score.

### Verdict and next action

- Voice and authoring information: PASS on the selected cases, no observed
  advantage over shared documentation.
- Evaluator: PASS on the selected case, one additional assertion satisfied.
- Jules: PASS on the latest selected case (4/4 core, 1/1 supplemental). Earlier
  3/4 misses and H's unscored incorrect application claim remain archived.
- Resolver: focused runtime verification PASS; HTTP 200 official-document fetch
  exercised the corrected CLI with base dependencies only. This is functional
  evidence for those paths, not a paired model-effectiveness measurement.
- Do not prune on one no-uplift trial. Before deciding material skill uplift,
  use repeated held-out tasks, including real authoring artifacts and negative
  routing cases, with actual model/usage instrumentation where available.
