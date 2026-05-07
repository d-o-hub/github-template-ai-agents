---
name: test-driven-development
description: Red-Green-Refactor workflow. Triggers during implementation or bug fixing.
category: quality
version: "1.0"
template_version: "0.3"
---

# Test-Driven Development (TDD)

The Prove-It pattern: No code without a failing test first.

## When to Use
- Implementing new features
- Fixing bugs (write a reproduction test first)
- Refactoring (ensure behavior is preserved)

## Instructions
1. **RED**: Write a test that fails for the new requirement.
   - Run the test and confirm it fails for the expected reason.
2. **GREEN**: Write the minimum amount of code required to make the test pass.
   - Do not optimize or generalize yet. Just make it pass.
3. **REFACTOR**: Clean up the code.
   - Remove duplication, improve naming, ensure style compliance.
   - Keep the tests green throughout.
4. **Repeat**: Move to the next sub-requirement.

## Rationalizations
| Rationalization | Reality |
|-----------------|---------|
| "I know it will work, the test is a waste of time." | Tests are documentation and proof, not just a safety net. |
| "Writing tests first is hard." | It's harder to add tests to un-testable code later. |
| "This is just a simple fix." | Every fix needs a reproduction to prevent it from coming back. |

## Red Flags
- [ ] Writing implementation code before the test
- [ ] Tests that pass but don't actually exercise the new code
- [ ] Skipping the refactor step and leaving "messy" green code

## Verification
- [ ] All tests passing
- [ ] Code coverage is maintained or improved
- [ ] Tests are readable and follow the DAMP principle
