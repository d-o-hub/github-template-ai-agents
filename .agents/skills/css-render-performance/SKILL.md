---
name: css-render-performance
version: "0.2.10"
category: code-quality
description: Guide CSS render performance analysis and optimization. Use this skill when reviewing or writing CSS animations, transitions, scroll-heavy UIs, or long lists — even if they just say "this animation is janky" or "optimize the CSS". Covers compositor layer promotion, paint vs composite, and content-visibility.
license: MIT
---

# CSS Render Performance

Guide CSS render performance analysis and optimization for smooth, jank-free user interfaces.

## When to Use

- User asks about CSS animation performance or janky transitions
- Reviewing scroll-heavy UIs or long lists for render performance
- Even if they just say "this animation is janky" or "optimize the CSS"

## Quick Check

- [ ] Profile with Chrome DevTools Performance tab (look for Long Frames)
- [ ] Check which CSS properties trigger layout vs paint vs composite
- [ ] Verify `will-change` is used sparingly (max 2-3 elements simultaneously)
- [ ] Test on throttled CPU (4x) and slow network to simulate user devices
- [ ] Confirm no layout-triggering properties in animations (width, height, top, left)

## Core Concepts

| Phase | What It Does | Cost | CSS Properties That Trigger It |
|-------|-------------|------|-------------------------------|
| **Layout** | Calculate geometry | Expensive | width, height, margin, padding, border, position, display, flex, grid |
| **Paint** | Fill in pixels | Expensive | color, background, box-shadow, visibility, border-radius |
| **Composite** | Layer on GPU | Cheap | transform, opacity |

**Goal**: Animate only composite-layer properties (transform, opacity) to avoid layout and paint.

## Optimization Strategies

### Promote Layers

Force elements onto their own compositing layer for GPU-accelerated animation:

```css
.animated-element {
  transform: translateZ(0); /* or will-change: transform */
}
```

Use `will-change` sparingly — it tells the browser to pre-allocate GPU memory.

### CSS Containment

Isolate DOM sub-trees to limit layout/paint scope:

```css
.card {
  contain: layout paint;
}
```

### Content Visibility

Skip rendering for off-screen content in long lists:

```css
.offscreen-item {
  content-visibility: auto;
  contain-intrinsic-size: 0 500px;
}
```

## Decision Flowchart

```
Is the element animating?
├── Yes → Which property?
│   ├── transform or opacity → ✓ Safe (composite only)
│   ├── width, height, top, left → ✗ Triggers layout — refactor
│   ├── background, color → ⚠ Triggers paint — use contain or promote layer
│   └── Multiple properties → Consider FLIP technique or Web Animations API
└── No → Is it in a scrollable container?
    ├── Yes → Apply content-visibility: auto
    └── No → Check for unnecessary repaints on state changes
```

## Gotchas

- `will-change: all` on many elements wastes GPU memory and causes mobile jank — budget to 2-3 elements max.
- `transform: translateZ(0)` on a parent promotes ALL children — can cause unexpected memory usage.
- Animating `width`/`height` triggers layout for EVERY frame — use `transform: scale()` instead.
- `content-visibility: auto` can cause layout shifts if `contain-intrinsic-size` is wrong.
- Developer hardware is fast — always profile on throttled CPU to see what users experience.

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
- [ ] Not testing on throttled CPU or mobile devices

## References

- [Performance Checklist](../../../agents-docs/references/performance-checklist.md) - CSS property cost table, layer promotion triggers, and optimization patterns.

## See Also

- `ui-ux-optimize` — UI/UX optimization with swarm agents
