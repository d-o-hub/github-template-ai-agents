---
name: ci-autofix
description: Detect and automatically fix failing CI pipelines using OpenCode CLI with Ollama Cloud. Reads open GitHub Actions runs, analyzes errors, researches fixes against official documentation, and applies safe auto-fixes only when the solution is unambiguous and documentation-validated.
license: MIT
---

# CI Autofix

Automatically detect failing CI jobs, analyze root causes, and apply safe auto-fixes using OpenCode CLI with Ollama Cloud — only when the fix is clearly documented and unambiguous.

## When to Use

- **Failing GitHub Actions runs** — YAML lint errors, syntax issues, deprecated actions
- **Known linter false positives** — yamllint `rule:truthy` on `on:` keys in GitHub Actions
- **Documented fix patterns** — issues with a clear, official-documentation-backed solution
- **Recurring CI failures** — same error appearing across multiple workflow files
- **Post-commit validation** — verify all workflows pass after changes

## Core Principles

> **Safety First**: Only apply fixes when the solution is 100% clear from official documentation (yamllint docs, GitHub Actions docs, action changelogs). Never assume or guess a fix.

- Research the error against official docs before applying any change
- If multiple fix options exist with trade-offs → **stop, report to user, do not auto-fix**
- If the error cause is ambiguous → **stop, report to user, do not auto-fix**
- If the fix requires logic changes (not just syntax) → **stop, report to user**

## Core Workflow

### Phase 1: Detect Failures

1. Read the current GitHub Actions run from the open browser tab
2. Identify all failing jobs and their error messages
3. Locate the affected workflow files in `.github/workflows/`
4. Extract the exact error lines and context

### Phase 2: Research & Validate Fix

1. Search official documentation for the exact error
   - yamllint docs: https://yamllint.readthedocs.io/
   - GitHub Actions docs: https://docs.github.com/en/actions
   - Action-specific changelogs and release notes
2. Confirm the fix is documented and unambiguous
3. Verify no alternative interpretations exist
4. Check if the fix is purely syntactic (safe) or semantic (requires human review)

### Phase 3: Auto-Fix with OpenCode CLI + Ollama Cloud

Only proceed if Phase 2 confirms a clear, documented fix.

```bash
# Configure OpenCode with Ollama Cloud provider
# opencode.json (project-level or ~/.config/opencode/config.json)
{
  "$schema": "https://opencode.ai/config.json",
  "provider": {
    "ollama": {
      "npm": "@ai-sdk/openai-compatible",
      "name": "Ollama Cloud",
      "options": {
        "baseURL": "https://ollama.com/v1",
        "apiKey": "${OLLAMA_API_KEY}"
      },
      "models": {
        "qwen3-coder:cloud": {
          "name": "qwen3-coder:cloud"
        }
      }
    }
  },
  "model": "ollama/qwen3-coder:cloud"
}
```

```bash
# Run the fix via OpenCode CLI (non-interactive / headless)
opencode run --model ollama/qwen3-coder:cloud \
  "Fix the yamllint error in .github/workflows/<file>.yml. \
   The error is: <exact error>. \
   The fix is documented at <source URL>: add '# yamllint disable-line rule:truthy' \
   as an inline comment on the line containing 'on:'. \
   Apply only this change, nothing else."
```

### Phase 4: Verify

1. Run yamllint locally to confirm fix: `yamllint -d '{extends: default}' .github/workflows/*.yml`
2. Commit with conventional message: `fix(ci): resolve yamllint <rule> in <filename>`
3. Push and confirm CI passes

## Known Fix Patterns

See `references/fix-patterns.md` for documented, validated fix patterns.

### Pattern: yamllint `rule:truthy` on `on:` key

**Error**: `[error] truthy value should be one of [false, true] (rule:truthy)`

**Root Cause**: yamllint interprets YAML `on:` key as a truthy boolean (`on` = `true` in YAML 1.1 spec). GitHub Actions uses `on:` as an event trigger keyword.

**Official Fix** ([yamllint docs](https://yamllint.readthedocs.io/en/stable/rules.html#module-yamllint.rules.truthy), [GitHub Actions community](https://github.com/adrienverge/yamllint/issues/430)):

Add `# yamllint disable-line rule:truthy` as an inline comment **on the same line** as `on:`:

```yaml
# WRONG - comment on preceding line (disable-line does not work)
# yamllint disable-line rule:truthy
on:

# CORRECT - inline comment on same line
on: # yamllint disable-line rule:truthy
  push:
    ...
```

**Confidence**: HIGH — single unambiguous documented fix, no side effects.

**OpenCode CLI command**:
```bash
opencode run --model ollama/qwen3-coder:cloud \
  "In .github/workflows/version-propagation.yml, the line 'on:' triggers a yamllint truthy error. \
   Fix: add '# yamllint disable-line rule:truthy' as an inline comment on the same 'on:' line. \
   Result should be: 'on: # yamllint disable-line rule:truthy'. Apply only this exact change."
```

## Decision Tree: Fix or Escalate?

```
CI Failure detected
       |
       v
Is error message exact and specific?
  No  --> STOP: Report to user, ask for clarification
  Yes |
       v
Is fix documented in official docs?
  No  --> STOP: Do not guess, report to user
  Yes |
       v
Is fix purely syntactic (no logic change)?
  No  --> STOP: Escalate to human review
  Yes |
       v
Is there exactly ONE valid fix?
  No  --> STOP: Present options to user
  Yes |
       v
Apply fix via OpenCode CLI + Ollama Cloud
       |
       v
Verify locally before committing
```

## OpenCode CLI Integration

### Setup

```bash
# Install OpenCode CLI
npm install -g opencode-ai

# Connect Ollama Cloud (requires ollama.com account + API key)
# Option A: via /connect command in TUI
opencode  # then run: /connect -> search "Ollama Cloud"

# Option B: manual config in opencode.json
# See configuration block in Phase 3 above

# Verify connection
opencode run --model ollama/qwen3-coder:cloud "echo hello"
```

### Headless / Scripted Usage

```bash
# Run fix non-interactively (for use in scripts or other agents)
opencode run --model ollama/qwen3-coder:cloud --print "<prompt>"

# With explicit working directory
opencode run --cwd /path/to/repo --model ollama/qwen3-coder:cloud "<prompt>"
```

## Quality Checklist

- [ ] Error message read directly from CI logs (no assumptions)
- [ ] Fix source is official documentation URL (not Stack Overflow, blog posts)
- [ ] Fix is syntactic-only (no behavioral changes)
- [ ] Single unambiguous fix exists
- [ ] Local yamllint validation passes after fix
- [ ] Commit message follows conventional commits format
- [ ] CI re-run confirms green status
- [ ] No unrelated files modified

## References

- `references/fix-patterns.md` — Validated fix patterns with documentation sources
- yamllint rules: https://yamllint.readthedocs.io/en/stable/rules.html
- GitHub Actions `on:` syntax: https://docs.github.com/en/actions/writing-workflows/choosing-when-your-workflow-runs/events-that-trigger-workflows
- OpenCode providers: https://opencode.ai/docs/providers/
- Ollama Cloud setup: https://ollama.com/docs/integrations/opencode
