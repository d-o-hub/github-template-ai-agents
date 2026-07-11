# Template Version Flow

End-to-end diagram of how a template version moves from authoring to display.

## Sources of Truth

| What | Where | Why |
|------|-------|-----|
| Template release history | `.template/CHANGELOG-TEMPLATE.md` (`## [X.Y.Z]` headings) | Human-readable record; humans edit it |
| Consumer-side default | `VERSION` (always `0.0.0` in a template repo) | Reset by `bump_patch_version.sh`; downstream consumers overwrite on first use |
| Displayed badge | `README.md` only | The only file that shows a template version badge |

## Propagation Path

```
Author edits .template/CHANGELOG-TEMPLATE.md
        │
        ▼
Author runs ./scripts/bump_patch_version.sh
        │
        ├── reads VERSION (0.0.0)
        ├── appends new ## [X.Y.Z] - DATE entry to .template/CHANGELOG-TEMPLATE.md
        ├── resets VERSION back to 0.0.0
        └── runs ./scripts/propagate-version.sh
                │
                ├── reads VERSION (just-reset 0.0.0)
                └── updates README.md badge to "version-0.0.0"
```

**Template repo vs consumer repo**

| Repo type | README badge shows | Source |
|-----------|--------------------|--------|
| **This template** | Template release (e.g. `0.2.11`) | Latest `## [X.Y.Z]` in `.template/CHANGELOG-TEMPLATE.md` (manual badge edit on release) |
| **Consumer project** | Project version | `VERSION` via `propagate-version.sh` |

`VERSION` stays `0.0.0` in the template so new codebases start clean. Do **not**
change `propagate-version.sh` to read `.template/CHANGELOG-TEMPLATE.md` — that
script is for consumers.

## What Goes Wrong

| Symptom | Cause | Fix |
|---------|-------|-----|
| `QUICKSTART.md` shows `version-0.2.0` | Stale badge from an earlier template release | Remove the badge line entirely; `README.md` is the only one |
| `agents-docs/MIGRATION.md` shows `version-0.2.8` | Same as above | Remove the badge line entirely |
| README badge shows `0.0.0` | This is correct for a template repo (it's `VERSION`) | No action; template version is in `.template/CHANGELOG-TEMPLATE.md` |
| `VERSION=0.3.0` after a release | Someone forgot to reset `VERSION` to `0.0.0` | Reset to `0.0.0` and re-run `bump_patch_version.sh` |
| `propagate-version.sh` overwrites badges with `0.0.0` | Expected behavior in a template repo | Don't add new version badges to other docs |

## For Consumer (Downstream) Repos

When a downstream consumer clones the template:

1. They run `./scripts/bootstrap.sh`
2. They edit `VERSION` to their project's version (e.g., `1.0.0`)
3. The pre-commit hook runs `propagate-version.sh` on their `VERSION` change
4. Their `README.md`, `CHANGELOG.md`, etc. get the correct version
5. They delete `.template/CHANGELOG-TEMPLATE.md` and use `CHANGELOG.md` instead

The scripts are designed for this consumer flow. The template repo itself is a special case where `VERSION=0.0.0` is correct.
