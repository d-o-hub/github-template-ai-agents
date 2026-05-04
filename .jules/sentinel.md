## Security Finding: Command Injection in CLI Providers

*   **Vulnerability**: The `do-web-doc-resolver` used `subprocess.run` with unsanitized URLs for `docling` and `ocr` providers, leaving them vulnerable to command injection payloads.
*   **Fix**: Implemented `is_shell_safe_url` in `utils.py` and updated the providers to check and block shell-dangerous characters in the URL string prior to calling `subprocess.run()`.
*   **Testing**: Added `tests/test_shell_safety.py` to ensure defense-in-depth against malicious URLs, including validating safe characters (`&`, `;`) and rejecting invalid ones (`|`, `<`, `>`, etc).

## 2026-04-28 - Fail-closed SSRF Protection
**Vulnerability:** The `is_safe_url` helper used a fail-open approach where DNS resolution failures or empty results would allow the URL to pass validation.
**Learning:** Security validation functions must explicitly handle errors by denying access (fail-closed) rather than ignoring them.
**Prevention:** Always implement explicit exception handling in safety-critical code that defaults to `False` or `AccessDenied`.

## 2026-05-02 - Shell Arithmetic Injection in Validation Logic
**Vulnerability:** Shell arithmetic expansion `$((...))` with unvalidated variables derived from `SKILL.md` frontmatter allowed arbitrary command execution during skill validation.
**Learning:** Bash evaluates variables within arithmetic contexts (`$(( ))` and `(( ))`) as expressions. If these variables contain command substitution or other shell constructs, they are executed.
**Prevention:** Strictly validate that all variables used in shell arithmetic contexts are numeric (e.g., using `[[ "$var" =~ ^[0-9]+$ ]]`) before evaluation.

## 2026-05-03 - Shell Arithmetic Injection via Environment Variables
**Vulnerability:** Environment-overridable numeric variables used in `(( ))`, `$(( ))`, and `[[ $A -lt $B ]]` were vulnerable to command injection (e.g., `VAR='a[$(id)0]'`).
**Learning:** Bash evaluates operands in arithmetic contexts as expressions. If a variable contains an array index like `a[$(...)0]`, the code inside `$(...)` is executed during evaluation.
**Prevention:** Strictly validate that all variables used in Bash arithmetic contexts are numeric (e.g., using `[[ "$var" =~ ^[0-9]+$ ]]`) before they are evaluated.

## 2026-05-15 - Sed Injection via Version File
**Vulnerability:** The `propagate-version.sh` script used an unvalidated `VERSION` variable directly in `sed` substitution strings, which could lead to command execution if `sed` supports the `e` flag (e.g., `VERSION='1.2.3/e;s/.*/echo INJECTED/e;#'`).
**Learning:** External files used as sources for shell script variables must be strictly validated even if they are internal to the repository, as they can be manipulated to achieve command injection in sensitive contexts like `sed`.
**Prevention:** Use anchored regular expressions (e.g., `[[ "$var" =~ ^[0-9]+\.[0-9]+\.[0-9]+$ ]]`) to validate all variables derived from files before using them in shell commands or substitutions.
