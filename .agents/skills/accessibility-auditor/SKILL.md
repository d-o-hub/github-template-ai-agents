---
name: accessibility-auditor
version: "0.2.10"
category: ui-ux
description: Audit web applications for WCAG 2.2 compliance, screen reader compatibility, keyboard navigation, and color contrast. Triggers on "accessibility audit", "a11y check", "WCAG compliance", "screen reader test", "keyboard navigation", "color contrast check", "ARIA validation", "wcag", " Section 508", "ADA compliance".
license: MIT
---

# Accessibility Auditor

Audit web applications for WCAG 2.2 compliance, screen reader compatibility, keyboard navigation, and color contrast issues.

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
