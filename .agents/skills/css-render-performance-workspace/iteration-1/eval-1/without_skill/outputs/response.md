# CSS Render Performance: Virtualized List with content-visibility: auto

## Decision Flowchart Checkpoints

When `content-visibility: auto` alone doesn't fix scroll jank, follow these additional checks in order:

### 1. Check Compositor Layer Promotion

**Problem**: Items not promoted to their own GPU layers cause full paint on scroll.

**Fix**: Add `will-change: transform` to list items:
```css
.list-item {
  will-change: transform;
}
```

**Verify**: Open DevTools → Layers panel. Each visible item should show as a separate compositor layer.

### 2. Check Paint vs Composite Properties

**Problem**: Animating layout/paint properties during scroll forces main thread work.

**Forbidden during scroll**:
- `width`, `height`, `top`, `left`, `margin`, `padding`
- `box-shadow`, `border-radius`, `background-image`
- `filter`, `clip-path`

**Allowed (composite-only)**:
- `transform`
- `opacity`

**Fix**: Replace any scroll-triggered animations with `transform: translate3d()` or `opacity`.

### 3. Check `contain` Property

**Problem**: `content-visibility: auto` alone doesn't fully isolate rendering.

**Fix**: Add containment to list items:
```css
.list-item {
  contain: layout style paint;
  content-visibility: auto;
}
```

**Why**: `contain` tells the browser the element's internals don't affect outside layout, enabling more aggressive optimization.

### 4. Check for Oversized content-visibility: auto

**Problem**: `content-visibility: auto` has overhead per-element for small items (< ~500px height).

**If items are small**:
```css
.list-item {
  content-visibility: hidden; /* Skip rendering entirely for off-screen */
}
```

**If items are large** (tall cards, complex layouts):
```css
.list-item {
  content-visibility: auto;
  contain-intrinsic-size: 0 500px; /* Estimated height */
}
```

### 5. Check Scroll Container Optimization

**Problem**: The scroll container itself may be causing jank.

**Fix**:
```css
.scroll-container {
  overflow-y: auto;
  will-change: scroll-position; /* Promote scroll container */
  overscroll-behavior: contain; /* Prevent scroll chaining */
}
```

**Avoid**:
```css
.scroll-container {
  /* DON'T DO THIS */
  scroll-behavior: smooth; /* Adds JS overhead per frame */
}
```

### 6. Check for Expensive Selectors

**Problem**: Complex CSS selectors cause O(n²) matching during style recalc.

**Bad**:
```css
.list > div:nth-child(odd) .content > p:first-of-type { ... }
```

**Good**:
```css
.list-item { ... }
```

**Verify**: DevTools → Performance →录制 → look for "Recalculate Style" events > 1ms.

### 7. Check for Forced Synchronous Layouts

**Problem**: JavaScript reading layout properties forces main thread to compute layout immediately.

**Forbidden reads during scroll**:
- `offsetHeight`, `offsetWidth`
- `getBoundingClientRect()`
- `getComputedStyle()` on layout-triggering properties

**Fix**: Use `requestAnimationFrame` for any JS that reads layout:
```javascript
let ticking = false;
scrollContainer.addEventListener('scroll', () => {
  if (!ticking) {
    requestAnimationFrame(() => {
      // Safe to read layout here
      ticking = false;
    });
    ticking = true;
  }
});
```

### 8. Check for Excessive DOM Nodes

**Problem**: Even with virtualization, too many DOM nodes cause style/layout overhead.

**Rule of thumb**: > 1500 DOM nodes causes measurable slowdown.

**Fix**:
- Ensure virtualization actually removes off-screen nodes from DOM
- Don't use `visibility: hidden` as virtualization — use `display: none` or DOM removal

## Quick Diagnostic Checklist

| Check | DevTools Method | Target |
|-------|-----------------|--------|
| Layer count | Layers panel | < 50 visible layers |
| Paint time | Performance → Paint | < 1ms per frame |
| Style recalc | Performance → Recalculate Style | < 2ms per frame |
| Layout thrashing | Performance → Layout | < 1ms per frame |
| DOM nodes | Elements → DOM count | < 1500 total |

## Recommended Order of Fixes

1. Add `contain: layout style paint` to items
2. Ensure only `transform`/`opacity` animate during scroll
3. Add `will-change: transform` to items
4. Verify virtualization removes DOM nodes (not just hides)
5. Check for forced synchronous layouts in JS
6. Profile with `content-visibility: hidden` vs `auto`
