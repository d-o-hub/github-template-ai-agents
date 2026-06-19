# Testing Strategy Evaluation

## User Scenario

A Python payment processing module with complex rounding logic and idempotency requirements.

## Decision Tree Analysis

Following the skill's **Strategy Decision Tree**:

1. **What are you testing?** → The scenario involves rounding logic (algorithms) and idempotency (data transformation correctness). This maps to **Business logic / algorithms**.
2. **Branch selected:** Property-Based Testing
3. **Recommended tool:** **Hypothesis** (Python)

## Why This Approach

| Characteristic | How It Applies |
|----------------|---------------|
| **Algorithm correctness** | Rounding logic has many edge cases (e.g., banker's rounding, half-even, boundary floats) that Hypothesis can systematically generate. |
| **Idempotency verification** | Hypothesis can generate arbitrary payment inputs and assert that applying the operation multiple times produces the same result — a classic property-based invariant. |
| **Edge cases** | Floating-point precision, currency boundaries, zero/negative amounts, and overflow conditions are all automatable via Hypothesis strategies. |

## Specific Recommendation

- **Primary tool:** `hypothesis` (pip install hypothesis)
- **Strategy:** Define properties like:
  - `round_payment(amount) == round_payment(round_payment(amount))` (idempotency)
  - `0 <= round_payment(amount) <= amount + tolerance` (monotonicity bounds)
  - Output has correct number of decimal places for the currency
- **Complementary:** Use `mutmut` for mutation testing to verify assertion strength once tests exist.

## Skill Assessment

The decision tree correctly routes to property-based testing for this scenario. The Python tool table accurately maps to Hypothesis. The **Gotchas** section warns about shrinking configuration — critical for payment rounding failures where minimal counterexamples matter. The skill lacks a dedicated "financial/precision" guidance section, but the general property-based guidance is sufficient for this use case.
