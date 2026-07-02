---
name: voice-profiles
description: |
  Adapt writing tone and style based on target audience and content type using predefined voice and context profiles.
category: quality
license: MIT
version: "1.0.0"
---

# Voice & Context Profiles

This skill enables agents to adapt their writing tone and style based on the target audience and content type. By applying these profiles, agents avoid generic "AI-sounding" output and produce content tailored to the specific medium and persona.

## When to Use

- When generating any text content (READMEs, blogs, emails, docs, social posts).
- When asked to adopt a specific "voice" or "tone".
- When the target platform (e.g., LinkedIn, Technical Blog) is known or detected.

## Voice Profiles

Independent of audience context; sets the persona.

- **`casual`**: Use contractions, short sentences (≤14 words), low jargon, and warm hedges.
- **`professional`**: Use active voice, concrete claims, and low hedging. (Default)
- **`technical`**: Use plain copulatives (is/has), one idea per sentence, and imperative mood.
- **`warm`**: Use direct address ("you"), strong verbs, and medium cadence (15-20 words).
- **`blunt`**: Use short declaratives, no padding, and no hedges.

## Context Profiles

Adjusts rule strictness for specific audiences.

- **`linkedin`**: Relaxed on em dashes, bold, emojis, numbered lists, and transitions.
- **`blog`**: All rules full strength. (Default)
- **`technical-blog`**: Technical terms are exempt; strict prose rules apply.
- **`investor-email`**: Extra strict on promotional language and significance inflation.
- **`docs`**: Relaxed on hedging and copula avoidance.
- **`casual`**: P0 credibility killers only.

## Instructions

1. **Auto-Detect Context**: If not explicitly specified, detect context from content cues:
   - **`technical-blog`**: Presence of code blocks or deep technical implementation details.
   - **`docs`**: README structure, API references, or technical documentation formats.
   - **`linkedin`**: Short length, presence of hashtags, or social-first formatting.
   - **`blog`**: Default if no other cues are present.
2. **Apply Profiles**: Combine the selected Voice and Context profiles.
3. **Default**: If no instructions are provided, use `professional` voice and `blog` context.

## Rationalizations

| Rationalization | Reality |
|-----------------|---------|
| "A single generic voice is safer." | Generic voices often trigger "AI-smell" and fail to engage specific audiences. |
| "Context doesn't matter for technical docs." | Technical docs require clarity and conciseness (Docs profile) differently than a narrative blog. |

## Red Flags

- [ ] Mixing incompatible profiles (e.g., `blunt` voice with `linkedin` social-first context without adjustment).
- [ ] Over-indexing on profile rules to the point of unreadability.

## See Also

- `avoid-ai-writing` — Use this skill to audit and remove AI-isms using these profiles.
