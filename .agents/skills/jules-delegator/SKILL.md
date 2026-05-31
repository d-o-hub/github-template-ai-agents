---
name: jules-delegator
version: "0.0.0"
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

## Red Flags
- [ ] Forgetting to pull results after a session is completed.
- [ ] Providing vague prompts that lead to incorrect implementations.
- [ ] Not verifying local context before session creation.

## References
- `references/cli-reference.md` - Detailed CLI command reference.
- `AGENTS.md` - Repository standards and quality gates.
