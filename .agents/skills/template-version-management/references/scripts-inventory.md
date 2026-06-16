# Version-Related Scripts Inventory

This template ships three version-related scripts. All three are **general-purpose utilities** designed for downstream consumer codebases; the template repo itself uses them in a degenerate mode (`VERSION=0.0.0`).

## `scripts/propagate-version.sh`

**Purpose:** Read `VERSION` and propagate it to all files that reference it.

**Inputs:**
- `VERSION` file (consumer-side version)
- `FILES_TO_UPDATE` array (list of files to update)

**Behavior:**
- Reads `VERSION` (validates it's strict semver `X.Y.Z`)
- For each file in `FILES_TO_UPDATE`, runs sed substitutions on:
  - `version-X.Y.Z` badges
  - `Template version: X.Y.Z` text
  - `**Version:** X.Y.Z` text
  - `| \`VERSION\` | \`X.Y.Z\` |` table cells
- Adds `[Unreleased]` section to `CHANGELOG.md` if missing
- Exits 0 on success, 1 on validation failure

**Template-repo behavior:** Updates `README.md` to `version-0.0.0` (because `VERSION=0.0.0`). Does not touch `CHANGELOG-TEMPLATE.md` (which is the template's own history).

**Consumer-repo behavior:** Updates `README.md`, `QUICKSTART.md`, `agents-docs/MIGRATION.md`, `CHANGELOG.md` to the consumer's `VERSION` value.

**Files updated (as of last edit):**
- `README.md`
- `CHANGELOG-TEMPLATE.md`
- `agents-docs/VERSION.md`
- `analysis/SWARM_ANALYSIS.md`

**Triggers:**
- Pre-commit hook (when `VERSION` changes)
- GitHub Actions `version-propagation.yml` (when `VERSION` changes on `main` or `feat/**`)

## `scripts/bump_patch_version.sh`

**Purpose:** Bump the patch version, append a new entry to `CHANGELOG-TEMPLATE.md`, and propagate.

**Inputs:**
- `VERSION` file (current version)
- `CHANGELOG-TEMPLATE.md` (target file)
- `git log` (last 15 non-merge commits, excluding version bumps)

**Behavior:**
- Reads `VERSION`, computes `MAJOR.MINOR.(PATCH+1)`
- Generates a changelog summary from `git log` (Added/Fixed/Changed sections)
- Inserts `## [X.Y.Z] - YYYY-MM-DD` into `CHANGELOG-TEMPLATE.md` after `## [Unreleased]`
- Writes new version to `VERSION`
- Runs `propagate-version.sh`

**Template-repo behavior:** Reads `VERSION=0.0.0`, computes `0.0.1`, inserts new entry, writes `0.0.1` to `VERSION`, then resets via `propagate-version.sh` reading the new value.

**Consumer-repo behavior:** Reads consumer `VERSION`, appends to consumer's `CHANGELOG.md` (note: consumer would rename `CHANGELOG-TEMPLATE.md` to `CHANGELOG.md` per the bootstrap flow).

**Triggers:**
- Manual invocation: `./scripts/bump_patch_version.sh`

## `scripts/bump_patch_version.sh` — Test Coverage

`tests/bump_patch_version.bats` validates:
- Version is incremented correctly
- New entry contains Added/Fixed/Changed sections from recent commits
- Both `VERSION` and `CHANGELOG-TEMPLATE.md` are updated

## When NOT to Modify These Scripts

The scripts are designed for downstream consumers. **Do not change their semantics to read from `CHANGELOG-TEMPLATE.md` instead of `VERSION`** — that would break every consumer repo using this template.

If a template-specific behavior is needed (e.g., a `propagate-template-version.sh` that reads the latest `## [X.Y.Z]` heading from `CHANGELOG-TEMPLATE.md`), add a **new** script rather than modifying these.
