---
name: cicd-pipeline
version: "0.2.10"
description: Design and implement CI/CD pipelines with GitHub Actions, GitLab CI, and Forgejo Actions. Use this skill when the user asks to set up, optimize, or troubleshoot CI/CD pipelines, configure workflow triggers, manage secrets in pipelines, handle pipeline failures, or implement deployment strategies — even if they don't say "CI/CD" explicitly.
category: workflow
license: MIT
---

# CI/CD Pipeline

Design and implement efficient, secure, and reliable CI/CD pipelines.

## When to Use

- User asks to set up, optimize, or troubleshoot CI/CD pipelines
- Configuring workflow triggers or managing secrets in pipelines
- Handling pipeline failures or implementing deployment strategies
- Even if they just say "set up CI" or "fix the pipeline"

## Platform Comparison

| Platform | Config Location | Runner | Secrets |
|----------|----------------|--------|---------|
| GitHub Actions | `.github/workflows/` | GitHub-hosted or self-hosted | `secrets.*` context |
| GitLab CI | `.gitlab-ci.yml` | Shared or specific runners | `$CI_JOB_VAULT` |
| Forgejo Actions | `.forgejo/workflows/` | Docker or host | Repository secrets |

## Pipeline Design Workflow

1. **Define triggers** — Push, PR, schedule, or manual dispatch. Use `paths` filters to skip unnecessary runs.
2. **Structure jobs** — Separate lint, test, build, and deploy into distinct jobs. Use dependencies for ordering.
3. **Add caching** — Cache dependencies (npm, pip, cargo) between runs. Reduces build times 30-70%.
4. **Manage secrets** — Never hardcode tokens. Use platform secret stores and rotate regularly.
5. **Add security scanning** — Run SAST, dependency scanning, and secret detection in CI.
6. **Configure notifications** — Alert on failures to Slack, Discord, or email.

## Common Failure Patterns

| Symptom | Likely Cause | Fix |
|---------|--------------|-----|
| Timeout on checkout | Shallow clone + large repo | Increase `fetch-depth` or use `--depth 1` |
| OOM during test | Too many parallel tests | Limit concurrency or add swap |
| Flaky test failures | Race conditions or external deps | Quarantine flaky tests, add retries |
| Secret not found | Wrong environment scope | Verify secret is available in the correct job/environment |
| Cache not restoring | Cache key mismatch | Use `hashFiles()` for deterministic keys |

## Gotchas

- GitHub Actions `GITHUB_TOKEN` expires after 1 hour — don't use it for long-running workflows.
- GitLab CI `rules:` and `only/except` are mutually exclusive — pick one per job.
- Forgejo Actions are compatible with GitHub Actions syntax but may lag behind on new features.
- Matrix builds multiply cost — a 3x3 matrix runs 9 jobs, not 3.
- Artifact retention defaults vary by platform — set explicit retention to avoid storage costs.

## Rationalizations

| Rationalization | Reality |
|-----------------|---------|
| "We don't need secrets management, we'll use environment variables" | Environment variables leak in logs, PRs, and error messages. Use secrets managers and rotate keys. |
| "Caching slows down the pipeline" | Properly configured caching reduces build times by 30-70% and costs. |
| "We'll add security scanning later" | Security vulnerabilities found in production are 100x more expensive to fix than in CI. |

## Red Flags

- [ ] Hardcoding secrets or tokens in workflow files
- [ ] Skipping security scanning in CI for speed
- [ ] Not caching dependencies between pipeline runs
- [ ] Using `actions/checkout@v3` instead of `@v4` (missing security fixes)

## References

- [Performance Checklist](../../../agents-docs/references/performance-checklist.md) - CI/CD optimization patterns, caching strategies, and runner sizing.
- `references/deployment-strategies.md` - Blue-green, canary, and rolling deployments.
- `references/failure-recovery.md` - Handling pipeline failures and rollbacks.
- `references/security-scanning.md` - Integrating security tools into pipelines.

## See Also

- `git-github-workflow` — Full commit-to-merge lifecycle including CI monitoring
- `github-pr-sentinel` — Specialized PR monitoring with CI failure diagnosis
