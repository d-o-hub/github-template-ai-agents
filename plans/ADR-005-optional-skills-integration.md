# ADR 005: Integration of Specialized Optional Skills

## Context
As the AI agent template grows, adding every available skill to the default context leads to "context rot" and exceeds token limits for smaller models. Specifically, regulatory skills like `eu-ai-act-compliance` and platform-specific skills like `durable-objects` are valuable but not universally required.

## Decision
We will implement a "Progressive Disclosure" pattern for skills:
1.  **Optional Skills**: Introduce a `SKILLS_OPTIONAL` array in `scripts/setup-skills.sh` and `scripts/validate-skills.sh`.
2.  **Opt-in Mechanism**: These skills are not symlinked by default unless `LINK_OPTIONAL=true` is set.
3.  **Discovery**: Optional skills are listed in `README.md` with a `⚙️` indicator to signal their specialized nature.
4.  **Categorization**: New categories like "Compliance & Governance" will be created to house these specialized skills.

## Consequences
- **Positive**: Keeps the default agent context lean and focused on core development tasks.
- **Positive**: Provides a clear path for enterprise-ready features (compliance) to be added without burdening all users.
- **Neutral**: Requires users to manually opt-in if they need these specialized capabilities.
- **Negative**: Adds slight complexity to the setup and validation scripts.
