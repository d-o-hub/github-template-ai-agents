# Agent Usage Restrictions (USE_RESTRICTIONS.md)

This document defines the boundaries for AI agent operations within this repository. All contributors (human and agent) must adhere to these policies to ensure safety, security, and maintainability.

## Allowed vs. Disallowed Usage

### ✅ Allowed

- **Autonomous Feature Development**: Implementing new features within the scope of approved ADRs.
- **Bug Fixes and Refactoring**: Improving code quality, fixing defects, and standardizing patterns.
- **Documentation**: Keeping READMEs, skills, and internal docs in sync with code.
- **Automated Testing**: Writing and running BATS, pytest, or other test suites.
- **Static Analysis**: Running and triaging findings from linters and security scanners.

### ❌ Disallowed

- **Production Deployment**: Agents must not trigger production deployments without an explicit human approval gate.
- **Credential Management**: Agents are forbidden from handling, storing, or rotating production secrets/keys.
- **Breaking API Changes**: No backwards-incompatible API changes without human-reviewed ADRs.
- **External Network Calls**: No unauthorized external API calls or data exfiltration.
- **Circumventing Quality Gates**: Disabling tests or linters to "pass" CI is strictly prohibited.

## High-Risk Automation Warning

Actions that modify critical infrastructure, security configurations, or financial systems are considered high-risk. These **MUST** require:
1. A written plan in `plans/`.
2. Explicit human approval of the plan.
3. Post-execution human verification.

## Human-in-the-Loop Expectations

While this repository promotes "automation-first," humans remain the ultimate authority:
- **Decision Gates**: Major architectural shifts (ADRs) require human sign-off.
- **Code Review**: All agent-generated PRs must be reviewed by a human maintainer.
- **Incident Response**: Humans must take control in the event of unexpected agent behavior or CI failures that the agent cannot resolve.

## Security and Secret-Handling Constraints

- **No Secrets in Code**: Never commit passwords, tokens, or PII.
- **Gitleaks Compliance**: All changes must pass Gitleaks scanning.
- **Least Privilege**: Agents should operate with the minimum permissions necessary for their assigned tasks.

## Third-Party Service and Rate-Limit Caveats

- Agents must respect rate limits of external services (GitHub API, LLM providers, etc.).
- Avoid high-frequency polling that could lead to IP blocking or cost overruns.

## Open-Source Disclaimer

**Users must validate all agent outputs.** While agents follow the rules in `AGENTS.md`, their output is non-deterministic and may contain errors. The human maintainer is responsible for the final state of the codebase.
