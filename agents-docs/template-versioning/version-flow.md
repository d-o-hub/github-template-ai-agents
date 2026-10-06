# Template Version Flow

Separate the template's release identity from the version of a product created
from it. The scripts below describe current behavior, not an automatic reset or
an inferred downstream release policy.

## Sources of Truth

| What | Where | Why |
|------|-------|-----|
| Template release history | `.template/CHANGELOG-TEMPLATE.md` (`## [X.Y.Z]` headings) | Human-readable record; humans edit it |
| Consumer placeholder here | Root `VERSION`, currently `0.0.0` | Starting value for adopters; not the template release number |
| Consumer product version | Downstream root `VERSION` | Product source of truth once the team sets its version policy |
| Template display | `README.md` template-version badge | Displays the template release, independently of the placeholder |

The template's release history is in `.template/CHANGELOG-TEMPLATE.md`; its
README badge currently reflects that history, not `VERSION=0.0.0`. There is no
automatic changelog-to-badge synchronization in the scripts below. Maintainers
must keep template release history/display consistent deliberately.

## Actual Patch-Bump Path

`scripts/bump_patch_version.sh`:

1. Reads root `VERSION` and validates a numeric `major.minor.patch` value.
2. Increments its patch component; it does **not** read the latest template
   release heading to choose the next version.
3. Summarizes recent commits into a new release entry immediately after
   `.template/CHANGELOG-TEMPLATE.md`'s `## [Unreleased]` heading. That file and
   heading must exist.
4. Writes the incremented value back to `VERSION`.
5. Runs `scripts/propagate-version.sh` using that new value.

**It never resets `VERSION` to `0.0.0`.** Starting from the template placeholder
would create a `0.0.1` entry, not the next release after the latest template
heading. Do not run it as a generic template-release step or as a reset command.

## Actual Propagation Path

`scripts/propagate-version.sh` reads and validates root `VERSION`. It substitutes
matching version badges, `Template version:` text, `**Version:**` text, and
`VERSION` table values in its fixed list of existing files:

- `README.md`, `QUICKSTART.md`, `agents-docs/MIGRATION.md`
- `.template/CHANGELOG-TEMPLATE.md`, `agents-docs/VERSION.md`
- `analysis/SWARM_ANALYSIS.md`

Missing listed files are warned about and skipped. The script does not discover
all project manifests or synchronize a package registry version. It does not
rewrite numbered release headings; for root `CHANGELOG.md` it only adds an
`## [Unreleased]` heading if absent.

Running propagation here with the placeholder can overwrite the template badge
with `0.0.0`; that is a script side effect, **not** the intended template release
display. Inspect diffs before an authorized release, and do not propagate the
consumer placeholder to “fix” a template badge.

## Hook Behavior

If the supplied pre-commit hook is configured, staging `VERSION` triggers
propagation. It then attempts to re-stage `README.md`, `QUICKSTART.md`,
`agents-docs/MIGRATION.md`, and `CHANGELOG.md` before running the quality gate.
That list is smaller than the propagation target list, so review both staged
and unstaged changes. Bootstrap configures the hook but does not itself bump
the version. These commands mutate files; use them deliberately, not as checks.

## For Downstream Product Repositories

1. Set `VERSION` to the product's version and replace template badges/URLs in
   the product README. Keep a product changelog separately from template history.
2. Decide whether to retain/adapt the release scripts, version-propagation
   workflow, and hook. Align their target files with the product's manifests,
   documentation, and package manager.
3. If deleting `.template/CHANGELOG-TEMPLATE.md`, replace the bump script's
   changelog target first; otherwise the existing bump command fails. The
   propagation script tolerates a missing file, but the bump script does not.
4. Verify resulting diffs and run the product's checks. Neither a version edit
   nor an implementation task authorizes a commit, push, tag, or release.

Current template maintainers retain their release history and placeholder
policy. Downstream cleanup is documented in [Adoption Profiles](../ADOPTION_PROFILES.md).
