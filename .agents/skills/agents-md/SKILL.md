---
name: agents-md
version: "0.2.10"
category: documentation
description: Create AGENTS.md files with production-ready best practices. Use this skill when creating new AGENTS.md files, implementing quality gates, or updating agent documentation — even if they just say "add an AGENTS.md" or "set up agent guidance". Not for readme-best-practices, skill-creator.
license: MIT
---

# AGENTS.md Best Practices

Create production-ready AGENTS.md files following best practices below.

## When to Use

- User asks to create or update AGENTS.md files
- Need to implement quality gates or agent documentation
- Even if they just say "add an AGENTS.md" or "set up agent guidance"

## Quick Start

**Basic:**

```bash
cat > AGENTS.md << 'EOF'
# AGENTS.md
## Named Constants
readonly MAX_FILE_SIZE=500

## Setup
- Install: npm install
- Test: npm test

## Code Style
- TypeScript strict
- Max line: 100
EOF
```

**Production:** See guide in `agents-docs/` folder

## Core Sections

### 1. Named Constants

```bash
## Named Constants
readonly MAX_FILE_SIZE=500
readonly TIMEOUT_SECONDS=30
readonly MAX_RETRIES=3
```

### 2. Pre-existing Issue Policy

```markdown
## Pre-existing Issues
**Fix ALL before completing:**
- [ ] Lint warnings
- [ ] Test failures
- [ ] Security vulnerabilities
```

### 4. Development Workflow Rules

```markdown
## Development Workflow
**Prerequisite**: Always fetch and pull the latest default remote branch before analyzing or making changes.
**Phase 1 (ANALYZE)**: Use TRIZ, write an ADR in `plans/`. (Human review required for ADR only)
**Phase 2 (DECOMPOSE)**: Plan tasks in `plans/GOAP_STATE.md`
**Phase 3 (EXECUTE)**: Implement using atomic commits. Loop until all GitHub Actions (CI checks) pass.
**Phase 4 (SYNTHESIZE)**: Update context using existing learnings.
```

### 3. Quality Gate

```markdown
## Quality Gate
```bash
npm run typecheck
npm run lint
npm run test
npm audit
```

```

## Tier Structure

- **Tier 1 (Essential):** Constants, setup, style, testing
- **Tier 2 (Professional):** Add quality gate, atomic commit, security
- **Tier 3 (Enterprise):** Add skills, sub-agents, nested AGENTS.md

See `agents-docs/SKILLS.md` for tier details.

## Best Practices

### DO:
- Define named constants at top
- Include pre-existing issue policy
- Specify quality gate commands
- Reference @agents-docs/ for detail

### DON'T:
- Use magic numbers
- Skip pre-existing issues
- Write vague commands ("run tests")
- Duplicate README content

## Quality Criteria

- [ ] Named constants defined
- [ ] Pre-existing issue policy included
- [ ] Quality gate specified
- [ ] < 160 lines (progressive disclosure)

## See Also

- `skill-creator` — Create and improve skills
- `learn` — Extract learnings into AGENTS.md

## Rationalizations

| Rationalization | Reality |
|-----------------|---------|
| "A README is enough, AGENTS.md is overkill" | AGENTS.md encodes agent-specific constraints and workflows that README cannot cover without clutter. |
| "I'll write it after the project stabilizes" | Without AGENTS.md from the start, agents accumulate inconsistent conventions that are costly to fix later. |
| "Just put everything in one big AGENTS.md" | Single monolithic files become unmaintainable; tier structure enables progressive disclosure. |

## Red Flags

- [ ] AGENTS.md contains vague commands like "run tests" without specific invocations
- [ ] Named constants missing or using magic numbers
- [ ] Quality gate section absent or incomplete

## References

- `agents-docs/SKILLS.md` - Skill framework
- `agents-docs/SUB-AGENTS.md` - Sub-agent patterns
- https://agents.md - Official spec
