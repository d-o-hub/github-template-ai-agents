# Skill Evaluation Tiers (NVIDIA SkillEvaluator Reuse)

Reuse of [NVIDIA SkillEvaluator](https://github.com/NVIDIA/SkillEvaluator)
(Apache-2.0; paper: [*Evaluating Skills, Not Just Agents*](https://arxiv.org/abs/2608.20614))
tier semantics **without vendoring** — zero new runtime dependencies.
See ADR-037.

## Tier mapping

| NVIDIA tier | Template equivalent | Gate |
|-------------|---------------------|------|
| Tier 1 Validation (static validators, secrets, license, hygiene, quality score) | `scripts/validate-skills.sh` + `quality_gate.sh` + `evals/evals.json` | Always gates (existing) |
| Tier 2 Deduplication (inter-skill similarity vs catalog) | `scripts/check-skill-overlap.sh` (word-5-gram Jaccard heuristic, no embeddings) | Advisory default; `--strict` gates |
| Tier 3 Live Evaluation (paired with/without-skill trials, Skill Lift) | `skill-creator` `run_loop.py` + benchmark flow (opt-in execution) | Advisory; gate when team opts in |

## Conventions adopted

- **Exit codes**: `check-skill-overlap.sh` exits 0 advisory, 1 on findings
  with `--strict`, 2 on bad flags — mirroring SkillEvaluator 0/1/2.
- **Progressive adoption**: start advisory (`--strict` off), enforce later —
  per SkillEvaluator CI-integration guidance.
- **EVAL.md negatives**: adversarial/negative prompts are first-class eval
  citizens. Every new skill ships at least one adversarial case in
  `evals/evals.json` (see `progressive-delivery` evals 3–4).
- **Reports**: `--format json` emits machine-readable pairs for CI artifacts.
- **Known limitation**: the heuristic catches verbatim duplication only
  (e.g. `triz-analysis`/`triz-solver` at 0.088); semantic-only overlap needs
  embeddings + LLM verification (future work, cf. SkillEvaluator Tier 2).

## References

- ADR-037 (`plans/adr-037-nvidia-skillevaluator-reuse.md`)
- Argo Rollouts docs (canary + `AnalysisTemplate`): <https://argoproj.github.io/argo-rollouts/>
- Flagger docs (mirror pre-stage, A/B, B/G): <https://docs.flagger.app/>
- OWASP GenAI LLM Top 10 2026: <https://genai.owasp.org/>
- MITRE ATLAS: <https://atlas.mitre.org/>
- REDAgentBench (executable red-teaming, Aug 2026): <https://arxiv.org/abs/2608.10669>
