# ADR-037: Reuse NVIDIA SkillEvaluator Tiers + Production Delivery Pipeline

Status: Accepted (build mode, 2026-09-27)
Date: 2026-09-27

> **Correction (2026-09-27).** Decision 1's Tier 3 mapping was wrong on
> verification. `skill-creator/scripts/run_loop.py` is a *description optimization
> loop for skill frontmatter* (trigger precision/recall), not a live-run harness,
> and `aggregate_benchmark.py` consumes `timing.json`/`grading.json` that nothing
> in the repo writes. Tier 3 is **not implemented**. Two smaller defects in the
> Tier 2 deliverable are also fixed: a missing `import sys` made `--strict` raise
> `NameError`, and the `0.04` threshold exceeded every score in the 54-skill
> catalog (observed max `0.0267`), so the check could never fire. Threshold is
> now `0.02`; `agents-docs/SKILL_EVAL_TIERS.md` is the accurate description.
> The rest of this ADR stands.

## Context

[NVIDIA SkillEvaluator](https://github.com/NVIDIA/SkillEvaluator) (Apache-2.0,
520 stars) is a three-tier framework for evaluating AI agent skills, grounded in
[*Evaluating Skills, Not Just Agents*](https://arxiv.org/abs/2608.20614)
(paired with/without-skill trials, Skill Lift):

- **Tier 1 Validation** — static validators (frontmatter, schema, secrets,
  license, hygiene, markdown, script lint) + quality score; always gates;
  keyless/offline-first; exit codes 0/1/2/3; progressive adoption
  (advisory → blocking → +LLM → +Tier 3).
- **Tier 2 Deduplication** — intra-skill embedding clusters + LLM verify
  (threshold 0.80); inter-skill similarity vs saved catalog; gates by default
  when run (`--no-block-on-dedup` for advisory).
- **Tier 3 Live Evaluation** — Harbor-sandboxed paired trials; advisory by
  default (`--block-on-agent-eval` to gate); eval dataset generation with
  four buckets **including negatives authored via `evals/EVAL.md`**.
- Supporting concepts: `doctor` readiness checks, `quality-check` keyless
  subset, policy overlays, `reports/` artifacts, `-c/--continue-on-failure`.

2026 best-practice sources (Sept 2026): Argo Rollouts official docs
(canary steps, `AnalysisTemplate` background/inline analysis, abort → weight
to zero + Degraded, 15–20 min rollouts, metrics verdict in 5–15 min);
Flagger v1.44 (CNCF graduated; `mirror:true` shadow pre-stage, threshold /
iterations, A/B + B/G mirroring, Gateway API); OWASP GenAI LLM Top 10 2026 +
Agent Control Standard; REDAgentBench (executable red-teaming, pin protocol
not just ASR); MITRE ATLAS.

## Decision

1. **Map, don't vendor.** No dependency on `skillevaluator` (Python/LLM/Docker
   stack is too heavy for a generic template). Reuse the *tier semantics*:
   - Tier 1 → existing `scripts/validate-skills.sh` + `quality_gate.sh` +
     `evals/evals.json` (already equivalent; document mapping).
   - Tier 2 → new keyless heuristic `scripts/check-skill-overlap.sh`
     (description/trigger Jaccard, advisory default, `--strict` gate mode),
     mirroring NVIDIA's start-advisory adoption path (no embeddings needed).
   - Tier 3 → existing `skill-creator` `run_loop.py` + benchmark flow
     (document mapping; execution stays opt-in).
2. **Adopt `EVAL.md` negatives convention.** Adversarial/negative prompts are
   first-class eval citizens (per NVIDIA + REDAgentBench). New skill evals
   must include at least one adversarial case.
3. **New `progressive-delivery` skill** implementing the production loop:
   failure → reproduce → candidate fix → evaluate → adversarial evaluation →
   shadow → canary → promote/rollback, per Argo/Flagger 2026 practice
   (SLO-gated promotion, automatic abort on threshold breach, short rollouts).
4. **Record mapping** in `agents-docs/SKILL_EVAL_TIERS.md`, linked from the
   `skill-evaluator` skill (no fork of NVIDIA code; Apache-2.0 attribution
   in the doc).

## Consequences

- Positive: template gains NVIDIA-aligned eval rigor with zero new runtime
  dependencies; overlap audit (Round 6 dogfood) becomes a repeatable gate;
  production rollout guidance grounded in Sept 2026 official docs.
- Negative: heuristic Tier 2 has false positives/negatives vs embeddings —
  hence advisory default; LLM-backed verification remains future work.
- Risks: none to existing CI (new script is advisory-only in the gate).

## Addendum (2026-09-27)

5. **Adopt the 4-bucket eval taxonomy** as an optional `bucket` field
   (`explicit` / `implicit` / `contextual` / `negative`), generalising decision
   2. Advisory: absent is valid, so no existing `evals.json` is retrofitted.
6. **Adopt an advisory cost budget** over the token/time deltas that the eval
   harness already produces, targeting the blog's finding that token savings are
   not automatic (`cuopt-install` +120.3%). Named-constant limits
   (`MAX_TOKEN_REGRESSION_PCT`, `MAX_TIME_REGRESSION_PCT`) that report rather
   than fail, consistent with the progressive-adoption posture above.

Both additions stop short of Tier 3: they measure eval-harness cost, not agent
trajectory cost. Closing the Tier 3 gap — paired with/without-skill trials,
Harbor-style isolation, real Skill Lift — is tracked separately.
