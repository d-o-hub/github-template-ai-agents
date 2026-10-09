---
name: jules-delegator
version: "0.2.10"
description: Use this skill to delegate complex coding tasks by creating Jules sessions via the Jules CLI. Use this skill when the user asks to delegate a coding task to Jules, create a Jules session, or hand off implementation work — even if they just say "send this to Jules" or "let Jules handle it". Jules is an AI coding agent that can autonomously implement features, fix bugs, and make code changes across repositories. Not for git-github-workflow.
category: agent
license: MIT
---

# Jules Delegator (CLI-Based)

Delegate complex tasks to Jules using the official CLI.

## When to Use

- Complex feature implementations that span multiple files.
- Refactoring large modules.
- Implementing complex bug fixes.
- Delegating work to run autonomously while you focus on other tasks.

## Prerequisites

- Jules CLI installed (`npm install -g @google/jules`)
- Authenticated with Google (`jules login`)

## Core Loop

1. **Prepare Context**: Detect repository and branch.
2. **Delegate**: Create a new session with a clear prompt.
3. **Monitor**: Check session status.
4. **Pull**: Retrieve results when complete.
5. **Review and Verify**: Inspect the full diff and run relevant local checks.

For explanation-only requests, show the workflow without authenticating,
creating/pulling a session, launching the TUI, or publishing. Respect the
requested scope. In retrieval/review explanations, state that later history
rewrites or publication require separate user authorization; a completed session
grants neither permission. Explain that failed local checks or non-conforming
commit subjects block shipping until corrected and revalidated; prose subjects
need authorized normalization before shipping under a conventional-commit policy.

## Workflow

### 1. Authenticate

Ensure you are logged in:

```bash
jules login
```

### 2. Detect Context

Auto-detect repository using `git remote get-url origin`.

### 3. Create Session

Start a new autonomous session:

```bash
# In repo directory (auto-detects repo)
jules remote new --session "Add OAuth2 authentication to the API"

# For specific repo
jules remote new --repo owner/repo --session "Implement dark mode"
```

### 4. Monitor Sessions

Check the status of your active sessions:

```bash
jules remote list --session
```

### 5. Retrieve Results

Retrieve the completed session's patch for inspection:

```bash
jules remote pull --session <session_id>
```

The default retrieves the patch without applying it. If the requested task
includes applying the results locally, first protect existing work and use a
review branch/worktree, then add `--apply`. Inspect `jules remote pull --help`
for the installed version; retrieval alone is not local application.

### 6. Review and Verify

Review every changed file against the handoff acceptance criteria, including
untracked/generated files, dependencies, configuration, and error paths. Run
the receiving project's relevant tests, lint/typechecks, and quality gate;
Jules' reported results are context, not local verification evidence. In an
explanation-only answer, describe these required checks without running them.

The TUI is an optional visual-diff aid when an interactive terminal is available:

Launch the TUI for a visual experience:

```bash
jules
```

## 7. Commit Validation Before Authorized Shipping

**`google-labs-jules[bot]` does not produce conventional commit messages.**
It writes prose ("I've hardened the `check-adr-compliance.sh` …") that
fails `commitlint` (header-max-length, type-empty, subject-empty). See
ADR-008 and PR #505 run 27086771117. This repository requires conventional
commits; downstream projects apply their own retained commit policy.

After reviewing and testing the results, validate commit messages before any
authorized push or PR. If prose subjects fail the retained policy, normalization
is needed before shipping; already-conforming subjects need no rewrite. In an
inspection-only task, report the violations and explain this gate without
performing normalization. History rewrites, force-pushes, and publishing require
explicit authorization under the receiving repository's policy.

For an authorized normalization task, derive the range and choose the type/scope
from the actual change; do not stamp every Jules task as a security fix:

```bash
# Verify the branch is clean and identify the agreed target branch.
git status --porcelain

# TARGET_REF, COMMIT_TYPE and COMMIT_SCOPE come from the approved task context.
BASE="$(git merge-base HEAD "$TARGET_REF")"
HEAD="$(git rev-parse HEAD)"

# Run only when rewriting non-conforming subjects is authorized.
./.agents/skills/jules-delegator/scripts/normalize-commits.sh \
    --from "$BASE" \
    --to   "$HEAD" \
    --type "$COMMIT_TYPE" \
    --scope "$COMMIT_SCOPE"

# Recompute the range and validate all resulting subjects before publishing.
npx commitlint --from "$BASE" --to HEAD
```

The rewriter:

- Keeps the first line of the body intact.
- Replaces the subject with `type(scope): <imperative, ≤72 chars>` derived
  from the diff (e.g. "hardened `check-adr-compliance.sh`" →
  `fix(security): harden check-adr-compliance.sh against injection`).
- Drops lines longer than the 100-char body wrap limit.
- Strips `Co-authored-by:` trailers (the human's `d-o-hub` trailer is
  re-added by the rewriter to preserve attribution).

## CLI Commands Summary

| Command | Purpose |
|---------|---------|
| `jules login` | Authenticate with Google |
| `jules logout` | Log out from Google |
| `jules remote list --repo` | List connected repositories |
| `jules remote list --session` | List active/past sessions |
| `jules remote new --repo <r> --session "<p>"` | Start a new session |
| `jules remote pull --session <id>` | Pull results from a session |
| `jules completion <bash\|zsh>` | Generate autocompletion script |
| `jules` | Launch interactive TUI |

## See Also

- `git-github-workflow` — Git workflow and PR lifecycle
- `implementer` — Execute code changes

## Rationalizations

| Rationalization | Reality |
|-----------------|---------|
| "I can do this faster manually" | Delegation allows for parallel progress and autonomous implementation of complex features. |
| "Setting up the CLI is too much work" | Authentication is one-time, and auto-detection simplifies session creation. |
| "Jules already validated its work, I don't need to re-validate" | Review the actual diff, run the receiving project's checks, and validate commit policy locally; a completion summary proves none of these. |
| "I can just edit the PR title to make it pass" | The PR title is the squash-merge subject, but the **commits** in the PR are also linted (see `commitlint` job in `.github/workflows/commitlint.yml`). Title-only fixes leave the bot commits failing. |
| "A Jules branch is disposable, so I can force-push it" | Other work and review signals may depend on it. Rewriting or publishing requires authorization, even for agent-created branches. |

## Red Flags

- [ ] Forgetting to pull results after a session is completed.
- [ ] Providing vague prompts that lead to incorrect implementations.
- [ ] Not verifying local context before session creation.
- [ ] Treating reported tests as local verification or skipping relevant checks.
- [ ] Rewriting or publishing during an explanation-only or inspection-only task.
- [ ] Shipping non-conforming subjects without commit validation/normalization.
- [ ] Opening a PR from a Jules session without first running `npx commitlint --from <base> --to <head>`.

## References

- `references/cli-reference.md` - Detailed CLI command reference.
- `AGENTS.md` - Repository standards and quality gates.
- `scripts/normalize-commits.sh` - Commit-message rewriter for Jules branches.
- `ADR-008` - Why this step is mandatory.

## Voice & Context

- **Default**: `professional` + `blog`
- **Reference**: `voice-profiles` skill for definitions and auto-detection.
