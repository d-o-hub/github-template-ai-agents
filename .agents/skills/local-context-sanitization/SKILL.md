---
name: local-context-sanitization
version: "0.1.0"
category: security
description: >
  Sanitize sensitive repository context, credentials, and PII before forwarding
  prompts or tool outputs to external models or remote tools. Use when local privacy
  boundaries or prompt sanitization are requested. Not for preventing emails in committed
  code (use privacy-first) or revoking/rotating leaked secrets (use secrets-management).
license: MIT
metadata:
  author: d-oit
  tags: privacy security context-shield sanitization mcp pii
---

# Local Context Sanitization

Guide the local sanitization of sensitive prompts, repository context, tokens,
and PII before forwarding data to external AI models or remote tool endpoints.

## When to Use

- User requests sanitization of prompt context before sending to external LLMs or third-party APIs.
- Handling confidential code, proprietary documentation, or local traces containing tokens or PII before sending to external services.
- Configuring or integrating local privacy tools (e.g., Model Context Protocol / MCP filters, local sanitization tools).

**Not for:**
- Preventing email addresses or PII from being committed into source files (use `privacy-first`).
- Revoking, rotating, or storing repository API keys and credentials (use `secrets-management`).
- General security code audits or static vulnerability scanning (use `security-code-auditor`).

## Explicit Scope & Responsibilities

To avoid overlap across security and privacy domain skills:

| Skill | Primary Scope & Responsibility |
|---|---|
| `privacy-first` | Prevent personal data (e.g. emails) from being committed to git source code or documentation. |
| `secrets-management` | Revoke, rotate, clean, and securely store leaked credentials and API keys in the codebase lifecycle. |
| `local-context-sanitization` | Sanitize sensitive context (PII, internal paths, tokens) locally before sending to external models/tools, safely substituting placeholders. |

## Guidance, Not a Runtime Security Control

This skill provides **architectural guidance and agent workflow rules**. It is not a software binary or active runtime security sandbox.

- **Local & Trusted Setup**: Any sanitization tool or MCP server (e.g., `do-context-shield`) must be installed, configured, and trusted locally on the host machine by the operator.
- **Restoration Policy**: Do not enable unmasking or restoring sensitive placeholders to the external calling model by default. Placeholders (e.g. `<REDACTED_API_KEY>`) should remain anonymized in external inference calls unless specifically configured with local decryption boundaries.

## Optional Tooling: do-context-shield

Adopters seeking an executable CLI or MCP server for local context redaction can integrate `do-context-shield`.

### Upstream References

- [do-context-shield Repository](https://github.com/d-oit/do-context-shield)
- [Canonical Private Data Skill](https://github.com/d-oit/do-context-shield/blob/main/.agents/skills/private-data/SKILL.md)
- [Client Integration Documentation](https://github.com/d-oit/do-context-shield/blob/main/docs/client-integration.md)

### Upstream Compatibility Note

CLI flags, environment variables, and MCP integration options for `do-context-shield` are version-specific. Always consult the [upstream client integration guide](https://github.com/d-oit/do-context-shield/blob/main/docs/client-integration.md) for the exact CLI syntax matching your installed version.

## Agent Workflow & Fail-Safe Rules

### 1. Verify Local Sanitizer Availability

Before attempting to send text containing sensitive context:
- Check if the local sanitizer CLI or MCP server is installed and responsive (e.g., `do-context-shield --version` or checking local MCP tool availability).

### 2. Fail-Safe Stopping Rule (CRITICAL)

If the local sanitizer executable or MCP server is unavailable, fails, or throws an error:
- **NEVER** claim that sanitization was completed.
- **NEVER** silently fall back to forwarding raw, un-sanitized sensitive text to external models or remote tools.
- **STOP IMMEDIATELY** and request explicit user confirmation or an approved alternative path before proceeding.

### 3. Handle Placeholders Safely

- Ensure redacted placeholders in output preserve structural context (e.g. replacing tokens with `<TOKEN_1>`) so downstream code synthesis remains functional without exposing actual values.

## Rationalizations

| Rationalization | Reality |
|-----------------|---------|
| "The sanitizer executable is missing, so I will just send the text directly." | Silent fallbacks expose sensitive context to external endpoints. Fail safely by halting execution. |
| "This skill automatically redacts all PII without any local tools." | Guidance skills cannot intercept network calls without a trusted local executable or MCP server installed. |
| "I should unmask placeholders before sending them to the remote model." | Unmasking sends raw data to the model, defeating the purpose of local sanitization. |

## Red Flags

- [ ] Falling back to sending raw text when a local sanitization tool is missing or errors
- [ ] Claiming text was sanitized when no local sanitizer was executed
- [ ] Conflating `privacy-first` (commit prevention) with local context filtering
- [ ] Hardcoding upstream CLI flags without referencing upstream version docs

## See Also

- `privacy-first` — Prevent personal data in source code and documentation
- `secrets-management` — Secrets lifecycle, revocation, and storage
- `security-code-auditor` — Audit code for security vulnerabilities
