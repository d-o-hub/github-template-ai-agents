# Quick Start Guide

> Set up shared agent instructions, then tailor checks to your product.
> This repository uses Full template maintainer policy; downstream adopters
> normally choose Minimal/Standard Light. Bootstrap runs the template quality
> gate and configures local git hooks. Optional linters (shellcheck,
> markdownlint, yamllint) are skipped when absent — run `./scripts/doctor.sh`
> to see what is missing. Skipped checks are not proof of success.

[![License: MIT](https://img.shields.io/badge/License-MIT-yellow.svg)](LICENSE)

## Prerequisites

- Git and Bash installed
- One or more CLI coding agents:
  - [Claude Code](https://claude.ai/code) (recommended)
  - [Gemini CLI](https://github.com/google-gemini/gemini-cli)
  - [OpenCode](https://opencode.ai/)
  - [Qwen Code](https://github.com/QwenLM/Qwen-Coder)
  - Or any agent that supports the AGENTS.md format

## Setup

```bash
# Evaluating this template itself (Full suite):
git clone https://github.com/d-o-hub/github-template-ai-agents.git
cd github-template-ai-agents

# After creating YOUR repo from the template ("Use this template"), clone that:
#   git clone https://github.com/<you>/<your-project>.git && cd <your-project>

# Deliberate setup: creates skill links and sets local core.hooksPath.
./scripts/bootstrap.sh
```

For a product, choose a profile and customize docs/local checks/CI before
treating bootstrap as verification of your application. It sets up template
tooling, not product dependencies; do not run it just to inspect a repository.

**Expected output:**

```text
==> Checking environment
  ✓ git present and inside a repository
==> Setting up skills
  ✓ Skills ready
==> Configuring git hooks via .githooks
  ✓ git hooks configured (core.hooksPath = .githooks)
==> Validating skills
  ✓ Skills valid
==> Running quality gate
  ✓ Quality gate passed

Bootstrap complete. Repository is ready for AI agent workflows.
```

`bootstrap.sh` is idempotent, but may change local hook configuration again.
Rerun deliberately when repairing template tooling.

### CLI (optional)

After setup, you can use the unified `agent-toolkit` CLI instead of calling scripts directly:

```bash
./bin/agent-toolkit help       # Show all commands
./bin/agent-toolkit doctor     # Environment diagnostics
./bin/agent-toolkit quality    # Run quality gate
./bin/agent-toolkit validate skills  # Validate skills only
```

### Use this template on GitHub

If you are starting from scratch, click **"Use this template"** on GitHub before
cloning your own repository. Follow the adopter cleanup path below; do not
carry the template's historical state into product operations.

### Start light (recommended)

Minimal and Standard profiles default to **Light** process; Full is the current
template maintainer profile. Day one does not require the Full maintenance stack:

1. Rewrite `AGENTS.md`, README, version policy, and retained tool overrides for
   the product. Use understand → change → verify → report; ship only on request.
2. Remove or reinitialize copied CI-status artifacts, per-agent and legacy
   metrics/DORA, and old plans. Keep only relevant tools, skills, and workflows;
   update required checks, rulesets, and triggers with any workflow removal.
3. Scale planning to risk: small fixes/docs need a short plan and relevant
   checks; architectural changes need a proportionate approved decision record.
   GOAP/TRIZ does not require opting into telemetry or always-fix maintenance.

See [agents-docs/ADOPTION_PROFILES.md](agents-docs/ADOPTION_PROFILES.md) for
the complete cleanup checklist and CI adaptation guidance. These are downstream
choices, not instructions to delete current maintainer artifacts here.

## Configure for Your Project

Edit `AGENTS.md` to add your project details:

### 1. Update Project Overview

```markdown
## Project Overview

<!-- Replace this section -->
This is a [language] project that [does what].
Primary stack: [frameworks, libraries, tools]
```

### 2. Update Setup Commands

````markdown
## Setup

```bash
# Example only: a pnpm product with these scripts defined
pnpm install --frozen-lockfile
pnpm dev
pnpm lint
pnpm typecheck
pnpm test
```
````

Replace the example with commands verified for your product. Do not pipe
alternative package-manager or language commands together.

The supplied `ci.yml` is an example multi-language/template suite: it also runs
template schema/content checks, root Python tests, skill tests, and BATS. Node
CI assumes `npm ci` / `npm test`, whereas the local checker uses `pnpm` when
available. pnpm, Yarn, and Bun adopters must align setup, lockfile/cache paths,
frozen installs, and test commands in both CI and local gates. Replace unrelated
language/template checks rather than assuming manifest detection is enough.

Remove optional maintainer workflows carefully; do not use generic `if: false`
guards as a substitute for changing required checks and triggers. CI-status
update/upload/persist steps live inside `ci.yml`'s `ci-success` job, so removing
only its cleanup workflow does not disable production. Preserve/replace the
required-job aggregation check when dropping those steps. See
[Adoption Profiles](agents-docs/ADOPTION_PROFILES.md#optional-maintainer-automation).

### 3. Add Language-Specific Style

Choose and customize rules for the product's actual toolchain:

```markdown
<!--
#### Rust
- Edition 2021, stable toolchain
- cargo fmt + cargo clippy -- -D warnings must pass
-->

<!--
#### TypeScript / JavaScript
- Strict mode, ESModules only, no implicit any
-->

<!--
#### Python
- Python 3.10+, async/await
- ruff + black; type hints on public functions
-->
```

## Test Your Setup

### With Claude Code

```bash
claude "Analyze this codebase and summarize its structure"
```

### With Gemini CLI

```bash
gemini "What are the main components of this project?"
```

### With OpenCode

```bash
opencode "Review the project structure"
```

These prompts check tool discovery and context, not application correctness or
skill effectiveness. Optional packs are adoption suggestions, distinct from
the eight default-unlinked Claude/Qwen skills; see
[link policy and pruning](agents-docs/ADOPTION_PROFILES.md#default-unlinked-skills-are-a-separate-mechanism).
Pruning also requires the curated `AGENTS.md` inventory and all affected
generators, not just recreating skill links.

## Start Coding

### Example: Implement a Feature

```bash
claude "Implement a function that validates user input"
```

Expected workflow (verify the agent actually follows it):

1. Read relevant files
2. Plan proportionately, then implement the feature
3. Run relevant product checks and report skipped checks or blockers
4. Summarize the diff; commit/push/PR/merge only if requested

Delegate retrieval → planning → implementation → verification. Independent
tasks may run in parallel; dependent stages must remain ordered. Light mode
does not impose Full metrics/DORA or unrequested inherited-failure remediation.

### Example: Fix a Bug

```bash
claude "Fix the bug in src/handler.py where null values cause crashes"
```

### Example: Refactor Code

```bash
claude "Refactor the authentication module to improve readability"
```

## Verify Everything Works

```bash
# Full template check; downstream repositories use their product gate instead.
./scripts/quality_gate.sh
```

Check that the intended checks actually ran, not merely that the command exited
successfully. **Static validation ≠ behavioral proof:** skill structure, eval
schema/fixture validation, and `run-evals.py` smoke checks invoke no model and
do not prove skill effectiveness. Low-impact documentation needs relevant
inventory/link/Markdown checks, not new behavioral tests by default.

### Version policy

The template's root `VERSION=0.0.0` is a consumer placeholder; template releases
are recorded in `.template/CHANGELOG-TEMPLATE.md`. Set downstream `VERSION` to
the product version and customize its README/changelog/release tools. The
existing patch-bump script increments `VERSION` and never resets it; it still
requires the template changelog unless adapted. See
[Version Flow](agents-docs/template-versioning/version-flow.md).

### Optional: Usage Policies & Eval Tracking

If useful for your product, copy and customize the policy templates:

```bash
cp .template/USE_RESTRICTIONS.md ./USE_RESTRICTIONS.md
cp .template/EVALS.md ./EVALS.md
```

- Edit `USE_RESTRICTIONS.md` to define what agents are allowed to do.
- Use `EVALS.md` to track performance and quality improvements over time.

## Troubleshooting

If bootstrap fails or the quality gate reports unexpected errors, run the doctor:

```bash
./scripts/doctor.sh
```

The doctor checks:

- Required tools (`git`, `bash`)
- Optional quality tools (`markdownlint-cli2`, `shellcheck`, `yamllint`)
- Git repository state
- Symlink support (critical on Windows)
- `.agents/skills` directory and expected symlinks
- Pre-commit hook installation
- Core file presence (`AGENTS.md`, `QUICKSTART.md`)

Share its output when filing a bug report.

### Common issues

| Symptom | Likely cause | Fix |
|---|---|---|
| Symlink errors during bootstrap | Windows without Developer Mode | Run inside WSL2 or enable Developer Mode |
| Commits skip the quality gate | `core.hooksPath` not set | Re-run `./scripts/bootstrap.sh` (sets `core.hooksPath=.githooks`) |
| Skills validation fails | Symlinks not created | Re-run `./scripts/bootstrap.sh` |
| Quality gate fails on fresh clone | Missing optional tools | Run `./scripts/doctor.sh` to identify gaps |

### Per-agent verification

If the agent does not respond, check installation:

- Claude Code: `claude --version`
- Gemini CLI: `gemini --version`
- OpenCode: `opencode --version`
- Qwen Code: `qwen --version`

## Convention

| Command | Purpose |
|---|---|
| `./scripts/bootstrap.sh` | First-time setup (idempotent) |
| `./scripts/doctor.sh` | Environment diagnostics |
| `./scripts/quality_gate.sh` | Local quality enforcement |
| `./scripts/validate-skills.sh` | Low-level skill check (called by bootstrap) |
| `./scripts/setup-skills.sh` | Low-level symlink setup (called by bootstrap) |

## Next Steps

| Topic | Resource |
|-------|----------|
| Understanding skills | [`agents-docs/SKILLS.md`](agents-docs/SKILLS.md) |
| Creating sub-agents | [`agents-docs/SUB-AGENTS.md`](agents-docs/SUB-AGENTS.md) |
| Configuring hooks | [`agents-docs/HOOKS.md`](agents-docs/HOOKS.md) |
| Context management | [`agents-docs/CONTEXT.md`](agents-docs/CONTEXT.md) |
| Available agents | [`agents-docs/AGENTS_REGISTRY.md`](agents-docs/AGENTS_REGISTRY.md) |
| Evaluation Tracking | [`.template/EVALS.md`](.template/EVALS.md) |
| Usage Restrictions | [`.template/USE_RESTRICTIONS.md`](.template/USE_RESTRICTIONS.md) |
| Adopting in existing repo | [`agents-docs/MIGRATION.md`](agents-docs/MIGRATION.md) |

## Common First Tasks

1. **Understand codebase**: "Summarize the project structure"
2. **Find files**: "Where is the authentication logic?"
3. **Add feature**: "Add input validation to the form"
4. **Fix bug**: "Fix the null pointer issue in handler.py"
5. **Write tests**: "Add tests for the user service"
6. **Refactor**: "Improve the code structure in module X"

---

**Need help?** See [`README.md`](README.md) for full documentation.
