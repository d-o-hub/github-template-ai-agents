---
name: verification-template
version: "0.2.10"
category: quality
description: Template for creating portable domain-specific verification skills. Use this skill when creating a verification checklist as a starting point for defining systematic verification checklists for new features, modules, or domain-specific operations — even if they just say "create a verification checklist" or "add quality checks for this". Not for skill-creator.
license: MIT
---

# Verification Skill Template

Define systematic, portable verification checklists for common operations within a specific domain.

## When to Use

- Establishing a new verification protocol for a specific component.
- Ensuring consistent quality gates across different implementations.
- Automating manual verification steps into a structured checklist.

## Verification Checklist

### [Operation Name]

- [ ] Requirement 1: [Description of success criteria]
- [ ] Requirement 2: [Description of success criteria]
- [ ] Edge Case 1: [Description of how to verify]

### [Data Integrity]

- [ ] Roundtrip: [Verify data matches after save/load]
- [ ] Schema: [Verify output adheres to expected schema]

### [Security/Safety]

- [ ] Permission: [Verify restricted access works as intended]
- [ ] Sanitization: [Verify inputs are correctly handled]

## Process

1. **Identify Operation**: What specific action needs verification?
2. **Define Success**: What does a "perfect" execution look like?
3. **Draft Checklist**: Use the categories above to list specific checks.
4. **Test Checklist**: Run through the checks on a real instance.
5. **Iterate**: Refine the checklist based on discovered edge cases.

## See Also

- `skill-creator` — Create and improve skills
- `skill-evaluator` — Evaluate and score skills

## Rationalizations

| Rationalization | Reality |
|-----------------|---------|
| "This is a minor change, full verification is overkill" | Every change needs verification to prevent regressions. |
| "I've tested this manually already" | Manual testing is prone to oversight; structured checklists ensure consistency. |

## Red Flags

- [ ] Skipping verification steps for "simple" changes
- [ ] Marking items as complete without actually performing the check
- [ ] Relying solely on successful build/lint without functional verification

## References

- `AGENTS.md` - Repository standards and quality gates
- `scripts/quality_gate.sh` - Automated verification entry point

## Voice & Context

- **Default**: `professional` + `blog`
- **Reference**: `voice-profiles` skill for definitions and auto-detection.
