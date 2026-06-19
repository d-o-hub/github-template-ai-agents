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

```yaml
- name: ShellCheck
  uses: ludeeus/action-shellcheck@master
- name: Run BATS
  run: |
    sudo apt-get install -y bats
    bats tests/
```

## Script Template

Use this template for new scripts:

```bash
#!/bin/bash
set -euo pipefail

# Script directory (portable)
SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"

# Error handler
error_exit() {
    echo "ERROR: $1" >&2
    exit "${2:-1}"
}

# Main function
main() {
    [[ $# -lt 1 ]] && {
        echo "Usage: $0 <argument>" >&2
        exit 1
    }

    # Your logic here
}

# Run if executed directly
if [[ "${BASH_SOURCE[0]}" == "${0}" ]]; then
    main "$@"
fi
```

## Installation

**ShellCheck**:

```bash
brew install shellcheck         # macOS
sudo apt-get install shellcheck # Linux
```

**BATS**:

```bash
brew install bats-core          # macOS
sudo apt-get install bats       # Linux
```

## Configuration

**.shellcheckrc** in project root:

```bash
shell=bash
disable=SC1090
enable=all
source-path=SCRIPTDIR
```

**For configuration details**: See [CONFIG.md](CONFIG.md)

## Testing Claude Code Plugins

**Test scripts using CLAUDE_PLUGIN_ROOT**:

```bash
@test "plugin script works" {
    export CLAUDE_PLUGIN_ROOT="$BATS_TEST_DIRNAME/.."
    run bash "$CLAUDE_PLUGIN_ROOT/scripts/search.sh" "query"
    [ "$status" -eq 0 ]
}
```

**Test hooks with JSON**:

```bash
@test "hook provides suggestions" {
    local input='{"tool":"Edit","params":{"file_path":"test.txt"}}'
    run bash "$HOOK_DIR/pre-edit.sh" <<< "$input"
    [ "$status" -eq 0 ]
    echo "$output" | jq empty
}
```

**More plugin patterns**: See [PATTERNS.md](PATTERNS.md)

## Troubleshooting

**ShellCheck**:
- SC1090 warnings: Add `# shellcheck source=path/to/file.sh`
- False positives: Use `# shellcheck disable=SCxxxx`

**BATS**:
- Tests interfere: Ensure proper `teardown()` cleanup
- Can't source script: Add main execution guard
- Path issues: Use `$BATS_TEST_DIRNAME` for relative paths

**Detailed troubleshooting**: See [TROUBLESHOOTING.md](TROUBLESHOOTING.md)

## Validation Loop Pattern

For quality-critical operations:

1. Make changes to script
2. **Validate immediately**: `shellcheck script.sh`
3. If validation fails:
   - Review error messages carefully
   - Fix the issues
   - Run validation again
4. **Only proceed when validation passes**
5. Run tests: `bats tests/script.bats`
6. If tests fail, return to step 1

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
| "BATS tests take too long to write" | Untested scripts break silently in production; test time is investment, not waste. |
| "set -e is too strict for my script" | Scripts without -e silently swallow errors and leave systems in inconsistent states. |

## Red Flags

- [ ] Running shell scripts without set -euo pipefail
- [ ] Skipping ShellCheck linting before committing shell scripts
- [ ] Suppressing SC warnings without documenting the reason and date
