# Skill Evaluation Tiers (NVIDIA SkillEvaluator Reuse)

Reuse of [NVIDIA SkillEvaluator](https://github.com/NVIDIA/SkillEvaluator)
(Apache-2.0; paper: [*Evaluating Skills, Not Just Agents*](https://arxiv.org/abs/2608.20614);
[benchmark blog](https://developer.nvidia.com/blog/evaluating-ai-agent-skill-performance-with-nvidia-skillevaluator/))
tier semantics **without vendoring** — zero new runtime dependencies.
See ADR-037 and its correction note below.

## Tier mapping

| NVIDIA tier | Template equivalent | Status | Gate |
|-------------|---------------------|--------|------|
| Tier 1 Validation (static validators, secrets, license, hygiene, quality score) | `scripts/validate-skills.sh` + `quality_gate.sh` + `evals/evals.json` | Implemented | Always gates |
| Tier 2 Deduplication (inter-skill similarity vs catalog) | `scripts/check-skill-overlap.sh` (word-5-gram Jaccard over `SKILL.md` bodies, no embeddings) | Implemented, **not wired to CI** | Advisory default; `--strict` gates |
| Tier 3 Live Evaluation (paired with/without-skill trials, Skill Lift) | — | **Not implemented** (see below) | n/a |

## Tier 2 threshold calibration

`THRESHOLD` is **`0.50`**. Two measurements bracket it:

| Measurement | Score | Meaning |
|-------------|-------|---------|
| Corpus noise floor | `0.0267` | Highest score in the 54-skill catalog (1431 pairs): `pwa-offline-sync` ↔ `reader-ui-ux` |
| Verbatim duplication | `0.9556` | Fixture pair sharing a large identical paragraph block |

Every score the real corpus produces sits in the `0.020`–`0.027` band, and that
band is **shared template boilerplate** — `Use this skill when…`,
`## Rationalizations`, `## Red Flags`, `Not for X`. It is not semantic overlap. A
threshold inside the band reports noise as findings and invites a merge reflex
that would break working skills.

`0.50` sits in the ~19× gap between the two measurements, aligned with NVIDIA's
own `DISTINCT` boundary so both systems agree on the word "distinct". At `0.50`
the live corpus is clean: no pairs, and `--strict` exits 0.

Two earlier defaults were wrong in opposite directions. `0.04` sat above every
observed score, so the check could never fire. `0.02` sat *inside* the noise
floor, so it reported **13 false positives** — boilerplate neighbours such as
`eu-ai-act-compliance` ↔ `secure-invite-and-access` and `delegate` ↔
`implementer`. None was a duplicate, and **the 13 pairs are not consolidation
candidates.** Do not act on them.

`tests/test-check-skill-overlap.bats` guards the calibration three ways: that the
default threshold stays strictly above the observed corpus maximum (read back
from `--threshold 0`, so nothing is hardcoded and the guard survives corpus
changes), that the default reports the real corpus clean, and that `--strict`
exits 1 **without** a traceback (a `NameError` also exits 1, which previously let
the broken gate pass green).

## Semantic overlap needs embeddings (out of scope)

NVIDIA's Tier 2 runs an embedding `similarity-check` and bands the cosine score:

| Band | Threshold |
|------|-----------|
| `EXACT_DUPLICATE` | ≥ 0.95 |
| `HIGH_SIMILARITY` | ≥ 0.90 |
| `SIMILAR` | ≥ 0.75 |
| `LOOSELY_RELATED` | ≥ 0.50 |
| `DISTINCT` | < 0.50 |

Its report default is `0.75`. **This template deliberately does not do that:**

- Embeddings would add a runtime dependency to a template whose headline property
  is zero-dependency, keyless operation.
- The providers this template's evals already call — Anthropic and Bedrock —
  expose no embeddings endpoint, so the dependency would be a standalone vector
  service, not a config flag.
- A local **Ollama** embedding path is the documented future option for adopters
  who want semantic overlap: an embedding model behind the same
  `SKILLS_DIR` / `--threshold` interface, keeping the `0.50` `DISTINCT` boundary
  from the table above.

Until then, treat `check-skill-overlap.sh` as a **duplication** gate. Use an
embedding-based checker whenever a skill split, merge, or consolidation is the
actual decision on the table.

## Tier 3 is not implemented

ADR-037 mapped Tier 3 to `skill-creator/scripts/run_loop.py` plus a benchmark flow.
That mapping is **incorrect** and is corrected here:

- `run_loop.py` is a *description optimization loop for skill frontmatter*. It
  scores trigger precision/recall (`true_positives` / `true_negatives`). It does
  not execute live skill runs and produces no paired trials.
- `aggregate_benchmark.py` reads `timing.json` / `grading.json`, which **nothing in
  the repo writes**. No benchmark workspace exists on disk.
- Consequently `skill-evaluator/SKILL.md` documents a workspace layout that is
  authored by hand, never produced by a runner.

Tier 3 proper — Harbor-sandboxed paired with/without-skill trials and Skill Lift —
remains unbuilt. Do not treat the `run_summary.delta` numbers in
`benchmark.md` as Skill Lift.

## What is measured today

| Signal | Producer | Consumer |
|--------|----------|----------|
| `duration_ms` per eval | `scripts/lib/eval_executors.py` (command checks) | `run-evals.py --format json` |
| `total_tokens` per eval | `run_loop.py` `parse_token_usage()` from `claude --json` | `run-evals.py --format json` |
| token/time budget verdict | `aggregate_benchmark.py` `evaluate_budget()` | `benchmark.md` |

This covers **eval-harness cost, not agent trajectory cost**. It is a partial
Tier 3, sufficient to catch a skill that inflates spend without reducing wasted
work — the blog's headline finding that token savings are *not* automatic
(`cuopt-install` +120.3% tokens, versus `jetson-optimize-memory` −76.9%).
Budget limits are advisory named constants (`MAX_TOKEN_REGRESSION_PCT`,
`MAX_TIME_REGRESSION_PCT`, both 50%) and never fail a build.

## 4-bucket eval taxonomy

Eval cases may carry an optional `bucket` field, per NVIDIA's dataset generator:

| Bucket | Tests |
|--------|-------|
| `explicit` | Request directly names the skill's job |
| `implicit` | Request needs the skill without naming the job |
| `contextual` | Adjacent request; tests non-triggering boundaries |
| `negative` | Out of scope; the skill must stay unloaded |

The field is **advisory**: absent is always valid, so no existing `evals.json` is
retrofit. `check_structure.py` warns only when buckets are declared but none is
tagged `negative`, and `eval_validators.py` rejects an unknown bucket *value*.
This generalises the ADR-037 rule that new skills ship at least one adversarial
case.

## Conventions adopted

- **Exit codes**: `check-skill-overlap.sh` exits 0 advisory, 1 on findings
  with `--strict`, 2 on bad flags — mirroring SkillEvaluator 0/1/2.
- **Progressive adoption**: start advisory (`--strict` off), enforce later —
  per SkillEvaluator CI-integration guidance.
- **Reports**: `--format json` emits machine-readable pairs for CI artifacts.
- **Known limitation**: the detector catches **verbatim duplication only**. It is
  a lexical n-gram measure, so a skill that is semantically duplicated but
  reworded lands near the `0.0267` noise floor and is invisible to it. Treat
  output as a duplication finding, never as a similarity verdict.

## Correction to ADR-037

ADR-037 specified Tier 2 as *"description/trigger Jaccard"*; the implementation
scores whole `SKILL.md` bodies via 5-gram shingles. The implementation is what
ships, and this document is the accurate description. Scoring descriptions would
be closer to NVIDIA's intent but loses the signal from `Rationalizations` and
`Red Flags`, where most duplication actually occurs.

## References

- ADR-037 (`plans/adr-037-nvidia-skillevaluator-reuse.md`) — accepted, with the
  Tier 3 correction above
- NVIDIA SkillEvaluator benchmark blog:
  <https://developer.nvidia.com/blog/evaluating-ai-agent-skill-performance-with-nvidia-skillevaluator/>
- Argo Rollouts docs (canary + `AnalysisTemplate`): <https://argoproj.github.io/argo-rollouts/>
- Flagger docs (mirror pre-stage, A/B, B/G): <https://docs.flagger.app/>
- OWASP GenAI LLM Top 10 2026: <https://genai.owasp.org/>
- MITRE ATLAS: <https://atlas.mitre.org/>
- REDAgentBench (executable red-teaming, Aug 2026): <https://arxiv.org/abs/2608.10669>
