---
name: shell-script-quality
version: "0.2.10"
category: code-quality
description: Lint and test shell scripts using ShellCheck and BATS. Use this skill when checking bash/sh scripts for errors, writing shell script tests, fixing ShellCheck warnings, setting up CI/CD for shell scripts, or improving bash code quality — even if they just say "fix this script" or "add tests for the shell script". Not for static-analysis, cicd-pipeline.
license: MIT
---

# Shell Script Quality

Comprehensive shell script linting and testing using ShellCheck and BATS with 2025 best practices.

## When to Use

- User asks to check bash/sh scripts for errors or fix ShellCheck warnings
- Need to write shell script tests or set up CI/CD for shell scripts
- Even if they just say "fix this script" or "add tests for the shell script"

## Quick Start

Copy this workflow checklist and track your progress:

```
Shell Script Quality Workflow:
- [ ] Step 1: Lint with ShellCheck
- [ ] Step 2: Fix reported issues
- [ ] Step 3: Write BATS tests
- [ ] Step 4: Verify tests pass
- [ ] Step 5: Integrate into CI/CD
```

## Core Workflow

### Step 1: Lint with ShellCheck

**Note**: When searching for patterns across scripts, use the dedicated **Grep Tool** (with pattern/type parameters) instead of calling `grep` or `find` directly, as per `AGENTS.md`.

```bash
# Lint single file
shellcheck script.sh

# Lint all scripts
find scripts -name "*.sh" -exec shellcheck {} +

# Use config file if present
shellcheck -x script.sh
```

### Step 1b: Verify new code at FULL severity (required before push)

This repo's `quality_gate.sh` runs `shellcheck --severity=error`, but Codacy's
**required** check has `issueThreshold: 0` and counts issues at *any* severity.
Code that passes the local gate can therefore still block a merge. Verify the
files you touched at full severity, where **all** levels are findings:

```bash
# Full severity on the files you changed
shellcheck path/to/changed.sh

# Delta check: compare full severity between HEAD and your branch, so you only
# see NEW issues. A blanket repo-wide full-severity run is NOT viable here --
# ~127 pre-existing findings would drown the signal.
git stash -q
shellcheck $(git ls-files '*.sh') 2>&1 | grep -cE '^In |SC[0-9]+' > /tmp/opencode/sc-base
git stash pop -q
shellcheck $(git ls-files '*.sh') 2>&1 | grep -cE '^In |SC[0-9]+' > /tmp/opencode/sc-new
diff /tmp/opencode/sc-base /tmp/opencode/sc-new && echo "no new findings"
```

Query the real verdict rather than guessing:

```bash
codacy pull-request <PR> -o json   # newIssues, quality.gate, per-issue resultDataId
```

Two codes that found real defects here, and are worth reading as bugs rather
than style:

| Code | Why it matters |
|------|----------------|
| `SC2235` | `(...)` is a **subshell**. `VAR+=(x)` inside it never reaches the parent, so a later `[[ " ${VAR[*]} " =~ " x " ]]` test silently never matches — a latent false green. |
| `SC2034` | "Appears unused" across a `source` boundary is usually a **real contract**: the variable is read by the sourcing script. Fix with a file-scope `disable` plus a stated reason, or fix the contract. |

**Common fixes**: See [SHELLCHECK.md](SHELLCHECK.md) for fix patterns

### Step 2: Fix Reported Issues

Apply fixes for common warnings:
- SC2086: Quote variables: `"$var"` not `$var`
- SC2155: Separate declaration and assignment
- SC2181: Check exit code directly with `if ! command`

**For detailed fixes**: See [SHELLCHECK.md](SHELLCHECK.md)

### Step 3: Write BATS Tests

```bash
#!/usr/bin/env bats

setup() {
    source "$BATS_TEST_DIRNAME/../scripts/example.sh"
}

@test "function succeeds with valid input" {
    run example_function "test"
    [ "$status" -eq 0 ]
    [ -n "$output" ]
}

@test "function fails with invalid input" {
    run example_function ""
    [ "$status" -ne 0 ]
    [[ "$output" =~ "ERROR" ]]
}
```

**Test patterns**: See [BATS.md](BATS.md) for comprehensive testing guide

### Step 4: Run Tests

```bash
# Run all tests
bats tests/

# Run with verbose output
bats -t tests/

# Run specific file
bats tests/example.bats
```

**If tests fail**: Review error output, fix issues, re-run validation

### Step 5: CI/CD Integration

**GitHub Actions**: See [CI-CD.md](CI-CD.md) for complete workflows

Quick integration:

On an Ubuntu runner after checkout, install the tools rather than using a
third-party action on a mutable branch. Adapt the script paths to the project.

```yaml
- name: Install shell checks
  run: |
    sudo apt-get update
    sudo apt-get install -y shellcheck bats
- name: ShellCheck
  run: shellcheck scripts/*.sh
- name: Run BATS
  run: bats tests/
```

## Script Template

```bash
#!/bin/bash
set -euo pipefail
SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
error_exit() { echo "ERROR: $1" >&2; exit "${2:-1}"; }
main() {
    [[ $# -lt 1 ]] && { echo "Usage: $0 <argument>" >&2; exit 1; }
    # Your logic here
}
[[ "${BASH_SOURCE[0]}" == "${0}" ]] && main "$@"
```

## Installation

```bash
brew install shellcheck         # macOS | sudo apt-get install shellcheck # Linux
brew install bats-core          # macOS | sudo apt-get install bats       # Linux
```

## Configuration

`.shellcheckrc` in project root: `shell=bash`, `disable=SC1090`, `enable=all`, `source-path=SCRIPTDIR`. See [CONFIG.md](CONFIG.md).

## Testing Claude Code Plugins

```bash
@test "plugin script works" {
    export CLAUDE_PLUGIN_ROOT="$BATS_TEST_DIRNAME/.."
    run bash "$CLAUDE_PLUGIN_ROOT/scripts/search.sh" "query"
    [ "$status" -eq 0 ]
}

@test "hook provides suggestions" {
    local input='{"tool":"Edit","params":{"file_path":"test.txt"}}'
    run bash "$HOOK_DIR/pre-edit.sh" <<< "$input"
    [ "$status" -eq 0 ]
    echo "$output" | jq empty
}
```

**More patterns**: See [PATTERNS.md](PATTERNS.md)

## Troubleshooting

- **ShellCheck**: SC1090 → add `# shellcheck source=path/to/file.sh`. False positives → `# shellcheck disable=SCxxxx`.
- **BATS**: Tests interfere → ensure proper `teardown()`. Can't source → add main execution guard. Path issues → use `$BATS_TEST_DIRNAME`.

See [TROUBLESHOOTING.md](TROUBLESHOOTING.md).

## Validation Loop Pattern

1. Make changes → `shellcheck script.sh` immediately.
2. If fails: review errors, fix, re-run.
3. Only proceed when validation passes → `bats tests/script.bats`.
4. If tests fail, return to step 1.

## References

- **[SHELLCHECK.md](SHELLCHECK.md)** - Complete ShellCheck guide and fix patterns
- **[BATS.md](BATS.md)** - BATS testing comprehensive guide
- **[CI-CD.md](CI-CD.md)** - GitHub Actions, GitLab CI, pre-commit hooks
- **[PATTERNS.md](PATTERNS.md)** - Common patterns and examples
- **[CONFIG.md](CONFIG.md)** - Configuration and setup details
- **[TROUBLESHOOTING.md](TROUBLESHOOTING.md)** - Common issues and solutions

## See Also

- `static-analysis` — Linter triage across any language
- `cicd-pipeline` — CI/CD for shell script testing

## Rationalizations

| Rationalization | Reality |
|-----------------|---------|
| "ShellCheck warnings are false positives" | Most SC warnings catch real bugs; suppress with documented reason, not dismissal. |
| "The local gate passed, so the code is clean" | The gate runs `--severity=error`; Codacy's required check counts issues at **any** severity. Warning-level findings pass locally and still block the merge. |
| "Just run full-severity ShellCheck on the whole repo" | ~127 findings already exist at full severity. Use a base-vs-branch **delta** so new issues are visible without the noise. |
| "BATS tests take too long to write" | Untested scripts break silently in production; test time is investment, not waste. |
| "set -e is too strict for my script" | Scripts without -e silently swallow errors and leave systems in inconsistent states. |

## Red Flags

- [ ] Running shell scripts without set -euo pipefail
- [ ] Skipping ShellCheck linting before committing shell scripts
- [ ] Trusting `--severity=error` as proof of Codacy-clean shell code
- [ ] Checking `codacy pull-request` only after discovering the PR is blocked
- [ ] Suppressing SC warnings without documenting the reason and date
