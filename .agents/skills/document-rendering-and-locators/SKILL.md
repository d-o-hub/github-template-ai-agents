---
version: "0.2.10"
name: document-rendering-and-locators
description: >
  Implement resilient document rendering and annotation anchoring. Use this skill when working with reader-core rendering, TOC generation, locator systems, or highlight anchoring changes — even if they just say "fix the document rendering" or "the highlights aren't sticking". Generic pattern applicable to EPUB, PDF, or any document format.
category: workflow
license: MIT
---

# Document Rendering and Locators

Purpose: implement resilient document rendering, locator extraction, and annotation anchoring.

## When to Use

- Integrating document rendering library or reader-core changes.
- Working on TOC, locator, or highlight/comment anchoring logic.
- Debugging annotation drift or document loading regressions.

## Workflow

1. **Define data model** -- confirm multi-signal locator requirements (position + text + chapter + DOM fallback).
2. **Design anchors** -- map DOM selections --> `{ position, selectedText, chapterRef, elementIndex, charOffset }`.
3. **Implement** -- use rendering library APIs for annotations and navigation, ensure async cleanup.
4. **Resilience** -- add re-anchoring strategy (exact match --> fuzzy text --> chapter fallback --> user notice).
5. **Performance** -- lazy-load document assets, reuse single rendition, clean up listeners to avoid leaks.
6. **Testing** -- add test cases for locator serialization + re-anchor helpers; capture regressions.

## Checklist

- [ ] Position + text excerpt + chapterRef persisted together.
- [ ] Anchor serialization uses stable casing + schema.
- [ ] Re-anchoring warns user when falling back.
- [ ] Event handlers removed on unmount.
- [ ] Telemetry events logged for load failures with trace IDs.

## See Also

- `reader-ui-ux` — Reader/admin UI with responsive layouts
- `turso-db` — Database for document storage

## Rationalizations

| Rationalization | Reality |
|-----------------|---------|
| "Exact match anchoring is always sufficient" | Documents change formatting across versions; multi-signal fallback prevents total anchor loss. |
| "Lazy loading complicates the code" | Eager loading wastes memory and blocks rendering; lazy loading is essential for large documents. |
| "Telemetry for load failures is overkill" | Without telemetry, silent anchor failures are invisible until users report them. |

## Red Flags

- [ ] Relying on a single anchoring signal without fallback strategy
- [ ] Not cleaning up event handlers on unmount
- [ ] Skipping locator serialization tests

## References

- `references/locator-patterns.md` - Document locator strategies
- `references/anchoring.md` - Annotation anchoring techniques
