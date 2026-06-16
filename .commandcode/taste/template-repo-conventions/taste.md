# Template Repo Conventions

- For template repos, `VERSION=0.0.0` is intentional (consumer-side default); template's own version lives in `CHANGELOG-TEMPLATE.md`. Confidence: 0.85
- `README.md` is the only doc that should display a template version badge; remove redundant badges from other docs. Confidence: 0.85
- `scripts/propagate-version.sh` and `scripts/bump_patch_version.sh` are general-purpose utilities for downstream consumers — never modify them for template-specific needs. Confidence: 0.85
- New skills must be added to `.agents/skills/<name>/` AND symlinked to `.claude/skills/` and `.qwen/skills/` via `./scripts/setup-skills.sh`. Confidence: 0.80
- Skill `SKILL.md` must stay under 250 lines, include `## Rationalizations` table and `## Red Flags` checklist. Confidence: 0.80
- After adding a new skill, run `./scripts/generate-llms-txt.sh` to keep `llms-full.txt` in sync. Confidence: 0.75
- Never add `.commandcode/` or `.mimocode/` to `.gitignore` — both directories are required at runtime and must be committed (agent tooling state and taste/learnings). Confidence: 0.95
