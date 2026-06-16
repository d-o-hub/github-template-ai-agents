# Rust Example (Bun + Cargo Side-by-Side)

This directory is a starting point for projects that need a Rust core (for
performance-critical code) alongside a Bun/TypeScript agent layer. The
companion `RUST-patterns.md` collects the canonical patterns this template
uses for any Rust component:

- Toolchain (edition 2021, `cargo fmt`, `cargo clippy -D warnings`)
- Async via Tokio; CPU parallelism via Rayon
- Numeric safety (`f32::total_cmp()`, seeded `StdRng`)
- Memory layout (CSR sparse, no connection pooling for local SQLite)
- 500-line per-file cap; named constants; mermaid diagrams only

See [`RUST-patterns.md`](./RUST-patterns.md) for the full reference.

## Layout

```text
examples/rust/
├── README.md            # this file
├── RUST-patterns.md     # reference patterns for any Rust code
└── (your crates here)   # add agent-core, agent-config, etc. as needed
```

The packages in `examples/monorepo-bun-turbo/packages/` are intentionally
empty scaffolds; this directory is the Rust-shaped counterpart when you
want native performance alongside the Bun agent layer.
