---
name: template-version-management
version: "0.2.10"
category: tool
description: Manage versioning in a template repository. Use when working with template repos where `VERSION` is intentionally pinned to 0.0.0, when bumping the template's own release version, when fixing stale version badges, or when answering questions about how versioning flows from `VERSION`/`CHANGELOG-TEMPLATE.md` to `README.md` — even if they just say "bump the template version", "fix the stale badge", or "how does versioning work here". Not for bumping versions in npm packages, Cargo.toml, or non-template projects (use your package manager's versioning).
license: MIT
---

# Template Version Management

Versioning in a **template** repository follows a different mental model than a regular project. `VERSION` is the consumer-side default (always `0.0.0`); the template's own release history is canonical in `CHANGELOG-TEMPLATE.md`; only `README.md` displays a template version badge; and the existing scripts (`propagate-version.sh`, `bump_patch_version.sh`) are general-purpose utilities that downstream consumers reuse unchanged.

## When to Use

- Bumping the template's own release version (e.g., 0.2.10 → 0.3.0)
- Fixing a stale template version badge in `README.md`, `QUICKSTART.md`, or `agents-docs/MIGRATION.md`
- Adding or updating version references when introducing a new doc file
- Answering "what's the template version" / "why is VERSION 0.0.0" / "where does the template version come from"
- Reviewing PRs that touch `VERSION`, `CHANGELOG-TEMPLATE.md`, or any version badge
- Onboarding contributors to the template's version flow

## The Mental Model

```
CHANGELOG-TEMPLATE.md  →  template release history (the canonical source)
README.md              →  only doc with a template version badge
VERSION                →  consumer-side default (0.0.0 for templates,
                          project version for downstream consumers)
scripts/propagate-version.sh
                       →  reads VERSION, propagates to README + CHANGELOG.md
                       →  general-purpose; works for any consumer project
scripts/bump_patch_version.sh
                       →  reads VERSION, appends a new entry to
                          CHANGELOG-TEMPLATE.md, then runs propagate-version.sh
                       →  general-purpose; downstream consumers use it on
                          their own CHANGELOG.md, not CHANGELOG-TEMPLATE.md
```

**Key rule:** scripts are primary. They are designed for downstream consumer codebases and must keep their `VERSION`-based design unchanged. The template's *own* version lives in `CHANGELOG-TEMPLATE.md`; the scripts and the template version are decoupled by design.

## Required Inputs

- The current template version (read from `CHANGELOG-TEMPLATE.md` `## [X.Y.Z]` heading)
- The desired next template version (e.g., "bump patch")
- The list of files that should display a template version badge (currently: only `README.md`)

## Steps

### 1. Verify the current state

```bash
# Template version (canonical)
grep -E "^## \[[0-9]+\.[0-9]+\.[0-9]+\]" CHANGELOG-TEMPLATE.md | head -1

# Consumer-side VERSION (should be 0.0.0 in a template repo)
cat VERSION

# Only file that displays a template version badge
grep -rn "Template Version" --include="*.md" .
```

### 2. Bump the template version

For a patch bump, use the existing script. It will:

1. Read the current `VERSION` (0.0.0 in a template repo)
2. Append a new `## [X.Y.Z] - YYYY-MM-DD` entry to `CHANGELOG-TEMPLATE.md`
3. Reset `VERSION` back to `0.0.0` for templates
4. Run `propagate-version.sh` to update the README badge

```bash
./scripts/bump_patch_version.sh
```

For minor/major template versions, edit `CHANGELOG-TEMPLATE.md` directly, then run `propagate-version.sh`.

### 3. Fix a stale badge

The most common stale badge is in `QUICKSTART.md` or `agents-docs/MIGRATION.md`. **Do not** add a new badge to these files — `README.md` is the only one. Remove the entire `Template Version` badge line. If a user-facing snippet inside a code block shows `Template version: X.Y.Z`, update that text to the current template version.

### 4. Update documentation when adding a versioned file

If a new file legitimately needs the template version, add it to `FILES_TO_UPDATE` in `scripts/propagate-version.sh` **and** add a row to the `## Versioned Files` table in `agents-docs/VERSION.md`. If the new file is not a top-level user-facing doc (e.g., a reference file), prefer linking to `README.md` instead of duplicating the badge.

### 5. Run the quality gate

```bash
./scripts/quality_gate.sh
```

This catches stale badges, broken version references, and any propagation drift.

## Common Pitfalls

- **Editing `VERSION` to "fix" the template version.** `VERSION=0.0.0` is intentional; the template's version is in `CHANGELOG-TEMPLATE.md`.
- **Adding a "Template Version" badge to a new doc file.** `README.md` is the only one. Link to `README.md` or `CHANGELOG-TEMPLATE.md` instead.
- **Modifying `scripts/propagate-version.sh` or `bump_patch_version.sh` to read from `CHANGELOG-TEMPLATE.md`.** They are general-purpose utilities for downstream consumers. Keep their `VERSION`-based design.
- **Manually editing the README badge instead of running `propagate-version.sh`.** The script is the source of truth; manual edits get overwritten on the next propagation.
- **Forgetting to reset `VERSION` to `0.0.0` after a template release.** Downstream consumers clone the template and expect a clean starting point.

## See Also

- `skill-creator` — Create and improve skills
- `readme-best-practices` — README best practices

## Rationalizations

| Rationalization | Reality |
|-----------------|---------|
| "I'll just hardcode the template version in `QUICKSTART.md` so the badge looks right." | The badge will go stale again on the next release. Remove it entirely; `README.md` is the only place that shows the version. |
| "Let me change `propagate-version.sh` to read from `CHANGELOG-TEMPLATE.md` so the badges stay accurate." | The script is a general-purpose utility for consumer repos. Changing it breaks downstream usage. The right fix is in the documentation, not the script. |
| "`VERSION=0.0.0` looks like a bug — I'll set it to the current template version." | The template's version lives in `CHANGELOG-TEMPLATE.md`. `VERSION` is intentionally `0.0.0` for downstream consumers to reset on first use. |
| "I can just edit the README badge manually." | `propagate-version.sh` will overwrite it on the next run. Always go through the script or `bump_patch_version.sh`. |
| "This new doc needs a template version badge too." | Unless it's a top-level user-facing doc, link to `README.md` or `CHANGELOG-TEMPLATE.md`. Avoid badge proliferation. |

## Red Flags

- [ ] A new `Template Version` badge appears in any file other than `README.md`
- [ ] `VERSION` is changed to a non-zero value in a template repository
- [ ] `scripts/propagate-version.sh` or `scripts/bump_patch_version.sh` is modified to read from `CHANGELOG-TEMPLATE.md` instead of `VERSION`
- [ ] A version string in any doc does not match the latest `## [X.Y.Z]` heading in `CHANGELOG-TEMPLATE.md`
- [ ] `bump_patch_version.sh` is run without resetting `VERSION` to `0.0.0` afterward
- [ ] Stale `version-0.X.Y` badge persists in `QUICKSTART.md` or `agents-docs/MIGRATION.md`
- [ ] A PR adds a new file with a hardcoded template version instead of going through the propagation script

## References

- `references/version-flow.md` — Detailed flow diagram of how version updates propagate from `CHANGELOG-TEMPLATE.md` to `README.md`
- `references/scripts-inventory.md` — Inventory of version-related scripts and what each one does
- `CHANGELOG-TEMPLATE.md` — Canonical template release history
- `agents-docs/VERSION.md` — Version management documentation (template + consumer)
- `scripts/propagate-version.sh` — Reads `VERSION`, propagates to consumer files
- `scripts/bump_patch_version.sh` — Bumps patch version, updates `CHANGELOG-TEMPLATE.md`
- `.github/workflows/version-propagation.yml` — CI workflow that runs propagation on `VERSION` changes
