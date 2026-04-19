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
