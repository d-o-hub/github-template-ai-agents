# CSS Render Performance: Virtualized List Jank Diagnosis

## Current Status
- **List size**: 5000 items
- **Applied**: `content-visibility: auto`
- **Problem**: Still experiencing scroll jank

## Decision Flowchart Analysis

Per the decision flowchart:

```
Is the element animating?
└── No → Is it in a scrollable container?
    ├── Yes → Apply content-visibility: auto (DONE)
    └── No → Check for unnecessary repaints on state changes
```

Since `content-visibility: auto` is already applied, you need to investigate **other performance bottlenecks**. Here's what to check:

---

## 1. Verify `contain-intrinsic-size` is Set

**Critical**: Without this, the browser can't calculate scroll height properly, causing massive scrollbar jumping.

```css
.item {
  content-visibility: auto;
  contain-intrinsic-size: auto 150px; /* height per item */
}
```

**Check**: Are all list items using `contain-intrinsic-size: auto <height>`? Missing this is the #1 cause of remaining jank after adding `content-visibility`.

---

## 2. Check for Layout-Triggering Properties in Scroll Handlers

Look at your scroll event listeners and any properties being animated during scroll:

**Properties that trigger layout (AVOID in scroll handlers):**
- `width`, `height`
- `top`, `left`, `right`, `bottom`
- `margin`, `padding`, `border`
- `display`, `position`, `flex`, `grid`

**Safe properties (composite-only):**
- `transform`
- `opacity`

**Refactor pattern:**
```javascript
// ❌ BAD - triggers layout every frame
element.style.top = `${scrollY}px`;
element.style.height = `${newHeight}px`;

// ✅ GOOD - compositor only, no layout
element.style.transform = `translateY(${scrollY}px)`;
```

---

## 3. Audit `will-change` Usage

**Rule**: Max 2-3 elements simultaneously using `will-change`.

Check for:
- `will-change: all` — NEVER use this
- Multiple elements with `will-change: transform` or `will-change: opacity`

**Fix**: Apply `will-change` dynamically via JavaScript on hover/interaction, remove after:
```javascript
element.addEventListener('mouseenter', () => {
  element.style.willChange = 'transform';
});
element.addEventListener('transitionend', () => {
  element.style.willChange = 'auto';
});
```

---

## 4. Add CSS Containment to Items

Isolate each list item to prevent layout/paint scope from bleeding:

```css
.item {
  content-visibility: auto;
  contain-intrinsic-size: auto 150px;
  contain: layout paint; /* isolate DOM subtree */
}
```

**Containment levels:**
- `contain: layout` — Internal layout doesn't affect external elements
- `contain: paint` — Children can't paint outside bounds
- `contain: size` — Size calculated without checking children
- `contain: strict` — All three combined

---

## 5. Profile with Chrome DevTools

Use the **Performance tab** while scrolling:

1. **Check for Long Frames** (>16ms = jank)
2. **Enable Paint Flashing** (Rendering drawer) — see what repaints during scroll
3. **Enable Layout Shift Regions** — spot reflows
4. **Open Layers panel** — verify you haven't created too many compositor layers

**Key things to look for:**
- Layout recalculation in scroll handlers
- Paint operations > 2ms
- Excessive layer count (>200-300 layers)

---

## 6. Test on Throttled CPU

Developer hardware is faster than user devices:

1. Chrome DevTools → Performance tab
2. Click gear icon → CPU: 4x slowdown
3. Repeat scroll test

If jank appears on throttled CPU but not your machine, you've found the issue.

---

## 7. Check for Unnecessary Repaints on State Changes

Look for:
- Class toggles that change paint-triggering properties (`background-color`, `color`, `box-shadow`, `border-radius`)
- Hover effects on multiple items simultaneously
- Intersection Observer callbacks that trigger layout

**Fix**: Use `contain` on parent containers to limit repaint scope.

---

## 8. Consider Virtualization Library

If CSS-only optimization isn't sufficient for 5000 items, use a virtualization library:
- React: `react-window`, `react-virtualized`
- Vue: `vue-virtual-scroller`
- Vanilla: `virtual-scroller`

These render only visible items (~20-50) instead of relying on `content-visibility` to skip rendering.

---

## Quick Checklist

- [ ] All items have `contain-intrinsic-size: auto <height>`
- [ ] No layout-triggering properties in scroll handlers
- [ ] `will-change` used on max 2-3 elements
- [ ] Each item has `contain: layout paint`
- [ ] Profiled with DevTools Performance tab (no Long Frames)
- [ ] Tested on 4x CPU throttling
- [ ] Paint flashing shows no unnecessary repaints
- [ ] Layer count is reasonable (<300)

## Gotchas to Watch For

- `content-visibility: auto` with wrong `contain-intrinsic-size` causes scrollbar jumping
- `will-change: all` on many elements wastes GPU memory and causes mobile jank
- `transform: translateZ(0)` on a parent promotes ALL children — unexpected memory usage
- Animating `width`/`height` triggers layout EVERY frame — use `transform: scale()` instead

---

*Based on `css-render-performance` skill v0.2.10 and `performance-checklist.md`*
