# Testing Quality Contracts

This repository enforces a strong, language-agnostic quality contract for both human developers and AI Agents.

## Testing Tiers

We recognize standard testing tiers. AI Agents should consider these when evaluating the "reward" for their tasks:

- **Smoke Tests**: Basic sanity checks. Must be ultra-fast and reliable.
- **Unit Tests**: Isolated logic verification.
- **Integration Tests**: Component interaction verification.
- **Performance/Benchmarks**: Resource usage and execution speed verification.

## Agent Behavior Rules for Testing

1. **Do not ignore red**: If tests fail, it is the agent's responsibility to diagnose and fix them, not suppress the error or adjust the test logic without a clear root cause.
2. **Coverage stability**: Coverage must not drop. If a refactor removes code, the agent must ensure corresponding test logic remains robust. (See `.test-quality.toml`).
3. **No overfitting**: Do not hardcode values just to make benchmarks or tests pass. Focus on correctness.
4. **Propose refactors**: If test complexity hinders progress, propose a refactor of the underlying code instead of creating brittle tests.

## CI Workflows

Continuous Integration (CI) is expected to conceptually align with `.test-quality.toml` (e.g., checking coverage, test success, and performance bounds). Downstream repositories should map generic CI steps to their language-specific tools.
