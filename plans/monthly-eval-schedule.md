# Monthly Skill Evaluation Schedule

Rotate through all 57 skills, testing 5 per month. Each month runs:
1. Live evals (with-skill vs without-skill baseline)
2. Trigger query testing (20 queries per skill)
3. Description optimization if accuracy drops below 85%

## Workspace Structure

Per the skill-evaluator spec:

```
<skill-name>-workspace/
└── iteration-1/
    ├── eval-1/
    │   ├── with_skill/
    │   │   ├── response.md
    │   │   ├── timing.json
    │   │   └── grading.json
    │   └── without_skill/
    │       ├── response.md
    │       ├── timing.json
    │       └── grading.json
    ├── eval-2/...
    ├── eval-3/...
    ├── benchmark.json
    └── grading.json
```

## Month 1 — Agent & Accessibility (COMPLETED)

| Skill | With Skill | Without Skill | Delta | Verdict |
|-------|-----------|---------------|-------|---------|
| accessibility-auditor | 3/3 (100%) | 3/3 (100%) | 0 | PASS |
| agent-browser | 3/3 (100%) | 2/3 (67%) | +1 | PASS |
| agent-coordination | 3/3 (100%) | 2/3 (67%) | +1 | PASS |
| agents-md | 3/3 (100%) | 3/3 (100%) | 0 | PASS |
| anti-ai-slop | 3/3 (100%) | 3/3 (100%) | 0 | PASS |

**Average delta**: +0.4 assertions
**Key finding**: agent-browser and agent-coordination show skill value (snapshot refs and quality gates respectively)

## Month 2 — API & Pipeline (COMPLETED)

| Skill | With Skill | Without Skill | Delta | Verdict |
|-------|-----------|---------------|-------|---------|
| api-design-first | 4/4 (100%) | 4/4 (100%) | 0 | PASS |
| architecture-diagram | 3/3 (100%) | 2/3 (67%) | +1 | PASS |
| cicd-pipeline | 3/3 (100%) | 3/3 (100%) | 0 | PASS |
| cloudflare-worker-api | 3/3 (100%) | 3/3 (100%) | 0 | PASS |
| codacy | 2/2 (100%) | 2/2 (100%) | 0 | PASS |

**Average delta**: +0.2 assertions
**Key finding**: architecture-diagram shows skill value (script scanning live structure vs manual approach)

## Month 3 — Code Quality & Database (COMPLETED)

| Skill | With Skill | Without Skill | Delta | Verdict |
|-------|-----------|---------------|-------|---------|
| codacy-cloud-cli | BLOCKED | 2/2 (100%) | — | BLOCKED (needs auth token) |
| code-review-assistant | 2/2 (100%) | BLOCKED | — | BLOCKED (no matching PR) |
| codeberg-api | 2/3 (67%) | 3/3 (100%) | -1 | PASS (without_skill used direct API) |
| css-render-performance | 3/3 (100%) | 2/3 (67%) | +1 | PASS |
| database-devops | 4/5 (80%) | 4/5 (80%) | 0 | PASS |

**Average delta**: +0.25 (excluding blocked)
**Key finding**: css-render-performance shows skill value (decision flowchart and containment guidance)

## Month 4 — Retrieval & Docs

| Skill | Cluster | Focus |
|-------|---------|-------|
| delegate | agent | Context retrieval and handoff (optimized in session) |
| dist-channel-selection | tool | Package publishing channel |
| do-web-doc-resolver | tool | URL to markdown resolution |
| docs-hook | workflow | Git hook documentation sync |
| document-rendering-and-locators | workflow | Document rendering and anchoring |

## Month 5 — Quality & Git

| Skill | Cluster | Focus |
|-------|---------|-------|
| dogfood | quality | Web app exploratory testing |
| dora-report | devops | Monthly metrics reporting |
| durable-objects | platform | Cloudflare DO patterns (optimized in session) |
| eu-ai-act-compliance | compliance | EU AI Act requirements |
| git-github-workflow | workflow | Full lifecycle (optimized in session) |

## Month 6 — Orchestration

| Skill | Cluster | Focus |
|-------|---------|-------|
| github-pr-sentinel | workflow | PR monitoring and CI diagnosis |
| goap-agent | workflow | Multi-step planning (optimized in session) |
| implementer | agent | Atomic code execution |
| intent-classifier | agent | Skill routing logic |
| iterative-refinement | code-quality | Test-fix improvement loops |

## Month 7 — Delegation & Learning

| Skill | Cluster | Focus |
|-------|---------|-------|
| jules-delegator | agent | Jules CLI session creation |
| learn | knowledge | Session learning extraction |
| lifecycle-management | quality | Resource cleanup patterns |
| memory-context | knowledge | Past context retrieval |
| migration-refactoring | code-quality | Framework migration workflows |

## Month 8 — Parallel & Privacy

| Skill | Cluster | Focus |
|-------|---------|-------|
| parallel-execution | agent | Concurrent task execution |
| privacy-first | security | PII detection and prevention (optimized in session) |
| pwa-offline-sync | workflow | Offline-first service workers |
| reader-ui-ux | workflow | Reader/admin UI patterns |
| readme-best-practices | documentation | README creation and audit |

## Month 9 — Security & Skills

| Skill | Cluster | Focus |
|-------|---------|-------|
| secure-invite-and-access | workflow | Auth endpoint patterns |
| security-code-auditor | security | Security audit workflows (optimized in session) |
| shell-script-quality | code-quality | ShellCheck and BATS testing |
| skill-creator | quality | Skill authoring and optimization |
| skill-evaluator | quality | Skill evaluation and scoring |

## Month 10 — Analysis & Testing

| Skill | Cluster | Focus |
|-------|---------|-------|
| static-analysis | code-quality | Linter triage and fix workflows (optimized in session) |
| task-decomposition | agent | Complex task breakdown |
| template-version-management | tool | Template versioning (optimized in session) |
| test-runner | testing | Test execution and diagnosis |
| testdata-builders | quality | Test fixture creation |

## Month 11 — Strategy & Innovation

| Skill | Cluster | Focus |
|-------|---------|-------|
| testing-strategy | testing | Test approach selection (optimized in session) |
| triz-analysis | analysis | TRIZ contradiction auditing |
| triz-solver | innovation | TRIZ problem solving |
| turso-db | database | Turso/LibSQL development (optimized in session) |
| ui-ux-optimize | ui-ux | UI/UX optimization with swarm |

## Month 12 — Templates & Research

| Skill | Cluster | Focus |
|-------|---------|-------|
| verification-template | quality | Verification checklist creation |
| web-search-researcher | tool | Web research and synthesis |

## Eval Protocol

For each skill, run:

### 1. Trigger Testing (20 queries)

Generate 10 should-trigger + 10 should-not-trigger queries. Run keyword analysis and real trigger tests on edge cases.

### 2. Live Evals (1 case per skill)

Run the most representative eval case with-skill vs without-skill. Grade against assertions with evidence.

### 3. Description Check

Verify description has:
- Pushy "even if they" language
- Negative triggers excluding overlapping skills
- Under 1024 characters
- Keyword accuracy ≥ 85%

### 4. Structural Check

Verify skill has:
- `## When to Use` section
- `## Rationalizations` with correct headers
- `## Red Flags` checklist
- `## See Also` cross-references
- Under 250 lines

## Metrics Tracking

Append results to `.agents/metrics.jsonl` after each monthly eval cycle:

```json
{
  "timestamp": "YYYY-MM-DDTHH:MM:SSZ",
  "agent": "mimo-auto",
  "task": "Monthly skill eval: <skill-name>",
  "skill_used": "skill-evaluator",
  "status": "completed",
  "tokens_used": 0,
  "duration_seconds": 0,
  "notes": "Trigger accuracy: X%, live eval: Y/Z assertions passed"
}
```

## Review Cadence

- **Weekly**: Check CI status on any description changes
- **Monthly**: Run full eval cycle on 5 skills
- **Quarterly**: Review metrics trends, identify skills needing deeper optimization
- **Annually**: Full audit of all 57 skills against latest agentskills.io spec

## Session Summary (2026-06-19)

### Completed this session

- **57/57 skills** have pushy "even if they" trigger language
- **57/57 skills** have negative triggers excluding overlapping skills
- **57/57 skills** have `## When to Use`, `## Rationalizations`, `## Red Flags`, `## See Also`
- **10 skills** fully optimized with real trigger testing (accuracy ≥ 85%)
- **4 skills** enriched with actionable content (cicd-pipeline, testing-strategy, delegate, implementer)
- **1 skill** trimmed (code-review-assistant: 259 → 167 lines)
- **1 skill** deprecated (self-fix-loop → git-github-workflow)
- **Month 1 evals** completed (5 skills, 15 assertions graded)
- **2 PRs** merged to main

### Skills with description optimization (trigger-tested)

| Skill | Before | After |
|-------|--------|-------|
| git-github-workflow | 55% | 85% |
| cicd-pipeline | 67% | 100% |
| goap-agent | 75% | 100% |
| agent-browser | 85% | 100% |
| codeberg-api | 0 pushy | 2 pushy |
| durable-objects | 0 pushy | 1 pushy |
| turso-db | 0 pushy | 1 pushy |
| privacy-first | 90% | 100% |
| template-version-management | 0 pushy | 1 pushy |
| security-code-auditor | 0 pushy | 1 pushy |
