# Adoption Profiles

Choose how much of the template to keep **in your downstream product repository**.
This repository itself uses **Full maintainer** policy and retains its history,
telemetry, workflows, and complete skill inventory. The cleanup below is not an
instruction to delete those artifacts here.

## Profiles

| Profile | Default process | Keep |
|---------|-----------------|------|
| **Minimal** | Light | Product instructions, relevant quality gate, basic CI, needed tool overrides |
| **Standard** | Light | Minimal + selected skills, hooks, and agent workflows |
| **Full** | Full | Current template maintenance: orchestration, generators, metrics/DORA, CI-status automation |

Light means understand → change → verify → report; commit/push/PR/merge only
when requested. Architectural changes still need a proportionate plan and
approved decision record. Selecting GOAP/TRIZ for a complex product change does
not opt the product into Full telemetry, always-fix maintenance, or generators.
Shared safety and task ownership apply in every profile.

## Adopter cleanup checklist

After creating your own repository, remove or reinitialize copied maintainer
state. Inspect consumers before pruning files so hooks and required checks do
not point at missing inputs.

- [ ] Rewrite `README.md`, `QUICKSTART.md`, `AGENTS.md`, and retained tool overrides for the product, including repository URLs, install/test commands, and Light process policy.
- [ ] Remove copied `.github/ci-status/ci-status.json` and `ci-summary.md` if you drop CI-status automation. If retaining it, generate new state from your repository's actual run; never reuse template run URLs or manufacture `passing`.
- [ ] Clear copied `.agents/metrics/metrics-*.jsonl`, legacy `.agents/metrics.jsonl`, `agents-docs/metrics-archive/`, `dora-metrics.jsonl`, and `agents-docs/dora-reports/`. Start fresh only if you opt into telemetry; otherwise remove its producers and consumers too.
- [ ] Remove or archive old template `plans/` ADRs, `GOAP_STATE.md`, indexes, and status records; establish product decision history if needed. Remove template ADR-registration checks when dropping that stack.
- [ ] Set product `VERSION` and changelog policy. The template's `0.0.0` is a consumer placeholder, not its release number; retain `.template/CHANGELOG-TEMPLATE.md` only as template provenance if useful. Adapt release tooling before use.
- [ ] Keep only tool configs, commands, hooks, and optional skill packs the team uses. Review `.github/` workflows, permissions, bot policies, and copied template-specific analysis/report references.
- [ ] Configure your repository's rulesets/branch protection for the retained check names, apps, events, and triggers. Remove stale requirements when retiring workflows; do not require checks that cannot run in your repository.

See `template-versioning/version-flow.md` for the actual release-script behavior.
The current template's maintainers keep these artifacts; do not apply this
checklist to their working copy during ordinary maintenance.

## Product CI, not inferred CI

The supplied `ci.yml` is an **example multi-language/template suite**. It runs
template content/schema checks, root Python tests, skill tests, and BATS in
addition to manifest-conditioned language steps. It is not a ready-made test
contract for every product, and a `package.json` does not identify a package
manager.

Replace install, lint, typecheck, build, and test commands with the product's
actual commands in both local gates and CI. Node CI currently uses `npm ci` /
`npm test`; the local language checker uses `pnpm` when available. pnpm, Yarn,
and Bun projects need their own setup, lockfile/cache settings, frozen install,
and test commands. Non-Node products should keep only relevant language checks.

### Minimal workflow starting point

Tailor these under `.github/workflows/` rather than treating filenames as a
mandatory set:

- `ci.yml` — product quality gate + tests
- `gitleaks.yml` — secret scan
- `commitlint.yml` — conventional commits / PR title, if adopted
- `markdown-lint.yml`, `yaml-lint.yml` — when relevant
- `security-scan.yml` — or equivalent product-relevant security checks

### Optional maintainer automation

Keep these only when they provide product value:

| Workflow | Why optional |
|----------|--------------|
| `dora-report.yml`, `dora-fdrt.yml`, `hotfix.yml` | Metrics/DORA reporting |
| `sync-turso-skill.yml` | Turso skill sync |
| `metrics-conflict-resolver.yml`, `validate-metrics.yml` | Per-agent/legacy metrics automation |
| `knowledge-cleanup.yml` | Lessons/knowledge maintenance |
| `track-gitleaks-release.yml` | Upstream release tracking |
| `auto-resolve-comments.yml`, `dedup-issues.yml` | Heavy issue automation |
| `dependabot-auto-merge.yml` | Requires rulesets/trust policy |
| `cleanup-ci-status-prs.yml` + status steps in `ci.yml` | Only if you retain CI-status artifacts |
| `update-llms-txt.yml` | Template-generated context maintenance |
| `patch-release-on-label.yml`, `version-propagation.yml` | Adapt to the product release/version policy |

Remove unneeded optional workflow files deliberately in the downstream repo.
Coordinate each removal with required checks, job `needs`, workflow consumers,
permissions, events, and path/branch triggers. Do not generically add `if: false`:
GitHub can report a skipped job as successful, while a workflow that never
triggers can leave a required check pending. Neither proves a product was tested.

CI-status production is **embedded in `ci.yml`'s `ci-success` job**: `Update CI
status artifacts`, `Upload CI status as artifact`, and `Persist CI data to main`.
Removing only the cleanup workflow or copied JSON does not stop production.
If dropping the feature, remove/adapt those producer steps and unnecessary write
permissions; preserve or replace `Check all required jobs passed` and its
dependencies. That final check also calls `scripts/update-ci-status.py --check`,
so retain the script until the aggregation check has a replacement. If keeping
the feature, adapt it to your job IDs/triggers and verify a real downstream run.
Record the chosen workflow scope in your product `AGENTS.md`.

## Skill packs

Skills live in `.agents/skills/` and load on demand. Keep a small relevant set;
add packs when the product needs them. Packs are adoption suggestions, not a
claim that every listed skill is unlinked by the current setup script.

### Core (recommended for Standard)

- `static-analysis`, `shell-script-quality`, `security-code-auditor`
- `git-github-workflow`, `code-review-assistant`
- `goap-agent`, `implementer`, `delegate`, `learn`
- `skill-creator`, `skill-evaluator`, `agents-md`, `readme-best-practices`
- `testing-strategy`, `test-runner`, `privacy-first`

### Optional packs (select when needed)

| Pack | Skills |
|------|--------|
| **Cloudflare / edge** | `durable-objects`, `cloudflare-worker-api` |
| **Turso / LibSQL** | `turso-db` (upstream sync workflow is a separate choice) |
| **Reader product** | `reader-ui-ux`, `document-rendering-and-locators`, `pwa-offline-sync` |
| **Compliance / vendors** | `eu-ai-act-compliance`, `codacy`, `codeberg-api` |
| **Research / browser** | `web-search-researcher`, `do-web-doc-resolver`, `agent-browser`, `dogfood` |
| **UI specialization** | `ui-ux-optimize`, `accessibility-auditor`, `css-render-performance` |

### Default-unlinked skills are a separate mechanism

The existing default-unlinked set contains eight names: `eu-ai-act-compliance`,
`durable-objects`, `reader-ui-ux`, `document-rendering-and-locators`,
`pwa-offline-sync`, `cloudflare-worker-api`, `codacy`, and `lifecycle-management`.
`scripts/setup-skills.sh` skips creating their Claude/Qwen links unless run with
`LINK_OPTIONAL=true`; setup and validation share
`scripts/lib/optional_skills.sh` as the manifest for this policy.
Other optional-pack skills can still be linked by default. This is link policy,
not deletion or an access restriction: canonical readers and Windsurf's
directory link can still see the skills. An ordinary setup rerun does not remove
already-created optional links merely because `LINK_OPTIONAL` is unset.

### Pruning skills you do not need

Prune only in a downstream repository after checking references and consumers.
Remove the chosen canonical skill directories and stale references in routing
rules, tool configs/commands, registries, and pack documentation. **Manually
update the curated `AGENTS.md` → `## Skills` table** to match the remaining
inventory; generators do not maintain that table.

Run symlink setup **and all affected documentation generators**, not just the
two catalog scripts:

```bash
./scripts/setup-skills.sh
./scripts/update-all-docs.sh
./scripts/generate-skills-reference.sh
python3 scripts/generate-skills-readme.py
```

`update-all-docs.sh` covers available skills, the intent catalog, and LLM context;
the separate generators cover the reference and canonical skills README.
Refresh affected diagrams/registries too. Then run inventory, links, Markdown,
and retained skill/config checks. If these generators/checks were pruned from a
Minimal product, update its remaining inventory and references directly instead.
The current template keeps all 54 canonical skills; the coordinating maintainer
handles shared generated outputs during scoped parallel work.

## Process modes

See `AGENTS.md` → **Process modes** and `BEHAVIORAL_DEFAULTS.md`. Use retrieval →
planning → implementation → verification, scaling planning to risk. Low-impact
documentation needs relevant inventory/link/Markdown checks, not new tests for
ceremony. **Static validation ≠ behavioral proof:** structure/schema/fixture
checks and `run-evals.py` smoke runs do not invoke a model. Use representative
behavioral evals before claiming a skill improves outcomes, and report skips.

## Related

- [Migration](MIGRATION.md) — migrating an existing repo
- [Quick Start](../QUICKSTART.md) — bootstrap path
- [Harness](HARNESS.md) — harness engineering principles
