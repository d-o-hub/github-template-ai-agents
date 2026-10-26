---
name: local-context-sanitization
version: "0.1.0"
category: security
description: >-
  Sanitize sensitive prompt context, PII, and credentials before forwarding to external LLMs, tools, or third-party APIs.
  Use when prompt or context sanitization is requested, when using do-context-shield, or when preparing external model prompts containing local repository context.
  Not for privacy-first (preventing personal data from being committed to source/docs).
  Not for secrets-management (revoking, rotating, and storing exposed credentials).
  Not for security-code-auditor (general code vulnerability scanning).
license: MIT
compatibility: Works with Claude Code, OpenCode, and similar agents. Guidance for local CLI/MCP tools.
metadata:
  author: d-oit
---

# Local Context Sanitization

Establish an executable local sanitization boundary for prompts and tool context before data leaves the machine to external models or third-party endpoints.

## When to Use

- User asks: "sanitize prompt", "local privacy boundary", "run do-context-shield", "redact context before sending", "local prompt shield"
- Preparing code snippets, logs, or repository context containing sensitive tokens or PII for external AI model evaluation
- Setting up local MCP or CLI context privacy boundaries

**Boundary distinctions:**
- `privacy-first`: Prevents emails and personal data from being committed to source code or documentation.
- `secrets-management`: Detects, revokes, rotates, and safely stores exposed credentials.
- `local-context-sanitization`: Sanitizes sensitive context before forwarding to external models/tools and handles placeholders safely.

## Guidance & Scope

- **Guidance only**: This skill provides workflow instructions, not an automated runtime security control or OS sandbox.
- **Local installation**: Relies on trusted local installation and configuration of sanitization tools.
- **Restoration policy**: Do not enable restoration/un-masking of raw values back to the calling model by default.
- **Optional tool integration**: Identifies `do-context-shield` (CLI / MCP) as an optional privacy boundary tool.

### Upstream References

- Product & Security Contract: [do-context-shield](https://github.com/d-oit/do-context-shield)
- Private Data Skill Reference: [SKILL.md](https://github.com/d-oit/do-context-shield/blob/main/.agents/skills/private-data/SKILL.md)
- Client Integration Guide: [client-integration.md](https://github.com/d-oit/do-context-shield/blob/main/docs/client-integration.md)

*Upstream Compatibility Note*: CLI commands and flags are version-specific. Always refer to the [upstream client integration guide](https://github.com/d-oit/do-context-shield/blob/main/docs/client-integration.md) for current syntax rather than hardcoding CLI flags.

## Fail-Safe Policy

If the local sanitizer executable or MCP server is unavailable, unconfigured, or returns an error:
1. **Never** claim sanitization occurred.
2. **Never** fall back silently to forwarding the raw sensitive context.
3. **Stop immediately** and inform the user, requesting an approved alternative path (e.g. installing the tool, manually redacting the prompt, or explicitly approving raw transmission).

## Required Inputs

- Raw prompt, snippet, or file context intended for external transmission.
- Status of local `do-context-shield` executable or local MCP privacy endpoint.

## Steps

1. **Verify Sanitizer Availability**: Check if `do-context-shield` CLI or MCP service is available locally.
2. **Handle Failures Safely**: If unavailable or non-functional, halt execution immediately. Request user direction.
3. **Process Context**: Pass raw prompt or code context through the local privacy tool. Ensure sensitive entities are replaced with deterministic placeholders.
4. **Inspect Output**: Confirm output contains placeholders without leaked raw tokens or PII.
5. **Transmit Safely**: Forward only the sanitized context to the external model or tool. Maintain placeholder mappings strictly client-side.

## Rationalizations

| Rationalization | Reality |
|-----------------|---------|
| "The external LLM provider claims zero data retention, so we don't need local sanitization." | Enterprise compliance and zero-trust policies require sanitizing data before network egress regardless of remote policies. |
| "If do-context-shield is missing, sending raw context is fine as a fallback." | Silent fallbacks leak sensitive context. A failed or missing sanitizer must halt transmission. |
| "Restoring raw values to the model helps answer quality." | Un-masking sensitive values to external LLMs defeats the purpose of the privacy boundary. Keep restoration off by default. |

## Red Flags

- [ ] Forwarding raw prompt or code context when local sanitizer binary/MCP is missing or errors out
- [ ] Claiming text was sanitized when no sanitizer execution took place
- [ ] Enabling restoration/un-masking of sensitive values back to external models by default
- [ ] Confusing file/doc commit linting (`privacy-first`) or secret revocation (`secrets-management`) with prompt egress sanitization

## See Also

- `privacy-first` — Prevent personal data and emails from being committed into source/docs
- `secrets-management` — Handle lifecycle, rotation, and vault storage of API keys and credentials
- `security-code-auditor` — Audit codebase for security vulnerabilities
