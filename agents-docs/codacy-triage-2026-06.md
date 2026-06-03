# Codacy Findings Triage — June 2026

> Generated: 2026-06-03 | Repository: `github-template-ai-agents`

## Summary

| Severity | Count | Status |
|----------|-------|--------|
| **Critical** | 13 | Action required |
| **High** | 118 | Mostly false positives (test assertions) |
| **Medium** | 16 | Mixed — CVEs + code quality |
| **Low** | 5 | Known false positives (subprocess SSRF) |
| **Total** | **152** | Grade: **A** |

---

## Critical (13) — Action Required

### Command Injection (SAST) — 8 findings

| Finding ID | Issue | Action |
|------------|-------|--------|
| `fa7011af`, `f6033326`, `d2af1b31` | subprocess `run()` with non-static strings | **Review**: Check if user input reaches subprocess calls. If URLs are validated by `is_safe_url()`, suppress via `.codacy.yml` file exclusion. |
| `dded75ed` | subprocess `run()` with user-controlled data | **Priority fix**: Verify input sanitization chain end-to-end. |
| `7977d513` | `TimeoutExpired` handling | **Low risk**: Exception handling pattern, likely false positive. Suppress. |
| `f595af89`, `a7c7f793` | `Popen` usage (1 with `shell=True`) | **Priority fix**: `shell=True` is a real risk. Convert to `shell=False` with arg list if possible. |
| *(1 remaining)* | subprocess `run()` pattern | Review for false positive. |

### SQL Injection (SAST) — 5 findings (Likely False Positives)

| Finding ID | Issue | Action |
|------------|-------|--------|
| `5e1c8dbb`, `7414268a` | Formatted SQL queries | **Review**: This is a shell/Python template repo with no database — likely false positives from string pattern matching. Suppress if confirmed. |
| `54b7fad6`, `71ac2b3f` | String concatenation with untrusted input | **Review**: Same as above — no SQL database in this project. Likely false positives. |
| `cecd6b88` | General SQL injection | **Review**: Same root cause. Suppress. |

### File Access — 1 finding

| Finding ID | Issue | Action |
|------------|-------|--------|
| `90fc73f8` | Unsafe `${var:?}` expansion | **Review**: Shell expansion safety. If in test/sentinel scripts, suppress. |

### Recommended Actions

1. **Immediate**: Fix `shell=True` Popen usage (2 findings)
2. **This sprint**: Convert SQL string formatting to parameterized queries (5 findings)
3. **Backlog**: Review remaining command injection findings for false positives

---

## High (118) — Mostly False Positives

### Assert Usage — 118 findings

| Issue | Context | Action |
|-------|---------|--------|
| "Use of assert detected" | All in test files (`tests/`, `*.bats`, test modules) | **Suppress**: `assert` is intentional in test code. Codacy's Bandit B101 already excluded for tests via `.codacy.yml`. These are SonarPython findings, not Bandit. |

### Recommended Action

Add SonarPython assertion rule exclusion in `.codacy.yml` or accept as known false positive. Test assertions are standard practice and should not be flagged.

---

## Medium (16) — Mixed

### CVE Vulnerabilities (SCA) — 7 findings

| Package | CVE | Issue | Fix Version |
|---------|-----|-------|-------------|
| `requests` 2.31.0 | CVE-2026-25645 | Predictable temp file creation | → **2.33.0** |
| `requests` 2.31.0 | CVE-2024-47081 | `.netrc` credentials leak | → **2.32.4** |
| `requests` 2.31.0 | CVE-2024-35195 | Certificate verification bypass | → **2.32.0** |
| `pytest` 7.4.0 | CVE-2025-71176 | Insecure temp directory (DoS/PE) | → **9.0.3** |
| `python-diskcache` | CVE-2025-69872 | Pickle deserialization RCE | → **5.6.0** |
| `psf/black` 23.0.0 | CVE-2024-21503 | ReDoS in `lines_with_leading_tabs_expanded()` | → **24.3.0** |
| `black` 23.0.0 | CVE-2026-32274 | Arbitrary file writes from cache | → **26.3.1** |

### Recommended Action

```bash
# Priority: update requests (3 CVEs)
pip install requests>=2.33.0

# High: update diskcache (RCE)
pip install python-diskcache>=5.6.0

# Medium: update black (ReDoS + file write)
pip install black>=26.3.1

# Medium: update pytest (DoS)
pip install pytest>=9.0.3
```

### Code Quality — 9 findings

| Issue | Count | Action |
|-------|-------|--------|
| Insecure temp file/directory usage | 5 | Review: use `tempfile.mkstemp()` with proper permissions |
| Try/Except/Pass | 3 | **Fix**: Add logging or re-raise; silent exception swallowing hides bugs |
| Subprocess input validation | 2 | Review: same as Critical command injection findings |

---

## Low (5) — Known False Positives

### Subprocess Module Usage — 5 findings

| Finding IDs | Issue | Action |
|-------------|-------|--------|
| `fa29c585`, `71502cdc`, `d16b07cd`, `cdc1bdfb`, `47ff293a` | "Consider possible security implications of subprocess module" | **Suppress**: All subprocess calls are protected by `is_safe_url()` SSRF validation. These are the same files already excluded in `.codacy.yml` (`docling.py`) or have inline protections. |

---

## Prioritized Action Plan

### Phase 1 — Security (This Sprint)

1. Fix `shell=True` Popen (convert to arg list)
2. Update `requests` to 2.33.0 (3 CVEs)
3. Update `python-diskcache` to 5.6.0 (RCE)
4. Convert SQL string formatting to parameterized queries

### Phase 2 — Quality (Next Sprint)

1. Update `black` to 26.3.1 (ReDoS + file write)
2. Update `pytest` to 9.0.3 (DoS)
3. Fix try/except/pass (add logging)
4. Review insecure temp file usage

### Phase 3 — Suppression (Manual)

1. **Test assertions (117 High)**: Codacy's SonarPython S101 is a built-in engine — NOT exposed as a configurable tool. `.codacy.yml` `sonarpython` key, `codacy pattern --disable`, and API endpoints all fail silently or return errors. **Only fix**: manually mark as "False Positive" via Codacy dashboard (https://app.codacy.com).
2. Suppress remaining subprocess false positives (5 Low) — already excluded via `.codacy.yml`
3. Document all suppressions with rationale
