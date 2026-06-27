## 2026-06-28 - Hardening Command Categorization and Forbidden Paths

**Vulnerability:** Limited coverage of destructive commands, interpreters, and sensitive directories allowed potential bypasses of agent security controls. Specifically, variant commands like `mkfs.ext4` could bypass detection if the regex was too strict.
**Learning:** Security keyword lists and forbidden directory denylists must be comprehensive and account for common variations and infrastructure components. Regex boundaries must allow for alphanumeric suffixes and dots to catch command variants while avoiding false positives from script names.
**Prevention:** Periodically review and expand `DESTRUCTIVE_KEYWORDS`, `INTERPRETER_KEYWORDS`, and `FORBIDDEN_OUTPUT_DIRS`. Use broad regex boundaries `[a-z0-9.]*` for command matching while strictly excluding known script extensions.
