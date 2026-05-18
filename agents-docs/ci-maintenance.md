# CI/CD Maintenance Rules

> Manually maintained. Review before every workflow change or GitHub deprecation cycle.

1. **Action Node Runtime Verification**: Before adding or bumping a GitHub Action, verify its runtime via `curl -s https://raw.githubusercontent.com/{owner}/{repo}/{tag}/action.yml | grep "using:"`. Prefer `node24` (or `composite`) over `node20`.
2. **Build Job Timeouts**: Set `timeout-minutes` on all build and test jobs (e.g., `20`) to prevent hangs from consuming runner minutes.
3. **Action Node Hardening**: Prefer pinning actions to specific commit SHAs with a version comment (e.g., `uses: actions/checkout@de0fac2e4500dabe0009e67214ff5f5447ce83dd # v4.2.2`).
4. **Local CI Rehearsal**: Always test workflow changes locally using `./scripts/run_act_local.sh` (requires `nektos/act`) before pushing.
5. **Periodic Action Audit**: Re-audit all workflow actions every GitHub deprecation cycle or when Node runtime warnings appear in logs.
