---
name: jules-delegator
version: "0.2.10"
description: Use this skill to delegate complex coding tasks by creating Jules sessions via the Jules CLI. Jules is an AI coding agent that can autonomously implement features, fix bugs, and make code changes across repositories.
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
5. **Review**: Launch TUI for visual diff and confirmation.

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

Pull changes once the session is completed:

```bash
jules remote pull --session <session_id>
```

### 6. Interactive Mode

Launch the TUI for a visual experience:

```bash
jules
```

## 7. Post-Pull Normalization (REQUIRED)

**`google-labs-jules[bot]` does not produce conventional commit messages.**
It writes prose ("I've hardened the `check-adr-compliance.sh` …") that
fails `commitlint` (header-max-length, type-empty, subject-empty). See
ADR-008 and PR #505 run 27086771117. **Never push a Jules session's branch
without normalization.**

After `jules remote pull --session <id>`, before pushing or letting any
PR open:

```bash
# 1. Verify the branch is clean
git status --porcelain

# 2. For each non-conventional commit in the Jules branch, rewrite it.
#    Find the merge-base and the head:
BASE="$(git merge-base HEAD origin/main)"
HEAD="$(git rev-parse HEAD)"

# 3. Auto-rewriter (see .agents/skills/jules-delegator/scripts/normalize-commits.sh):
./.agents/skills/jules-delegator/scripts/normalize-commits.sh \
    --from "$BASE" \
    --to   "$HEAD" \
    --type fix \
    --scope security

# 4. Force-push the rewritten branch (Jules session branches are disposable).
git push --force-with-lease origin <branch>

# 5. Validate locally before requesting review.
./scripts/validate-commit-message.sh <(git log -1 --pretty=%B)
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

## Rationalizations

| Rationalization | Reality |
|-----------------|---------|
| "I can do this faster manually" | Delegation allows for parallel progress and autonomous implementation of complex features. |
| "Setting up the CLI is too much work" | Authentication is one-time, and auto-detection simplifies session creation. |
| "Jules already validated its work, I don't need to re-validate" | Jules has no knowledge of `commitlint.config.cjs` and will produce prose commits; without normalization the PR is blocked at CI. |
| "I can just edit the PR title to make it pass" | The PR title is the squash-merge subject, but the **commits** in the PR are also linted (see `commitlint` job in `.github/workflows/commitlint.yml`). Title-only fixes leave the bot commits failing. |
| "Force-pushing a Jules branch is unsafe" | Jules session branches are disposable by design; the merge base is the same. |

## Red Flags

- [ ] Forgetting to pull results after a session is completed.
- [ ] Providing vague prompts that lead to incorrect implementations.
- [ ] Not verifying local context before session creation.
- [ ] Pushing a Jules session's branch without running the Post-Pull Normalization step.
- [ ] Opening a PR from a Jules session without first running `npx commitlint --from <base> --to <head>`.

## References

- `references/cli-reference.md` - Detailed CLI command reference.
- `AGENTS.md` - Repository standards and quality gates.
- `scripts/normalize-commits.sh` - Commit-message rewriter for Jules branches.
- `ADR-008` - Why this step is mandatory.
