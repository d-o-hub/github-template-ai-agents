---
name: ui-ux-optimize
description: >
  Swarm-powered UI/UX prompt optimizer with auto-research agents, handoff coordination,
  confidence-scored autoresearch loops, and backpressure quality gates. Use this skill when optimizing UI/UX for web apps, mobile apps, games, dashboards, SaaS, e-commerce, kiosks, or any screen-based product.
version: "0.2.10"
category: ui-ux
license: MIT
---

# UI/UX Prompt Optimizer

## Compliance Mandate

You are operating as a **constrained design executor**, not a free creative agent, once tokens are frozen.

- Style decisions not listed in the project Token Scaffold: **FORBIDDEN** after Phase 2.
- Font substitution mid-session: **FORBIDDEN**.
- Color variation ("similar to...", "a shade of..."): **FORBIDDEN** after freeze.
- Inventing new token names not in the scaffold: **FORBIDDEN**.
- When a required token category is missing: output a warning and ask the user — do NOT infer a value.
- Before Phase 2: full creative freedom to research and propose. After Phase 2 freeze: zero discretion.
- **FREEZE ENFORCEMENT**: `scripts/validate-tokens.cjs` programmatically enforces the freeze. Any attempt to modify a locked token after its initial commit will cause a validation failure.

Swarm-powered skill for generating implementation-ready UI/UX prompts. Uses a **swarm of 7 specialized agents** with handoff coordination, an **autoresearch loop** (try → score → keep/revert → repeat), and **backpressure quality gates** to converge on high-quality output.

## When to Use

- UI/UX design help, redesign, or critique for any digital product
- Prompt optimization for a design or coding agent
- A structured design brief from a vague idea
- A design audit of an existing interface
- Variant generation for a design system or component

Supported: web apps, mobile apps, dashboards, admin tools, e-commerce, SaaS, web/mobile games, kiosk/touch UIs, internal tools, prototypes.

## When NOT to Use

- Pure branding (logos, print, identity only)
- Motion graphics or video production
- Backend architecture with no UI component
- Marketing copy without interface context
- Already implementation-ready requests

## Swarm Architecture

7 specialized agents with handoff coordination. Full details → `references/swarm-coordination.md`

```
RESEARCH SCOUT → TOKEN ARCHITECT → LAYOUT ENGINEER → VARIANT GENERATOR → BROWSER VERIFIER → QUALITY AUDITOR
                                    └── ANTI-SLOP SENTINEL (cross-cutting) ──┘
```

| Agent | Domain |
|---|---|
| Research Scout | Domain trends, platform guidelines, competitor analysis |
| Token Architect | Semantic design tokens, typography, color, spacing |
| Layout Engineer | Navigation, screen hierarchy, responsive composition |
| Variant Generator | 3 design variants with shared tokens + override diffs |
| Browser Verifier | Playwright screenshots, overlap detection, tap targets |
| Quality Auditor | Review checklist scoring, confidence, lessons |
| Anti-Slop Sentinel | Cross-cutting: translates vague language, detects AI patterns |

## Autoresearch Loop

Inspired by pi-autoresearch: try → measure → keep/revert → repeat until score stabilizes.

1. Run full swarm pipeline
2. Quality Auditor scores with confidence (MAD-based)
   - Game products: 0–66 (all 10 sections), threshold 60
   - Non-game products: 0–57 (9 sections, game-specific N/A), threshold 52
   - Use **effective percentage** (score/max_applicable) for keep decision
3. Effective ≥ 91% AND confidence ≥ 2.0× → **KEEP**
4. Effective < 91% OR confidence < 1.0× → **REVISE** (re-run weak agent downstream)
5. Score regresses → **REVERT** (discard, try different approach)
6. Max 5 iterations per session

Full details → `references/swarm-coordination.md`

## Session Files

Two files persist across runs (matching pi-autoresearch pattern):
- `ui-ux-session.md` — living document: objective, what's been tried, key wins, dead ends
- `ui-ux-session.jsonl` — append-only log: one JSON line per iteration

These files are for developer-led regression testing:
- `evals/golden-tokens.json` — Reference token snapshot: the canonical correct tokens for regression testing.
- `evals/eval-prompt.md` — The exact prompt that produced the golden output.

> Before submitting output, compare against `evals/golden-tokens.json` if it exists.
> If your output deviates in color, font, spacing, or radius from the frozen tokens, revise before responding.

## Gotchas

These failure modes recur across sessions. Keep as quick-reference.

- **AI Slop gravity:** Agents default to Inter, purple gradients, three-column feature grids. Override explicitly with opinionated font choices and precedent products.
- **Mobile horizontal overflow:** Horizontal nav/lists break on mobile <768px. Always enforce `overflow-x-auto` for horizontal navigation, `overflow-x-hidden` on root container.
- **Z-Index wars:** Absolute positioning for core layout causes overlapping elements. Enforce flow-based layouts (Flexbox/Grid). Absolute only for HUDs/overlays with defined safe zones.
- **Flickering transitions:** State transitions without presence guards flicker. Use `AnimatePresence` with `mode="wait"` and `initial={false}`. High-motion elements need `will-change-transform transform-gpu backface-visibility-hidden`.
- **Scrollbar jitter:** Unstable scrollbars cause layout shifts between viewports. Enforce `overflow-x-hidden` on root, `overflow-y-auto` for content containers.
- **Nested scroll contexts:** `min-h-screen` in sub-components inside scrollable parents creates double scrollbars. Use `min-h-full` for sub-components.

## Token Scaffold (Populated in Phase 2, Frozen for All Subsequent Phases)

Before any code or prompt is generated, the Token Architect MUST define and commit all of the following categories to `docs/design/design-tokens.json` (W3C Design Tokens format). Values are chosen by the model based on project context and research — but once written, they are FROZEN for the session.

**Required categories:**

| Category | Required keys |
|---|---|
| `colors` | `primary`, `background`, `surface`, `text_primary`, `text_muted`, `accent`, `error`, `success` |
| `typography` | `font_family`, `scale_px[]`, `weight{}`, `line_height{}` |
| `spacing` | `unit` (must be 4 or 8), `gutter` |
| `radius` | `sm`, `md`, `lg`, `pill` |
| `shadow` | single string value |
| `breakpoints` | `[mobile, tablet, desktop, wide]` as px values |
| `effects` | `antiFlicker` string |

**FREEZE RULE:** Once written to `docs/design/design-tokens.json`, no token value may change without an explicit user instruction in the chat. All phases read from this file — never re-invent.

**CREATIVE FREEDOM:** The actual values are fully up to the model's judgment based on:
- Research Scout findings (domain trends, competitor patterns)
- Anti-Slop Sentinel translation (what "premium" or "minimal" actually means for this product)
- Platform guidelines (iOS HIG, Material 3, game genre conventions, etc.)

## Required Workflow

Run every step. Swarm coordinates handoffs.

### Phase 1: Research & Translate

**Step 0 — Research Scout: Auto-Research.** Research domain trends, platform guidelines, competitor patterns via `websearch`. Handoff → `research_context`. See → `references/auto-research.md`

**Step 1 — Anti-Slop Sentinel: Translate.** Convert vague words to measurable constraints. Cross-ref `anti-ai-slop` skill. Handoff → `anti_slop_warnings`. See → `references/anti-slop-rules.md`

### Phase 2: Token & Structure

**Step 2 — Token Architect: Build & Freeze Tokens.**
1. **If `docs/design/design-tokens.json` exists:** READ it — do NOT modify unless the user explicitly instructs an override.
2. **If it does not exist:** Populate all Token Scaffold categories creatively based on `research_context` and `anti_slop_warnings`. Write to `docs/design/design-tokens.json`.
3. **DIFF check:** For any proposed style value, compare against the local `docs/design/design-tokens.json`. Reject divergence — output a warning listing the conflicting value and revert to the frozen token.
4. **NEVER** generate new token category names outside the scaffold.
5. Handoff → `design_tokens`. See → `references/design-tokens.md`

**Step 3 — Layout Engineer: Navigation & Composition.** Nav model, screen map, responsive spec. See → `references/navigation-clarity.md`, `references/layout-composition.md`

**Step 3a — Game Layer** *(skip if not game).* HUD, menus, safe zones. See → `references/game-ui-rules.md`

### Phase 3: Generate & Verify

**Step 4 — Coordinator: Assemble Prompt.** See → `templates/optimize-prompt-template.md`
- Copy the frozen Token Scaffold keys as a comment header into every generated file.
- Reference only token keys — never raw values — in component code.
- Output must include responsive styles for all four breakpoints defined in `breakpoints` token.

**Step 4a — Sync Code.** Run `node .agents/skills/ui-ux-optimize/scripts/sync-tokens.cjs` to generate `src/lib/design-system.tsx` from your JSON tokens. Never edit the `.tsx` file directly.

**Step 5 — Variant Generator: 3 Variants.** Default: editorial/product/expressive. Game: immersive/competitive/minimal-hud. See → `references/variant-worktree-flow.md`

**Step 6 — Layout Engineer: Safety Audit.** Overlap, wrapping, truncation at all breakpoints. Fill `templates/design-audit-template.md`.

**Step 6a — Token Validation (pre-check).** Run `node .agents/skills/ui-ux-optimize/scripts/validate-tokens.cjs` to fast-fail if `docs/design/design-tokens.json` or `src/lib/design-system.tsx` are missing or misaligned. Fix before browser verification.

**Step 6b — Browser Verifier: Screenshots** *(when HTML available).* Playwright at 375/768/1024/1440px. If no HTML prototype exists, **SKIP** with a `browser_verification.status: "SKIPPED"` note describing what would be verified. See → `references/browser-verification.md`

### Phase 4: Audit & Learn

**Step 7 — Anti-Slop Sentinel: Final Audit.** No banned words remain.

**Step 8 — Quality Auditor: Score & Gate.** Score against checklist (0–66). See → `references/review-checklist.md`

**Step 9 — Quality Auditor: Record Lessons.** Append to session files. See → `references/self-learning-loop.md`

## Quality Bar

- Navigation defined before aesthetics
- No vague adjectives in optimized prompt
- All token roles have semantic names
- Layouts pass overlap check at all breakpoints
- Anti-slop audit passed
- Confidence ≥ 2.0× (or marginal flag)
- Lessons recorded in session files

## Cross-Skill Integration

| Skill | Integration |
|---|---|
| `web-search-researcher` | Research Scout — deep research |
| `anti-ai-slop` | Anti-Slop Sentinel — pattern detection |
| `agent-coordination` | Swarm orchestration |
| `iterative-refinement` | Autoresearch loop |
| `parallel-execution` | Parallel variant generation |

## References

| File | Purpose |
|---|---|
| `references/swarm-coordination.md` | Swarm architecture, handoff protocol, agent contracts |
| `references/auto-research.md` | Auto-research workflow, search strategies |
| `references/design-tokens.md` | Token categories, naming, semantic structure |
| `references/typography.md` | Role-based type system, text-wrap and tabular numbers |
| `references/animations.md` | Interruptible animations, enter/exit transitions |
| `references/color-system.md` | Restrained palettes, contrast rules |
| `references/layout-composition.md` | Layout rhythm, density, hierarchy |
| `references/navigation-clarity.md` | Navigation models, labels, cross-screen rules |
| `references/responsive-screen-rules.md` | Per-breakpoint behavior, no-overlap validation |
| `references/game-ui-rules.md` | HUD, controls, safe zones, menu systems |
| `references/anti-slop-rules.md` | Banned phrases, banned clichés |
| `references/prompt-patterns.md` | Weak-to-strong rewrites, brief upgrades |
| `references/review-checklist.md` | Pass/fail quality checks (0–66 scoring) |
| `references/self-learning-loop.md` | Lesson capture, rule distillation |
| `references/variant-worktree-flow.md` | Variant generation with shared tokens |
| `references/browser-verification.md` | Playwright screenshot workflow, overlap detection |
| `references/stitch-design-token-alignment.md` | Design-first workflow, token DNA normalization |
| `templates/optimize-prompt-template.md` | Structured prompt assembly template |
| `templates/design-audit-template.md` | Fill-in audit checklist for Step 6 |

## Scripts

| Script | Purpose |
|---|---|
| `scripts/validate-tokens.cjs` | Fast-fail: checks design docs + TOKENS export exist |
| `scripts/check-output.cjs` | Eval assertion: contains/not_contains for code output |
| `scripts/verify.py` | Browser verification: overlap, tap targets, scroll audit |

## See Also

- `anti-ai-slop` — Avoid AI slop in UI/UX
- `css-render-performance` — CSS render performance optimization

## Rationalizations

| Rationalization | Reality |
|-----------------|---------|
| "I can skip the token freeze and just eyeball it" | Without frozen tokens, visual drift accumulates silently across components and sessions. |
| "Research Scout is optional for a simple UI" | Even simple UIs benefit from domain context; skipping research leads to generic slop. |
| "The autoresearch loop takes too long, ship the first draft" | First drafts rarely converge on quality; the loop exists to catch regressions before users do. |

## Red Flags

- [ ] Token scaffold modified after Phase 2 freeze
- [ ] Anti-slop audit skipped to save time
- [ ] Variants generated without shared token foundation
