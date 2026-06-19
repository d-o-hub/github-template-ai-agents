# CSS Render Performance: Virtualized List Jank After `content-visibility: auto`

## Decision Flowchart Analysis

According to the skill's flowchart, your list falls into the "scrollable container" branch. You've already applied `content-visibility: auto` — the recommended action. Since jank persists, the issue is not off-screen rendering but something else in the render pipeline.

## What to Check Next

### 1. CSS Containment (Isolate Layout/Paint Scope)

Each list item should have `contain: layout paint` to limit the browser's layout and paint scope to that item only. Without containment, changing one item can trigger layout recalculation across siblings.

```css
.list-item {
  contain: layout paint;
  content-visibility: auto;
  contain-intrinsic-size: 0 50px; /* match your item height */
}
```

### 2. `will-change` Usage Audit

Check if `will-change` is applied to too many elements. The skill specifies a hard limit of 2-3 elements simultaneously. If each of your 5000 items has `will-change`, the browser wastes GPU memory and causes compositing jank on mobile.

```css
/* BAD - applied to all items */
.list-item { will-change: transform; }

/* GOOD - only the visible/transitioning items */
.visible-item { will-change: transform; }
```

### 3. Layout-Triggering Properties in Animations

Profile with Chrome DevTools Performance tab. Look for Long Frames. Check if scroll handlers or intersection observers are mutating layout-triggering properties:

- `width`, `height`, `top`, `left` → triggers layout every frame
- `background`, `color`, `box-shadow` → triggers paint every frame

If you see these in animations, replace with composite-only properties (`transform`, `opacity`).

### 4. `contain-intrinsic-size` Accuracy

Wrong `contain-intrinsic-size` causes layout shifts as you scroll, forcing the browser to recalculate. Verify the value matches your actual item height.

### 5. Profile on Throttled CPU

Developer hardware masks real jank. Always test on:
- Chrome DevTools → Performance → CPU 4x throttling
- Slow network (3G) to simulate mobile

This reveals whether the bottleneck is layout, paint, or compositing.

### 6. Check for Unnecessary Repaints

Even without animation, scroll events can trigger repaints if:
- `box-shadow` is used on list items
- `border-radius` changes on scroll
- Background images are repainted on visibility changes

## Summary

| Check | Why |
|-------|-----|
| `contain: layout paint` | Isolates each item's layout/paint scope |
| `will-change` budget | Max 2-3 elements; don't apply to all items |
| Layout-triggering properties | `width`/`height` in animations → layout per frame |
| `contain-intrinsic-size` accuracy | Wrong value → layout shifts → recalculation |
| Throttled CPU profiling | Reveals real user experience vs developer hardware |
| Scroll-triggered repaints | `box-shadow`, `background` on scroll → paint cost |

## Red Flags to Watch

- [ ] `will-change` on more than 2-3 elements simultaneously
- [ ] `transform: translateZ(0)` on a parent promoting ALL children (unexpected memory)
- [ ] Animating `width`/`height` instead of `transform: scale()`
- [ ] `content-visibility: auto` without `contain-intrinsic-size`
- [ ] Not profiling on throttled CPU

## References

- Skill: `css-render-performance` (`.claude/skills/css-render-performance/SKILL.md`)
- Performance checklist: `agents-docs/references/performance-checklist.md`
