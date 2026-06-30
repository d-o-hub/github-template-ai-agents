---
name: code-review-assistant
version: "0.2.10"
category: code-quality
description: Automated code review with PR analysis, change summaries, quality checks, and code smell detection. Use this skill when reviewing pull requests, generating review comments, checking against best practices, identifying code smells, or providing refactoring guidance — even if they just say "review this" or "look at this PR". Not for static-analysis, security-code-auditor.
license: MIT
---

# Code Review Assistant

Automated code review with intelligent analysis of changes, quality checks, and actionable feedback generation.

## When to Use

- **Reviewing pull requests** - Analyze diffs and provide feedback
- **Change summarization** - Generate PR descriptions from code changes
- **Quality checks** - Style guide compliance, best practices
- **Security review** - Detect potential security issues in changes
- **Code smell detection** - Identify bloaters, dispensables, and couplers
- **Refactoring guidance** - Suggest targeted improvements
- **Review automation** - Auto-approve simple changes, flag complex ones
- **Learning tool** - Explain changes for knowledge sharing

## Core Workflow

### Phase 1: Change Analysis

1. **Identify modified files** - Categorize by type and risk level
2. **Calculate metrics** - Lines changed, complexity delta, test coverage
3. **Detect patterns** - New features, bug fixes, refactoring, dependencies
4. **Assess risk** - Critical paths, public APIs, security-sensitive areas

### Phase 2: Quality Assessment

1. **Style compliance** - Check against project style guide
2. **Best practices** - Design patterns, code organization
3. **Test coverage** - Verify tests accompany changes
4. **Documentation** - Check for necessary doc updates
5. **Security scan** - Identify potential vulnerabilities

### Phase 3: Feedback Generation

1. **Summarize changes** - High-level description of what changed
2. **Identify issues** - Bugs, anti-patterns, performance concerns
3. **Suggest improvements** - Refactoring opportunities, optimizations
4. **Highlight positives** - Good practices to reinforce
5. **Generate review comments** - Specific, actionable feedback

## Code Smells Detection

### Bloaters

- **Long Method** (>30 lines of logic)
- **Large Class** (>300 lines)
- **Long Parameter List** (>4 params)

### Object-Orientation Abusers

- **Switch Statements** (replace with polymorphism)
- **Temporary Field**
- **Refused Bequest**

### Dispensables

- **Duplicate Code**
- **Lazy Class**
- **Dead Code**
- **Speculative Generality**

### Couplers

- **Feature Envy**
- **Inappropriate Intimacy**
- **Message Chains** (obj.getX().getY())

## Core Quality Principles

- **DRY** — Extract repeated logic into shared functions or constants
- **Single Responsibility** — Each function/class should have one clear purpose
- **No Magic Numbers** — Replace bare literals with named constants

See `static-analysis` for linter tool registry and per-language commands.

## File Risk Assessment

| Risk Level | Patterns | Examples |
|------------|----------|----------|
| **Critical** | Auth, security, payment | `**/auth/**`, `**/security/**`, `**/payment/**` |
| **High** | API, models, database | `**/api/**`, `**/models/**`, `**/database/**` |
| **Medium** | Services, utils | `**/services/**`, `**/helpers/**` |
| **Low** | Tests, docs | `**/tests/**`, `**/*.md` |

## Change Metrics

| Metric | Threshold | Action |
|--------|-----------|--------|
| **Files Changed** | > 20 | Extra review needed |
| **Lines Changed** | > 500 | Consider splitting PR |
| **Complexity Delta** | +10 | Needs scrutiny |
| **Test Coverage** | < 80% | Flag for tests |
| **TODO/FIXME** | > 3 | Needs triage |

## Review Feedback Format

When reporting issues, use this structure:

- **Issue**: clear description of the problem
- **Suggestion**: specific actionable fix
- **Why**: reasoning behind the suggestion

For positive observations, highlight the practice and its benefit.

## GitHub Integration

See `references/github-integration.md` for API usage, auto-approval criteria, and webhook setup.

## Review Summary Template

```markdown
## Code Review Summary

### 📊 Change Overview
- **Files Changed**: {file_count}
- **Lines Modified**: +{additions}/-{deletions}
- **Risk Level**: {risk_level}
- **Estimated Review Time**: {review_time} minutes

### ⚠️ Issues Found
{issues_table}

### ✅ Positive Observations
{positive_observations}

### 🏁 Review Decision
**{decision}** - {decision_reason}
```

## Review Checklist

- [ ] No magic numbers (use named constants)
- [ ] Functions/methods under 50 lines
- [ ] DRY principle followed
- [ ] All new code has corresponding tests
- [ ] No hardcoded secrets or credentials
- [ ] Security-sensitive code properly reviewed
- [ ] Documentation updated for API changes
- [ ] No debugging code left in (console.log, print)

## Rationalizations

| Rationalization | Reality |
|-----------------|---------|
| "The PR is too large to review properly" | Large PRs hide defects; split them or request a breakdown before approving. |
| "Auto-approve is good enough for small changes" | Small changes in critical paths (auth, payments) still need human scrutiny. |
| "Review comments are just noise" | Actionable feedback prevents repeated mistakes and builds team knowledge. |

## Red Flags

- [ ] Approving PRs without checking test coverage
- [ ] Ignoring security-pattern findings in review comments
- [ ] Auto-approving changes in critical-path files without inspection

## References

- `references/github-integration.md` - GitHub API integration
- `references/security-patterns.md` - Security review patterns
- `references/style-guides.md` - Common style guide configurations

## See Also

- `static-analysis` — Linter triage and fix workflows
- `security-code-auditor` — Security audit workflows
- `codacy` — Local Codacy CLI analysis
