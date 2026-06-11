> **Skills:** This reference is used by
> [codacy-analysis-cli](../SKILL.md) and
> [codacy-cloud-cli](../SKILL-cloud.md).

# Supported Codacy Tools (v1.4.0/v1.5.0)

This repository template supports a wide range of languages. Codacy integrates multiple industry-standard tools for analysis.

## Core Language Support

| Language | Primary Tools | Local Support |
|----------|---------------|---------------|
| **Go** | aligncheck, deadcode, gosec, Revive, Staticcheck | ✅ Partial |
| **Rust** | Opengrep (Security), clippy (Cloud-only) | ✅ Partial |
| **C/C++** | Clang-Tidy, Cppcheck, Flawfinder | ✅ Partial |
| **TypeScript** | ESLint, BiomeJS, Opengrep | ✅ Yes |
| **JavaScript** | ESLint, BiomeJS, PMD | ✅ Yes |
| **Shell** | ShellCheck, Opengrep | ✅ Yes |
| **Markdown** | markdownlint, remark-lint | ✅ Yes |
| **YAML** | Checkov, Trivy | ✅ Yes |

## Security & Compliance

- **Secrets Detection**: Trivy, Opengrep.
- **Vulnerability Scanning**: Trivy (SBOM, dependency analysis).
- **Infrastructure as Code**: Checkov (Terraform, Kubernetes, CloudFormation).

## General Analysis

- **Duplication**: PMD CPD, jscpd.
- **Complexity**: Lizard (supports C, C++, C#, Java, JS, Objective-C, Python, Ruby, Swift, PHP, Go, Lua, Rust).

## Local Analysis Limitations

The local `codacy-analysis-cli` may fail to run certain tools if the required runtimes (e.g., Ruby for SQLint, Java for PMD) are not available in the local environment. Always check the Cloud CLI (`codacy pull-request`) or the Codacy dashboard for the definitive list of issues.
