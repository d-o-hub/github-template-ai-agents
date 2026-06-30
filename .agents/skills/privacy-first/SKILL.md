---
name: privacy-first
version: "0.2.10"
category: security
description: >
  Prevent email addresses and personal data from entering the codebase.
  Use this skill when the user asks to prevent emails, remove personal data,
  run a privacy check, scan for PII, or ensure no email addresses leak into
  source code or documentation — even if they just say "no email" or "check
  for personal data". Not for security audits (use security-code-auditor),
  EU AI Act compliance (use eu-ai-act-compliance), or hardcoded secrets
  (use security-code-auditor).
license: MIT
compatibility: Works with Claude Code, OpenCode, and similar agents. No external dependencies.
metadata:
  author: d-oit
  version: "1.0"
  tags: privacy security email lint quality personal-data
---

# Privacy First

This skill ensures no email addresses or personal data leak into the codebase.
It provides detection, prevention, and automated checking.

## When to Use

- User asks: "prevent emails", "remove personal data", "privacy check", "never use email"
- Before writing any new code, config, or documentation file
- During code review or quality gate checks
- When adding contact information to any file

## Agent Workflow

### 1. Before Writing Any File

Before creating or editing any file, check for email patterns:

```bash
# Scan the file being edited for email patterns
grep -E '[a-zA-Z0-9._%+-]+@[a-zA-Z0-9.-]+\.[a-zA-Z]{2,}' <file> || true
```

### 2. Replacement Rules

| Context | Instead of | Use |
|---|---|---|
| Author/contact | `support@project.com` | GitHub Issues link |
| Support | `help@project.com` | `https://github.com/owner/repo/issues` |
| Code of Conduct | `contact@project.com` | "Report via GitHub Issues" |
| Package metadata | `email = "..."` | Remove email field entirely |
| Examples | `user@gmail.com` | Test domain: `user@example.com` (only in tests) |

### 3. File-Type Specific Rules

**Python (pyproject.toml, setup.py)**

```toml
# Bad
authors = [{name = "Author", email = "author@example.com"}]

# Good
authors = [{name = "Author"}]
```

**Markdown (README.md, CONTRIBUTING.md)**

```markdown
<!-- Bad -->
Contact: support@project.com

<!-- Good -->
Report issues: https://github.com/owner/repo/issues
```

**Configuration files**
- Never add email fields
- Use URLs to GitHub instead

### 4. Exceptions (Allowed)

The following are permitted and should NOT be flagged:

- Test data in `tests/` directories using standard test domains:
  - `example.com`, `example.org`, `test.com`, `localhost`
- URLs in documentation pointing to external services
- Git history (cannot modify)
- Skill reference files with generic examples (for demonstration)

## Quality Gate Integration

To add automated checks to pre-commit or CI:

```bash
# Add to scripts/quality_gate.sh or .pre-commit-config.yaml

# Scan for email patterns (exclude test data and git)
EMAIL_PATTERN='[a-zA-Z0-9._%+-]+@[a-zA-Z0-9.-]+\.[a-zA-Z]{2,}'

# Exclude patterns (test domains, git, node_modules)
EXCLUDE_PATTERN='example\.com|example\.org|test\.com|\.git|node_modules'

# Check source files
if grep -rE "$EMAIL_PATTERN" --include="*.py" --include="*.toml" --include="*.yaml" --include="*.json" --include="*.md" . 2>/dev/null | grep -vE "$EXCLUDE_PATTERN"; then
    echo "ERROR: Email address detected in codebase"
    exit 1
fi
```

## Quick Reference

**Never do:**
- Add `email = "..."` to any config file
- Write `contact@project.com` in any markdown
- Use real email addresses in examples
- Include personal emails in commit messages

**Always do:**
- Use GitHub Issues URLs for support
- Remove email fields from package metadata
- Use test domains (`example.com`) only in test files
- Link to SECURITY.md for vulnerability reporting

## See Also

- `security-code-auditor` — General security audits
- `eu-ai-act-compliance` — EU AI Act compliance

## Rationalizations

| Rationalization | Reality |
|-----------------|---------|
| "It's just a README, no one cares about emails in docs" | Scrapers harvest emails from public repos; any address becomes a phishing target. |
| "We need a real contact email for support" | Use GitHub Issues or a web form; email addresses in repos are permanent even after deletion. |
| "This is an internal tool, privacy doesn't apply" | Internal repos get leaked; personal data in source code violates privacy-by-design principles. |

## Red Flags

- [ ] Adding email fields to package metadata or config files
- [ ] Using real email addresses in documentation examples
- [ ] Skipping email scans in CI because "it's just a test file"

## Voice & Context

- **Default**: `professional` + `blog`
- **Reference**: `voice-profiles` skill for definitions and auto-detection.
