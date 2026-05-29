# ADR 006: Codacy Static Analysis Skill Integration

## Context

Static analysis is crucial for maintaining code quality and security in a template repository that aims to support multiple languages (Go, Rust, C, TypeScript, etc.). We need a specialized skill that allows agents to interact with Codacy, triage PR findings, and validate configurations locally.

## Decision

We will integrate the `codacy` skill into the `.agents/skills/` directory with the following characteristics:

1. **Generalized Support**: The skill will be designed to support all major languages (Go, Rust, C, TypeScript, Shell, Markdown) rather than being limited to a specific subset.
2. **CLI Integration**: It will prioritize usage of `@codacy/analysis-cli` and `@codacy/codacy-cloud-cli` for both local and remote analysis.
3. **Reference Documentation**: We will provide detailed reference files for configuration format, output schema, and supported tools.
4. **Template Configuration**: A default `.codacy.yml` template will be provided in `templates/codacy/` to facilitate quick adoption.
5. **Evaluation Suite**: An eval set will be included to ensure agents understand how to use the skill effectively.

## Consequences

- **Positive**: Standardizes how agents handle code quality issues across different languages.
- **Positive**: Simplifies PR triage by providing clear workflows for findings and false positives.
- **Neutral**: Requires users to install Codacy CLIs if they wish to perform local analysis.
- **Neutral**: Skill needs to be kept up-to-date with Codacy's evolving toolset.
