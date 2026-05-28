# Performance Checklist

## CSS Render Performance

### CSS Property Cost Table

| Property | Triggers Layout | Triggers Paint | Compositor Only |
|---|---|---|---|
| width / height | ✅ | ✅ | ❌ |
| top / left / right / bottom | ✅ | ✅ | ❌ |
| background-color | ❌ | ✅ | ❌ |
| color | ❌ | ✅ | ❌ |
| box-shadow | ❌ | ✅ | ❌ |
| border-radius | ❌ | ✅ | ❌ (when not composited) |
| transform | ❌ | ❌ | ✅ |
| opacity | ❌ | ❌ | ✅ |
| filter (GPU-accelerated) | ❌ | ❌ | ✅ |

### Layer Promotion Triggers

Certain CSS properties force the browser to create a new compositor layer. This is useful for performance, but creates memory overhead.

- `transform: translateZ(0)` or `translate3d`
- `will-change: transform, opacity`
- `backface-visibility: hidden`
- `position: fixed` or `sticky`
- Video or Canvas elements

### will-change Budget Rules

- **Do not** apply `will-change: all`.
- **Do not** apply it to too many elements (layer explosion causes more jank).
- **Apply dynamically:** Add `will-change` via JavaScript when user hovers or begins an interaction, remove it when animation ends.

### CSS contain Guide

Isolate a sub-tree of the DOM to prevent its layout changes from affecting the rest of the document.
- `contain: layout;` — Internal layout does not affect external elements.
- `contain: paint;` — Children cannot paint outside the element's bounds.
- `contain: size;` — Element size can be calculated without checking children.
- `contain: strict;` — Equivalent to `contain: size layout paint`.

### content-visibility: auto Patterns

Great for long lists.
- Set `content-visibility: auto` on the list items (not the parent container).
- ALWAYS provide `contain-intrinsic-size` so the browser knows the rough dimension, avoiding massive scrollbar jumping when items render.

```css
.item {
  content-visibility: auto;
  contain-intrinsic-size: auto 150px;
}
```

### DevTools Layer Panel Workflow

1. Open DevTools > Rendering drawer.
2. Enable "Paint flashing" to see what repaints during interaction.
3. Enable "Layout Shift Regions" to spot reflows.
4. Open the "Layers" panel to see 3D visualization of compositor layers and verify you haven't created too many.

### prefers-reduced-motion Integration

Always respect user accessibility preferences for animations.

```css
@media (prefers-reduced-motion: reduce) {
  *, ::before, ::after {
    animation-duration: 0.01ms !important;
    animation-iteration-count: 1 !important;
    transition-duration: 0.01ms !important;
    scroll-behavior: auto !important;
  }
}
```

---

## CI/CD Optimization Patterns

### Build Optimization

- **Parallel Execution**: Split independent jobs to run in parallel.
- **Matrix Builds**: Test multiple configurations simultaneously with `max-parallel` control.

### Caching Strategies

- **Dependency Caching**: Cache package managers to speed up installs.
- **Build Cache**: Cache compilation outputs (e.g., `target/`, `node_modules/.cache`).

### Docker Optimization

- **Layer Caching**: Order Dockerfile instructions by change frequency.
- **Multi-stage Builds**: Reduce final image size by separating build and runtime environments.

### Artifact Management

- **Upload Optimization**: Use non-zipped artifacts for single files if supported (actions/upload-artifact@v4).
- **Artifact Size Limits**: Monitor and limit artifact sizes to prevent bloat.

### Runner Optimization

- **Custom Images**: Build custom VM images with pre-installed tools for faster, more consistent workflows.
- **Runner Sizing**: Choose appropriate runner sizes (e.g., 2-core for linting, 8-core for integration tests).

### Pipeline Optimization Checklist

- [ ] Enable job parallelization
- [ ] Implement dependency caching
- [ ] Use matrix builds with max-parallel
- [ ] Optimize Docker layer caching
- [ ] Minimize artifact uploads
- [ ] Use appropriate runner sizes
- [ ] Configure concurrency controls
- [ ] Remove unused dependencies
