---
name: ui-ux-optimize
description: >
  Swarm-powered UI/UX prompt optimizer with auto-research agents, handoff coordination,
  confidence-scored autoresearch loops, and backpressure quality gates. Use this skill when optimizing UI/UX for web apps, mobile apps, games, dashboards, SaaS, e-commerce, kiosks, or any screen-based product — even if they just say "improve the UI" or "optimize the UX" or "make it sound human" or "this feels robotic". Not for css-render-performance.
version: "0.3.0"
category: ui-ux
license: MIT
---

# UI/UX Prompt Optimizer

## Compliance Mandate

You are a **constrained design executor** once tokens are frozen.

- Style/Font/Color decisions not in Token Scaffold: **FORBIDDEN** after Phase 2.
- Missing required token category: warn and ask user — do NOT infer.
- Before Phase 2: full creative freedom. After Phase 2 freeze: zero discretion.
- **FREEZE ENFORCEMENT**: `scripts/validate-tokens.cjs` enforces the freeze programmatically.

Swarm-powered skill for generating implementation-ready UI/UX prompts. Uses **7 specialized agents**, an **autoresearch loop** (try → score → keep/revert → repeat), and **backpressure quality gates**.

## When to Use

- UI/UX design help, redesign, or critique for any digital product
- Prompt optimization for a design or coding agent
- A structured design brief from a vague idea
- A design audit or variant generation for a design system

Supported: web apps, mobile apps, dashboards, admin tools, e-commerce, SaaS, games, kiosk/touch UIs, prototypes.

## When NOT to Use

- Pure branding (logos, print, identity only)
- Motion graphics or video production
- Backend architecture with no UI component
- Marketing copy without interface context

## Anti-AI-Slop Guide

Systematic antidote for generic AI patterns in UI, UX, and copy.
**Modes:** (1) Audit existing UI, (2) Creation (read rules first), (3) Spot-fix one element.
Always **name the sin** before fixing. Full pattern tables → `references/anti-slop-guide.md`
and `references/anti-slop-rules.md`. Doctrine: specificity over universality; constraints
create identity; undo over confirm.

## Swarm Architecture

7 specialized agents. Full details → `references/swarm-coordination.md`

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

Try → measure → keep/revert → repeat. Full details → `references/swarm-coordination.md`

1. Run full swarm pipeline
2. Quality Auditor scores (MAD-based): Game 0–66, Non-game 0–57. Use **effective percentage** (score/max_applicable).
3. Effective ≥ 91% AND confidence ≥ 2.0× → **KEEP**
4. Effective < 91% OR confidence < 1.0× → **REVISE**
5. Score regresses → **REVERT**
6. Max 5 iterations per session

## Session Files

- `ui-ux-session.md` — living document: objective, wins, dead ends
- `ui-ux-session.jsonl` — append-only log: one JSON line per iteration

Compare against `evals/golden-tokens.json` if it exists. Revise if output deviates.

## Gotchas

- **AI Slop gravity:** Agents default to Inter, purple gradients, three-column grids. Override with opinionated font choices.
- **Mobile horizontal overflow:** Nav/lists break on <768px. Enforce `overflow-x-auto` on horizontal nav, `overflow-x-hidden` on root.
- **Z-Index wars:** Use Flexbox/Grid for layout; absolute only for HUDs/overlays.
- **Flickering transitions:** Use `AnimatePresence` with `mode="wait"` and `initial={false}`.
- **Scrollbar jitter / Nested scroll:** Use `overflow-x-hidden` on root, `min-h-full` for sub-components.

## Token Scaffold (Phase 2, Frozen for All Subsequent Phases)

Define and commit all categories to `docs/design/design-tokens.json` (W3C Design Tokens format). FROZEN once written.

| Category | Required keys |
|---|---|
| `colors` | `primary`, `background`, `surface`, `text_primary`, `text_muted`, `accent`, `error`, `success` |
| `typography` | `font_family`, `scale_px[]`, `weight{}`, `line_height{}` |
| `spacing` | `unit` (4 or 8), `gutter` |
| `radius` | `sm`, `md`, `lg`, `pill` |
| `shadow` | single string value |
| `breakpoints` | `[mobile, tablet, desktop, wide]` as px values |
| `effects` | `antiFlicker` string |

**FREEZE RULE:** No token value may change without explicit user instruction. All phases read from this file.

**CREATIVE FREEDOM:** Values up to model's judgment based on Research Scout findings, Anti-Slop Sentinel translation, and platform guidelines.

## Required Workflow

Run every step. Swarm coordinates handoffs.

### Phase 1: Research & Translate

**Step 0 — Research Scout: Auto-Research.** Domain trends, platform guidelines, competitor patterns via `websearch`. Handoff → `research_context`. See → `references/auto-research.md`

**Step 1 — Anti-Slop Sentinel: Translate.** Convert vague words to measurable constraints. Handoff → `anti_slop_warnings`. See → `references/anti-slop-rules.md`

### Phase 2: Token & Structure

**Step 2 — Token Architect: Build & Freeze Tokens.** If `docs/design/design-tokens.json` exists, READ only. Otherwise populate categories from `research_context` and `anti_slop_warnings`. DIFF check against frozen tokens. Handoff → `design_tokens`. See → `references/design-tokens.md`

**Step 3 — Layout Engineer.** Nav model, screen map, responsive spec. See → `references/navigation-clarity.md`, `references/layout-composition.md`. Game Layer *(skip if not game)*: HUD, menus, safe zones. See → `references/game-ui-rules.md`

### Phase 3: Generate & Verify

**Step 4 — Coordinator: Assemble Prompt.** Copy frozen Token Scaffold keys as comment header into every generated file. Reference only token keys — never raw values. Include responsive styles for all four breakpoints.

**Step 4a — Sync Code.** Run `node .agents/skills/ui-ux-optimize/scripts/sync-tokens.cjs` to generate `src/lib/design-system.tsx`. Never edit the `.tsx` file directly.

**Step 5 — Variant Generator: 3 Variants.** Default: editorial/product/expressive. Game: immersive/competitive/minimal-hud. See → `references/variant-worktree-flow.md`

**Step 6 — Layout Engineer: Safety Audit.** Overlap, wrapping, truncation at all breakpoints.

**Step 6a — Token Validation.** Run `node .agents/skills/ui-ux-optimize/scripts/validate-tokens.cjs` to fast-fail if tokens or design system are misaligned.

**Step 6b — Browser Verifier** *(when HTML available).* Playwright at 375/768/1024/1440px. If no HTML, **SKIP**. See → `references/browser-verification.md`

### Phase 4: Audit & Learn

**Step 7 — Anti-Slop Sentinel: Final Audit.** No banned words remain.

**Step 8 — Quality Auditor: Score & Gate.** Score against checklist (0–66). See → `references/review-checklist.md`

**Step 9 — Record Lessons.** Append to session files. See → `references/self-learning-loop.md`

## Quality Bar

- Navigation defined before aesthetics, no vague adjectives, semantic token names
- Layouts pass overlap check at all breakpoints, anti-slop audit passed
- Confidence ≥ 2.0× (or marginal flag), lessons recorded in session files

## Cross-Skill Integration

| Skill | Integration |
|---|---|
| `web-search-researcher` | Research Scout — deep research |
| `agent-coordination` | Swarm orchestration, parallel variant generation |
| `iterative-refinement` | Autoresearch loop |

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
| `references/anti-slop-rules.md` | Banned phrases and clichés |
| `references/prompt-patterns.md` | Weak-to-strong rewrites, brief upgrades |
| `references/review-checklist.md` | Pass/fail quality checks (0–66 scoring) |
| `references/self-learning-loop.md` | Lesson capture, rule distillation |
| `references/variant-worktree-flow.md` | Variant generation with shared tokens |
| `references/browser-verification.md` | Playwright screenshot workflow, overlap detection |
| `references/stitch-design-token-alignment.md` | Design-first workflow, token DNA normalization |

## Scripts

| Script | Purpose |
|---|---|
| `scripts/validate-tokens.cjs` | Fast-fail: checks design docs + TOKENS export exist |
| `scripts/check-output.cjs` | Eval assertion: contains/not_contains for code output |
| `scripts/verify.py` | Browser verification: overlap, tap targets, scroll audit |

## See Also

- `css-render-performance` — CSS render performance optimization

## Rationalizations

| Rationalization | Reality |
|-----------------|---------|
| "I can skip the token freeze and just eyeball it" | Without frozen tokens, visual drift accumulates silently across components and sessions. |
| "Research Scout is optional for a simple UI" | Even simple UIs benefit from domain context; skipping research leads to generic slop. |
| "The autoresearch loop takes too long, ship the first draft" | The loop catches regressions before users do; first drafts rarely converge on quality. |

## Red Flags

- [ ] Token scaffold modified after Phase 2 freeze
- [ ] Anti-slop audit skipped to save time
- [ ] Variants generated without shared token foundation
