# Migration Guide (skill packs)

> For full template adoption, see **[MIGRATION.md](./MIGRATION.md)**.

This short guide covers **optional skill packs** only.

## Optional domain packs

These skills stay in `.agents/skills/` but are **not** linked into
`.claude/skills/` unless you opt in:

| Pack | Skills |
|------|--------|
| Cloudflare | `cloudflare-worker-api`, `durable-objects` |
| Database | `turso-db` |
| Document apps | `document-rendering-and-locators`, `reader-ui-ux`, `pwa-offline-sync` |
| Access / compliance | `secure-invite-and-access`, `eu-ai-act-compliance` |
| Forgejo/Codeberg | `codeberg-api` |

### Link optional packs

```bash
LINK_OPTIONAL=true ./scripts/setup-skills.sh
./scripts/validate-skills.sh
```

Shared optional list: `scripts/lib/skill-dirs.sh`.

### EU AI Act Compliance

See `.agents/skills/eu-ai-act-compliance/SKILL.md` for logger setup and checklists.

### Cloudflare Durable Objects

See `.agents/skills/durable-objects/SKILL.md` for Workers + DO patterns.
