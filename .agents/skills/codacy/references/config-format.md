> **Skill:** This reference is used by [codacy-analysis-cli](../SKILL.md).

# Codacy Configuration Format

The repository uses `.codacy.yml` or `.codacy.yaml` for advanced configuration.

## Basic Structure

```yaml
---
exclude_paths:
  - "target/**"
  - "node_modules/**"
  - "vendor/**"
  - "**/tests/**"

languages:
  rust:
    enabled: true
  go:
    enabled: true
  c:
    enabled: true
  typescript:
    enabled: true
  shell:
    enabled: true

engines:
  duplication:
    enabled: true
    exclude_paths:
      - "tests/**"

```

## Tool-Specific Configuration

You can tune specific engines under the `engines` key:

```yaml
engines:
  shellcheck:
    exclude_paths:
      - "scripts/legacy/**"
  cppcheck:
    language: c++
  phpcs:
    php_version: 8.1
  metric:
    # Cyclomatic complexity thresholds

    config:
      languages:
        - "rust"
        - "go"
        - "typescript"

```

## Validation

Validate your configuration locally using the Codacy Analysis CLI:

```bash
codacy-analysis-cli validate-configuration (v1.4.0) --directory .

```
