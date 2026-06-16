# Template Version Flow

End-to-end diagram of how a template version moves from authoring to display.

## Sources of Truth

| What | Where | Why |
|------|-------|-----|
| Template release history | `CHANGELOG-TEMPLATE.md` (`## [X.Y.Z]` headings) | Human-readable record; humans edit it |
| Consumer-side default | `VERSION` (always `0.0.0` in a template repo) | Reset by `bump_patch_version.sh`; downstream consumers overwrite on first use |
| Displayed badge | `README.md` only | The only file that shows a template version badge |

## Propagation Path

```
Author edits CHANGELOG-TEMPLATE.md
        │
        ▼
Author runs ./scripts/bump_patch_version.sh
        │
        ├── reads VERSION (0.0.0)
        ├── appends new ## [X.Y.Z] - DATE entry to CHANGELOG-TEMPLATE.md
        ├── resets VERSION back to 0.0.0
        └── runs ./scripts/propagate-version.sh
                │
                ├── reads VERSION (just-reset 0.0.0)
                └── updates README.md badge to "version-0.0.0"
```

**Wait — does that mean the README badge is always `0.0.0`?**

Yes. In a template repo, the README badge shows `VERSION` (0.0.0), not the template's release version. The template's release history is in `CHANGELOG-TEMPLATE.md`. The README badge in a template repo therefore intentionally displays `0.0.0` — it's the consumer-side value, not the template release version.

If the README should display the template release version (e.g., `0.2.10`), the maintainer manually edits the badge or the propagation script is updated — but updating the script breaks downstream consumers, so manual edits are the conventional approach for templates.

## What Goes Wrong

| Symptom | Cause | Fix |
|---------|-------|-----|
| `QUICKSTART.md` shows `version-0.2.0` | Stale badge from an earlier template release | Remove the badge line entirely; `README.md` is the only one |
| `agents-docs/MIGRATION.md` shows `version-0.2.8` | Same as above | Remove the badge line entirely |
| README badge shows `0.0.0` | This is correct for a template repo (it's `VERSION`) | No action; template version is in `CHANGELOG-TEMPLATE.md` |
| `VERSION=0.3.0` after a release | Someone forgot to reset `VERSION` to `0.0.0` | Reset to `0.0.0` and re-run `bump_patch_version.sh` |
| `propagate-version.sh` overwrites badges with `0.0.0` | Expected behavior in a template repo | Don't add new version badges to other docs |

## For Consumer (Downstream) Repos

When a downstream consumer clones the template:

1. They run `./scripts/bootstrap.sh`
2. They edit `VERSION` to their project's version (e.g., `1.0.0`)
3. The pre-commit hook runs `propagate-version.sh` on their `VERSION` change
4. Their `README.md`, `CHANGELOG.md`, etc. get the correct version
5. They delete `CHANGELOG-TEMPLATE.md` and use `CHANGELOG.md` instead

The scripts are designed for this consumer flow. The template repo itself is a special case where `VERSION=0.0.0` is correct.
