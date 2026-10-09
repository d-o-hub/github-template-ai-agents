# Monthly Skill Evaluation Schedule

## Current Evidence Status

This is a maintenance plan, not evidence of completed behavioral evaluations.
Repository checks (`check_structure.py`, `eval-skills.sh`, `run-evals.py`) are
static audits/smoke checks. They invoke no model and cannot establish behavioral
PASS, trigger accuracy, token savings, or uplift over a baseline.

Manual paired trials are scheduled only when an operator can capture independent
with-skill and without-skill outputs. Until evidence is linked for both sides,
behavioral status is **NOT_RUN** (or **BLOCKED** with a reason).

## Inventory-Derived Rotation

Rebuild the queue from canonical directories containing `SKILL.md`, excluding
`_`-prefixed support folders and `*-workspace` directories. Do not maintain a
hardcoded skill count or a fixed list that retains removed/consolidated names.
Use an annual cycle and derive the monthly batch size from the current inventory.

The following prints a plan only; it does not run behavioral evaluations:

```python
from math import ceil
from pathlib import Path

MONTHS_PER_CYCLE = 12
root = Path(".agents/skills")
skills = sorted(
    path.name for path in root.iterdir()
    if path.is_dir() and (path / "SKILL.md").is_file()
    and not path.name.startswith("_") and not path.name.endswith("-workspace")
)
if not skills:
    raise SystemExit("No canonical skills found; cannot build rotation")
batch_size = ceil(len(skills) / MONTHS_PER_CYCLE)
for month in range(MONTHS_PER_CYCLE):
    batch = skills[month * batch_size:(month + 1) * batch_size]
    print(f"Month {month + 1}: {', '.join(batch) or 'catch-up / reruns'}")
```

At cycle start, record the inventory snapshot and review date in the evidence
directory. Prioritize recently changed skills or unresolved findings, then
return to the queue; record deferrals so every current skill is covered.

## Monthly Protocol

1. **Static audit:** check layout/schema/fixtures and the template-local minimum
   of 3 eval cases. Record command, exit status, date, and static-only verdict.
2. **Definition review:** read assertions and routing boundaries. Verify that
   contextual cases supply context and negative cases actually stay out of scope.
3. **Manual paired trials, if available:** use fresh isolated sessions with the
   same prompts, fixtures, model configuration, and tool access. Follow
   `skill-evaluator`'s manual-paired protocol; no automated model runner is shipped.
4. **Evidence-based grading:** cite actual output/transcript artifacts for each
   scored assertion, and identify case IDs and denominators. Mark blocked cases
   separately; never count missing output as PASS.
5. **Description review:** compare observed routing for should-trigger and
   should-not-trigger cases before editing descriptions. Keyword inspection alone
   is not a measured trigger-accuracy result. Use `skill-creator` for changes.
6. **Report scope:** keep static status and behavioral status separate. Record
   tokens, timing, cost, or accuracy only when measured with a cited source;
   otherwise write **not measured**, not numeric placeholders or estimates.

Static checks require local fixtures, not service credentials. For a manual trial
that needs authentication or a live service, use authorized mocks/dry-runs when
appropriate or report BLOCKED. Do not claim a blocked case passed.

## Evidence Layout and Review Cadence

Keep temporary trials outside the repository in a user-approved directory.
For each selected skill, save the inventory snapshot, configuration, case IDs,
paired transcripts/outputs, assertion grading, and a scoped summary. Link those
artifacts before marking a behavioral trial complete.

- **On skill changes:** rerun relevant static checks and review affected assertions.
- **Monthly:** process the inventory-derived batch; capture manual trials only
  when the execution environment and evidence are available.
- **Quarterly:** review unresolved findings, deferrals, and evidence quality.
- **Annually:** refresh the inventory and rotation; audit all current canonical skills.

## Archive: Unverified Human Notes

The following records were inherited from the previous schedule, including its
2026-06-19 session summary. They are **unverified human notes**: no linked paired
output artifacts, grading evidence, or measurement sources accompany these
tables here. Reported scores/verdicts are preserved for historical context, not
endorsed as current results or automated behavioral runs. Old skill names in
this archive are historical only and are excluded from the active rotation.

### Reported Month 1 — Agent & Accessibility

| Skill (historical) | Reported with skill | Reported without skill | Reported delta | Reported verdict |
|---|---|---|---|---|
| accessibility-auditor | 3/3 (100%) | 3/3 (100%) | 0 | PASS |
| agent-browser | 3/3 (100%) | 2/3 (67%) | +1 | PASS |
| agent-coordination | 3/3 (100%) | 2/3 (67%) | +1 | PASS |
| agents-md | 3/3 (100%) | 3/3 (100%) | 0 | PASS |
| anti-ai-slop | 3/3 (100%) | 3/3 (100%) | 0 | PASS |

Unverified note: average delta +0.4 assertions; value attributed to agent-browser
snapshot references and agent-coordination quality gates.

### Reported Month 2 — API & Pipeline

| Skill (historical) | Reported with skill | Reported without skill | Reported delta | Reported verdict |
|---|---|---|---|---|
| api-design-first | 4/4 (100%) | 4/4 (100%) | 0 | PASS |
| architecture-diagram | 3/3 (100%) | 2/3 (67%) | +1 | PASS |
| cicd-pipeline | 3/3 (100%) | 3/3 (100%) | 0 | PASS |
| cloudflare-worker-api | 3/3 (100%) | 3/3 (100%) | 0 | PASS |
| codacy | 2/2 (100%) | 2/2 (100%) | 0 | PASS |

Unverified note: average delta +0.2 assertions; value attributed to
architecture-diagram live-structure scanning.

### Reported Month 3 — Code Quality & Database

| Skill (historical) | Reported with skill | Reported without skill | Reported delta | Reported verdict |
|---|---|---|---|---|
| codacy-cloud-cli | BLOCKED | 2/2 (100%) | — | BLOCKED (needs auth token) |
| code-review-assistant | 2/2 (100%) | BLOCKED | — | BLOCKED (no matching PR) |
| codeberg-api | 2/3 (67%) | 3/3 (100%) | -1 | PASS (baseline used direct API) |
| css-render-performance | 3/3 (100%) | 2/3 (67%) | +1 | PASS |
| database-devops | 4/5 (80%) | 4/5 (80%) | 0 | PASS |

Unverified note: average delta +0.25 excluding blocked cases; value attributed
to css-render-performance decision flowchart and containment guidance.

### Reported Month 4 — Retrieval & Docs

| Skill (historical) | Reported with skill | Reported without skill | Reported delta | Reported verdict |
|---|---|---|---|---|
| delegate | 3/3 (100%) | 3/3 (100%) | 0 | PASS |
| dist-channel-selection | 4/5 (80%) | 3/5 (60%) | +1 | PASS |
| do-web-doc-resolver | 4/4 (100%) | 3/4 (75%) | +1 | PASS |
| docs-hook | 3/3 (100%) | 2/3 (67%) | +1 | PASS |
| document-rendering-and-locators | 3/3 (100%) | 2/3 (67%) | +1 | PASS |

Unverified note: average delta +0.8 assertions; value attributed to version
guidance, quality scoring, low-overhead docs hooks, and locator fallback chains.

### Reported Month 5 — Quality & Git

| Skill (historical) | Reported with skill | Reported without skill | Reported delta | Reported verdict |
|---|---|---|---|---|
| dogfood | 2/3 (67%) | 2/3 (67%) | 0 | PASS (localhost not running) |
| dora-report | 3/3 (100%) | 2/3 (67%) | +1 | PASS |
| durable-objects | 4/4 (100%) | 3/4 (75%) | +1 | PASS |
| eu-ai-act-compliance | 3/3 (100%) | 3/3 (100%) | 0 | PASS |
| git-github-workflow | 3/3 (100%) | 3/3 (100%) | 0 | PASS |

Unverified note: average delta +0.4 assertions; value attributed to DORA/TRIZ
guidance and Durable Object RPC/SQLite examples. Blocked/missing live services
are not acceptable evidence for a new behavioral PASS under the current protocol.

### Reported Session Summary (2026-06-19)

Historical claims, not the current inventory or verified measurements:

- 57/57 skills had expanded trigger language, negative boundaries, and the listed sections.
- 10 skills were trigger-tested/optimized with reported accuracy at least 85%.
- 4 skills were enriched: cicd-pipeline, testing-strategy, delegate, implementer.
- code-review-assistant was trimmed from 259 to 167 lines.
- self-fix-loop was deprecated in favor of git-github-workflow.
- Month 1 covered 5 skills / 15 assertions; 2 PRs were reported merged.

| Skill (historical) | Reported before | Reported after |
|---|---|---|
| git-github-workflow | 55% | 85% |
| cicd-pipeline | 67% | 100% |
| goap-agent | 75% | 100% |
| agent-browser | 85% | 100% |
| codeberg-api | 0 pushy phrases | 2 pushy phrases |
| durable-objects | 0 pushy phrases | 1 pushy phrase |
| turso-db | 0 pushy phrases | 1 pushy phrase |
| privacy-first | 90% | 100% |
| template-version-management | 0 pushy phrases | 1 pushy phrase |
| security-code-auditor | 0 pushy phrases | 1 pushy phrase |
