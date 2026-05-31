---
name: dist-channel-selection
version: "0.2.10"
description: Guide for selecting the correct distribution channel (npm, Cargo, etc.) based on artifact type and target audience. Use when preparing to publish or release a new version of a package.
---

# Distribution Channel Selection

Ensure artifacts are published to the correct channels with appropriate verification.

## Decision Matrix

| Artifact Type | Channel | Primary Verification | Dry Run Command |
|---------------|---------|----------------------|-----------------|
| Rust library  | crates.io | `cargo test`         | `cargo publish --dry-run` |
| WASM library  | npm     | `scripts/wasm_size_gate.sh` | `npm pack --dry-run` |
| CLI (Node)    | npm     | `npm test`           | `npm pack --dry-run` |
| CLI (Rust)    | GitHub/npm | `scripts/quality_gate.sh` | `cargo build --release` |

## Preconditions

- [ ] Version bumped in `VERSION` file.
- [ ] `CHANGELOG.md` updated with new version details.
- [ ] `./scripts/quality_gate.sh` passes locally.
- [ ] All CI checks are green.

## Publishing Process

### 1. Verification

Run the domain-specific verification tools (e.g., WASM size gates, LOC enforcement).

### 2. Dry Run

Always perform a dry run before the final publish to catch packaging issues.

### 3. Final Publish

Use the official toolchain for the selected channel.

## Common Pitfalls

- Publishing WASM binaries without size verification.
- Forgetting to sync the `VERSION` file across sub-packages.
- Incomplete CHANGELOG leading to consumer confusion.

## References

- `AGENTS.md` - Version management policy
- `scripts/wasm_size_gate.sh` - WASM size enforcement
