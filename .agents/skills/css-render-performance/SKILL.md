---
name: css-render-performance
version: "0.2.10"
description: Guide CSS render performance analysis and optimization. Use when reviewing or writing CSS animations, transitions, scroll-heavy UIs, or long lists. Covers compositor layer promotion, paint vs composite, and content-visibility.
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

## References

- [Performance Checklist](../../../agents-docs/references/performance-checklist.md) - CSS property cost table, layer promotion triggers, and optimization patterns.
