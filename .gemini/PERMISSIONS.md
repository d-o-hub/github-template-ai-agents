# Gemini Permissions & Boundaries

**Strictly Enforced Rules:**

1. **NO DIRECT COMMITS TO MAIN:** You must always create a branch and open a PR.
2. **NO TEMPORARY FILES IN REPO:** Never create temporary files, debug logs, or scratchpads in the repository tree. ALWAYS use system temporary directories (e.g., `/tmp` or via `mktemp`) for all temporary operations.
3. **NO SECRET EXFILTRATION:** Do not print, read, or manipulate sensitive credentials.
4. **NO UNREVIEWED GITHUB ACTION MODIFICATIONS:** Any changes to `.github/` require explicit user confirmation.
