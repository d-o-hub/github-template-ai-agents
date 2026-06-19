# Monthly Skill Evaluation Schedule

Rotate through all 57 skills, testing 5 per month. Each month runs:
1. Live evals (with-skill vs without-skill baseline)
2. Trigger query testing (20 queries per skill)
3. Description optimization if accuracy drops below 85%

## Month 1 — Agent & Accessibility

| Skill | Cluster | Focus |
|-------|---------|-------|
| accessibility-auditor | ui-ux | WCAG compliance audit workflow |
| agent-browser | tool | Browser automation CLI triggering |
| agent-coordination | agent | Strategy selection and coordination |
| agents-md | documentation | AGENTS.md creation and quality gates |
| anti-ai-slop | ui-ux | AI slop detection and avoidance |

## Month 2 — API & Pipeline

| Skill | Cluster | Focus |
|-------|---------|-------|
| api-design-first | platform | OpenAPI spec creation |
| architecture-diagram | documentation | SVG diagram generation |
| cicd-pipeline | workflow | Pipeline design (optimized in session) |
| cloudflare-worker-api | workflow | Worker route definition |
| codacy | code-quality | Local Codacy CLI analysis |

## Month 3 — Code Quality & Database

| Skill | Cluster | Focus |
|-------|---------|-------|
| codacy-cloud-cli | code-quality | Cloud Codacy API queries |
| code-review-assistant | code-quality | PR review workflow |
| codeberg-api | platform | Forgejo API operations (optimized in session) |
| css-render-performance | code-quality | CSS render optimization (optimized in session) |
| database-devops | database | Schema design and migrations |

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
