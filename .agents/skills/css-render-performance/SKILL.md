---
name: css-render-performance
version: "0.2.10"
category: code-quality
description: Guide CSS render performance analysis and optimization. Use when reviewing or writing CSS animations, transitions, scroll-heavy UIs, or long lists. Covers compositor layer promotion, paint vs composite, and content-visibility.
license: MIT
---

# CSS Render Performance

Guide CSS render performance analysis and optimization for smooth, jank-free user interfaces.

## Core Concepts

- **Layout**: Calculating geometry of elements. Expensive.
- **Paint**: Filling in pixels. Also expensive.
- **Composite**: Layering painted parts. Cheapest (GPU accelerated).

## Optimization Strategies

- **Promote Layers**: Use `transform: translateZ(0)` for elements that animate.
- **Budget will-change**: Apply dynamically via JS, don't use `will-change: all`.
- **CSS Containment**: Use `contain: layout paint` to isolate DOM sub-trees.
- **Content Visibility**: Use `content-visibility: auto` for off-screen content.

## Rationalizations

| Rationalization | Reality |
|-----------------|---------|
| "The UI feels fine on my machine" | Developer hardware is faster than user devices; profile on throttled CPU and slow networks. |
| "will-change: all is safe for animations" | Premature layer promotion wastes GPU memory and causes compositing jank on mobile. |
| "content-visibility doesn't matter for small pages" | Even small pages benefit from skipping paint for off-screen content during scroll. |

## Red Flags

- [ ] Using will-change on too many elements simultaneously
- [ ] Animating layout-triggering properties (width, height, top, left)
- [ ] Ignoring paint and composite costs when adding CSS transitions

## References

- [Performance Checklist](../../../agents-docs/references/performance-checklist.md) - CSS property cost table, layer promotion triggers, and optimization patterns.
