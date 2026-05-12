## 2026-05-12 - Shell hardening against injection and environment portability

**Vulnerability:** Shell scripts using \`bc\` for floating-point comparisons and \`echo -e\` for outputting variables are vulnerable to environment-specific failures (missing \`bc\`) and argument injection (if variables start with \`-\`).

**Learning:** \`bc\` is not always available in minimal container environments. \`printf\` is a safer and more robust alternative to \`echo\` for handling variables and color codes.

**Prevention:** Use \`python3\` for robust floating-point comparisons in shell scripts. Always use \`printf\` with a format string when outputting variables that could contain untrusted data or start with a hyphen.

## 2026-05-12 - Dependency Supply Chain Hardening

**Vulnerability:** The \`mistralai\` package was found to be quarantined on PyPI, posing a supply chain risk.

**Learning:** Third-party packages can be compromised or quarantined at any time. CI/CD pipelines fail if a required package is unavailable or blocked.

**Prevention:** Comment out or remove dependencies that are quarantined or flagged as high risk. Use internal mirrors or vendoring for critical dependencies when possible.
