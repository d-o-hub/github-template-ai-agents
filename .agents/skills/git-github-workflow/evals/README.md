# Git-GitHub Workflow Evals

Consolidated eval scenarios merged from git-github-workflow, atomic-commit, and github-workflow skills.

## Eval 1-3: Core Workflow (Original git-github-workflow)

- Eval 1: Full workflow (commit → PR → CI → merge)
- Eval 2: GitHub issues check and blocking issue detection
- Eval 3: Post-merge validation on main

## Eval 4-6: Atomic Commit Scenarios (Migrated from atomic-commit)

- Eval 4: Full atomic workflow with zero warnings
- Eval 5: Quality gate failure handling at PRE_COMMIT
- Eval 6: Rollback on CI check failure after push

## Eval 7-9: GitHub Workflow Scenarios (Migrated from github-workflow)

- Eval 7: Push, PR, and auto-merge on green CI
- Eval 8: Pre-existing vs new CI failure detection
- Eval 9: Auto-rebase when behind main

## Running Evals

Detailed setup steps are in:
- `README_ATOMIC_COMMIT.md` - 10 eval scenarios with setup (migrated)
- `README_GITHUB_WORKFLOW.md` - 20 eval scenarios with setup (migrated)

## Quality Criteria

All evals must:
- [ ] Exit with correct error codes
- [ ] Show clear success/failure messages
- [ ] Leave repository in clean state
- [ ] Not leave orphaned branches or PRs
- [ ] Provide actionable error messages
- [ ] Be reproducible
