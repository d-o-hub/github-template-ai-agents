# Workflow Reference

> Detailed workflow procedures referenced by AGENTS.md.
> Keep procedures here, not in AGENTS.md, to stay within `MAX_LINES_AGENTS_MD=150`.

## Pre-Existing Issue Resolution

**Fix ALL pre-existing issues before completing any task:**

- [ ] Lint warnings (shellcheck, markdownlint)
- [ ] Test failures
- [ ] Security vulnerabilities
- [ ] Documentation gaps (broken links, missing files)
- [ ] Code style violations

**Process:**

1. Run quality gate: `./scripts/quality_gate.sh`
2. Note all failures (even unrelated to your changes)
3. Fix ALL issues
4. Re-run quality gate to confirm zero failures

## Atomic Commit Workflow

The atomic commit pattern validates, commits, pushes, creates PR, and verifies CI.

```bash
# Create feature branch
git checkout -b feat/your-feature-name

# Make changes

# Run atomic commit (validates, commits, pushes, creates PR, verifies)
./scripts/atomic-commit/run.sh

# If checks fail, fix and retry
```

See `.opencode/commands/atomic-commit.md` for the full command specification.

## Post-Task Learning

After non-trivial work, capture non-obvious discoveries:

1. **Run the `learn` skill** if available, or manually append to the nearest relevant `AGENTS.md`
2. **Capture only**: hidden file relationships, surprising execution behavior, undocumented commands, fragile config, files that must change together
3. **Never write**: obvious facts, duplicates, verbose explanations, session-specific notes
4. **Scoping**: project-wide → root `AGENTS.md`; script-specific → `scripts/AGENTS.md`; skill-specific → `.agents/skills/<name>/AGENTS.md`

This ensures the template self-improves over time as projects evolve. See `agents-docs/LESSONS.md` for the verbose historical record.

## Quality Gate Usage

```bash
# Full quality gate (required before commit)
./scripts/quality_gate.sh

# Skip specific checks
SKIP_TESTS=true ./scripts/quality_gate.sh
SKIP_LINT=true ./scripts/quality_gate.sh
SKIP_LINKS=true ./scripts/quality_gate.sh

# Minimal quality gate (fast path for CI debugging)
./scripts/minimal_quality_gate.sh
```

## Dependabot PRs

Dependabot PRs are auto-merged via CI when all checks pass. Do not manually merge or close Dependabot PRs.

## GitHub Actions Best Practices

All workflows in this repository must adhere to the following security and reliability standards:

1. **Full SHA Pinning**: All actions must be pinned to a 40-character commit SHA. Always include a comment with the readable version (e.g., `uses: actions/checkout@SHA # v4`).
2. **Timeout Minutes**: Every job must include a `timeout-minutes` property to prevent hanging runners and unnecessary costs.
3. **Least Privilege**: Workflows and jobs must explicitly define `permissions`. Start with `permissions: contents: read` and only add required scopes.
4. **Concurrency Control**: Use `concurrency` groups with `cancel-in-progress: true` for PRs and development branches to optimize resource usage.
5. **Fail-Fast Pattern**: Sequence jobs and steps so that lightweight validations (linting, quality gates) run before expensive or time-consuming tests.
