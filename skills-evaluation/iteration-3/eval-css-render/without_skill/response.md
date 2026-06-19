# CSS Render Performance: Virtualized List Scroll Jank

## Diagnosis Checklist (After `content-visibility: auto`)

You've already taken the first step with `content-visibility: auto`. Here's what else to check:

### 1. Compositor Layer Promotion
Items may not be on their own compositor layers, causing repaints to propagate.

**Check:** Do list items have `will-change: transform` or `transform: translateZ(0)`?
```css
.list-item {
  will-change: transform;
  /* or */
  transform: translateZ(0);
}
```

### 2. Paint Complexity
Even with containment, expensive paint operations cause jank.

**Check for:**
- Large `box-shadow` with blur radius
- `filter: blur()`, `drop-shadow()`
- Complex `border-radius` on large areas
- Gradient backgrounds on large elements
- `text-shadow` on many elements

**Fix:** Simplify or move to compositable-only effects (opacity, transform).

### 3. Forced Synchronous Layouts
JavaScript reading layout properties after DOM writes triggers forced reflow.

**Check:** Are you reading `offsetHeight`, `getBoundingClientRect()`, `clientWidth` during scroll handlers?

**Fix:** Batch reads before writes, or use `requestAnimationFrame`.

### 4. CSS Containment Strength
`content-visibility: auto` optimizes rendering, but stronger containment may help.

**Check:** Should you add explicit containment?
```css
.list-item {
  contain: layout style paint;
  content-visibility: auto;
}
```

### 5. Intersection Observer Optimization
Virtualized lists should use IntersectionObserver to lazy-load content, not scroll events.

**Check:** Are you using `IntersectionObserver` to detect visible items, or manual scroll calculations?

### 6. Layout Thrashing in Scroll Handler
Multiple DOM writes per frame cause layout thrashing.

**Check:** Is your scroll handler doing layout-triggering operations?
```javascript
// BAD: triggers layout each iteration
items.forEach(item => {
  item.style.transform = `translateY(${scrollY}px)`;
});

// BETTER: batch with requestAnimationFrame
requestAnimationFrame(() => {
  items.forEach(item => {
    item.style.transform = `translateY(${scrollY}px)`;
  });
});
```

### 7. Expensive Selectors
Complex CSS selectors slow style recalculation.

**Check:** Avoid deep descendant selectors, attribute selectors with wildcards, `:has()` on large trees.

### 8. Repaint Boundaries
Ensure paint is contained to individual items, not parent containers.

**Check:** Use browser DevTools > Layers panel to verify items are separate paint layers.

---

## Priority Order

1. Verify `content-visibility: auto` is actually working (check DevTools Performance panel)
2. Add compositor layer promotion (`will-change: transform`)
3. Simplify paint operations (shadows, filters)
4. Eliminate forced synchronous layouts
5. Add stronger CSS containment if needed
6. Ensure IntersectionObserver for virtualization

## Quick Test

Open Chrome DevTools > Performance > Record while scrolling. Look for:
- Long "Recalculate Style" events
- "Update Layer Tree" taking > 4ms
- "Paint" events on scroll frames
- Layout shifts (purple bars in Performance timeline)
