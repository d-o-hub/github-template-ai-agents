# Version Management

> Single source of truth: `VERSION` file at project root.
>
> **Template note:** in a template repository, `VERSION` is intentionally
> pinned to `0.0.0`. The template's own release history is tracked in
> `CHANGELOG-TEMPLATE.md`, and `README.md` is the only doc that displays a
> template version badge.

## Overview

Version propagation is fully automated. You only edit the `VERSION` file — everything else updates automatically.

In a **template** repository, `VERSION` is intentionally pinned to
`0.0.0`. The template's own release history lives in
`CHANGELOG-TEMPLATE.md`; the only version badge the template displays
is in `README.md`, and `scripts/propagate-version.sh` keeps it in sync
with the value of `VERSION` at the time it was last run. Downstream
consumer repositories reset `VERSION` to their own version on first
use.

## How It Works

```
VERSION (single source)
  ├── pre-commit hook (local dev)
  │     └── scripts/propagate-version.sh
  │
  └── GitHub Actions (CI)
        └── .github/workflows/version-propagation.yml
```

## Bumping Version

```bash
# Edit VERSION file only
echo "0.3.0" > VERSION

# Commit - pre-commit hook propagates automatically
git add VERSION
git commit -m "chore: bump version to 0.3.0"
```

The pre-commit hook detects the VERSION change and runs `propagate-version.sh`, which updates:
- `README.md` - version badge (single source of truth for the template version)
- `CHANGELOG.md` - adds `[Unreleased]` section if missing

For the template's own version history (the human-readable record of
template releases), edit `CHANGELOG-TEMPLATE.md` directly or run
`./scripts/bump_patch_version.sh`. `QUICKSTART.md` and
`agents-docs/MIGRATION.md` do **not** display a template version
badge — `README.md` is the only one.

## Manual Propagation

```bash
./scripts/propagate-version.sh
```

## Versioned Files

| File | Pattern | Updated By |
|------|---------|------------|
| `VERSION` | `0.0.0` (template) or project version (consumer) | Manual edit |
| `README.md` | `version-X.Y.Z` badge | propagate-version.sh |
| `CHANGELOG-TEMPLATE.md` | template release history | bump_patch_version.sh / manual |
| `CHANGELOG.md` | `[Unreleased]` section | propagate-version.sh (if missing) |

## CI Workflow

On push to `main` or `feat/**` branches that change `VERSION`:
1. `.github/workflows/version-propagation.yml` triggers
2. Runs `propagate-version.sh`
3. Commits and pushes any remaining updates

This catches cases where the pre-commit hook was skipped or failed.

## Adding New Versioned Files

If a new file needs version references:
1. Add it to `FILES_TO_UPDATE` array in `scripts/propagate-version.sh`
2. Add appropriate `sed` patterns for the file's version format
3. Update this documentation

## Lessons

- Never manually edit version strings in multiple files — always use `VERSION` + propagate
- The pre-commit hook re-stages propagated files automatically (`git add`)
- CI workflow is a safety net for missed propagations
