# .opencode/agent/ - Symlinks for Skills

This folder contains **symlinks only** for skills. Do not add real skill files here.

All skills live canonically in `.agents/skills/`.
Each skill entry here is a symlink created by `./scripts/setup-skills.sh`.

```
<skill-name>/  ->  ../../.agents/skills/<skill-name>/
```

Note: Agent `.md` definition files (not skills) are real files in this folder.

To add a new skill:
1. Create it in `.agents/skills/<skill-name>/`
2. Run `./scripts/setup-skills.sh` to create symlinks in all CLI folders

See `agents-docs/SKILLS.md` for authoring guidelines.