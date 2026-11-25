# Forgejo Actions (CI/CD)

Forgejo Actions reference for authoring and configuring CI/CD workflows on
Forgejo and Codeberg instances (codeberg.org or self-hosted).

Triggering a run of an existing workflow via the REST API (repository dispatch)
belongs to the `codeberg-api` skill.

## Workflow Location

Place workflow files in the repository's `.forgejo/workflows/` directory.
Forgejo Actions are largely compatible with GitHub Actions syntax but may lag
behind on new features.

## Example: Build Workflow

```yaml
name: Build
on: [push, pull_request]
jobs:
  build:
    runs-on: docker
    steps:
      - uses: actions/checkout@v4
      - name: Run tests
        run: npm test
      - name: Build
        run: npm run build
```

`runs-on` must match a registered runner label (e.g. `docker`). Available
labels are listed under `/{owner}/{repo}/settings/actions/runners`.

## Manual and API Triggers

- Declare `on: workflow_dispatch` (optionally with `inputs:`) so the workflow
  can be run manually from the repository's Actions tab.
- Trigger via REST API:
  `POST /repos/{owner}/{repo}/actions/workflows/{filename}/dispatches` with
  body `{"ref":"refs/heads/main"}` (plus declared `inputs:`) — see the
  `codeberg-api` skill for dispatch mechanics, auth, and error handling.

## Best Practices (2026)

- Use **matrix builds** for parallel testing
- Enable **caching** for dependencies
- Use **branch protection** with required workflows
- Keep **secrets** for API tokens (`FORGEJO_TOKEN`) in the repository's secret store

## See Also

- `codeberg-api` — Trigger Forgejo/Codeberg workflow runs via the REST API
- [`deployment-strategies.md`](deployment-strategies.md) — Blue-green, canary, and rolling deployments
- [`failure-recovery.md`](failure-recovery.md) — Handling pipeline failures and rollbacks
- [`security-scanning.md`](security-scanning.md) — Integrating security tools into pipelines
