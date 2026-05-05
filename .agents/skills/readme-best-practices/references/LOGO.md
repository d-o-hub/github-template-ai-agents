# SVG Logo Creation Guide

How to create a professional SVG logo for GitHub README files.

## Logo anatomy

```
+----------------------------------------------------------+
| [icon]  [ACRONYM]                                        |
|         ----------------------------------------         |
|         [full-project-name]  [Lang1] [Lang2] [Tag]       |
+----------------------------------------------------------+
```

**Dimensions:** `viewBox="0 0 320 80"` — use `width="320"` in README `<img>` tag.

---

## Color palette (dark-mode first)

| Role | Value | Usage |
|---|---|---|
| Background start | `#0f172a` | Gradient start (dark navy) |
| Background end | `#1e293b` | Gradient end (slate) |
| Primary accent | `#6366f1` | Indigo — acronym, primary icon |
| Secondary accent | `#06b6d4` | Cyan — gradient end, chips |
| Gradient mid | `#8b5cf6` | Purple — optional midpoint |
| Text muted | `#94a3b8` | Subtitle / project name |
| Divider | `#334155` | Separator line |
| Python chip bg | `#1e3a5f` | Dark blue chip |
| Rust chip bg | `#1c1917` | Dark brown chip |
| LLM chip bg | `#0c2340` | Deep blue chip |

---

## Domain-specific icon ideas

| Domain | Icon suggestion | SVG element |
|---|---|---|
| Web / HTTP resolver | Chain of dots + arrow | `<circle>` + `<line>` cascade |
| CLI tool | `>_` terminal symbol | `<text>` in monospace |
| Rust project | Gear / cog | `<path>` polygon |
| Python | `{py}` or snake | `<text>` or simple `<path>` |
| AI / LLM | Brain nodes, cascade | Connected `<circle>` nodes |
| Database | Stacked cylinders | `<ellipse>` + `<rect>` |
| Cascade resolver | Vertical dots + arrow down | `<circle>` + `<line>` + `<polygon>` |
| Document tool | Doc with lines | `<rect>` + `<line>` elements |

---

## Minimal SVG template

Copy from `assets/logo-template.svg` and customize:

1. Replace `ABC` with your project acronym (2-4 chars)
2. Replace `project-name` with your repo slug
3. Replace the icon group (lines 10-15) with a domain-specific icon
4. Update chip labels and colors to match your tech stack
5. Save as `assets/logo.svg`

---

## Cascade resolver icon (for web-doc-resolver style projects)

```svg
<g transform="translate(18, 16)">
  <!-- Vertical cascade line -->
  <line x1="10" y1="5" x2="10" y2="42" stroke="url(#accent)" stroke-width="2" stroke-dasharray="3 2"/>
  <!-- Provider nodes -->
  <circle cx="10" cy="5"  r="4" fill="#6366f1"/>
  <circle cx="10" cy="16" r="3.5" fill="#7c3aed"/>
  <circle cx="10" cy="27" r="3.5" fill="#0891b2"/>
  <circle cx="10" cy="38" r="3.5" fill="#06b6d4"/>
  <!-- Arrow pointing down -->
  <polygon points="5,40 15,40 10,48" fill="#06b6d4" opacity="0.8"/>
</g>
```

---

## GitHub rendering rules

- **Always** use `<img src="assets/logo.svg" alt="PROJECT logo" width="320"/>` — not inline `<svg>`
- SVG must be in `assets/` folder at repo root, referenced with relative path
- GitHub sanitizes SVGs: `<foreignObject>`, `<script>`, `<use href>` are stripped
- Custom fonts do NOT load — always use system font stacks:
  `font-family="'Segoe UI', system-ui, -apple-system, sans-serif"`
- Keep file under **50KB**
- Test both light and dark mode: GitHub appends `#gh-dark-mode-only` / `#gh-light-mode-only` to `src` for theme variants

---

## Light/dark theme variants

To serve different logos per GitHub theme:

```markdown
<picture>
  <source media="(prefers-color-scheme: dark)" srcset="assets/logo-dark.svg">
  <source media="(prefers-color-scheme: light)" srcset="assets/logo-light.svg">
  <img alt="Project logo" src="assets/logo-dark.svg" width="320">
</picture>
```

Or use the single-file approach with GitHub's URL suffix:
```markdown
<img src="assets/logo.svg#gh-dark-mode-only" alt="logo" width="320"/>
<img src="assets/logo-light.svg#gh-light-mode-only" alt="logo" width="320"/>
```

---

## Checklist

- [ ] ViewBox is `0 0 320 80`
- [ ] Background uses gradient (not solid color)
- [ ] Acronym is 2-4 characters, uses accent gradient fill
- [ ] Subtitle text is the exact repo slug
- [ ] Font family uses system-ui fallback stack
- [ ] No `<foreignObject>`, `<script>`, or external font references
- [ ] File saved as `assets/logo.svg`
- [ ] Tested in GitHub dark mode (preview in browser)
- [ ] File size under 50KB
