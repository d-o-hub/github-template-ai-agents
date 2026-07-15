# Anti-AI-Slop Guide (full tables)

Companion to `SKILL.md` Anti-AI-Slop section and `anti-slop-rules.md`.

## UI Slop Patterns (Visual Design)

| Pattern | What it looks like | Why it's slop |
|---|---|---|
| Purple gradient hero | `#7c3aed → #2563eb` | Default Tailwind AI palette |
| Glassmorphism cards | Frosted glass, `backdrop-blur` | Overused since iOS 15 |
| Rounded everything | `border-radius: 24px+` | Removes personality |
| Inter / DM Sans / Space Grotesk | Default "modern" sans | Signals "AI-generated UI" |
| Emojis in headers | Decorative emoji | Startup theater |
| Hero headline formula | `[Verb] your [noun] with [product]` | Indistinguishable commodity |
| Three-column feature grid | Icon + bold label + 1 sentence | Generic SaaS landing |
| CTA: "Get started for free" | Large primary button | Meaningless |

**Instead:** Typography first; commit to one extreme (minimal or dense); real color theory; let content shape layout; reference design movements (Swiss, Bauhaus, Brutalist web).

## UX Slop Patterns (Interaction & Flow)

| Pattern | Why it's slop |
|---|---|
| Onboarding modal | Interrupts before context |
| 5-step wizard | Treats users as suspects |
| Tooltip tours | Teaches the wrong interface |
| "Are you sure?" | Prefer undo |
| Toast notifications | Noise after two sessions |
| Hamburger menu | Discovery failure |

**Instead:** Undo over confirm; empty states with one next action; progressive disclosure; optimistic UI; inline notifications.

## Copy Slop Patterns

| Slop Type | Examples | Fix |
|---|---|---|
| Hollow affirmations | Absolutely!, Certainly! | Start with content |
| AI superlatives | Powerful, seamless, robust | Specific claims and data |
| Listicle reflex | Bullets for everything | Prose unless genuine sets |
| Transition theater | "In conclusion..." | Say the thing |
| Emoji inflation | Decorative emoji spam | Zero unless casual/social |
| Feature announcement | "We're excited to announce..." | State concrete behavior |

## Audit Workflow

1. Scan UI, UX, and Copy canons. List every match by name.
2. Severity: structural (redesign), surface (easy fix), cosmetic (polish).
3. Fix structural first. Name the design principle in the replacement.
