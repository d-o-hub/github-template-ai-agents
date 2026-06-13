---
name: cicd-pipeline
version: "0.2.10"
description: Design and implement CI/CD pipelines with GitHub Actions, GitLab CI, and Forgejo Actions. Includes pipeline optimization, secrets management, and failure handling patterns.
category: workflow
---

# CI/CD Pipeline

Design and implement efficient, secure, and reliable CI/CD pipelines.

## Pipeline Patterns

- **Parallel Execution**: Run independent jobs simultaneously.
- **Matrix Builds**: Test multiple environment variants.
- **Caching**: Use `setup-*` actions with built-in caching for dependencies.
- **Artifacts**: Optimize upload size and retention.

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

## References

- [Performance Checklist](../../../agents-docs/references/performance-checklist.md) - CI/CD optimization patterns, caching strategies, and runner sizing.
- `references/deployment-strategies.md` - Blue-green, canary, and rolling deployments.
- `references/failure-recovery.md` - Handling pipeline failures and rollbacks.
- `references/security-scanning.md` - Integrating security tools into pipelines.
