---
name: testing-strategy
version: "0.2.10"
description: Design and implement comprehensive testing strategies for software projects. Use this skill when planning test suites, choosing testing approaches like property-based testing, visual regression, load testing, mutation testing, or E2E test generation — even if they just say "how should we test this" or "what testing approach should we use".
category: testing
license: MIT
---

# Testing Strategy

Design and implement comprehensive testing strategies with modern techniques.

## When to Use

- User asks to plan test suites or choose testing approaches
- Need to decide between property-based, visual regression, load testing, etc.
- Even if they just say "how should we test this" or "what testing approach should we use"

## Strategy Decision Tree

```
What are you testing?
├── Business logic / algorithms → Property-Based Testing
│   └── Tool: Hypothesis (Python), fast-check (JS)
├── UI appearance / visual state → Visual Regression
│   └── Tool: Playwright screenshots, Percy, Chromatic
├── Performance under load → Load & Stress Testing
│   └── Tool: Locust (Python), k6 (JS), JMeter (Java)
├── Test suite quality itself → Mutation Testing
│   └── Tool: Mutmut (Python), Stryker (JS/Java/C#)
└── End-to-end user flows → E2E Testing
    └── Tool: Playwright, Cypress, Selenium
```

## Strategy Reference

| Strategy | What It Catches | When To Use | Effort |
|----------|----------------|-------------|--------|
| **Property-Based** | Edge cases, boundary conditions | Algorithms, data transformations, parsers | Medium |
| **Visual Regression** | UI layout shifts, rendering bugs | Any visual component, responsive design | Low |
| **Load & Stress** | Performance bottlenecks, memory leaks | APIs, databases, critical paths | High |
| **Mutation Testing** | Weak assertions, missing test cases | Any code with existing unit tests | Medium |
| **E2E** | Integration bugs, user flow breaks | Critical user journeys, smoke tests | High |

## Language-Specific Tools

| Language | Property-Based | Visual | Load | Mutation |
|----------|---------------|--------|------|----------|
| Python | Hypothesis | Playwright | Locust | Mutmut |
| JavaScript | fast-check | Playwright/Percy | k6 | Stryker |
| Java | jqwik | Selenium | JMeter | PIT |
| C# | FsCheck | Playwright | NBomber | Stryker.NET |

## Quality Gates

Integrate testing into CI/CD:
- Check mutation score thresholds (>80% target)
- Monitor Core Web Vitals in load tests (LCP < 2.5s)
- Auto-quarantine flaky tests after 3 consecutive failures
- Fail build if coverage drops on new code

## Gotchas

- Property-based tests need shrinking configuration — without it, counterexamples are huge and unhelpful.
- Visual regression tests are environment-sensitive — use fixed viewport sizes and font rendering settings.
- Load tests against production data need anonymization — never use real customer data.
- Mutation testing on legacy code produces many surviving mutants — start with a baseline and improve incrementally.
- Flaky E2E tests erode trust — quarantine them immediately and fix root cause before re-enabling.

## Rationalizations

| Rationalization | Reality |
|-----------------|---------|
| "Testing takes too long, I need to ship now" | Skipping tests creates technical debt and leads to regressions that take longer to fix. |
| "The code is self-explanatory, it doesn't need tests" | Tests document behavior and ensure it stays consistent as code evolves. |
| "I'll add tests once the feature is 'finished'" | Tests should be written alongside code (TDD/BDD) to ensure the implementation is correct. |

## Red Flags

- [ ] Declining code coverage on new features
- [ ] Committing code with failing or bypassed tests
- [ ] Ignoring flaky tests instead of identifying and fixing the root cause
- [ ] Running all tests on every change instead of targeted test selection

## References

- [Testing Strategy Patterns](../../../agents-docs/references/testing-patterns.md) - Comprehensive collection of testing patterns and strategies

## See Also

- `test-runner` — Execute tests and diagnose failures
- `dogfood` — Exploratory testing of web applications
- `testdata-builders` — Create test fixtures and factories
