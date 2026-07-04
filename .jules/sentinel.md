## 2026-06-28 - Hardening Command Categorization and Forbidden Paths

**Vulnerability:** Limited coverage of destructive commands, interpreters, and sensitive directories allowed potential bypasses of agent security controls. Specifically, variant commands like `mkfs.ext4` could bypass detection if the regex was too strict.
**Learning:** Security keyword lists and forbidden directory denylists must be comprehensive and account for common variations and infrastructure components. Regex boundaries must allow for alphanumeric suffixes and dots to catch command variants while avoiding false positives from script names.
**Prevention:** Periodically review and expand `DESTRUCTIVE_KEYWORDS`, `INTERPRETER_KEYWORDS`, and `FORBIDDEN_OUTPUT_DIRS`. Use broad regex boundaries `[a-z0-9.]*` for command matching while strictly excluding known script extensions.

## 2026-06-29 - Hardened Suffix Pattern for Command Categorization

**Vulnerability:** Greedy suffix matching `[a-z0-9.]*` caused false positives on common words (e.g., `show` matched `sh`, `google` matched `go`).
**Learning:** Suffix patterns for command matching must distinguish between versioned/hyphenated variants and unrelated words. A more restrictive pattern `([.][a-z0-9]+|[0-9-][a-z0-9.]*)?` allows for `python3.11`, `mkfs.ext4`, and `nc-traditional` while rejecting words where the keyword is just a prefix.
**Prevention:** Use structured suffix regexes that require a dot, digit, or hyphen immediately following the keyword when matching command variants.

## 2026-06-30 - Expanded Sensitive Command and Path Coverage

**Vulnerability:** Gaps in command categorization and forbidden path lists allowed potential execution of sensitive system tools and access to credential files.
**Learning:** Security boundaries must be frequently audited to include data-exfiltration tools (tar, zip), networking utilities (telnet, ftp), and ecosystem-specific configuration files (.npmrc, .ssh).
**Prevention:** Maintain comprehensive lists of sensitive keywords and paths that prioritize "fail-secure" defaults for agent operations.

## 2026-07-03 - Hardening Command Categorization and Forbidden Paths

**Vulnerability:** Gaps in forbidden path denylists and command categorization allowed potential access to cloud provider credentials (e.g., .aws, .kube) and execution of system-critical tools (e.g., firewall-cmd, crontab).
**Learning:** Security boundaries must be frequently audited to include infrastructure-specific configuration files and administrative utilities that could be used for persistence or lateral movement.
**Prevention:** Expand `FORBIDDEN_PATHS` and command keyword lists to cover ecosystem-specific secrets and administrative tools.

## 2026-07-04 - Fix Path Validation Bypass for Nested Forbidden Paths

**Vulnerability:** The `validate_safe_path` function only checked if the top-level component of a path was in `FORBIDDEN_PATHS`, allowing bypasses for nested sensitive files (e.g., `subdir/.env`).
**Learning:** Security validation must be recursive or iterative over all user-controllable path components. Checking only the root of a relative path is insufficient when subdirectories are allowed.
**Prevention:** Always iterate through all parts of a resolved path when checking against a denylist of forbidden files or directories.
