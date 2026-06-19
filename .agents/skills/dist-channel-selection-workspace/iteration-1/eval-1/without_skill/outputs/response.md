# Publishing a Rust Library to crates.io

## Prerequisites

1. **Create a crates.io account**: Go to [crates.io](https://crates.io) and sign in with your GitHub account.
2. **Generate an API token**: Go to Account Settings → API Tokens → New Token. Copy the token.
3. **Log in via CLI**: Run `cargo login <your-token>` to authenticate.

## Prepare Your Library

1. **Ensure your `Cargo.toml` is correct**:
   - `name`: Unique name (check [crates.io](https://crates.io) to ensure it's not taken).
   - `version`: Semantic version (e.g., `0.1.0`).
   - `license` or `license-file`: Required (e.g., `MIT`, `Apache-2.0`).
   - `description`: Short summary (required).
   - `repository`: URL to your Git repo (recommended).
   - `keywords` or `categories`: Helps discoverability (optional but recommended).

2. **Verify your library builds**:
   ```bash
   cargo build
   cargo test
   ```

3. **Check for issues**:
   ```bash
   cargo publish --dry-run
   ```
   This simulates publishing without actually uploading. Fix any warnings or errors.

## Publish

```bash
cargo publish
```

If successful, your library is live at `https://crates.io/crates/<your-crate-name>`.

## Post-Publish

- **Tag the release**: `git tag v0.1.0 && git push --tags`
- **Update version**: Bump `version` in `Cargo.toml` for the next release.
- **Document**: Update your README with installation instructions (`cargo add <crate>`).

## Common Issues

- **Name taken**: Choose a different name or use a prefix (e.g., `myorg-`).
- **Missing license**: Add `license = "MIT"` (or appropriate) to `Cargo.toml`.
- **Build failures**: Ensure `cargo build` and `cargo test` pass locally.
- **Token issues**: Re-run `cargo login` with a fresh token if authentication fails.

## Versioning

Follow semantic versioning (`MAJOR.MINOR.PATCH`):
- `MAJOR`: Breaking changes.
- `MINOR`: New features (backward-compatible).
- `PATCH`: Bug fixes.

Once published, a version cannot be reused—yank if needed (`cargo yank --version <version>`).
