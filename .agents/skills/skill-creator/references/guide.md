# Skill Creator Reference Guide

Templates, examples, and best practices for creating and maintaining AI agent skills.

## Skill Templates

### Template 1: Process Skill

For skills that define step-by-step workflows:

```markdown
---
name: skill-name
description: [Action verb] [what it does]. Use this skill when [specific scenarios].
---

# Skill Title

Brief overview of skill purpose and scope.

## When to Use

- [Scenario 1: Specific situation]
- [Scenario 2: Specific situation]

## Process

### Step 1: [Action]

Clear instructions for this step.

**Checklist**:
- [ ] Task 1
- [ ] Task 2

### Step 2: [Action]

Clear instructions for this step.

## Examples

### Example 1: [Name]

```text
Example workflow or code
```

## Best Practices

### DO:

- [Action to take]

### DON'T:

- [Action to avoid]

## Rationalizations

| Rationalization | Reality |
|-----------------|---------|
| "Excuse" | Why the excuse is wrong. |

## Red Flags

- [ ] Red flag to watch for

## Reference Files

- `references/guide.md` - Additional documentation

```

### Template 2: Knowledge Skill

```markdown
---
name: domain-knowledge
description: [Domain] expertise and guidance. Use when [specific need].
---

# Domain Knowledge

Overview of the domain and why it matters.

## Core Concepts

### Concept 1: [Name]

Explanation in 2-3 sentences.

## When to Use

- When working with [domain element]
- When needing [specific knowledge]

## Key Patterns

### Pattern 1: [Name]

Description and when to use.

## Guidelines

### Best Practices
- [Guideline 1]

### Common Pitfalls
- [Pitfall to avoid]

## Related Skills

- **[related-skill](../related-skill/SKILL.md)** - How it connects
```

### Template 3: Tool Skill

```markdown
---
name: tool-usage
description: [Tool] usage and best practices. Use when [tool operation needed].
---

# Tool Name

Overview of the tool and its purpose.

## Installation

```bash
[Installation command]
```

## Basic Usage

### Command 1: [Name]

```bash
[Command syntax]
```

## When to Use

- [Use case 1]

## Best Practices

### DO:

- [Action to take]

### DON'T:

- [Anti-pattern 1]

## Troubleshooting

| Error | Cause | Solution |
|-------|-------|----------|
| [Error] | [Cause] | [Solution] |

```

## Description Writing

### Good Descriptions

```yaml
description: Debug and fix failing tests in Rust projects. Use this skill when tests fail and you need to diagnose root causes, fix async/await issues, or handle race conditions.
```

```yaml
description: Implement new features systematically with proper testing and documentation. Use when adding new functionality to the codebase.
```

### Bad Descriptions

```yaml
description: Helps with testing
# Too vague - no trigger scenarios
```

```yaml
description: Provides guidance on building APIs
# Missing when-to-use context
```

### Principles

1. **Imperative phrasing**: "Use this skill when..." rather than "This skill does..."
2. **Focus on user intent**: Describe what the user is trying to achieve
3. **Err on pushy side**: Explicitly list contexts where the skill applies
4. **Keep concise**: Max 1024 characters

## Naming Conventions

| Good Names | Bad Names |
|------------|-----------|
| `episode-management` | `helper` (too vague) |
| `test-debugging` | `Episode_Management` (wrong format) |
| `code-review` | `test debugging` (contains space) |
| `api-integration` | `very-long-skill-name-that-is-hard-to-type` (too long) |

Rules: lowercase, hyphens only, max 64 chars, descriptive.

## Example: Creating a Skill via CLI

```bash
python -m scripts.init_skill \
  --skill-name production-deploy \
  --description "Deploy Rust applications safely with pre-deployment checks. Use when deploying to production."
```

This creates full directory structure with SKILL.md, evals/evals.json (3 placeholder cases), scripts/example.py, and references/guide.md.

## Best Practices

### Start from Real Expertise

Avoid generating generic skills. Extract patterns from:
- Real tasks completed with agents
- Corrections made during execution
- Existing internal documentation and runbooks
- Code review comments and issue trackers
- Real-world failure cases and their resolutions

### Refine with Real Execution

Run the skill against real tasks, then feed results back:
- What triggered false positives?
- What was missed?
- What could be cut?

### Effective Instruction Patterns

1. **Gotchas sections** — highest-value content for project specifics
2. **Templates for output format** — provide template rather than describing in prose
3. **Checklists for multi-step workflows**
4. **Validation loops**: Do work -> Validate -> Fix -> Repeat

### Spend Context Wisely

Focus on what the agent would not know without the skill: project conventions, domain-specific procedures, non-obvious edge cases, particular APIs. Do not explain concepts like what HTTP or PDF is.

## Common Mistakes

| Mistake | Problem | Fix |
|---------|---------|-----|
| Vague description | Agent does not know when to invoke | Add specific scenarios and keywords |
| No examples | Hard to understand usage | Include 2-3 concrete examples |
| Too long | Exceeds context limits | Move details to reference files |
| Wrong name format | Skill not recognized | Use lowercase with hyphens only |
| Missing When-to-Use | Unclear invocation triggers | Add dedicated trigger section |

## Skill Dependencies and Cross-References

Skills can reference other skills:

```markdown
## Related Skills
- **[goap-agent](../goap-agent/SKILL.md)** - Use before implementing (Phase 2: decomposition)
```

Link between skills:

```markdown
See also: **[agent-coordination](../agent-coordination/SKILL.md)** for concurrent task patterns.
```

## Output Patterns

### Template Pattern (Strict)

For API responses or data formats, provide exact templates:

```markdown
## Report structure

ALWAYS use this exact template:

# [Title]
## Executive summary
[One-paragraph overview]

## Key findings
- Finding 1 with supporting data
```

### Template Pattern (Flexible)

```markdown
## Report structure

Here is a sensible default, but adapt as needed:

# [Title]
## Executive summary
[Overview]
```

### Examples Pattern

For quality-sensitive output, provide input/output pairs to demonstrate style and level of detail.

## Maintenance

- **Versioning**: Use SemVer. Major (1.0.0) for breaking changes, Minor (0.1.0) for additions, Patch (0.0.1) for fixes.
- **Updating**: Preserve backward compatibility. Update description if scope changes.
- **Deprecation**: Update description to indicate deprecation, point to replacement, and remove after transition period.

## Measuring Effectiveness

Track skill performance with eval benchmarks:
- **Pass rate**: Percentage of assertions passing
- **Invocation accuracy**: Correct trigger vs. false trigger ratio
- **Time delta**: Speed impact of skill invocation
- **Token delta**: Context window impact of skill
