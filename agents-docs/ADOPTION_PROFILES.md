# Adoption Profiles

Choose how much of this template to keep. The full repository is the
**template maintainer** surface; most product teams want a smaller default.

## Profiles

| Profile | Who | Keep |
|---------|-----|------|
| **Minimal** | New product repo; one AI coding tool | Core docs + quality gate + basic CI |
| **Standard** | Team using agents daily | Minimal + skills system + PR/git workflows |
| **Full** | This template's own maintainers | Everything (metrics, DORA, Turso sync, etc.) |

## Minimal workflow set

Keep these under `.github/workflows/` (names may vary slightly):

- `ci.yml` — quality gate + tests
- `gitleaks.yml` — secret scan
- `commitlint.yml` — conventional commits / PR title
- `markdown-lint.yml`
- `yaml-lint.yml`
- `security-scan.yml` (or equivalent CodeQL/Trivy)

### Optional to disable for adopters

These are primarily for **maintaining this template** or niche products:

| Workflow | Why optional |
|----------|--------------|
| `dora-report.yml`, `dora-fdrt.yml` | Template metrics reporting |
| `sync-turso-skill.yml` | Turso skill sync |
| `metrics-conflict-resolver.yml`, `validate-metrics.yml` | `.agents/metrics.jsonl` automation |
| `knowledge-cleanup.yml` | Lessons/knowledge maintenance |
| `track-gitleaks-release.yml` | Upstream release tracking |
| `auto-resolve-comments.yml`, `dedup-issues.yml` | Heavy issue automation |
| `dependabot-auto-merge.yml` | Requires rulesets/trust policy |
| `cleanup-ci-status-prs.yml` + CI status update jobs | Only if you use `ci-status.json` |

Disable by deleting the workflow file or adding `if: false` at the job level.
Document your choice in your project `AGENTS.md`.

## Skill packs

Skills live in `.agents/skills/`. Agents load them on demand; unused skills
cost little unless discovery catalogs are huge. Still, start with a **core**
set and add packs when the product needs them.

### Core (recommended for Standard)

- `static-analysis`, `shell-script-quality`, `security-code-auditor`
- `git-github-workflow`, `github-pr-sentinel`, `code-review-assistant`
- `goap-agent`, `implementer`, `delegate`, `learn`
- `skill-creator`, `skill-evaluator`, `agents-md`, `readme-best-practices`
- `testing-strategy`, `test-runner`, `privacy-first`

### Optional packs (enable when needed)

| Pack | Skills |
|------|--------|
| **Cloudflare / edge** | `durable-objects`, `cloudflare-worker-api` |
| **Turso / LibSQL** | `turso-db` (+ `sync-turso-skill` workflow) |
| **Reader product** | `reader-ui-ux`, `document-rendering-and-locators`, `pwa-offline-sync` |
| **Compliance / vendors** | `eu-ai-act-compliance`, `codacy`, `codeberg-api` |
| **Research / browser** | `web-search-researcher`, `do-web-doc-resolver`, `agent-browser`, `dogfood` |
| **UI specialization** | `ui-ux-optimize`, `accessibility-auditor`, `css-render-performance` |

Optional skills listed in `scripts/setup-skills.sh` (`SKILLS_OPTIONAL`) are not
linked unless `LINK_OPTIONAL=true`. Extend that list for adopter-local optional
skills.

### Pruning skills you do not need

```bash
# Example: remove a pack you will never use (after copying the template)
rm -rf .agents/skills/turso-db .agents/skills/durable-objects
./scripts/setup-skills.sh
./scripts/generate-available-skills.sh
./scripts/generate-skill-catalog.sh
```

## Process modes

See `AGENTS.md` → **Process modes**. Day-one adopters should use **light mode**;
use full GOAP/ADR/TRIZ when changes are large or architectural.

## Related

- `agents-docs/MIGRATION.md` — migrating an existing repo
- `QUICKSTART.md` — bootstrap path
- `agents-docs/HARNESS.md` — harness engineering principles
