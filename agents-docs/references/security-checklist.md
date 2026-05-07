# Security Audit Checklist

## Pre-Audit Preparation

- [ ] Identify the technology stack and frameworks
- [ ] List all entry points (APIs, forms, file uploads)
- [ ] Document authentication and authorization mechanisms
- [ ] Identify sensitive data flows
- [ ] Review existing security documentation

## Code Review Checklist

### Input Validation
- [ ] All user inputs are validated
- [ ] Type casting is used appropriately
- [ ] Length limits are enforced
- [ ] Format validation is applied (regex, schemas)
- [ ] Range checks are implemented for numeric values

### Output Encoding
- [ ] HTML output is properly escaped
- [ ] JavaScript context encoding is applied
- [ ] URL parameters are encoded
- [ ] SQL queries use parameterization

### Authentication
- [ ] Password policies are enforced
- [ ] Session tokens are cryptographically secure
- [ ] Session expiration is implemented
- [ ] Login rate limiting is in place
- [ ] Account lockout mechanisms exist
- [ ] MFA is supported (if required)

### Authorization
- [ ] Access controls are enforced on every endpoint
- [ ] Role-based access control is properly implemented
- [ ] Direct object references are protected
- [ ] Horizontal and vertical privilege escalation is prevented

### Cryptography
- [ ] Strong encryption algorithms are used
- [ ] Keys are properly managed (not hardcoded)
- [ ] Sensitive data is encrypted at rest
- [ ] TLS is enforced for all communications
- [ ] Certificate validation is not disabled

### Session Management
- [ ] Session IDs are random and unpredictable
- [ ] Sessions timeout after inactivity
- [ ] Sessions are invalidated on logout
- [ ] Secure and HttpOnly flags are set on cookies
- [ ] SameSite cookie attribute is configured

### Error Handling
- [ ] Stack traces are not exposed to users
- [ ] Sensitive information is not logged inappropriately
- [ ] Generic error messages are shown to users
- [ ] All errors are properly handled

### File Handling
- [ ] File uploads validate type and size
- [ ] Uploaded files are stored outside web root
- [ ] Path traversal is prevented
- [ ] Executable extensions are restricted

### API Security
- [ ] Rate limiting is implemented
- [ ] API keys/tokens are properly validated
- [ ] CORS is properly configured
- [ ] Content-Type validation is enforced
- [ ] API versioning strategy is in place

### Dependencies
- [ ] All dependencies are up to date
- [ ] Known vulnerabilities (CVEs) are checked
- [ ] Unused dependencies are removed
- [ ] License compliance is verified

## Configuration Review

### Security Headers
- [ ] Content-Security-Policy is configured
- [ ] X-Content-Type-Options: nosniff is set
- [ ] X-Frame-Options or CSP frame-ancestors is set
- [ ] Strict-Transport-Security (HSTS) is enabled
- [ ] Referrer-Policy is configured
- [ ] Permissions-Policy is set

### Environment
- [ ] Debug mode is disabled in production
- [ ] Environment variables are properly secured
- [ ] No hardcoded credentials in configuration
- [ ] Database connections use least privilege
- [ ] Logging levels are appropriate for environment

## Post-Audit

- [ ] Document all findings with severity
- [ ] Create remediation timeline
- [ ] Assign owners for each fix
- [ ] Schedule re-audit after remediation
- [ ] Update security documentation

---

# OWASP Guidelines

## OWASP Top 10 (2021)

### A01: Broken Access Control
- Deny by default - all requests should fail unless explicitly allowed
- Implement once, reuse everywhere - use centralized access control
- Minimize CORS usage - restrictive origins only
- Rate limit API access to reduce brute force attacks

### A02: Cryptographic Failures
- Encrypt data in transit (TLS 1.2+) and at rest
- Use strong, industry-standard algorithms (AES-256, RSA-4096)
- Never roll your own crypto - use established libraries
- Properly manage keys with secure key management systems

### A03: Injection
- Use parameterized queries for database access
- Validate and sanitize all user input
- Use allowlists for input validation
- Escape special characters in context-specific ways

### A04: Insecure Design
- Adopt secure design patterns and principles
- Use threat modeling for critical features
- Integrate security language into user stories
- Limit resource consumption per user/request

### A05: Security Misconfiguration
- Minimal platform - remove unnecessary features
- Patch and upgrade in timely manner
- Disable verbose error messages in production
- Configure security headers properly

### A06: Vulnerable and Outdated Components
- Maintain inventory of all components and versions
- Remove unused dependencies
- Monitor for CVEs affecting your stack
- Have a patch management process

### A07: Identification and Authentication Failures
- Implement multi-factor authentication
- Use strong session management
- Don't use default credentials
- Implement proper password recovery flows

### A08: Software and Data Integrity Failures
- Verify dependencies and use trusted repositories
- Implement digital signatures for critical data
- Ensure CI/CD pipelines have proper integrity checks
- Don't deserialize untrusted data

### A09: Security Logging and Monitoring Failures
- Ensure all login, access control, and input validation failures are logged
- Logs should be in a format suitable for monitoring
- Ensure logs are protected from tampering
- Use real-time alerting for suspicious activities

### A10: Server-Side Request Forgery (SSRF)
- Sanitize and validate all client-supplied input data
- Use allowlists for URLs and IP addresses
- Disable unused URL schemas
- Enforce network segmentation

## Secure Coding Practices

### Input Validation
- Validate all input on the server side
- Use type, length, format, and range constraints
- Reject invalid input rather than sanitizing
- Use allowlists, not denylists

### Output Encoding
- Encode all output appropriate for the context
- Use framework auto-escaping when available
- Be aware of different encoding contexts (HTML, JavaScript, URL, CSS)

### Authentication
- Implement secure password storage (bcrypt, Argon2)
- Use secure session management
- Implement account lockout after failed attempts
- Support MFA where possible

### Error Handling
- Don't expose stack traces or system details in production
- Use generic error messages for users
- Log detailed errors securely
- Handle all exceptions gracefully

---

# Automated Security Scanning (CI/CD)

The following automated scans are performed in CI to ensure code security:

## Shell Script Analysis (ShellCheck)
- Scan all bash/shell scripts for security vulnerabilities.
- Focused on: `add-default-case`, `avoid-nullary-conditions`, `deprecate-which`, `check-unassigned-uppercase`, `quote-safe-variables`.

## Filesystem Security Scan (Trivy)
- Scan repository for secrets, misconfigurations, and vulnerabilities.
- Scans for CRITICAL, HIGH, and MEDIUM severity issues.

## Infrastructure as Code (IaC) Scan
- Scan GitHub Actions workflows for misconfigurations.
- Integrated into the CI/CD pipeline.

## Secret Scanning (Gitleaks)
- Enforced via GitHub Actions to prevent accidental commit of secrets.
