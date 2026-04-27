## 2026-04-16 - Path Traversal in Pathlib Join
**Vulnerability:** Path traversal in `scripts/lib/eval_executors.py` where `skill_path / file_path` allowed absolute path injection.
**Learning:** In Python's `pathlib`, the `/` operator returns the second operand if it's absolute, bypassing the base path.
**Prevention:** Strip leading slashes from subpaths and validate with `.resolve()` and `.relative_to()` to enforce directory boundaries.

## 2026-04-16 - SSRF Bypass via Flawed Hostname Extraction
**Vulnerability:** SSRF bypass in `.agents/skills/do-web-doc-resolver/scripts/utils.py` where `parsed.netloc.split(":")[0]` was used to extract the hostname.
**Learning:** Using `netloc.split(":")` to extract a hostname fails when the URL contains user information (e.g., `http://user@127.0.0.1`), as it returns the username instead of the host.
**Prevention:** Always use `urllib.parse.urlparse(url).hostname` to reliably extract the hostname for security validations and blacklisting.

## 2026-04-18 - Credential Exposure in URL Reconstruction
**Vulnerability:** URL reconstruction in `normalize_url` and `fetch_llms_txt` in `.agents/skills/do-web-doc-resolver/scripts/utils.py` used `parsed.netloc`, which includes user credentials (e.g., `user:pass@host`).
**Learning:** `parsed.netloc` preserves credentials and raw port strings. Using it to reconstruct URLs for further requests or cache keys can lead to credential leakage in logs/cache or SSRF bypasses if the host is misidentified.
**Prevention:** Use a dedicated helper to reconstruct `netloc` from `parsed.hostname` and `parsed.port`, explicitly stripping credentials and normalizing default ports.

## 2026-04-20 - Path Traversal in Bash Link Validation
**Vulnerability:** Path traversal in `scripts/validate-links.sh` allowed checking existence of files outside the repository via absolute paths or `..` sequences in documentation links.
**Learning:** Bash string prefix matching `[[ "$path" != "$base"* ]]` is vulnerable to partial directory name bypasses (e.g., `/app` matching `/app-secret`).
**Prevention:** Reject absolute paths explicitly and use `realpath` to resolve links. Always append trailing slashes to both path and base when performing boundary checks: `[[ "$resolved_path/" != "$resolved_root/"* ]]`.

## 2026-04-22 - SSRF via Redirect Bypass
**Vulnerability:** SSRF protection in `do-web-doc-resolver` was bypassed by providing a safe initial URL that redirected to an internal resource (e.g., `127.0.0.1`).
**Learning:** The `requests` library follows redirects automatically by default, but only validates the initial URL against SSRF blacklists.
**Prevention:** Disable automatic redirects (`allow_redirects=False`) and implement a manual redirect loop that validates each hop against `is_safe_url()`.

## 2026-04-21 - Defense-in-Depth for SSRF Protection
**Vulnerability:** Incomplete SSRF protection in `do-web-doc-resolver` where orchestrator and provider levels lacked initial URL validation.
**Learning:** Relying on utility-level SSRF checks is insufficient if high-level entry points bypass them or if specialized tools (e.g., `docling`, `tesseract`) are called directly without validation.
**Prevention:** Implement centralized SSRF validation at all entry points (orchestrators) and redundant checks at the provider level. Use `--` separators in subprocess calls to prevent argument injection from malicious URLs.

## 2026-04-21 - Local Commit Message Validation
**Requirement:** CI was catching commit message violations that should be caught locally.
**Learning:** Relying on CI for format validation increases feedback loop time and results in broken builds.
**Prevention:** Enforce commit message validation locally via `commit-msg` git hook. Provide `./scripts/ai-commit.sh` helper for agents to produce valid commits.

## 2026-04-23 - Robust SSRF Protection via ip.is_global
**Vulnerability:** SSRF protection in `do-web-doc-resolver` used a manual blacklist of `BLOCKED_NETWORKS`, which could miss non-public IP ranges like CGNAT (100.64.0.0/10) or documentation/reserved ranges.
**Learning:** Manual IP blacklists are brittle and incomplete. Using `ipaddress.ip_address(ip).is_global` provides a more robust, future-proof way to identify non-public IPs (including private, reserved, loopback, and IPv4-mapped IPv6).
**Prevention:** Prefer `ip.is_global` (or `not ip.is_global` to block) for SSRF validation. Always restore `socket.getdefaulttimeout()` when temporarily overriding it to avoid side effects in other network operations.

## 2026-04-24 - Trust Score Manipulation via Insecure URL Parsing
**Vulnerability:** URL trust scoring in `do-web-doc-resolver/scripts/utils.py` used `urlparse(url).netloc` and loose substring matching (`site in domain`) to identify trusted sites.
**Learning:** `urlparse().netloc` includes user credentials (e.g., `trusted.com@evil.com`), allowing attackers to masquerade as trusted domains. Furthermore, `in` operator matching allows spoofing via related domains (e.g., `notgithub.com`).
**Prevention:** Always use `urlparse(url).hostname` for domain-based security decisions to strip credentials. Use strict exact matching or explicit subdomain checks (`domain.endswith("." + site)`) instead of loose substring searches.

## 2026-04-25 - JSON and Argument Injection in Research Engine
**Vulnerability:** `scripts/lib/research-engine.sh` used heredocs with variable interpolation for JSON generation and lacked `--` separator for positional arguments in a Python call.
**Learning:** Shell heredocs are fragile for JSON generation if content contains quotes or control characters. Positional arguments starting with `-` can be misinterpreted as command flags by the receiving process.
**Prevention:** Use `python3 -c "import json; ..."` with `sys.argv` for safe JSON construction instead of shell templates. Use `--` to explicitly separate options from positional arguments in CLI calls.

## 2026-05-24 - Injection and Fragility in Manual JSON Handling
**Vulnerability:** Command discovery and verification scripts used manual string concatenation for JSON generation and brittle `grep | cut` for parsing, leading to injection risks and failures on special characters (quotes, commas, braces).
**Learning:** Manual JSON construction in shell scripts is highly error-prone and insecure when handling untrusted or complex strings. Standardizing on a dedicated tool like `jq` eliminates these risks.
**Prevention:** Always use `jq` with `--arg` or `--argjson` for safe JSON generation and `jq -r` for robust parsing in shell scripts. Avoid regex-based "parsing" of JSON structures.

## 2026-05-24 - Argument Injection in GH CLI
**Vulnerability:** Argument injection in `scripts/gh-labels-creator.sh` where label names from `gh label list` were passed to `gh label delete` without `--` separator.
**Learning:** Using `--` separator after flags is mandatory to safely handle positional arguments that might start with a hyphen. Placing flags *after* `--` causes them to be treated as positional arguments, breaking the command.
**Prevention:** Always use `gh command --flags -- "positional_args"` and use `jq -r` to ensure raw output from JSON.
