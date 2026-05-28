---
name: github-pr-sentinel
description: Monitor a GitHub pull request until it's merged, green, or blocked. Polls CI checks, review comments, and mergeability state continuously. Diagnoses failures, retries flaky checks up to 3 times, auto-fixes branch-related issues when possible, and stops only when user help is required. Use when asked to "monitor a PR", "watch CI", "handle review comments", "sentinel a PR", or keep an eye on failures and feedback.
compatibility: Any CLI agent (OpenCode, Claude, Codex, Cursor, etc.)
metadata:
  source: https://github.com/openai/codex/tree/main/.codex/skills/babysit-pr
  version: "1.0.0"
---

# PR Sentinel

Monitor a GitHub pull request persistently until one of these terminal outcomes occurs.

## Terminal Outcomes (stop when any is true)

- **PR merged or closed** — stop immediately on confirmation.
- **PR ready to merge** — CI green, no unaddressed review comments, not blocked on required review approval, no merge conflict risk.
- **User help required** — CI infrastructure issues, exhausted flaky retries (3 cycles), permission problems, or ambiguous situations that cannot be resolved safely.

Do **not** stop merely because a snapshot returns `idle` while checks are still pending.

## Inputs

Accept any of:

- No argument: infer PR from current branch (`--pr auto`)
- PR number
- PR URL

## Core Workflow

1. When asked to "monitor"/"watch"/"babysit" a PR, start with `--watch` (continuous mode) unless doing a one-shot diagnostic.
2. Run the watcher script to snapshot PR/CI/review state.
3. Inspect the `actions` list in the JSON response.
4. If `diagnose_ci_failure` is present, inspect failed run logs and classify the failure.
5. If **branch-related**: patch code locally, commit, and push.
6. If `process_review_comment` is present, inspect surfaced review items and decide whether to address them.
7. If a review item is actionable and correct, patch code locally, commit, and push.
8. If **likely flaky/unrelated** and `retry_failed_checks` is present, rerun failed jobs with `--retry-failed-now`.
9. If both actionable review feedback and `retry_failed_checks` are present, **prioritize review feedback first** — a new commit retriggers CI, so avoid rerunning flaky checks on the old SHA.
10. On every loop, verify mergeability / merge-conflict status (e.g. via `gh pr view`).
11. After any push or rerun, immediately return to step 1 and continue polling on the updated SHA.
12. If you paused `--watch` to patch/commit/push, **relaunch `--watch` yourself** in the same turn after the push.
13. Repeat polling until the PR is green + review-clean + mergeable, `stop_pr_closed` appears, or a user-help-required blocker is reached.
14. Keep consuming watcher output in the same turn while babysitting is active — do not end the turn with a detached `--watch` process.

## Commands

### One-shot snapshot

```bash
python3 .agents/skills/github-pr-sentinel/scripts/gh_pr_watch.py --pr auto --once
```

### Continuous watch (JSONL)

```bash
python3 .agents/skills/github-pr-sentinel/scripts/gh_pr_watch.py --pr auto --watch
```

### Trigger flaky retry cycle

```bash
python3 .agents/skills/github-pr-sentinel/scripts/gh_pr_watch.py --pr auto --retry-failed-now
```

### Explicit PR target

```bash
python3 .agents/skills/github-pr-sentinel/scripts/gh_pr_watch.py --pr <number-or-url> --once
```

## CI Failure Classification

Use `gh` commands to inspect failed runs before deciding to rerun:

```bash
gh run view <run-id> --json jobs,name,workflowName,conclusion,status,url,headSha
gh run view <run-id> --log-failed
```

**Branch-related** — logs point to changed code (compile/test/lint/typecheck in touched areas):

- Patch code locally, commit with conventional format, push.

**Flaky/unrelated** — transient infra issues (timeouts, runner failures, registry outages, rate limits):

- Rerun failed jobs.

**Ambiguous** — do one manual diagnosis attempt before choosing rerun.

See [references/heuristics.md](references/heuristics.md) for the full checklist.

## Review Comment Handling

The watcher surfaces review items from:

- PR issue comments
- Inline review comments
- Review submissions (COMMENT / APPROVED / CHANGES_REQUESTED)

It surfaces feedback from trusted human reviewers (repo OWNER/MEMBER/COLLABORATOR + authenticated operator) and approved review bots.

On a fresh state file, existing pending review feedback is surfaced immediately (not only new comments after monitoring starts).

### When a comment is actionable and correct

1. Patch code locally.
2. Commit: `fix: address PR review feedback (#<n>)`
3. Push to the PR head branch.
4. Resume watching on the new SHA immediately — do not stop after reporting the push.
5. If monitoring was in `--watch` mode, restart `--watch` immediately after the push.

### When a comment is non-actionable

- Already resolved in GitHub → safely ignore.
- Ambiguous → record as handled, continue polling.
- Conflicts with user intent → stop and ask.

## Git Safety Rules

- Work **only** on the PR head branch.
- Avoid destructive git commands.
- Do not switch branches unless necessary to recover context.
- Before editing, check for unrelated uncommitted changes. If present, **stop and ask the user**.
- After each fix, commit and `git push`, then re-run the watcher.
- If you interrupted `--watch` to fix, **restart `--watch` immediately** after the push.
- Do not run multiple concurrent `--watch` processes for the same PR.
- A push is **not** a terminal outcome — continue monitoring unless a strict stop condition is met.

### Commit message format

- `fix: fix CI failure on PR #<n>`
- `fix: address PR review feedback (#<n>)`

## Monitoring Loop Pattern

1. Run `--once`.
2. Read `actions`.
3. Check if PR is merged/closed — if so, report terminal state and stop.
4. Check CI summary, new review items, mergeability/conflict status.
5. Diagnose CI failures; classify branch-related vs flaky.
6. Process actionable review comments **before** flaky reruns when both are present.
7. Retry failed checks only when `retry_failed_checks` is present and you are not about to replace the current SHA.
8. If you pushed a commit or triggered a rerun, report briefly and continue polling.
9. After a review-fix push, **proactively restart `--watch`** in the same turn.
10. If everything is passing, mergeable, no unaddressed reviews, and not blocked on approval — report success and stop.
11. If blocked on user-help issue — report the blocker and stop.
12. Otherwise sleep per polling cadence and repeat.

### Preferring `--watch`

When the user asks to monitor/watch/babysit a PR, use `--watch` for autonomous polling. Use `--once` only for debugging or one-shot checks.

Do **not** stop to ask whether to continue — poll autonomously until a strict stop condition or explicit user interruption.

## Polling Cadence (Adaptive)

- **CI not green**: poll every 1 minute.
- **CI green**: start at 1 min, back off exponentially on no change (1m → 2m → 4m → 8m → 16m → 32m), cap at 1 hour.
- **Reset to 1 min** whenever anything changes (new SHA, check status change, new review, mergeability change).
- **CI regresses** (new commit, rerun failure): return to 1-minute polling.
- **PR merged/closed**: stop immediately.

## Stop Conditions (Strict)

Stop **only** when:

| Condition | Action |
|-----------|--------|
| PR merged or closed | Stop immediately |
| PR ready to merge (green + review-clean + mergeable) | Report success, stop |
| User intervention required (infra outage, exhausted retries, permissions) | Report blocker, stop |

**Keep polling** when:

- `actions` contains only `idle` but checks are still pending.
- CI is still running/queued.
- Review state is quiet but CI is not terminal.
- CI is green but mergeability is unknown/pending.
- CI is green and mergeable but waiting on review approval.
- CI is green but merge-conflict risk may change.

## Output Expectations

### During monitoring

- Concise progress updates on status changes only.
- Occasional heartbeat during long unchanged periods.
- Push confirmations, intermediate CI snapshots, and review-action updates are progress only — not final.

### CI green celebration

One-time when CI first transitions to all green:

```
🚀 CI is all green! 33/33 passed. Still on watch for review approval.
```

### Final summary (when a stop condition is met)

Include:

- Final PR SHA
- CI status summary
- Mergeability / conflict status
- Fixes pushed
- Flaky retry cycles used
- Remaining unresolved failures or review comments

## Rationalizations
| Rationalization | Reality |
|-----------------|---------|
| "CI is just being flaky, I'll just merge it" | Flakiness masks real bugs. Rerun or fix, never ignore. |
| "A human will review this anyway, I don't need to be perfect" | The sentinel's job is to save human reviewers time by catching low-hanging fruit. |
| "This PR is small, I can skip the full monitoring loop" | Small PRs can have big impacts. Consistency is key to reliability. |

## Red Flags
- [ ] Stopping the monitoring loop before a terminal outcome is reached
- [ ] Ignoring actionable review feedback in favor of automated checks
- [ ] Rerunning failed checks more than 3 times without diagnosing the root cause

## References

- `references/heuristics.md` - CI/Review decision tree for fix vs rerun vs stop
- `references/github-api-notes.md` - GitHub CLI commands and endpoints used by the watcher
