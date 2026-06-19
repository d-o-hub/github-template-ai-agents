# Publishing a Rust Library to crates.io

## Preconditions

- [ ] Version bumped in the `VERSION` file (root of the repository).
- [ ] `CHANGELOG.md` updated with the new version details.
- [ ] `./scripts/quality_gate.sh` passes locally (if available in the project).
- [ ] All CI checks are green (GitHub Actions, etc.).

## Step 1: Verification

Run the primary verification command for Rust libraries:

```bash
cargo test
```

Ensure all tests pass and there are no compilation warnings.

## Step 2: Dry Run

Always perform a dry run before the final publish to catch packaging issues:

```bash
cargo publish --dry-run
```

This simulates the publish process without actually uploading to crates.io. It will catch:
- Missing or incorrect `Cargo.toml` metadata
- Files that are excluded but needed
- Packaging errors

## Step 3: Final Publish

Once the dry run succeeds and all preconditions are met, run:

```bash
cargo publish
```

This will upload your library to crates.io and make it publicly available.

## Common Pitfalls

- **Skipping the dry run**: Dry runs catch packaging errors, missing files, and metadata issues that silently corrupt published artifacts.
- **Incomplete CHANGELOG**: Leads to consumer confusion and makes it hard for users to understand what changed.
- **Skipping quality gate checks**: Always run the project's quality gate (if available) before releasing.
- **Version mismatches**: Ensure the `VERSION` file matches the version in `Cargo.toml`.

## Red Flags

- [ ] Publishing without running `cargo publish --dry-run` first
- [ ] Forgetting to update `CHANGELOG.md` before publishing
- [ ] Skipping quality gate checks prior to release