# AI Slop Audit — Landing Page Copy

**Source text:**
> Welcome to our revolutionary platform! We leverage cutting-edge AI to deliver world-class solutions. Our best-in-class team is passionate about driving innovation. Experience the future of productivity today!

---

## Slop Pattern Analysis

| # | Pattern | Example from Copy | Severity |
|---|---------|-------------------|----------|
| 1 | **Empty superlatives / hype words** | "revolutionary", "cutting-edge", "world-class", "best-in-class" | High |
| 2 | **Corporate buzzword stacking** | "leverage", "innovation", "productivity" — all in one paragraph | High |
| 3 | **"Experience the future" cliché** | "Experience the future of productivity today!" — the most overused SaaS tagline | High |
| 4 | **No concrete claim** | Every sentence is vague. What does the platform actually *do*? Unknown. | Critical |
| 5 | **Exclamation-point overuse** | Two out of three sentences end with `!` | Medium |
| 6 | **Passive identity as solution** | "Our team is passionate about" — says nothing about outcomes | Medium |
| 7 | **Generic "we leverage" construction** | "We leverage cutting-edge AI" — filler phrase with no specificity | High |
| 8 | **"Driving innovation"** | Empty action phrase — innovation about what? For whom? | High |

---

## Diagnosis

This text is a textbook case of **AI slop** (or human-written text that reads identically to AI slop). Every sentence follows the same template:

```
[Exclamation] + [buzzword-laden claim] + [no specifics]
```

The paragraph says nothing. A reader learns:
- Not *what* the platform does
- Not *who* it's for
- Not *why* "revolutionary" is warranted
- Not *what* "innovation" means in context

This is copy that could describe any product in any industry. It's indistinguishable from a ChatGPT-generated marketing paragraph.

---

## Verdict

**Rating: Severe slop.** Every single sentence contains at least one flagged pattern. The copy has zero specificity, zero personality, and zero proof.

---

## Rewrite Suggestions

Replace with concrete, human-sounding copy that answers: *What does this do? For whom? Why should I care?*

| Original | Rewrite (example) |
|----------|-------------------|
| "Welcome to our revolutionary platform!" | Drop entirely. The first words should name the problem or the user. |
| "We leverage cutting-edge AI to deliver world-class solutions." | State what the product *is* and what it *does*. E.g., "Writes your monthly finance reports from raw data in under 2 minutes." |
| "Our best-in-class team is passionate about driving innovation." | Cut. Nobody reads this and changes behavior. |
| "Experience the future of productivity today!" | End with a concrete CTA or outcome. E.g., "Try it free — no credit card required." |

### Rewrite draft:

> **Stop writing reports by hand.** DataPilot pulls your spreadsheet exports, runs the analysis, and formats a board-ready PDF in under two minutes. Used by 1,200 finance teams. Start free — no credit card needed.

This version is specific, has proof, and sounds like a human wrote it.