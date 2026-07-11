# Version Management

> Single source of truth: `VERSION` file at project root.
>
> **Template note:** in a template repository, `VERSION` is intentionally
> pinned to `0.0.0` for **downstream projects**. The template's own release
> history is tracked in `.template/CHANGELOG-TEMPLATE.md`. In *this* template
> repo, `README.md` shows the **template** version badge (from the latest
> `## [X.Y.Z]` in `.template/CHANGELOG-TEMPLATE.md`). After you use the
> template, only `VERSION` drives the README badge.

## Overview

**Two different version concepts:**

| Concept | Source of truth | Displayed in |
|---------|-----------------|--------------|
| Template release | `.template/CHANGELOG-TEMPLATE.md` | README badge **in the template repo only** |
| Project / consumer version | `VERSION` (start `0.0.0`) | README badge **after** you adopt the template |

For a **consumer** repository: edit `VERSION`, then `propagate-version.sh`
(or the pre-commit hook) updates README and related files.

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
- `README.md` - project version badge (consumer repos)
- `CHANGELOG.md` - adds `[Unreleased]` section if missing

For the **template's own** release history, edit `.template/CHANGELOG-TEMPLATE.md`
and set the README template badge to match the new `## [X.Y.Z]` heading.
Do not change `VERSION` away from `0.0.0` in the template repo.
`QUICKSTART.md` and `agents-docs/MIGRATION.md` do **not** display a version badge.

## Manual Propagation

```bash
./scripts/propagate-version.sh
```

## Versioned Files

| File | Pattern | Updated By |
|------|---------|------------|
| `VERSION` | `0.0.0` (template) or project version (consumer) | Manual edit |
| `README.md` | `version-X.Y.Z` badge | propagate-version.sh |
| `.template/CHANGELOG-TEMPLATE.md` | template release history | bump_patch_version.sh / manual |
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
