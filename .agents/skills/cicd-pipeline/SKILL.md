---
name: cicd-pipeline
version: "0.2.10"
description: Design and implement CI/CD pipelines with GitHub Actions, GitLab CI, and Forgejo Actions. Includes pipeline optimization, secrets management, and failure handling patterns.
---

# CI/CD Pipeline

Design and implement efficient, secure, and reliable CI/CD pipelines.

## Pipeline Patterns

- **Parallel Execution**: Run independent jobs simultaneously.
- **Matrix Builds**: Test multiple environment variants.
- **Caching**: Use `setup-*` actions with built-in caching for dependencies.
- **Artifacts**: Optimize upload size and retention.

## References

- [Performance Checklist](../../../agents-docs/references/performance-checklist.md) - CI/CD optimization patterns, caching strategies, and runner sizing.
- `references/deployment-strategies.md` - Blue-green, canary, and rolling deployments.
- `references/failure-recovery.md` - Handling pipeline failures and rollbacks.
- `references/security-scanning.md` - Integrating security tools into pipelines.
