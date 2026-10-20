# Cargo & Rust Subprocess Isolation Reference

This reference provides technical details for isolating child Cargo processes
invoked inside tests or integration test fixtures.

## 1. Environment Variable Interference Matrix

When `cargo test`, `cargo llvm-cov`, or `cargo nextest` runs, it populates
environment variables that can disrupt nested Cargo invocations:

| Variable | Outer Tool | Problem in Child Process | Remediation |
| | | | |
| `CARGO_TARGET_DIR` | `cargo` / CI | Lock contention on target dir | Set child `CARGO_TARGET_DIR` to a tempdir |
| `RUSTFLAGS` | `cargo llvm-cov` | Forces coverage instrumentation | Remove or override in child `Command` |
| `CARGO_ENCODED_RUSTFLAGS` | `cargo` | Overrides `RUSTFLAGS` | Remove in child `Command` |
| `LLVM_PROFILE_FILE` | `llvm-cov` | Child writes raw `.profraw` to outer path | Remove or redirect to child-specific path |
| `CARGO_MAKEFLAGS` | `cargo` | Passes outer GNU make jobserver FDs | Remove in child `Command` |

## 2. Centralized Child Process Command Sanitizer

In Rust test suites, build a centralized helper to instantiate child
`std::process::Command` instances:

```rust
use std::ffi::OsStr;
use std::path::Path;
use std::process::Command;

pub fn isolated_cargo_cmd(target_dir: &Path) -> Command {
    let mut cmd = Command::new("cargo");

    // Direct target outputs to an isolated temporary directory
    cmd.env("CARGO_TARGET_DIR", target_dir);

    // Strip outer compiler and coverage flags
    cmd.env_remove("RUSTFLAGS");
    cmd.env_remove("CARGO_ENCODED_RUSTFLAGS");
    cmd.env_remove("LLVM_PROFILE_FILE");
    cmd.env_remove("CARGO_MAKEFLAGS");

    // Ensure child builds do not attempt interactive prompts
    cmd.env("CARGO_TERM_COLOR", "never");

    cmd
}
```

## 3. Parsing Machine-Readable Coverage Data

Avoid parsing human-readable stdout summary tables, which vary across tool
releases.

### Recommended Pattern (JSON Report)

```bash
# Export structured JSON report
cargo llvm-cov --json --output-path coverage.json
```

```python
import json

def read_line_coverage(json_path: str) -> float:
    with open(json_path, 'r') as f:
        data = json.load(f)
    # Extract line summary statistics from LLVM coverage JSON output
    data_summary = data.get("data", [{}])[0].get("totals", {}).get("lines", {})
    percent = data_summary.get("percent", 0.0)
    return float(percent)
```

## 4. Handling `.profraw` File Litter

When running tests with LLVM coverage enabled:

1. Custom subprocesses running un-sanitized LLVM binaries will write `.profraw`
   files into the working directory if `LLVM_PROFILE_FILE` is unset or contains
   `%p`.
2. Configure `LLVM_PROFILE_FILE` explicitly when child coverage is desired.
3. Ensure test teardown cleans up temporary directories holding profile
   artifacts.
