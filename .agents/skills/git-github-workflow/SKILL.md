---
name: git-github-workflow
version: "0.3.0"
description: Orchestrates the full git-to-merge lifecycle: validate → commit → check issues → create PR → monitor ALL GitHub Actions (including pre-existing failures) → fix via swarm/web research → merge with strategy selection → post-merge validate. Use this skill when the user asks to ship changes end-to-end, manage a PR through CI, or handle the complete commit-to-merge workflow — even if they just say "push it" or "ship it". Not for simple one-off git operations (revert, squash, cherry-pick) or isolated tasks (just review, just test, just lint).
category: workflow
license: MIT
---

# Git-GitHub Workflow Skill

**Unified atomic state-machine workflow:** validate → commit → check issues → create PR → monitor ALL Actions → fix (swarm/web research) → merge (strategy selection) → post-merge validate

## When to Use

- User asks to commit code, create a PR, push changes, or merge
- Need to manage the full git lifecycle from commit to merge
- Even if they just say "push it" or "ship it"

## Overview

Orchestrates complete code submission as a state machine with **swarm agent coordination** and 8 phases. See `references/SWARM.md` for agents and `references/HANDOFF.md` for coordination.

## Workflow Phases

### Phase 0: PRE_COMMIT (Validation)

- Run quality gate with zero warnings policy
- Scan for secrets in staged changes
- Verify not on protected branch (main/master)
- Check gh CLI authentication
- **Failure:** Abort immediately, no changes made

### Phase 1: ATOMIC COMMIT (Agent: commit-agent)

- Stage ALL changes (`git add -A`)
- Create atomic commit with conventional format
- Auto-detect commit type from changed files
- Generate meaningful commit message

### Phase 2: CHECK GITHUB ISSUES (Agent: issue-agent)

- List open issues in repository
- Check issue relevance to current changes
- Identify blocking issues (labeled "blocking"/"critical")
- Determine if issues need fixing before merge

### Phase 3: CREATE PR (Agent: pr-agent)

- Push to new feature branch (auto-generated or custom name)
- Create comprehensive PR with commit summary and context
- Link related issues in PR body
- Auto-detect existing PR for the branch

### Phase 4: MONITOR ALL ACTIONS (Agent: monitor-agent)

**CRITICAL:** ALL GitHub Actions must pass, including pre-existing
- Monitor PR checks continuously (`gh pr checks`)
- Check ALL repository workflows (`gh run list`)
- Distinguish pre-existing vs new issues
- Detect warnings (configurable fail-on-warning)
- Wait for ALL checks green or timeout
- Branch protection awareness

### Phase 5: ISSUE RESOLUTION (Agent: fix-agent) [Conditional]

If ANY check fails:
- Trigger web research (web-search-researcher + doc-resolver)
- Use available skills to fix issues
- Re-run checks after fixes
- Retry up to N times (configurable)

### Phase 6: MERGE (Agent: merge-agent)

- Verify ALL checks passing and merge state
- Merge with configurable strategy (squash/merge/rebase)
- Delete feature branch (optional)
- Close related issues (optional)

### Phase 7: POST-MERGE VALIDATION (Agent: validate-agent)

- Checkout main branch
- Verify ALL files present
- Validate documentation complete
- Run final quality gate
- Check repository integrity

## Quality Gates

| Phase | Check | Failure Action |
|-------|-------|----------------|
| PRE_COMMIT | Quality gate zero warnings | Abort |
| PRE_COMMIT | No secrets in staged changes | Abort |
| PRE_COMMIT | Not on protected branch | Abort |
| COMMIT | Valid conventional format | Rollback |
| PRE_PUSH | Remote accessible | Rollback |
| PUSH | SHA verification | Rollback |
| PR_CREATE | gh CLI authenticated | Rollback |
| VERIFY | All CI checks green, zero warnings | Rollback |

## Commit Format

`type(scope): Brief description (72 chars max)`

- Why not what - user perspective
- Reference issues: Fixes #123
- **Types:** feat, fix, docs, style, refactor, perf, test, ci, chore
- **Auto-detection:** CI→ci | Test→test | Docs→docs | New→feat | Mod→fix

## Auto-Merge Strategies

| Method | Command | Description |
|--------|---------|-------------|
| `squash` | `gh pr merge --squash` | Combine into single commit (default) |
| `merge` | `gh pr merge --merge` | Create merge commit |
| `rebase` | `gh pr merge --rebase` | Fast-forward after rebase |

## Error Codes

| Code | Meaning | Phase |
|------|---------|-------|
| 0 | Success | - |
| 1 | General error | - |
| 2 | Quality gate failed | PRE_COMMIT |
| 3 | Commit failed | COMMIT |
| 4 | GitHub issues blocking | ISSUES |
| 5 | PR creation failed | PR |
| 6 | Actions checks failed | MONITOR |
| 7 | Max retries / timeout | FIX |
| 8 | Merge failed | MERGE |
| 9 | Post-merge validation failed | VALIDATE |

## Usage

```bash
# Full workflow
bash .agents/skills/git-github-workflow/run.sh --message "feat: implement feature"

# Partial modes
bash .agents/skills/git-github-workflow/run.sh --check-issues-only
bash .agents/skills/git-github-workflow/run.sh --validate-main-only
```

## Arguments

| Argument | Description | Default |
|----------|-------------|---------|
| `--message, -m` | Commit message | auto-generated |
| `--merge-method` | merge/squash/rebase | squash |
| `--branch-name` | Custom branch name | auto-generated |
| `--rebase` / `--no-rebase` | Auto-rebase if behind | true |
| `--check-all-actions` | Monitor repo-wide Actions | true |
| `--fail-on-warning` | Treat warnings as errors | true |
| `--cleanup-branch` | Delete branch after merge | false |
| `--fix-issues` | Auto-fix issues | false |
| `--close-issues` | Close related issues on merge | false |
| `--strict-validation` | ALL checks must pass | true |
| `--skip-issue-check` | Skip GitHub issues check | false |
| `--skip-ci` | Skip CI verification (emergency) | false |
| `--post-merge-validate` | Validate after merge | true |
| `--auto-research` | Web research on failures | true |
| `--dry-run` | Simulate without executing | false |
| `--max-retries` | Max fix attempts | 3 |
| `--timeout` | Actions timeout (seconds) | 3600 |
| `--base-branch` | Target branch for PR | main |

## Pre-existing Issue Handling

**STRICT MODE (default):** ALL checks must pass, including pre-existing. No exceptions.

If pre-existing failures found: document → web research → apply fix → re-run checks → merge only when ALL green.

**NON-STRICT (`--no-strict-validation`):** Distinguishes pre-existing vs new issues. New failures block merge; only pre-existing can merge. Reports all issues clearly.

## Web Research Integration

On ANY failure: launch web-search-researcher → query failure → do-web-doc-resolver → get official docs → apply fix → re-run checks → retry (default max 3).

## Post-Merge Validation

After merge: checkout main, pull latest, verify all files present, validate docs, run quality gate, check repo integrity.

## Configuration

```bash
GIT_GITHUB_WORKFLOW_TIMEOUT=3600
GIT_GITHUB_WORKFLOW_MAX_RETRIES=3
GIT_GITHUB_WORKFLOW_STRICT_VALIDATION=1
GIT_GITHUB_WORKFLOW_AUTO_RESEARCH=1
GIT_GITHUB_WORKFLOW_POST_MERGE_VALIDATE=1
GIT_GITHUB_WORKFLOW_CLOSE_ISSUES=0
GIT_GITHUB_WORKFLOW_MERGE_METHOD=squash
GIT_GITHUB_WORKFLOW_REBASE=1
GIT_GITHUB_WORKFLOW_FAIL_ON_WARNING=1
GIT_GITHUB_WORKFLOW_CHECK_ALL_ACTIONS=1
GIT_GITHUB_WORKFLOW_CLEANUP_BRANCH=0
```

## Success Criteria

Workflow succeeds when:
1. ✓ Quality gate passed (zero warnings)
2. ✓ Atomic commit with valid conventional format
3. ✓ GitHub issues checked (none blocking or resolved)
4. ✓ PR created and pushed to feature branch
5. ✓ ALL GitHub Actions passing (pre-existing fixed)
6. ✓ Issues resolved via web research (if needed)
7. ✓ Merged to main with configured strategy
8. ✓ Post-merge validation passes

## Rationalizations

| Rationalization | Reality |
|-----------------|---------|
| "I'll skip the quality gate, it's a tiny change" | Small changes cause most production incidents. |
| "Rollback is too complex, I'll fix forward" | Fix-forward creates tangled history. |
| "Post-merge validation is redundant" | Ensures merge didn't introduce integration issues. |
| "Pre-existing failures aren't my problem" | They still block your PR's merge status. |
| "I'll merge now and fix CI later" | Broken CI contaminates main for all contributors. |

## Red Flags

- [ ] Bypassing the quality gate for "trivial" changes
- [ ] Merging with GitHub Actions still failing
- [ ] Ignoring pre-existing CI failures as "not my problem"
- [ ] Disabling rollback on failure
- [ ] Skipping post-merge validation on main

## See Also

- `references/SWARM.md` - Agent definitions and coordination
- `references/HANDOFF.md` - Handoff protocol
- `references/IMPLEMENTATION_ATOMIC_COMMIT.md` - State machine, rollback matrix, secret patterns (migrated)
- `references/IMPLEMENTATION_GITHUB_WORKFLOW.md` - GitHub API, merge strategies, troubleshooting (migrated)
- `run.sh` - Workflow implementation script
- `evals/README.md` - Consolidated test scenarios

## Voice & Context

- **Default**: `professional` + `blog`
- **Reference**: `voice-profiles` skill for definitions and auto-detection.
