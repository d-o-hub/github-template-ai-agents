---
name: ui-ux-optimize
description: >
  Swarm-powered UI/UX prompt optimizer with auto-research agents, handoff coordination,
  confidence-scored autoresearch loops, and backpressure quality gates. Use for web apps,
  mobile apps, games, dashboards, SaaS, e-commerce, kiosks, and any screen-based product.
---

# UI/UX Prompt Optimizer

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

7 specialized agents with handoff coordination. Full details → `reference/swarm-coordination.md`

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
2. Quality Auditor scores (0–66) with confidence (MAD-based)
3. Score ≥ 60 AND confidence ≥ 2.0× → **KEEP**
4. Score < 60 OR confidence < 1.0× → **REVISE** (re-run weak agent downstream)
5. Score regresses → **REVERT** (discard, try different approach)
6. Max 5 iterations per session

Full details → `reference/swarm-coordination.md`

## Session Files

Two files persist across runs (matching pi-autoresearch pattern):
- `ui-ux-session.md` — living document: objective, what's been tried, key wins, dead ends
- `ui-ux-session.jsonl` — append-only log: one JSON line per iteration

## Required Workflow

Run every step. Swarm coordinates handoffs.

### Phase 1: Research & Translate

**Step 0 — Research Scout: Auto-Research.** Research domain trends, platform guidelines, competitor patterns via `websearch`. Handoff → `research_context`. See → `reference/auto-research.md`

**Step 1 — Anti-Slop Sentinel: Translate.** Convert vague words to measurable constraints. Cross-ref `anti-ai-slop` skill. Handoff → `anti_slop_warnings`. See → `reference/anti-slop-rules.md`

### Phase 2: Token & Structure

**Step 2 — Token Architect: Build Tokens.** Semantic token system from research + translated language. Handoff → `design_tokens`. See → `reference/design-tokens.md`

**Step 3 — Layout Engineer: Navigation & Composition.** Nav model, screen map, responsive spec. See → `reference/navigation-clarity.md`, `reference/layout-composition.md`

**Step 3a — Game Layer** *(skip if not game).* HUD, menus, safe zones. See → `reference/game-ui-rules.md`

### Phase 3: Generate & Verify

**Step 4 — Coordinator: Assemble Prompt.** See → `templates/optimize-prompt-template.md`

**Step 5 — Variant Generator: 3 Variants.** Default: editorial/product/expressive. Game: immersive/competitive/minimal-hud. See → `reference/variant-worktree-flow.md`

**Step 6 — Layout Engineer: Safety Audit.** Overlap, wrapping, truncation at all breakpoints.

**Step 6a — Browser Verifier: Screenshots** *(when HTML available).* Playwright at 375/768/1024/1440px. See → `reference/browser-verification.md`

### Phase 4: Audit & Learn

**Step 7 — Anti-Slop Sentinel: Final Audit.** No banned words remain.

**Step 8 — Quality Auditor: Score & Gate.** Score against checklist (0–66). See → `reference/review-checklist.md`

**Step 9 — Quality Auditor: Record Lessons.** Append to session files. See → `reference/self-learning-loop.md`

## Required Outputs

| Field | Content |
|---|---|
| `research_context` | Domain trends, platform guidelines, competitor patterns |
| `optimized_prompt` | Full implementation-ready prompt |
| `design_tokens_summary` | Token architecture with semantic roles |
| `product_ui_mode` | Classified interface model |
| `navigation_model` | Navigation type and screen hierarchy |
| `screen_or_state_map` | All key screens or states |
| `responsive_behavior_summary` | Per-breakpoint layout behavior |
| `anti_slop_warnings` | What was removed or translated |
| `layout_risk_flags` | Overlap, wrapping, or truncation risks |
| `variant_plan` | Variant names, rationale, diff summaries |
| `implementation_notes` | Agent-ready constraints |
| `lessons_learned` | What improved, confused, or harmed this run |
| `improvement_rules` | Reusable rules derived from lessons |
| `browser_verification` | Screenshots + overlap/nav-wrap/tap-target results |
| `quality_score` | Score out of 66, confidence multiplier |

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

## Reference Files Index

| File | Purpose |
|---|---|
| `reference/swarm-coordination.md` | Swarm architecture, handoff protocol, agent contracts |
| `reference/auto-research.md` | Auto-research workflow, search strategies |
| `reference/design-tokens.md` | Token categories, naming, semantic structure |
| `reference/typography.md` | Role-based type system, wrapping safety |
| `reference/color-system.md` | Restrained palettes, contrast rules |
| `reference/layout-composition.md` | Layout rhythm, density, hierarchy |
| `reference/navigation-clarity.md` | Navigation models, labels, cross-screen rules |
| `reference/responsive-screen-rules.md` | Per-breakpoint behavior, no-overlap validation |
| `reference/game-ui-rules.md` | HUD, controls, safe zones, menu systems |
| `reference/anti-slop-rules.md` | Banned phrases, banned clichés |
| `reference/prompt-patterns.md` | Weak-to-strong rewrites, brief upgrades |
| `reference/review-checklist.md` | Pass/fail quality checks (0–66 scoring) |
| `reference/self-learning-loop.md` | Lesson capture, rule distillation |
| `reference/variant-worktree-flow.md` | Variant generation with shared tokens |
| `reference/browser-verification.md` | Playwright screenshot workflow, overlap detection |
| `reference/stitch-design-token-alignment.md` | Design-first workflow, token DNA normalization |
