---
name: security-code-auditor
version: "0.2.10"
category: security
description: Perform security audits on code to identify vulnerabilities, misconfigurations, and security anti-patterns. Use when users ask to 'audit', 'review', or 'check security' of code, configurations, or repositories — even if they just say "check for security issues" or "is this secure". Trigger on keywords like 'security review', 'vulnerability scan', 'OWASP', 'secure coding', 'penetration test', or 'security assessment'.
license: MIT
---

# Security Code Auditor

Perform security audits on code, configurations, and repositories to identify vulnerabilities and security issues.

## When to Use

- User asks to audit, review, or check security of code
- Need to perform vulnerability scans or OWASP Top 10 checks
- Even if they just say "check for security issues" or "is this secure"

## Scope

- **Includes:** Source code review, dependency scanning, configuration auditing, OWASP Top 10 checks
- **Excludes:** Network penetration testing, active exploitation, social engineering

## Audit Workflow

### 1. Initial Assessment

- Identify the technology stack and frameworks
- Determine the application's attack surface
- Review authentication and authorization mechanisms

### 2. Static Analysis

- Check for injection vulnerabilities (SQL, NoSQL, OS command, LDAP)
- Identify insecure deserialization
- Review cryptographic implementations
- Validate input sanitization

### 3. Configuration Review

- Review security headers (CSP, HSTS, X-Frame-Options)
- Check CORS policies
- Validate session management settings
- Examine environment variable handling

### 4. Dependency Scanning

- Check for known CVEs in dependencies
- Review outdated packages
- Validate license compliance

## Common Vulnerability Patterns

### Injection Flaws

```python
# BAD: Direct string concatenation
query = "SELECT * FROM users WHERE id = " + user_id

# GOOD: Parameterized queries
cursor.execute("SELECT * FROM users WHERE id = ?", (user_id,))
```

### Secrets Management

- Never hardcode credentials in source code
- Use environment variables or secure vaults
- Rotate keys regularly
- Use placeholders like `[REDACTED]` or `example-token` in examples

### Authentication Issues

- Enforce strong password policies
- Implement multi-factor authentication
- Use secure session tokens with proper expiration
- Validate all authenticated endpoints

## Severity Classification

| Level | Criteria | Response Time |
|-------|----------|---------------|
| Critical | Remote code execution, authentication bypass | Immediate |
| High | Data exposure, privilege escalation | 24 hours |
| Medium | Information disclosure, CSRF | 1 week |
| Low | Best practice violations | Next sprint |

## Remediation Priorities

1. **Fix critical vulnerabilities immediately**
2. **Validate all user inputs**
3. **Implement defense in depth**
4. **Add security monitoring and logging**

## See Also

- `eu-ai-act-compliance` — EU AI Act specific compliance
- `privacy-first` — Email/personal data prevention
- `static-analysis` — Linter-based security checks

## Rationalizations

| Rationalization | Reality |
|-----------------|---------|
| "This is just internal code, security doesn't matter as much" | Internal tools are common entry points for lateral movement. |
| "I'll fix the security issues in a follow-up PR" | Security is a prerequisite, not an afterthought. Never ship known vulnerabilities. |
| "A security review will slow us down" | 1 hour of review > 1 week of incident response and data breach cleanup. |

## Red Flags

- [ ] Dismissing vulnerabilities as "unlikely to be exploited" without evidence
- [ ] Skipping dependency scans for "trusted" third-party libraries
- [ ] Hardcoding "temporary" secrets with the intent to remove them later

## References

- [Security Checklist](../../../agents-docs/references/security-checklist.md) - Comprehensive security audit checklist, OWASP Top 10, and CI/CD security scanning.
- `references/remediation-guide.md` - Step-by-step vulnerability remediation
