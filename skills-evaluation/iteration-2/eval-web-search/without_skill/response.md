# Rust Error Handling Best Practices (2026)

## Overview

Rust's error handling has matured significantly. The ecosystem now centers on two complementary crates—**thiserror** (v2.x) for libraries and **anyhow** (v1.x) for applications—alongside stable standard library features.

---

## 1. Core Principles

- **Use `Result<T, E>` for recoverable errors**, `panic!` only for unrecoverable/unreachable states (bugs, contract violations).
- **Never use `.unwrap()` or `.expect()` in production code** except in tests or where a panic is genuinely intended.
- **Propagate errors with `?`** — the operator converts via `From` and bubbles up automatically.

---

## 2. Library Error Types with `thiserror` (v2.x)

`thiserror` is the standard for defining public error enums in libraries. It derives `std::error::Error` and `Display` without polluting your public API.

```rust
use thiserror::Error;

#[derive(Error, Debug)]
pub enum DataStoreError {
    #[error("data store disconnected")]
    Disconnect(#[from] io::Error),

    #[error("the data for key `{0}` is not available")]
    Redaction(String),

    #[error("invalid header (expected {expected:?}, found {found:?})")]
    InvalidHeader { expected: String, found: String },

    #[error("unknown data store error")]
    Unknown,
}
```

### Key patterns:
- **`#[from]`**: Auto-generates `From` impl and marks field as `#[source]`.
- **`#[source]`**: Marks the underlying error without generating `From`.
- **`#[error(transparent)]`**: Forwards `Display` and `source()` to inner error (use for "anything else" variants or opaque public types).
- **Backtrace support**: Fields named `Backtrace` are auto-detected; `#[backtrace]` shares a backtrace with the source.

---

## 3. Application-Level Handling with `anyhow` (v1.x)

`anyhow` provides a single `anyhow::Error` type for applications where you don't need callers to match on variants.

```rust
use anyhow::{Context, Result};

fn load_config(path: &str) -> Result<Config> {
    let content = std::fs::read_to_string(path)
        .with_context(|| format!("Failed to read config from {}", path))?;
    let config: Config = serde_json::from_str(&content)
        .context("Failed to parse config")?;
    Ok(config)
}
```

### Key patterns:
- **`.context(msg)` / `.with_context(|| msg)`**: Wraps errors with human-readable context.
- **`bail!(msg)`**: Early return with an error.
- **`ensure!(condition, msg)`**: Conditional early return.
- **`anyhow!(msg)`**: Construct ad-hoc errors.
- **Downcasting**: `error.downcast_ref::<T>()` to recover concrete types.
- **Backtraces**: Automatic on nightly/stable when `RUST_BACKTRACE=1` or `RUST_LIB_BACKTRACE=1`.

---

## 4. When to Use Which

| Scenario | Recommended |
|---|---|
| Library (public API) | `thiserror` enums |
| Application / binary | `anyhow::Result<T>` |
| Both in same project | Library exposes `thiserror` enums; app wraps them with `anyhow` via `#[from]` or `.context()` |
| Embedded / no-std | `anyhow` with `default-features = false` + global allocator |

---

## 5. Modern Idioms (2026)

- **`std::error::Error` is stable** — use it as the bound for generic error handling.
- **`?` operator is ergonomic** — chains with `From`, `.map_err()`, and `.context()`.
- **`error(transparent)` for API evolution** — hide internal repr behind an opaque public error type:
  ```rust
  #[derive(Error, Debug)]
  #[error(transparent)]
  pub struct PublicError(#[from] ErrorRepr);

  #[derive(Error, Debug)]
  enum ErrorRepr { /* private, free to change */ }
  ```
- **Error context is essential** — low-level errors like "No such file or directory" are unhelpful without context about what operation was attempted.
- **Don't over-specify error types** — in application code, `anyhow` is preferred; reserve specific enums for library boundaries.
- **Avoid `Box<dyn Error>`** — use `anyhow::Error` or `thiserror` enums instead.

---

## 6. Error Handling Anti-Patterns to Avoid

- Using `panic!` for expected failures (use `Result` instead).
- Swallowing errors silently (always propagate or log).
- Overly granular error enums in application code (use `anyhow`).
- Using `.unwrap()` outside of tests or prototyping.
- Forgetting to add context when propagating errors across abstraction layers.

---

## Sources

- [The Rust Programming Language — Error Handling](https://doc.rust-lang.org/book/ch09-00-error-handling.html)
- [thiserror 2.0.18 documentation](https://docs.rs/thiserror/latest/thiserror/)
- [anyhow 1.0.102 documentation](https://docs.rs/anyhow/latest/anyhow/)
