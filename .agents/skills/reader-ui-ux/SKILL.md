---
version: "0.3.0"
name: reader-ui-ux
description: >
  Build localized, accessible reader/admin UI with responsive layouts, telemetry, and state management, plus resilient document rendering, TOC generation, and multi-signal locator/annotation anchoring for EPUB, PDF, or any document format. Use this skill when building React screens, polishing UX, implementing responsive reader/admin layouts, working with reader-core rendering, TOC, locator systems, or highlight anchoring — even if they just say "fix the UI", "make it responsive", "fix the document rendering", or "the highlights aren't sticking". Not for ui-ux-optimize.
category: workflow
license: MIT
---

# Reader UI/UX & Document Rendering

Purpose: deliver intentional, localized, accessible reader/admin UX atop resilient document rendering, locator extraction, and annotation anchoring. The rendering/locator scope was absorbed from document-rendering-and-locators (ADR-038).

## When to Use

- Modifying reader/admin React screens, layout primitives, or shared UI components.
- Adding localization copy, accessibility improvements, or design polish.
- Building locale switchers, typography controls, or comment/annotation panels.
- Integrating a document rendering library or making reader-core rendering changes.
- Working on TOC, locator, or highlight/comment anchoring logic.
- Debugging annotation drift or document loading regressions.

## Workflow

Do the rendering/data-model work first; the UI layer sits on top of it and
inheriting a broken anchor model poisons every screen above it.

### Rendering, locators, and anchoring

1. **Define data model** — confirm multi-signal locator requirements
   (position + text + chapter + DOM fallback) before any anchoring code.
2. **Design anchors** — map DOM selections onto
   `{ position, selectedText, chapterRef, elementIndex, charOffset }`.
3. **Implement** — use the rendering library's APIs for annotations and
   navigation; ensure async cleanup of everything the renderer starts.
4. **Resilience** — add a re-anchoring strategy: exact match → fuzzy text →
   chapter fallback → user notice. The fallback must warn the user, never
   silently land in the wrong place.
5. **Performance** — lazy-load document assets, reuse a single rendition
   instance, and clean up listeners so long reading sessions do not leak.

### UI/UX layer

6. **Define experience** — confirm viewport-specific layout (mobile drawer
   vs desktop side panels) and theme rules.
7. **Localization** — add strings to locale catalogs, ensure fallback,
   surface the locale switcher.
8. **Accessibility** — keyboard focus, ARIA labels, reduced motion,
   semantic regions.
9. **State** — use state management selectors, avoid prop drilling,
   memoize heavy renders.
10. **Observability** — log key UI actions and document load failures with
    trace IDs so silent anchor failures are diagnosable.
11. **Testing** — component tests for the UI; locator serialization and
    re-anchor helper tests for the anchor model; E2E coverage for primary
    flows. Capture annotation-drift regressions as fixed fixtures.

## Checklist

**UI/UX:**

- [ ] Layout responsive (mobile/tablet/desktop) with deliberate spacing.
- [ ] Strings localized and locale header updated.
- [ ] Error states use ErrorBoundary + inline alerts.
- [ ] Async effects cancel via AbortController; cleanup functions implemented.
- [ ] UI interactions include aria-labels + focus traps where applicable.

**Rendering/locators:**

- [ ] Position + text excerpt + chapterRef persisted together.
- [ ] Anchor serialization uses stable casing + schema.
- [ ] Re-anchoring warns user when falling back.
- [ ] Event handlers removed on unmount.

## See Also

- `avoid-ai-writing` — Avoid AI slop in UI/UX copy
- `css-render-performance` — CSS render performance optimization
- `ui-ux-optimize` — UI/UX optimization loops
- `turso-db` — Database for document storage

## Rationalizations

| Rationalization | Reality |
|-----------------|---------|
| "Accessibility is a nice-to-have, not a requirement" | Legal compliance (WCAG, ADA, Section 508) and user inclusion make it mandatory. |
| "I'll add localization later after the UI is done" | Retroactive localization is costly; string extraction and fallback logic should be designed upfront. |
| "Prop drilling is simpler than state management" | Prop drilling breaks at scale; memoized selectors prevent unnecessary re-renders and deep coupling. |
| "Exact match anchoring is always sufficient" | Documents change formatting across versions; multi-signal fallback prevents total anchor loss. (absorbed from document-rendering-and-locators) |
| "Lazy loading complicates the code" | Eager loading wastes memory and blocks rendering; lazy loading is essential for large documents. (absorbed from document-rendering-and-locators) |
| "Telemetry for load failures is overkill" | Without telemetry, silent anchor failures are invisible until users report them. (absorbed from document-rendering-and-locators) |

## Red Flags

- [ ] Reader UI built without keyboard navigation support
- [ ] Locale strings hardcoded in components instead of catalog
- [ ] Missing ErrorBoundary or AbortController cleanup on async effects
- [ ] Relying on a single anchoring signal without fallback strategy (absorbed from document-rendering-and-locators)
- [ ] Not cleaning up event handlers on unmount (absorbed from document-rendering-and-locators)
- [ ] Skipping locator serialization tests (absorbed from document-rendering-and-locators)

## References

- `references/responsive-patterns.md` - Responsive layout patterns
- `references/accessibility-checklist.md` - WCAG compliance checklist
- `references/locator-patterns.md` - Document locator strategies (absorbed from document-rendering-and-locators)
- `references/anchoring.md` - Annotation anchoring techniques (absorbed from document-rendering-and-locators)

## Voice & Context

- **Default**: `professional` + `blog`
- **Reference**: `voice-profiles` skill for definitions and auto-detection.
