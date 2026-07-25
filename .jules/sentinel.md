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

## 2026-07-05 - Fix Command Categorization Masking Bypass
**Vulnerability:** Command strings containing both a dangerous command (e.g., \`rm -rf /\`) and a safe-looking script name (e.g., \`rm.sh\`) were incorrectly exempt from dangerous categorization. This occurred because a single positive script-pattern match would short-circuit the entire validation logic.
**Learning:** Security validation of command strings must be exhaustive. If a command string contains multiple occurrences of a keyword, every occurrence must be validated against safety patterns. A single "safe" instance cannot be allowed to mask other dangerous instances in the same string.
**Prevention:** Use iterative matching (e.g., a \`while\` loop with \`BASH_REMATCH\`) to ensure every keyword instance in a command string is inspected. If any instance fails the safety check, the entire string must be treated as dangerous.

## 2026-07-06 - Hardened Regex Keyword Matching with Dot Escaping
**Vulnerability:** Keywords containing literal dots (e.g., \`nc.openbsd\`) were being used directly in regex construction, allowing the dot to be interpreted as a wildcard. This could lead to false positives (e.g., \`ncXopenbsd\`) or potential bypasses if used for exclusion.
**Learning:** When building regular expressions from a list of keywords that may contain special characters like dots, those characters must be escaped first. Native Bash parameter expansion \`\${VAR//./\\\\.}\` is an efficient way to handle this before regex construction.
**Prevention:** Always escape literal dots and other shell/regex metacharacters in security keywords before incorporating them into a larger regular expression. Use specific boundaries and hardened suffix patterns to ensure exact matching of command variants.

## 2026-07-07 - Case-Insensitive Forbidden Path Validation

**Vulnerability:** Path validation checks against `FORBIDDEN_PATHS` were case-sensitive, potentially allowing bypasses using alternate casing (e.g., `.GIT`, `.Env`) on case-insensitive filesystems or as a general oversight.
**Learning:** Security denylists for file and directory names must be enforced case-insensitively to account for cross-platform filesystem behavior and to prevent simple obfuscation bypasses.
**Prevention:** Always normalize path components (e.g., to lowercase) before comparing them against a denylist of forbidden names. Pre-calculating a lowercase set of forbidden strings improves performance.

## 2026-07-08 - Blocking Unspecified IPv6 Address in SSRF Protection
**Vulnerability:** The `do-web-doc-resolver` skill's SSRF protection did not explicitly block the unspecified IPv6 address `[::]`, which can be used to access services on the local host on many systems.
**Learning:** SSRF protection must account for all representations of localhost, including both IPv4 (`0.0.0.0`, `127.0.0.1`) and IPv6 (`::1`, `::`) variants. The unspecified address `::` is often treated as localhost by networking stacks.
**Prevention:** Explicitly include `::` in hostname blocklists and `::/128` in network blocklists for all SSRF validation logic.

## 2026-07-14 - Harden Command Categorization against Env Var Injection
**Vulnerability:** Command categorization could be bypassed by prefixing dangerous commands with environment variable assignments (e.g., `LD_PRELOAD=./evil.so ls`). The '=' and '+' characters were not being normalized, causing keywords to be merged and missed by the boundary-based regex.
**Learning:** Environment variable assignments are often used in shell commands and can contain both dangerous variables themselves and act as a bypass mechanism for keyword detection. Normalization must include assignment operators to ensure proper tokenization of commands.
**Prevention:** Always include '=' and '+' in the list of normalized characters for command string analysis. Maintain a list of dangerous environment variables to flag even when they are used at the start of a command without `env`.

## 2026-07-15 - Hardening Forbidden Paths with Pattern Blocking

**Vulnerability:** Static denylists for forbidden paths were insufficient to catch variations of sensitive files like custom environment files (e.g., .env.local) or credential files with various names (e.g., cert.pem, key.pfx).
**Learning:** Security validation must combine explicit denylists with pattern-based matching to provide broader coverage against known sensitive file types and naming conventions.
**Prevention:** Implement suffix and prefix matching in path validation logic to block entire classes of sensitive files (e.g., *.pem, *.key, .env*) in addition to maintaining a comprehensive list of specific forbidden filenames.

## 2026-07-22 - Pattern-Based SSH Private Key Blocking and Multi-VCS Hardening

**Vulnerability:** Static exact-matching of specific SSH key names (e.g., `id_rsa`, `id_ed25519`) failed to block SSH keys using newer algorithms (e.g., `id_ed25519_sk`, `id_ecdsa_sk`), custom suffixes, or backups (e.g., `id_rsa_backup`, `id_rsa.old`). Additionally, other version control systems like Mercurial (`.hg`) and Subversion (`.svn`) were not explicitly blocked in forbidden path validation.
**Learning:** Hardcoded lists of exact filenames are prone to omissions. Combining prefix and suffix matching allows blocking an entire class of sensitive keys (such as any file starting with `id_rsa` or similar that does not end with `.pub`) while allowing public keys, ensuring robust coverage for alternative structures and metadata.
**Prevention:** Apply dynamic prefix-based patterns in combination with exclusion lists (e.g., `not endswith('.pub')`) to block private key variations. Expand static denylists to encompass alternative VCS folders and shell histories to enforce comprehensive coverage.

## 2026-07-20 - Dynamic Pattern-Based SSH Private Key Prefix Blocking

**Vulnerability:** Static path denylists for specific filenames like `id_rsa` or `id_ed25519` are insufficient to prevent access/exposure of SSH private keys with custom/dynamic names (e.g. `id_rsa_personal`, `id_ed25519_github`).
**Learning:** Security validation logic must use wildcard or pattern-based prefix matching to capture all variants of SSH private keys, while safely exempting public key counterparts (ending with `.pub`) to avoid breaking valid references.
**Prevention:** In `validate_safe_path`, block any path component starting with standard SSH key prefixes (`id_rsa`, `id_dsa`, `id_ecdsa`, `id_ed25519`, `id_xmss`) if they do not end with `.pub`.

## 2026-07-23 - Hardening Pattern-Based Key and Certificate Blocking in Path Validation

**Vulnerability:** Path validation rules did not cover certificate and keystore formats like `.p12`, `.pkcs8`, `.pk8`, `.der`, `.keystore`, `.jks`, `.dockercfg`, and `.publishsettings`. It also omitted default names for SSH keys like `identity` which could be used to reference private keys.
**Learning:** Path validation checks based on extensions/prefixes must cover all common cryptographic, credential, and keystore formats used in modern systems. Limiting the blocklist to standard filenames (like `id_rsa`) leaves alternate naming schemes vulnerable.
**Prevention:** Continuously audit and enrich pattern-based path filters to capture all credential-related suffixes (.p12, .pkcs8, .pk8, .der, .keystore, .jks, .dockercfg, .publishsettings) and default names (identity) while exempting their public counterparts.

## 2026-07-24 - Harden Forbidden Paths with Cloud and Package Configs

**Vulnerability:** Path validation checks omitted directories and configuration files containing cloud platform credentials and private package repository tokens (such as `.cargo`, `.s3cfg`, `.boto`, `.gcloud`, and `.azure`). This omission left sensitive local host files vulnerable to accidental access or exposure.
**Learning:** A static denylist of sensitive files must encompass local registry and cloud configurations, as exposure of these locations could lead to immediate privilege escalation and credential compromise.
**Prevention:** Add alternative package registry configs and cloud provider default directories (`.cargo`, `.s3cfg`, `.boto`, `.gcloud`, `.azure`) to the strict denylist within path validation logic.
