---
name: secrets-management
version: "0.2.10"
category: security
description: >-
  Own the secret lifecycle: detect leaked secrets, rotate them, and store them correctly. Use when
  handling API keys, tokens, or credentials — even if they just say "rotate this key", "where do I put
  this secret", or "this key is hardcoded". Not for privacy-first (email/PII lint), general
  vulnerability audits (use security-code-auditor), or commit/PR lifecycle mechanics (use
  git-github-workflow).
license: MIT
---

# Secrets Management

Detect, rotate, and store secrets. A leaked secret is an incident: revoke
first, clean history second, prevent third.

## When to Use

- Suspected or confirmed leaked API key, token, or credential
- Choosing where a secret lives (env, manager, vault, CI secrets)
- Rotating keys on schedule or offboarding
- Reviewing code that handles secrets

## Steps

1. **Detect** — scan with `gitleaks`; treat any hit as live until proven
   otherwise. Check history too (`git log -S`), not just HEAD.
2. **Revoke first** — rotate at the provider before cleaning the repo.
   A cleaned repo with a live leaked key is still an incident.
3. **Clean** — purge from history if needed; confirm with a rescan.
4. **Store correctly** — env vars or a secret manager; CI secrets for
   pipelines; never hardcoded, never in docs or chat logs.
5. **Prevent** — pre-commit hooks (`gitleaks`), least-privilege scopes,
   short TTLs, and rotation reminders.

## Rules

- Never print a secret, even redacted-partially, into logs or PR comments.
- Never echo a secret value back, even if the user pasted it into the
  conversation or asks for a copy "for debugging". Offer the reference
  name (`STRIPE_SECRET_KEY`) or the command to fetch it instead.
- Never commit a "test" secret that resembles a real one.
- Separate secret *values* from secret *references* in every example.

## Rationalizations

| Rationalization | Reality |
|-----------------|---------|
| "It's just a test key, safe to commit" | Test-shaped keys get copied into production and scraped by bots within minutes. |
| "I'll rotate it later, let me push the fix first" | Every minute a leaked key stays live is exploitation window; revoke before anything else. |

## Red Flags

- [ ] Secret value visible in terminal output, logs, or review comments
- [ ] Rotation postponed past the current session
- [ ] New hardcoded credential in any file, including tests and examples

## See Also

- `security-code-auditor` — Audit code for vulnerabilities
- `privacy-first` — Keep emails and PII out of the codebase
- `git-github-workflow` — Pre-commit secret scanning in the lifecycle

## References

- `evals/evals.json` — leak-response cases incl. live-key negative
