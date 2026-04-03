# Atomic Commit Workflow

A comprehensive bash-based workflow for safe, validated git commits with integrated CI/CD verification.

## Overview

The atomic-commit workflow provides a complete solution for:
- Pre-commit validation (quality gates, secret detection, tests)
- Atomic commit creation with conventional format
- Safe synchronization and push with conflict handling
- Automated PR creation
- CI check verification

## Scripts

### 1. pre-commit-check.sh

Runs comprehensive checks before allowing commits.

**Features:**
- Repository state validation
- Quality gate execution
- Secret detection (passwords, API keys, tokens)
- Test execution for detected project types
- Commit message validation (conventional format)

**Usage:**
```bash
./scripts/atomic-commit/pre-commit-check.sh
./scripts/atomic-commit/pre-commit-check.sh --staged-only
./scripts/atomic-commit/pre-commit-check.sh --quiet
```

**Exit Codes:**
- 0: All checks passed
- 1: Critical failure (blocks commit)
- 2: Warning found (treated as failure - no skipping)

---

### 2. atomic-commit.sh

Creates atomic commits with validation and conventional formatting.

**Features:**
- Auto-detects commit type from changed files
- Validates conventional commit format
- Runs pre-commit checks (unless --no-verify)
- Supports amend, dry-run, and auto-staging

**Usage:**
```bash
# Simple commit with auto-detected type
./scripts/atomic-commit/atomic-commit.sh "Add user authentication"

# Conventional commit with type and scope
./scripts/atomic-commit/atomic-commit.sh --type feat --scope auth "Add OAuth2 support"

# Amend previous commit
./scripts/atomic-commit/atomic-commit.sh --amend "Updated commit message"

# Dry run to preview changes
./scripts/atomic-commit/atomic-commit.sh --dry-run --type fix "Fix login bug"
```

**Exit Codes:**
- 0: Commit successful
- 1: Commit failed
- 2: Validation warning (treated as failure)

---

### 3. sync-and-push.sh

Safely synchronizes with remote and pushes changes.

**Features:**
- Fetches from remote with pruning
- Detects branch divergence
- Rebases local changes (or merge with --no-rebase)
- Handles conflicts gracefully
- Supports force-with-lease (safe force push)
- Auto-stash support for local changes

**Usage:**
```bash
# Sync and push current branch
./scripts/atomic-commit/sync-and-push.sh

# Force push with lease (safe)
./scripts/atomic-commit/sync-and-push.sh --force

# Auto-stash local changes before sync
./scripts/atomic-commit/sync-and-push.sh --auto-stash

# Target specific branch
./scripts/atomic-commit/sync-and-push.sh --branch feature/my-branch
```

**Exit Codes:**
- 0: Sync and push successful
- 1: Failed (conflicts, push rejected)
- 2: Warning (requires manual intervention)

---

### 4. create-pr.sh

Creates GitHub pull requests with proper formatting and validation.

**Features:**
- Auto-generates PR title from commits (conventional format)
- Uses repository PR template or auto-fills from commits
- Supports draft PRs, labels, reviewers, assignees
- Validates PR data before creation
- Opens PR in browser after creation

**Requirements:**
- GitHub CLI (`gh`) installed and authenticated

**Usage:**
```bash
# Create PR with auto-generated title
./scripts/atomic-commit/create-pr.sh

# Create PR with custom title
./scripts/atomic-commit/create-pr.sh --title "feat(auth): Add OAuth2 support"

# Create draft PR with labels
./scripts/atomic-commit/create-pr.sh --draft --labels "enhancement,WIP"

# Create PR targeting develop branch
./scripts/atomic-commit/create-pr.sh --base develop

# Open in browser after creation
./scripts/atomic-commit/create-pr.sh --web
```

**Exit Codes:**
- 0: PR created successfully
- 1: Failed to create PR
- 2: Warning (PR exists or needs review)

---

### 5. verify-checks.sh

Polls GitHub Actions until all checks pass or fail.

**Features:**
- Polls checks for current branch or specific PR
- Watch mode for continuous monitoring
- Configurable timeout and poll interval
- Displays real-time check status
- Supports `--fail-ok` for non-blocking failures

**Requirements:**
- GitHub CLI (`gh`) installed and authenticated

**Usage:**
```bash
# Check current branch
./scripts/atomic-commit/verify-checks.sh

# Watch checks on a PR
./scripts/atomic-commit/verify-checks.sh --pr 42 --watch

# Check with 5 minute timeout
./scripts/atomic-commit/verify-checks.sh --timeout 300

# Non-blocking mode
./scripts/atomic-commit/verify-checks.sh --fail-ok
```

**Exit Codes:**
- 0: All checks passed
- 1: One or more checks failed
- 2: Timeout or warning state

## Complete Workflow Example

```bash
# 1. Make your changes
# ... edit files ...

# 2. Create atomic commit
./scripts/atomic-commit/atomic-commit.sh --type feat --scope api "Add user endpoints"

# 3. Sync and push to remote
./scripts/atomic-commit/sync-and-push.sh

# 4. Create pull request
./scripts/atomic-commit/create-pr.sh --web

# 5. Wait for CI checks to pass
./scripts/atomic-commit/verify-checks.sh --watch
```

## Integration Points

### Pre-Commit Hook

Install as pre-commit hook:
```bash
cp scripts/atomic-commit/pre-commit-check.sh .git/hooks/pre-commit
chmod +x .git/hooks/pre-commit
```

### CI/CD Integration

All scripts support environment variables for CI environments:
```bash
export VERBOSE=false
export FORCE_COLOR=0
export DRY_RUN=true  # For testing
```

### Script Chaining

Scripts can be chained for automated workflows:
```bash
./scripts/atomic-commit/atomic-commit.sh "Fix bug" && \
./scripts/atomic-commit/sync-and-push.sh && \
./scripts/atomic-commit/create-pr.sh
```

## Script Standards

All scripts follow these standards:

- **Strict mode**: `set -euo pipefail`
- **Colored output**: TTY detection, `FORCE_COLOR` override
- **Verbose logging**: `VERBOSE` environment variable
- **Exit codes**: 0=success, 1=failure, 2=warning
- **No warning skipping**: Warnings treated as failures
- **Comprehensive error handling**: Trap-based error handling
- **Help documentation**: `--help` flag for all scripts

## Common Environment Variables

| Variable | Description | Default |
|----------|-------------|---------|
| `VERBOSE` | Enable verbose output | `true` |
| `FORCE_COLOR` | Set to `0` to disable colors | auto-detect |
| `DRY_RUN` | Preview without executing | `false` |

## Script-Specific Variables

### atomic-commit.sh
- `COMMIT_TYPE`: Override auto-detected type
- `COMMIT_SCOPE`: Set commit scope
- `NO_VERIFY`: Skip pre-commit checks

### sync-and-push.sh
- `USE_FORCE`: Enable force-with-lease
- `AUTO_STASH`: Auto-stash local changes
- `REMOTE`: Remote name
- `NO_REBASE`: Use merge instead of rebase

### create-pr.sh
- `BASE_BRANCH`: Target branch
- `DRAFT`: Create draft PR
- `LABELS`: Comma-separated labels
- `REVIEWERS`: Comma-separated reviewers
- `ASSIGNEES`: Comma-separated assignees

### verify-checks.sh
- `TIMEOUT_SECONDS`: Max wait time
- `POLL_INTERVAL`: Seconds between polls
- `WATCH_MODE`: Keep polling until done
- `REQUIRE_ALL`: Exit 1 on failures
