---
name: dist-channel-selection
version: "0.2.10"
category: tool
description: Guide for selecting the correct distribution channel (npm, Cargo, etc.) based on artifact type and target audience. Use when preparing to publish or release a new version of a package.
license: MIT
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

## Rationalizations

| Rationalization | Reality |
|-----------------|---------|
| "I'll skip the dry run — the publish always works." | Dry runs catch packaging errors, missing files, and metadata issues that silently corrupt published artifacts. |
| "The VERSION file doesn't need to match package.json." | Version mismatches confuse consumers, break CI/CD pipelines, and invalidate changelog entries. |

## Red Flags

- [ ] Publishing without running the dry-run command first
- [ ] Forgetting to update CHANGELOG.md before publishing
- [ ] Skipping quality gate checks prior to release

## References

- `AGENTS.md` - Version management policy
- `scripts/wasm_size_gate.sh` - WASM size enforcement
