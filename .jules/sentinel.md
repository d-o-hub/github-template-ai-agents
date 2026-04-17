## 2026-04-16 - Path Traversal in Pathlib Join
**Vulnerability:** Path traversal in `scripts/lib/eval_executors.py` where `skill_path / file_path` allowed absolute path injection.
**Learning:** In Python's `pathlib`, the `/` operator returns the second operand if it's absolute, bypassing the base path.
**Prevention:** Strip leading slashes from subpaths and validate with `.resolve()` and `.relative_to()` to enforce directory boundaries.

## 2026-04-16 - SSRF Bypass via Flawed Hostname Extraction
**Vulnerability:** SSRF bypass in `.agents/skills/do-web-doc-resolver/scripts/utils.py` where `parsed.netloc.split(":")[0]` was used to extract the hostname.
**Learning:** Using `netloc.split(":")` to extract a hostname fails when the URL contains user information (e.g., `http://user@127.0.0.1`), as it returns the username instead of the host.
**Prevention:** Always use `urllib.parse.urlparse(url).hostname` to reliably extract the hostname for security validations and blacklisting.
