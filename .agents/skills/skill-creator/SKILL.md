---
name: skill-creator
description: Create new Claude Code skills with proper directory structure, SKILL.md file, and YAML frontmatter. Use this skill when you need to create a new reusable knowledge module for Claude Code.
---

# Skill Creator

Create new Claude Code skills following the official format and best practices.

## Quick Reference

- **[Templates and Examples](templates-and-examples.md)** - Skill templates
- **[Reference Guide](reference/guide.md)** - Complete templates and examples

## When to Use

- Creating a new reusable knowledge module
- Adding specialized guidance for specific tasks
- Building domain-specific expertise into Claude Code

## Skill Structure

```
.agents/skills/
└── skill-name/
    └── SKILL.md
```

### SKILL.md Format

```markdown
---
name: skill-name
description: Clear description (max 1024 chars)
---

# Skill Title

[Content]
```

## Naming Requirements

**Rules**:
- Lowercase letters only
- Hyphens for word separation
- No spaces or underscores
- Max 64 characters

**Examples**:
- ✅ `episode-management`
- ✅ `test-debugging`
- ✗ `Episode_Management`
- ✗ `test debugging`

## Description Best Practices

**Structure**: `[Action verb] [what it does]. Use this when [scenarios].`

✅ Good:
```yaml
description: Debug and fix failing tests. Use when tests fail and you need to diagnose root causes.
```

✗ Too vague:
```yaml
description: Helps with testing
```

## Skill Creation Process

### Step 1: Define Purpose
What problem does this skill solve?

### Step 2: Choose Name
Lowercase with hyphens, descriptive.

### Step 3: Write Description
Action, what it solves, when to invoke.

### Step 4: Structure Content

Recommended sections:
1. Introduction
2. When to Use
3. Core Concepts/Process
4. Examples
5. Best Practices
6. Integration

### Step 5: Create Files

```bash
mkdir -p .agents/skills/skill-name
# Create SKILL.md
```

### Step 6: Validate

Checklist:
- [ ] Directory name matches skill name
- [ ] SKILL.md exists
- [ ] YAML frontmatter valid
- [ ] Name is lowercase with hyphens
- [ ] Description < 1024 chars
- [ ] Examples provided

## Skill Templates

See **[templates-and-examples.md](templates-and-examples.md)** and **[reference/guide.md](reference/guide.md)** for:

1. **Process Skill** - Step-by-step workflows
2. **Knowledge Skill** - Domain expertise
3. **Tool Skill** - Tool usage

## Integration with Agents

1. Reference agents in skill
2. Ensure skill complements agent capabilities
3. Make clear when skill vs agent is appropriate

## Best Practices

### DO:
✓ Write clear, specific descriptions
✓ Include concrete examples
✓ Structure content logically
✓ Use consistent formatting
✓ Follow naming conventions

### DON'T:
✗ Use vague descriptions
✗ Skip examples
✗ Use uppercase or underscores
✗ Exceed 1024 chars in description

## Validation

```bash
# Check structure
test -f .agents/skills/skill-name/SKILL.md && echo "✓ OK"

# Check name format
grep "^name:" .agents/skills/skill-name/SKILL.md
```

## Summary

Creating effective skills:
1. **Purpose**: Solve specific problems
2. **Naming**: Clear, lowercase, hyphenated
3. **Description**: Specific with when-to-use
4. **Structure**: Well-organized sections
5. **Examples**: Concrete usage examples

## Reference Files

- **[templates-and-examples.md](templates-and-examples.md)** - Quick templates for process, knowledge, and tool skills
- **[reference/guide.md](reference/guide.md)** - Complete templates, naming/description examples, validation checklist, testing guide, and common mistakes
