# CSS Animation Performance Analysis

## Performance Issue

**Yes, there is a performance problem.** Animating `width` and `height` properties triggers **layout (reflow)** on every animation frame.

## Why This Is Bad

The browser rendering pipeline has steps: Layout → Paint → Composite. Animating `width` or `height` forces the browser to:

1. Recalculate layout for the element and potentially its ancestors/siblings
2. Repaint affected pixels
3. Composite layers

This happens **60+ times per second** during the animation, causing:
- High CPU usage
- Dropped frames (jank)
- Battery drain on mobile devices

## Recommended Alternatives

| Instead of | Use |
|------------|-----|
| `width` | `transform: scaleX()` |
| `height` | `transform: scaleY()` |
| Both | `transform: scale()` |

**Example fix:**
```css
/* Bad - triggers layout */
.animate {
  transition: width 0.3s, height 0.3s;
}

/* Good - GPU composited, no layout */
.animate {
  transition: transform 0.3s;
}
.animate:hover {
  transform: scale(1.2);
}
```

## Other Triggering Properties to Avoid

Avoid animating these directly:
- `width`, `height`, `top`, `left`, `margin`, `padding`
- `border-width`, `font-size`, `line-height`

## Safe-to-Animate Properties

- `transform` (GPU-composited)
- `opacity` (GPU-composited)
- `filter` (can be GPU-composited)

## Rule of Thumb

Use the `will-change` hint only when needed and animate only `transform` and `opacity` for smooth 60fps animations.
