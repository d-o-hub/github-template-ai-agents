---
name: testing-strategy
description: Design and implement comprehensive testing strategies for software projects. Use for test planning, property-based testing, visual regression, load testing, mutation testing, and E2E test generation. Handles Python, JavaScript, and other languages.
---

# Testing Strategy

Design and implement comprehensive testing strategies with modern techniques.

## Strategy Selection

Choose the appropriate testing approach for your project:

**Property-Based** - Discover edge cases with generative testing.
**Visual Regression** - Detect UI changes with screenshot comparison.
**Load & Stress** - Verify performance under pressure.
**Mutation Testing** - Measure test suite effectiveness.
**Test Maintenance** - Keep tests healthy and reliable.

## Available Patterns

- **Load Testing**: Pre-configured scenarios for REST, GraphQL, and Browser tests.
- **Mutation Testing**: Configuration and operators for Stryker, Mutmut, and PIT.
- **Property-Based**: Patterns for stateful testing, custom strategies, and common properties.
- **Visual Testing**: Guide for Playwright, Storybook, and masking dynamic content.
- **Maintenance**: Health metrics, flaky test management, and AI-assisted diagnosis.

## Language Support

- Python (Hypothesis, Mutmut, Locust)
- JavaScript/TypeScript (fast-check, Stryker, k6, Playwright)
- Java (PIT, JMeter)
- C# (Stryker.NET)

## Quality Gates

Integrate testing into CI/CD:
- Check mutation score thresholds.
- Monitor Core Web Vitals in load tests.
- Auto-quarantine flaky tests.

## References

- [Testing Strategy Patterns](../../../agents-docs/references/testing-patterns.md) - Comprehensive collection of testing patterns and strategies
