---
version: "0.2.10"
name: testdata-builders
description: >
  Maintain deterministic builders/factories for test entities. Use this skill when authoring tests, extending test utilities, or adding schema fields that affect fixtures — even if they just say "create test data" or "build a factory for this". Not for test-runner, testing-strategy.
category: quality
license: MIT
---

# Testdata Builders

Provide consistent factories/builders for test entities to keep tests concise and deterministic.

## When to Use

- Authoring or refactoring tests.
- Extending test utilities or seeding data for integration tests.
- Adding new schema fields that affect test fixtures.

## Workflow

1. **Catalog entities** -- list required builders for all domain entities.
2. **Define defaults** -- choose realistic base values aligned with project conventions.
3. **Implement builder** -- pure function returning object + `withOverrides` pattern for customization; ensure types exported.
4. **Helpers** -- add specialized utilities (e.g., `makeEntityWithRelations`, `makeSeededRandom`).
5. **Docs** -- update test utilities README to explain builder usage.
6. **Usage** -- refactor tests to import builders instead of ad-hoc inline objects.

## Checklist

- [ ] Builders updated whenever schema changes (CI should fail otherwise).
- [ ] Randomness eliminated or seeded to keep snapshots stable.
- [ ] Builders include metadata defaults (timestamps, locale, trace IDs).
- [ ] Exported types re-used by all test suites.
- [ ] Test utilities package has unit tests covering builder edge cases.

## Example Pattern

```typescript
// Builder pattern for test entities
function makeUser(overrides: Partial<User> = {}): User {
  return {
    id: `user-${nextId()}`,
    email: `user-${nextId()}@example.com`,
    name: `Test User ${nextId()}`,
    createdAt: new Date('2026-01-01T00:00:00Z'),
    ...overrides,
  };
}

// Usage: const admin = makeUser({ role: 'admin', email: 'admin@test.com' });
```

## See Also

- `test-runner` — Execute tests and diagnose failures
- `testing-strategy` — Choose testing approaches and plan test suites
- `dogfood` — Exploratory testing of web applications

## Rationalizations

| Rationalization | Reality |
|-----------------|---------|
| "Inline test data is fine for now" | Inline objects proliferate silently; builders enforce consistency and catch schema drift. |
| "Builders are overkill for simple entities" | Simple today becomes complex tomorrow; early investment prevents ad-hoc sprawl. |
| "I'll reuse fixtures from other tests" | Shared mutable fixtures cause order-dependent failures and hidden coupling. |

## Red Flags

- [ ] Inline test objects repeated across multiple test files
- [ ] Builders not updated when schema changes
- [ ] Random test data without seeding that breaks snapshot stability

## References

- `references/builder-patterns.md` - Common factory/builder patterns
- `references/test-data-strategy.md` - Test data management strategy

## Voice & Context

- **Default**: `professional` + `blog`
- **Reference**: `voice-profiles` skill for definitions and auto-detection.
