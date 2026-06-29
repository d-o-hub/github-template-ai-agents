## 2026-06-28 - Hardening Command Categorization and Forbidden Paths

**Vulnerability:** Limited coverage of destructive commands, interpreters, and sensitive directories allowed potential bypasses of agent security controls. Specifically, variant commands like `mkfs.ext4` could bypass detection if the regex was too strict.
**Learning:** Security keyword lists and forbidden directory denylists must be comprehensive and account for common variations and infrastructure components. Regex boundaries must allow for alphanumeric suffixes and dots to catch command variants while avoiding false positives from script names.
**Prevention:** Periodically review and expand `DESTRUCTIVE_KEYWORDS`, `INTERPRETER_KEYWORDS`, and `FORBIDDEN_OUTPUT_DIRS`. Use broad regex boundaries `[a-z0-9.]*` for command matching while strictly excluding known script extensions.

## 2026-06-29 - Hardened Suffix Pattern for Command Categorization

**Vulnerability:** Greedy suffix matching `[a-z0-9.]*` caused false positives on common words (e.g., `show` matched `sh`, `google` matched `go`).
**Learning:** Suffix patterns for command matching must distinguish between versioned/hyphenated variants and unrelated words. A more restrictive pattern `([.][a-z0-9]+|[0-9-][a-z0-9.]*)?` allows for `python3.11`, `mkfs.ext4`, and `nc-traditional` while rejecting words where the keyword is just a prefix.
**Prevention:** Use structured suffix regexes that require a dot, digit, or hyphen immediately following the keyword when matching command variants.
