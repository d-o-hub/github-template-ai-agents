# Migration Guide

This guide provides instructions for adopting new skills and patterns in existing projects using the AI agent template.

## Adopting New Skills

We have introduced specialized optional skills like `eu-ai-act-compliance` and `durable-objects`.

### EU AI Act Compliance

This skill helps you implement "Compliance-by-Design" for AI systems deployed to EU users.

**How to Adopt:**

1. Run `./scripts/setup-skills.sh` to ensure the new skill is linked to your agent's context.
2. Initialize the compliance framework in your project:

   ```typescript
   // Example for a Node.js/TypeScript project
   import { AIActLogger } from "./eu-ai-act-compliance";
   const logger = new AIActLogger({ systemId: "my-app", riskClassification: "limited_risk" });
   ```

3. Use the checklist in `.agents/skills/eu-ai-act-compliance/SKILL.md` to audit your transparency disclosures and logging.

### Cloudflare Durable Objects

This skill provides best practices for distributed state management on Cloudflare.

**How to Adopt:**

1. Run `./scripts/setup-skills.sh`.
2. Review your `wrangler.jsonc` or `wrangler.toml` for Durable Object bindings and migrations.
3. Migrate from `fetch()`-based communication to RPC methods if your compatibility date is >= 2024-04-03.
4. Use the `references/rules.md` in the skill folder to optimize your storage and concurrency patterns.

## General Migration Process

Whenever the template is updated:

1. Pull the latest changes from the template repository.
2. Run `./scripts/setup-skills.sh` to refresh symlinks.
3. Run `./scripts/validate-skills.sh` to verify your environment.
4. Check `CHANGELOG.md` for breaking changes or new features.
