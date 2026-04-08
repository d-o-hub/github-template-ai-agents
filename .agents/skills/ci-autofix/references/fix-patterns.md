# CI Autofix — Validated Fix Patterns

This reference contains ONLY fix patterns that are:
- Documented in official sources
- Unambiguous (single correct fix)
- Safe to apply automatically (syntactic, no behavioral change)

---

## Pattern 001: yamllint `rule:truthy` false positive on `on:` key

**Applies to**: GitHub Actions workflow YAML files  
**Error message**: `[error] truthy value should be one of [false, true] (rule:truthy)`  
**Affected files**: Any `.github/workflows/*.yml` with `on:` as the event trigger key  
**Confidence**: HIGH — Auto-fix safe  

### Root Cause

YAML 1.1 spec treats `on` as a boolean truthy value (equivalent to `true`). yamllint enforces this by default via the `truthy` rule. GitHub Actions uses `on:` as an event trigger keyword — this is a well-known false positive.

**Official Sources**:
- yamllint truthy rule docs: https://yamllint.readthedocs.io/en/stable/rules.html#module-yamllint.rules.truthy
- yamllint issue #430 (GitHub Actions false positive): https://github.com/adrienverge/yamllint/issues/430
- yamllint issue #540 (same, confirmed): https://github.com/adrienverge/yamllint/issues/540
- yamllint issue #666 (same, confirmed): https://github.com/adrienverge/yamllint/issues/666

### Fix

Add `# yamllint disable-line rule:truthy` as an **inline comment on the same line** as `on:`.

**IMPORTANT**: `disable-line` applies to the line it appears ON, not the next line.

```yaml
# BEFORE (causes error)
on:
  push:
    branches: [main]

# AFTER (fix applied)
on: # yamllint disable-line rule:truthy
  push:
    branches: [main]
```

**Common Mistake** — comment on preceding line does NOT work:
```yaml
# WRONG: this does not suppress the error on the next line
# yamllint disable-line rule:truthy
on:
```

### OpenCode CLI Command

```bash
opencode run --model ollama/qwen3-coder:cloud \
  "In .github/workflows/<FILENAME>.yml, find the line that contains only 'on:' \
   (the GitHub Actions event trigger, usually near the top of the file). \
   Add '# yamllint disable-line rule:truthy' as an inline comment on that exact line. \
   The result must be: 'on: # yamllint disable-line rule:truthy'. \
   Do not modify any other line. Do not add blank lines. Preserve all indentation."
```

### Verification

```bash
yamllint -d '{extends: default}' .github/workflows/<FILENAME>.yml
# Expected: no errors (exit code 0)
```

---

## Pattern 002: Deprecated `actions/checkout` SHA pinning warning

**Applies to**: GitHub Actions workflows using `actions/checkout@<sha>`  
**Error type**: Warning (actionlint), not yamllint  
**Confidence**: HIGH — Auto-fix safe  

### Fix

Update to latest pinned SHA from https://github.com/actions/checkout/releases

**Official Source**: https://docs.github.com/en/actions/security-guides/security-hardening-for-github-actions#using-third-party-actions

### OpenCode CLI Command

```bash
opencode run --model ollama/qwen3-coder:cloud \
  "In .github/workflows/<FILENAME>.yml, update 'actions/checkout@<OLD_SHA>' \
   to 'actions/checkout@<NEW_SHA> # <VERSION_TAG>'. \
   Use only the exact SHA provided. Do not modify any other step."
```

---

## Pattern 003: Missing `permissions:` block (security hardening)

**Applies to**: GitHub Actions workflows without explicit permissions  
**Error type**: Best practice violation (not a CI error per se)  
**Confidence**: MEDIUM — Requires human confirmation of scope  
**Auto-fix**: NO — Escalate to human (permissions are semantic, not syntactic)

### Reason Not Auto-Fixed

The correct permission set depends on what the workflow does. Wrong permissions can break functionality or introduce security issues. Always present options to user.

---

## Escalation Patterns (Do NOT Auto-Fix)

| Error Type | Reason to Escalate |
|---|---|
| Logic errors in workflow scripts | Behavioral change required |
| Missing secrets or env vars | Infrastructure decision |
| Action version upgrades (major) | Breaking changes possible |
| Flaky tests / intermittent failures | Root cause unclear |
| Matrix strategy changes | Semantic impact |
| Concurrency/timeout settings | Performance trade-offs |
| Permission scope changes | Security decision |

---

## Adding New Patterns

To add a new validated fix pattern:

1. Confirm error is 100% reproducible and unambiguous
2. Find the fix in official documentation (not forums/blogs)
3. Verify fix is purely syntactic (no behavioral change)
4. Document source URL
5. Add OpenCode CLI command template
6. Mark confidence level: HIGH (auto-fix) or MEDIUM/LOW (escalate)
7. Add verification command
