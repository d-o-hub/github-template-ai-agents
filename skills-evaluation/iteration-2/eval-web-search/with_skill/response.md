## Summary

Rust error handling in 2026 continues to revolve around `Result<T, E>` and `Option<T>` as the foundational types, with the ecosystem matured around two dominant crates: **thiserror 2.0.18** (for library-defined typed errors) and **anyhow 1.0.102** (for application-level error handling with context). The `?` operator remains the primary mechanism for error propagation, and the community has converged on clear guidelines for when to use each tool.

## Findings

### Official Rust Book (Error Handling Chapter)
**Source**: https://doc.rust-lang.org/book/ch09-00-error-handling.html
**Key Info**:
- Rust groups errors into two categories: **recoverable** (`Result<T, E>`) and **unrecoverable** (`panic!` macro)
- No exceptions — errors are handled at compile time, ensuring all error paths are acknowledged before deployment
- This dual-model approach is a core design choice, not a limitation

### dasroot.net — Rust Error Handling: Result, Option, and the ? Operator Mastered
**Source**: https://dasroot.net/posts/2026/01/rust-error-handling-result-option-question-operator/
**Published**: February 1, 2026
**Key Info**:
- The `?` operator unwraps `Ok`/`Some` and returns `Err`/`None` early, eliminating nested `match` statements
- A 2026 benchmark study by the Rust Performance Working Group found codebases using `Result`/`Option` consistently had **30% fewer runtime errors** compared to exception-based approaches
- `thiserror` 1.6.0 with `#[derive(Error)]` and `#[from]` enables custom error types with automatic conversion
- `anyhow` crate is "now recommended in many projects" for unified error handling with both `Result` and `Option`
- Combinators (`map`, `and_then`, `or_else`) enable clean transformation and recovery chains
- Rust 1.75 (2025) introduced new linting rules (`missing_match_arms`) to catch common `Result`/`Option` handling mistakes

### reintech.io — Rust Error Handling Best Practices: Result, Option, and Beyond
**Source**: https://reintech.io/blog/rust-error-handling-best-practices-result-option-beyond
**Published**: February 5, 2026
**Key Info**:
- **Library code → `thiserror`**: consumers need to match on specific errors
- **Application code → `anyhow`**: focus on error messages and context for debugging
- **Binary/CLI tools → `anyhow`**: users need helpful error messages
- **Public API → `thiserror`**: typed errors are part of the contract
- Custom error types should implement `Display` (for user-facing messages) and `From` (for type conversion)
- `anyhow::Context` adds descriptive context as errors propagate up the call stack, preserving the original error chain
- **Clippy lints to enable**: `unwrap_used = "deny"`, `expect_used = "warn"`, `panic = "deny"`
- Migration strategy from `unwrap()`: audit → categorize → start at edges → work inward → add tests
- Async error handling: `tokio::try_join!` runs multiple futures concurrently and returns early on any failure

### anyhow 1.0.102 (docs.rs)
**Source**: https://docs.rs/anyhow/latest/anyhow/
**Key Info**:
- `Result<T, anyhow::Error>` (or `anyhow::Result<T>`) as the return type for any fallible function
- `?` propagates any error implementing `std::error::Error`
- `anyhow::Context` trait provides `.context()` and `.with_context()` for adding descriptive context
- Backtrace capture supported on Rust ≥ 1.65 via `RUST_BACKTRACE=1` or `RUST_LIB_BACKTRACE=1`
- Supports `no_std` mode with `default-features = false`
- `anyhow!` macro for ad-hoc error messages; `bail!` for early returns; `ensure!` for conditional early returns

### thiserror 2.0.18 (docs.rs)
**Source**: https://docs.rs/thiserror/latest/thiserror/
**Key Info**:
- Derive macro for `std::error::Error` — zero boilerplate
- `#[from]` attribute generates `From` impl for automatic error conversion via `?`
- `#[source]` attribute for error chaining (returned by `Error::source()`)
- `#[backtrace]` attribute for backtrace capture (nightly Rust ≥ 1.73)
- `error(transparent)` forwards source and Display to an underlying error — useful for "anything else" variants or hiding implementation details
- Errors can be enums, structs with named fields, tuple structs, or unit structs
- Deliberately does not appear in your public API — same as hand-written impls

### color-eyre 0.6.5 (docs.rs)
**Source**: https://docs.rs/color-eyre/latest/color_eyre/
**Key Info**:
- Colorful, well-formatted error reports for panics and `eyre::Reports`
- Integrates with `tracing-error` for SpanTrace capture (cheaper than backtraces)
- Three verbosity levels: minimal, short (with backtrace), full (with source lines)
- Custom `Section` trait for attaching extra context (e.g., stdout/stderr from commands)
- `RUST_SPANTRACE=0` disables span trace capture; `RUST_LIB_BACKTRACE=1` enables short backtrace format

### Rust 1.95.0 (April 16, 2026)
**Source**: https://doc.rust-lang.org/beta/releases.html
**Key Info**:
- Stabilized `if let` guards on match arms — enables more expressive pattern matching in error handling
- Rust 1.94.0 (March 2026) stabilized `AtomicPtr::update`/`try_update` and other APIs
- No direct error-handling language changes in recent releases — the feature set is mature
- Current stable Rust: 1.95.0; beta: 1.97.0-beta.4

## Resources
- [The Rust Book — Error Handling](https://doc.rust-lang.org/book/ch09-00-error-handling.html) — Official fundamentals
- [dasroot.net — Rust Error Handling Mastered](https://dasroot.net/posts/2026/01/rust-error-handling-result-option-question-operator/) — Comprehensive 2026 guide
- [reintech.io — Best Practices](https://reintech.io/blog/rust-error-handling-best-practices-result-option-beyond) — Practical patterns and migration strategy
- [anyhow docs](https://docs.rs/anyhow/latest/anyhow/) — Application error handling
- [thiserror docs](https://docs.rs/thiserror/latest/thiserror/) — Library error type derivation
- [color-eyre docs](https://docs.rs/color-eyre/latest/color_eyre/) — Colorful error reporting
- [Rust Release Notes](https://doc.rust-lang.org/beta/releases.html) — Latest version info

## Gaps
- No dedicated 2026 blog post from blog.rust-lang.org specifically on error handling (the Rust blog focuses on release announcements)
- Limited information on Rust 2027 edition error handling changes (none announced yet)
- The `eyre` crate (parent of `color-eyre`) docs were not directly fetched — covered via `color-eyre` and `anyhow` references
- No direct comparison benchmarks between `thiserror` 2.0 and 1.x performance characteristics
