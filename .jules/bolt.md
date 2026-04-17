# Bolt Learnings - GitHub Actions Optimization

## Security & Reliability
- **SHA Pinning**: Mandatory for all actions to ensure supply chain security. Always append a `# vX.Y.Z` comment for Dependabot.
- **Timeout Management**: Every job should have `timeout-minutes` to prevent runaway costs and hanging runners. (Default: 5-10m for simple tasks, 30m+ for CodeQL).
- **Least Privilege (Job-Level)**: Explicitly define `permissions` at the **job level** rather than the workflow level. This minimizes the risk area and satisfies high-standard security scanners like SonarCloud.
- **Permission Defaults**: Start with `permissions: contents: read` and only add required scopes (e.g., `issues: write`, `pull-requests: write`, `security-events: write`).

## Performance & Cost
- **Concurrency**: Use `concurrency` groups with `cancel-in-progress: true` on PRs and development branches to prune redundant runs and save runner minutes.
- **Fail Fast**: Order steps and jobs to fail early (e.g., linting before expensive tests).

## Action Version Reference (2026-04-17)
- `actions/checkout@de0fac2e4500dabe0009e67214ff5f5447ce83dd` # v6.0.2
- `actions/setup-node@53b83947a5a98c8d113130e565377fae1a50d02f` # v6.3.0
- `actions/setup-python@a309ff8b426b58ec0e2a45f0f869d46889d02405` # v6.2.0
- `actions/setup-go@4a3601121dd01d1626a1e23e37211e3254c1c06c` # v6.4.0
- `actions/github-script@d746ffe35508b1917358783b479e04febd2b8f71` # v9.0.0
- `actions/stale@b5d41d4e1d5dceea10e7104786b73624c18a190f` # v10.2.0
- `github/codeql-action/*@7fc6561ed893d15cec696e062df840b21db27eb0` # v4.35.2
