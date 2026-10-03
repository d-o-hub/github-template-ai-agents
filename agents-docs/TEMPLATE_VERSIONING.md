# Template Versioning (contributor doc, absorbed from template-version-management skill)

## When to Use

- Bumping the template's own release version (e.g., 0.2.10 → 0.3.0)
- Fixing a stale template version badge in `README.md`, `QUICKSTART.md`, or `agents-docs/MIGRATION.md`
- Adding or updating version references when introducing a new doc file
- Answering "what's the template version" / "why is VERSION 0.0.0" / "where does the template version come from"
- Reviewing PRs that touch `VERSION`, `.template/CHANGELOG-TEMPLATE.md`, or any version badge
- Onboarding contributors to the template's version flow

## The Mental Model

```
.template/CHANGELOG-TEMPLATE.md  →  template release history (the canonical source)
README.md              →  only doc with a template version badge
VERSION                →  consumer-side default (0.0.0 for templates,
                          project version for downstream consumers)
scripts/propagate-version.sh
                       →  reads VERSION, propagates to README + CHANGELOG.md
                       →  general-purpose; works for any consumer project
scripts/bump_patch_version.sh
                       →  reads VERSION, appends a new entry to
                          .template/CHANGELOG-TEMPLATE.md, then runs propagate-version.sh
                       →  general-purpose; downstream consumers use it on
                          their own CHANGELOG.md, not .template/CHANGELOG-TEMPLATE.md
```

**Key rule:** scripts are primary. They are designed for downstream consumer codebases and must keep their `VERSION`-based design unchanged. The template's *own* version lives in `.template/CHANGELOG-TEMPLATE.md`; the scripts and the template version are decoupled by design.

## Required Inputs

- The current template version (read from `.template/CHANGELOG-TEMPLATE.md` `## [X.Y.Z]` heading)
- The desired next template version (e.g., "bump patch")
- The list of files that should display a template version badge (currently: only `README.md`)

## Steps

### 1. Verify the current state

```bash
# Template version (canonical)
grep -E "^## \[[0-9]+\.[0-9]+\.[0-9]+\]" .template/CHANGELOG-TEMPLATE.md | head -1

# Consumer-side VERSION (should be 0.0.0 in a template repo)
cat VERSION

# Only file that displays a template version badge
grep -rn "Template Version" --include="*.md" .
```

### 2. Bump the template version

Edit `.template/CHANGELOG-TEMPLATE.md` directly and add the release heading:

1. Add `## [X.Y.Z] - YYYY-MM-DD` at the top of the released sections, below
   `## [Unreleased]`.
2. Update the `README.md` version badge to match — it is the only doc that shows
   one.
3. Update `sonar.projectVersion` in `sonar-project.properties`. SonarCloud uses it
   to anchor the new-code period, so a stale value silently keeps the window
   open and stops resetting.
4. Leave `VERSION` at `0.0.0`.

Do **not** use `scripts/bump_patch_version.sh` here. It is a downstream-consumer
utility: it derives the new version from `VERSION` (pinned to `0.0.0` in a
template repo), so running it here rewrites the advertised `0.2.14` down to
`0.0.1` instead of bumping anything. It also does not reset `VERSION` afterwards,
which earlier revisions of this document claimed it did. See Common Pitfalls.

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

- **Editing `VERSION` to "fix" the template version.** `VERSION=0.0.0` is intentional; the template's version is in `.template/CHANGELOG-TEMPLATE.md`.
- **Running `scripts/bump_patch_version.sh` in this repository.** It is a
  downstream-consumer utility and it derives everything from `VERSION`, which is
  pinned to `0.0.0` here. Measured in a sandbox, running it writes `0.0.1` into
  `VERSION`, rewrites the `0.2.14` badge in `README.md` down to `0.0.1`, rewrites
  `Template version:` text in `QUICKSTART.md` and `agents-docs/MIGRATION.md`, and
  prepends a bogus `## [0.0.1]` entry to `.template/CHANGELOG-TEMPLATE.md`. It
  does not bump the template version; it corrupts the advertised one. Cut a
  template release by editing `.template/CHANGELOG-TEMPLATE.md`, the `README.md`
  badge and `sonar.projectVersion` by hand, and leave `VERSION` at `0.0.0`.
  Fixing this *inside* the script is the wrong move — see the next pitfall.
- **Adding a "Template Version" badge to a new doc file.** `README.md` is the only one. Link to `README.md` or `.template/CHANGELOG-TEMPLATE.md` instead.
- **Modifying `scripts/propagate-version.sh` or `bump_patch_version.sh` to read from `.template/CHANGELOG-TEMPLATE.md`.** They are general-purpose utilities for downstream consumers. Keep their `VERSION`-based design.
- **Guarding a template-only hazard inside a consumer script.** A template
  concern does not belong in a script that ships to every adopting repository,
  even when the hazard is real and the fix is a three-line guard. Put the
  template-side answer in this file instead.
- **Manually editing the README badge instead of running `propagate-version.sh`.** The script is the source of truth; manual edits get overwritten on the next propagation.
- **Forgetting to reset `VERSION` to `0.0.0` after a template release.** Downstream consumers clone the template and expect a clean starting point.

## References

- `template-versioning/version-flow.md` — Detailed flow diagram of version propagation
- `template-versioning/scripts-inventory.md` — Inventory of version-related scripts
- `.template/CHANGELOG-TEMPLATE.md` — Canonical template release history
- `agents-docs/VERSION.md` — Version management documentation (template + consumer)
- `scripts/propagate-version.sh`, `scripts/bump_patch_version.sh` — General-purpose consumer utilities
- `.github/workflows/version-propagation.yml` — CI workflow on `VERSION` changes
