## 2026-06-28 - Hardening Command Categorization and Forbidden Paths

**Vulnerability:** Limited coverage of destructive commands, interpreters, and sensitive directories allowed potential bypasses of agent security controls. Specifically, variant commands like `mkfs.ext4` could bypass detection if the regex was too strict.
**Learning:** Security keyword lists and forbidden directory denylists must be comprehensive and account for common variations and infrastructure components. Regex boundaries must allow for alphanumeric suffixes and dots to catch command variants while avoiding false positives from script names.
**Prevention:** Periodically review and expand `DESTRUCTIVE_KEYWORDS`, `INTERPRETER_KEYWORDS`, and `FORBIDDEN_OUTPUT_DIRS`. Use broad regex boundaries `[a-z0-9.]*` for command matching while strictly excluding known script extensions.

## 2026-07-15 - Hardening Keyword Matching Against False Positives

**Vulnerability:** Greedy suffix matching (`[a-z0-9.]*`) after security keywords caused unrelated commands to be flagged as dangerous (e.g., `nslookup` matching `node`, `google` matching `go`, `shout` matching `sh`).
**Learning:** Command variant matching must distinguish between legitimate versioned binaries/subcommands (which typically start with a digit or dot) and unrelated words that happen to contain the keyword as a prefix.
**Prevention:** Use constrained suffix patterns like `([.][a-z0-9]+|[0-9][a-z0-9.]*)?` instead of broad alphanumeric globs when matching command variants to ensure the suffix belongs to a version or extension of the intended command.
