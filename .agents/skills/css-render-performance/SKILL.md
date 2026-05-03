---
name: css-render-performance
description: >
  Guide CSS render performance analysis and optimization. Use when reviewing or writing
  CSS animations, transitions, scroll-heavy UIs, or long lists where jank, reflow,
  or repaint is a concern. Covers compositor layer promotion, paint vs composite
  properties, will-change budgeting, CSS contain, and content-visibility: auto.
  Invoke when prompts mention: animation jank, scroll performance, will-change,
  content-visibility, CSS contain, reflow, repaint, or compositor layer optimization.
version: "1.0"
template_version: "1.0"
license: MIT
metadata:
  source: jakubkrehel/make-interfaces-feel-better (performance.md seed)
  category: frontend-performance
---

# CSS Render Performance

Guide agents to write CSS and JavaScript that stays on the GPU compositing pipeline,
avoiding expensive layout recalculations and paint operations.

## When to Use

- CSS animations or transitions that feel janky
- Scroll performance issues on long lists or parallax
- Reviewing `will-change` usage (over- or under-applied)
- Using `content-visibility: auto` for virtualized-style rendering
- CSS `contain` for component isolation
- DevTools layer panel auditing

## When NOT to Use

- Pure design/aesthetic tasks with no performance concern
- Backend or server-side rendering optimization
- Network/asset performance (use `pwa-offline-sync` instead)
- General UI layout without animation

## Core Principle: Compositor-Only Properties

Only two CSS properties trigger GPU compositing without layout or paint:
- `transform` (translate, scale, rotate)
- `opacity`

Everything else (`top`, `left`, `width`, `background`, `box-shadow`) triggers layout or paint. **Always animate transform/opacity.**

## Process

### Step 1 — Identify the trigger
Is the jank caused by: layout (reflow), paint, or composite? Use DevTools Performance panel to confirm.

### Step 2 — Apply compositor promotion
See `references/paint-and-composite.md` for the full property cost table and promotion patterns.

### Step 3 — Budget `will-change`
- Apply only to elements that WILL animate (not preemptively to all cards)
- Remove after animation completes if dynamic
- Max 3-5 simultaneously promoted elements per viewport

### Step 4 — Apply `contain` for isolation
```css
.component { contain: layout style paint; }
```
Prevents child changes from triggering parent layout recalculation.

### Step 5 — Apply `content-visibility` for long lists
```css
.list-item {
  content-visibility: auto;
  contain-intrinsic-size: auto 80px; /* estimated item height */
}
```
Browser skips rendering off-screen items entirely.

## Quality Checklist

- [ ] Animations use only `transform` and/or `opacity`
- [ ] `will-change` applied only to elements actively about to animate
- [ ] No more than 5 simultaneously promoted layers
- [ ] Long lists (>100 items) use `content-visibility: auto`
- [ ] Components with self-contained layout use `contain: layout style paint`
- [ ] `prefers-reduced-motion` guard on all animations
- [ ] DevTools composite layer count verified (no layer explosion)

## Best Practices

✓ Animate `transform: translateX()` instead of `left:`
✓ Use `will-change: transform` on elements before animation starts, remove after
✓ Apply `contain: strict` to isolated widget components
✓ Use `content-visibility: auto` on list items, not parent containers
✘ Never apply `will-change: all`
✘ Never `will-change` static or rarely-animated elements
✘ Don't nest `content-visibility: auto` containers

## Cross-Skill Integration

| Skill | Integration |
|---|---|
| `ui-ux-optimize` | Browser Verifier agent — passes render audit results |
| `anti-ai-slop` | Gradient backgrounds cause expensive paint — surface layering is cheaper |
| `pwa-offline-sync` | Offline-first UIs need performant rendering for low-power devices |
| `reader-ui-ux` | Long reading UIs benefit from `content-visibility: auto` on paragraphs |

## Reference Files

| File | Purpose |
|---|---|
| `references/paint-and-composite.md` | Full property cost table, layer promotion patterns, DevTools workflow |
