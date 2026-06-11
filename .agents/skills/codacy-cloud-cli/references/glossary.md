# Codacy Glossary

Definitions of common Codacy concepts used across Analysis and Cloud CLIs.

## Concepts

- **Issue**: A specific quality or security finding detected by a static analysis tool (e.g., a lint error, a security vulnerability).
- **Finding**: A security-specific issue, often including CVE data and remediation steps.
- **Severity**: The impact of an issue, typically categorized as Critical, High, Medium, or Low (Cloud) or Error, Warning, Info (Analysis).
- **Coverage**: The percentage of code covered by automated tests.
- **Tool**: An engine that performs static analysis (e.g., ESLint, Ruff, Semgrep).
- **Pattern**: A specific rule within a tool that checks for a certain type of issue.
- **Quality Gate**: A set of criteria (e.g., no new critical issues, minimum coverage) that a pull request must meet to be merged.

## Provider

The platform where your repository is hosted.

| Value | Platform |
|-------|----------|
| `gh`  | GitHub |
| `gl`  | GitLab |
| `bb`  | Bitbucket |
| `ghe` | GitHub Enterprise |
| `gle` | GitLab Enterprise |
| `bbe` | Bitbucket Enterprise |
