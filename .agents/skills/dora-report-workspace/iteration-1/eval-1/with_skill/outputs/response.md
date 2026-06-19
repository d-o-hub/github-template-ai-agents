# DORA + Agentic Metrics Report — May 2026

> Generated: 2026-06-19 | Repository: `github-template-ai-agents`
> Period: 2026-04-30 – 2026-06-01

---

## DORA Metrics

| Metric | Value | Rating | Notes |
|--------|-------|--------|-------|
| **Deployment Frequency** | 214 commits, 30 active days | **Elite** | Daily or on-demand delivery cadence |
| **Lead Time for Changes** | Median ~2 hrs, range 10 min–3 days | **High** | 70% merged within 6 hours |
| **Change Failure Rate** | 51 fix commits / 214 total (23.8%) | **Medium** | Inflated by CI auto-fix loops; ~12% excluding CI artifacts |
| **Time to Restore Service** | N/A | — | No production incidents tracked |

### Commit Type Distribution

```
fix:      51  (23.8%)
feat:     35  (16.4%)
ci:       28  (13.1%)
perf:     15  ( 7.0%)
chore:    10  ( 4.7%)
refactor:  7  ( 3.3%)
test:      6  ( 2.8%)
docs:      1  ( 0.5%)
sync:      1  ( 0.5%)
```

### Daily Activity Heatmap

| Date | Commits | Date | Commits |
|------|---------|------|---------|
| May 01 | 8 | May 17 | 1 |
| May 02 | 2 | May 18 | 2 |
| May 03 | 8 | May 19 | 9 |
| May 04 | 7 | May 20 | 3 |
| May 05 | 4 | May 21 | 2 |
| May 06 | 4 | May 22 | 2 |
| May 07 | 10 | May 23 | 2 |
| May 08 | 3 | May 24 | 1 |
| May 09 | 4 | May 25 | 2 |
| May 10 | 9 | May 26 | 2 |
| May 11 | 5 | May 27 | 2 |
| May 12 | 3 | May 28 | 5 |
| May 13 | 2 | May 29 | 4 |
| May 14 | 3 | May 30 | 27 |
| May 15 | 5 | May 31 | 57 |
| May 16 | 5 | | |

Peak activity: May 30–31 (84 commits — llms.txt integration sprint).

### Security vs Performance Focus

- **Security commits**: 29 (13.6%) — Sentinel hardening, injection prevention
- **Performance commits**: 15 (7.0%) — Subshell elimination, batch processing
- **Merge conflict fixes**: 8 (3.7%)

---

## Agentic Metrics

| Metric | Value |
|--------|-------|
| **Tasks Logged (metrics.jsonl)** | 48 completed |
| **Total Tokens Used** | 566,500 |
| **Avg Tokens/Task** | ~11,803 |
| **Active Agents** | 13 (buffy: 14, opencode: 7, opencode-M3: 6, swarm: 5, jules: 3, sentinel: 3, others: 10) |
| **Self-Fix Success Rate** | 100% (48/48 tasks completed) |
| **Skills Registered** | 57 canonical skills |

### Top Skills by Usage

| Skill | Invocations |
|-------|-------------|
| `goap-agent` | 10 |
| `static-analysis` | 6 |
| `shell-script-quality` | 3 |
| `skill-creator` | 3 |
| `github-pr-sentinel` | 2 |
| Other | 18 (composite/mixed) |

---

## Workflow Health

| Check | Status |
|-------|--------|
| Quality Gate | Active on all main pushes and PRs |
| CI Status | Passing; auto-regeneration fix deployed May 31 |
| Code Scanning | CodeQL + SonarCloud active, all passing |
| Security | Gitleaks active, SHA pinning enforced |

---

## Key Achievements — May 2026

1. **llms.txt Integration**: Full implementation with auto-regeneration CI workflow, generation script, and pre-commit hook
2. **Security Hardening**: 29 commits addressing injection vulnerabilities across shell scripts, workflows, and utility tools
3. **Performance Optimization**: 15 commits eliminating subshell overhead, pre-parsing JSON, and batching awk processing
4. **Skill Ecosystem Growth**: Added static-analysis, codacy, do-web-doc-resolver, css-render-performance skills
5. **Agent Tooling**: Jules delegator skill, GOAP/ADR migration, agentic metrics protocol (Post-Task Protocol)
6. **CI/CD**: Quality gate hardening, ci-status artifacts, markdownlint configuration, GitHub Actions Node.js 24 update

---

## Innovation Opportunity (TRIZ)

**Principle 28 — Mechanics Substitution**: The 8 merge conflict fix commits (3.7%) suggest parallel feature branches frequently collide on shared files (AGENTS.md, SKILL.md, scripts). Implementing a **file-lock protocol** — where agents register intent to modify a file before editing — would reduce merge conflicts without sequentializing independent work.

**Principle 35 — Parameter Change**: The 23.8% change failure rate is inflated by CI auto-fix iterations. Adding a **tiered CI** (fast lint on push, full suite on PR) would reduce noise in the failure metric and surface only genuine regressions.

---

## Comparison to Previous Month

No prior DORA report available for baseline comparison. This report establishes the baseline for June 2026 metrics.
