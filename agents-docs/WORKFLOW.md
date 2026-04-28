# Workflow Reference

> Detailed workflow procedures referenced by AGENTS.md.

## PR & Commit Guidelines

- **Branching**: Use one branch per feature or bugfix.
- **Scope**: Ensure each PR addresses exactly one concern.
- **Protection**: NEVER commit directly to the `main` branch.

### Commit Type Mapping

Use the following mapping to choose the correct commit type for security-related changes:

| Intent                        | Type     | Scope suggestion |
|-------------------------------|----------|------------------|
| Security patch / hardening    | `fix`    | `security`       |
| New security feature/control  | `feat`   | `security`       |
| Security-related CI/tooling   | `ci`     | `security`       |

### Troubleshooting Commitlint Failures

The following types are allowed: `build`, `chore`, `ci`, `docs`, `feat`, `fix`, `perf`, `refactor`, `revert`, `style`, `test`.

If `commitlint` rejects your message:
1. Identify the correct type from the table above.
2. Reword the commit: `git commit --amend -m "<type>(<scope>): <subject>"`
3. Verify the fix: `npx commitlint --from HEAD~1`
4. If the error is not in the HEAD commit: `git rebase -i <commit>^` and change `pick` to `reword`.

DO NOT invent new types or skip linting.
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
