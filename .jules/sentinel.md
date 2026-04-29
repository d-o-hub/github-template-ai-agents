## Security Finding: Command Injection in CLI Providers

*   **Vulnerability**: The `do-web-doc-resolver` used `subprocess.run` with unsanitized URLs for `docling` and `ocr` providers, leaving them vulnerable to command injection payloads.
*   **Fix**: Implemented `is_shell_safe_url` in `utils.py` and updated the providers to check and block shell-dangerous characters in the URL string prior to calling `subprocess.run()`.
*   **Testing**: Added `tests/test_shell_safety.py` to ensure defense-in-depth against malicious URLs, including validating safe characters (`&`, `;`) and rejecting invalid ones (`|`, `<`, `>`, etc).

## 2026-04-28 - Fail-closed SSRF Protection
**Vulnerability:** The `is_safe_url` helper used a fail-open approach where DNS resolution failures or empty results would allow the URL to pass validation.
**Learning:** Security validation functions must explicitly handle errors by denying access (fail-closed) rather than ignoring them.
**Prevention:** Always implement explicit exception handling in safety-critical code that defaults to `False` or `AccessDenied`.

## 2026-04-29 - Path Traversal in Evaluation Framework
**Vulnerability:** The evaluation runner (`scripts/run-evals.py`) and its executors allowed path traversal via the `--skill` argument and `files` definitions in `evals.json`, potentially leading to arbitrary code execution if a malicious skill was loaded.
**Learning:** Even internal tooling should enforce strict path boundaries. Relying on simple sanitization (like stripping leading slashes) is insufficient compared to explicit rejection of traversal sequences and absolute paths.
**Prevention:** Use `Path.is_absolute()` and check for `..` substrings before joining paths in tools that handle user-provided or data-driven file paths.
