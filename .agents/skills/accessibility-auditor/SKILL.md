---
name: accessibility-auditor
version: "0.2.10"
category: ui-ux
description: Audit web applications for WCAG 2.2 compliance, screen reader compatibility, keyboard navigation, and color contrast. Use this skill when the user asks for an accessibility audit, a11y check, WCAG compliance review, screen reader test, keyboard navigation check, color contrast check, or ARIA validation — even if they don't explicitly mention "accessibility" or "WCAG". Also triggers on Section 508 and ADA compliance requests. Not for css-render-performance.
license: MIT
---

# Accessibility Auditor

Audit web applications for WCAG 2.2 compliance, screen reader compatibility, keyboard navigation, and color contrast issues.

## When to Use

- User asks for an accessibility audit or a11y check
- Reviewing WCAG 2.2 compliance or Section 508/ADA requirements
- Testing screen reader compatibility or keyboard navigation
- Checking color contrast or ARIA validation
- Even if they just say "is this accessible" or "check for accessibility issues"

## Audit Workflow

### Phase 1: Automated Scan

Check these automatically using axe-core, Lighthouse, or WAVE:
- Color contrast (1.4.3)
- Missing alt text (1.1.1)
- Form labels (3.3.2)
- Heading hierarchy (1.3.1)

### Phase 2: Manual Testing

- **Screen Reader**: Navigate with NVDA/VoiceOver/JAWS arrow keys.
- **Keyboard**: Verify Tab order and focus indicators (2.4.7).
- **Zoom**: Test reflow at 400% zoom (1.4.10).

## Severity Classification

| Severity | Impact | Priority |
|----------|-------------|----------|
| **Critical** | Blocks access | Fix immediately |
| **High** | Significant barrier | Fix before release |
| **Medium** | Minor friction | Next sprint |
| **Low** | Enhancement | Backlog |

## See Also

- `css-render-performance` — CSS render performance optimization
- `ui-ux-optimize` — UI/UX optimization with swarm agents

## Rationalizations

| Rationalization | Reality |
|-----------------|---------|
| "Automated scans catch everything" | Automated tools miss keyboard traps, focus order, screen reader semantics, and cognitive load issues. |
| "Accessibility only matters for blind users" | Motor, cognitive, and situational impairments affect far more users than visual alone. |
| "We'll fix accessibility in the next release" | Each release without a11y compounds legal risk and excludes users; fix forward. |

## Red Flags

- [ ] Only automated scans run without manual keyboard/screen reader testing
- [ ] Color contrast issues deferred as cosmetic
- [ ] ARIA labels applied without role verification

## References

- [Accessibility Checklist](../../../agents-docs/references/accessibility-checklist.md) - Complete WCAG 2.2 criteria and testing procedures.
- `references/aria-guide.md` - ARIA authoring practices
- `references/screen-reader-testing.md` - Testing procedures
- `references/color-contrast.md` - Contrast calculations

## Voice & Context

- **Default**: `professional` + `blog`
- **Reference**: `voice-profiles` skill for definitions and auto-detection.
