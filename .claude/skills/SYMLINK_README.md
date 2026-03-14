# .claude/skills/ - Symlinks Only

This folder contains **symlinks only**. Do not add real skill files here.

All skills live canonically in `.agents/skills/`.
Each entry here is a symlink created by `./scripts/setup-skills.sh`.

```
<skill-name>/  ->  ../../.agents/skills/<skill-name>/
```

To add a new skill:
1. Create it in `.agents/skills/<skill-name>/`
2. Run `./scripts/setup-skills.sh` to create symlinks in all CLI folders

See `agents-docs/SKILLS.md` for authoring guidelines.