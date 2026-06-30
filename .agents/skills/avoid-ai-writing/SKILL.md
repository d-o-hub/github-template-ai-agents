---
name: avoid-ai-writing
description: Audit and rewrite content to remove AI writing patterns ("AI-isms"). Use this skill when asked to "remove AI-isms," "clean up AI writing," "edit writing for AI patterns," "audit writing for AI tells," or "make this sound less like AI." Supports detect-only, rewrite (default), and edit-in-place modes, voice profiles, and iterative convergence.
category: quality
license: MIT
version: "3.10.0"
---

# Avoid AI Writing — Audit & Rewrite

You are editing content to remove AI writing patterns ("AI-isms") that make text sound machine-generated.

## When to Use

- When asked to "humanize" or "clean up" AI-generated text.
- Before publishing agent-generated READMEs, changelogs, or documentation.
- When auditing content for statistical AI tells.

## Core Modes

- **`rewrite`** (default): Flag AI-isms and rewrite text to fix them. Returns Issues, Rewritten text, What changed, and a Second-pass audit.
- **`detect`**: Flag AI-isms only. No rewriting. Useful for CI/CD gates or audits.
- **`edit`**: Edit a file in-place with minimal, targeted changes using the Edit tool.

## Voice Profiles (Optional)

Independent of audience context; sets the persona.

- **`casual`**: Contractions, short sentences (≤14 words), low jargon.
- **`professional`**: Active voice, concrete claims, low hedging.
- **`technical`**: Plain copulatives (is/has), one idea per sentence, imperative mood.
- **`warm`**: Direct address ("you"), strong verbs, medium cadence (15-20 words).
- **`blunt`**: Short declaratives, no padding, no hedges.

## Context Profiles

Adjusts rule strictness for specific audiences.

- **`linkedin`**: Social-first; relaxed on formatting, strict on P0 credibility killers.
- **`blog`**: Default; all rules full strength.
- **`technical-blog`**: Technical terms (robust, leverage, etc.) exempt; strict prose rules.
- **`investor-email`**: Extra strict on promotional language and significance inflation.
- **`docs`**: Clarity over voice; relaxed on hedging and copula avoidance.
- **`casual`**: Slack/DM style; P0 credibility killers only.

## Instructions

1. **Audit**: Identify AI-isms using the `references/patterns.md` catalog.
2. **Apply Profile**: Adjust strictness based on context and tone based on voice.
3. **Execute Mode**:
   - `rewrite`: Return audit, full rewrite, change summary, and second-pass audit.
   - `detect`: Return severity-grouped issues (P0/P1/P2) and assessment.
   - `edit`: Apply minimal Edit tool changes to target file; return edit report.
4. **Convergence**: If `--iterate 2` is passed, repeat until no patterns remain (max 2 passes).

## Severity Tiers

- **P0 — Credibility killers**: Cutoff disclaimers, chatbot artifacts, vague attributions.
- **P1 — Obvious AI smell**: Word-list violations, template phrases, "Let's" openers.
- **P2 — Stylistic polish**: Generic conclusions, uniform length, transition overuse.

## Rationalizations

| Rationalization | Reality |
|-----------------|---------|
| "AI writing is grammatically perfect, so it's fine." | Perfection is a tell; natural human writing has varied rhythm and personality. |
| "I can just ask the LLM to 'sound human'." | One-shot "sound human" prompts are vibes-based; this skill uses a structured audit. |
| "This will flag non-native speakers." | Patterns are signals, not proof. Use judgment and pair with context. |

## Red Flags

- [ ] Sanding away all personality in pursuit of "clean" prose (creating new uniformity).
- [ ] Rewriting quoted material or code blocks.
- [ ] Ignoring the Second-pass audit (patterns often survive the first edit).

## References

- `references/patterns.md` — Exhaustive catalog of AI patterns and vocabulary.

## See Also

- `ui-ux-optimize` — For optimizing UI/UX specific copy and layouts.
- `readme-best-practices` — For documentation structure and discovery.
