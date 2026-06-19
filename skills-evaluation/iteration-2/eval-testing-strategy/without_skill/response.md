# Property-Based Testing Strategy for Python Payment Processing Module

## Overview

Property-based testing (PBT) validates that code satisfies invariants across a wide range of generated inputs, rather than testing individual examples. For a payment processing module, this catches edge cases that manual test cases miss—especially around currency arithmetic, rounding, and idempotency.

## Recommended Tool

Use [Hypothesis](https://hypothesis.readthedocs.io/) with its `hypothesis` and `hypothesis[strategies]` modules. It integrates natively with `pytest`.

```bash
pip install hypothesis pytest
```

---

## Core Properties to Test

### 1. Idempotency

Applying the same payment twice should not double-charge. Useful for retry scenarios.

```python
from hypothesis import given, strategies as st

@given(amount=st.decimals(min_value=0.01, max_value=100000, places=2),
       currency=st.sampled_from(["USD", "EUR", "GBP"]))
def test_payment_idempotency(payment_processor, amount, currency):
    idempotency_key = "test-key-123"
    result1 = payment_processor.charge(amount, currency, idempotency_key=idempotency_key)
    result2 = payment_processor.charge(amount, currency, idempotency_key=idempotency_key)
    assert result1.transaction_id == result2.transaction_id
    assert result1.amount == result2.amount
```

### 2. Immutability of Successful Transactions

Once a payment succeeds, the recorded amount must equal the requested amount.

```python
@given(amount=st.decimals(min_value=0.01, max_value=100000, places=2))
def test_successful_payment_records_exact_amount(payment_processor, amount):
    result = payment_processor.charge(amount, "USD")
    assert result.amount == amount
    assert result.status == "completed"
```

### 3. Zero/Negative Amount Rejection

Payments with zero or negative amounts must always fail.

```python
@given(amount=st.one_of(
    st.decimals(max_value=0, places=2),
    st.decimals(min_value=-1000, max_value=0, places=2)
))
def test_zero_negative_amount_rejected(payment_processor, amount):
    with pytest.raises(InvalidAmountError):
        payment_processor.charge(amount, "USD")
```

### 4. Refund Never Exceeds Original Charge

```python
@given(
    charge_amount=st.decimals(min_value=1, max_value=50000, places=2),
    refund_fraction=st.decimals(min_value=0, max_value=1, places=2),
)
def test_refund_does_not_exceed_charge(payment_processor, charge_amount, refund_fraction):
    charge = payment_processor.charge(charge_amount, "USD")
    refund_amount = charge_amount * refund_fraction
    refund = payment_processor.refund(charge.transaction_id, refund_amount)
    assert refund.amount <= charge.amount
```

### 5. Currency Consistency

The currency returned in a transaction must match the currency requested.

```python
@given(
    amount=st.decimals(min_value=0.01, max_value=100000, places=2),
    currency=st.sampled_from(["USD", "EUR", "GBP", "JPY"]),
)
def test_currency_consistency(payment_processor, amount, currency):
    result = payment_processor.charge(amount, currency)
    assert result.currency == currency
```

### 6. Sum of Partial Refunds Equals Total

Multiple partial refunds on a single charge should never exceed the original amount.

```python
from hypothesis import given, settings
from hypothesis.strategies import lists

@given(
    charge_amount=st.decimals(min_value=10, max_value=50000, places=2),
    refund_amounts=lists(
        st.decimals(min_value=0.5, max_value=100, places=2),
        min_size=1, max_size=5,
    ),
)
@settings(max_examples=200)
def test_partial_refund_sum_constraint(payment_processor, charge_amount, refund_amounts):
    charge = payment_processor.charge(charge_amount, "USD")
    total_refunded = Decimal("0")
    for amt in refund_amounts:
        if total_refunded + amt > charge_amount:
            with pytest.raises(RefundExceedsChargeError):
                payment_processor.refund(charge.transaction_id, amt)
        else:
            payment_processor.refund(charge.transaction_id, amt)
            total_refunded += amt
    assert total_refunded <= charge_amount
```

---

## Strategy Definitions

Define reusable Hypothesis strategies for payment-specific types:

```python
from decimal import Decimal
from hypothesis import strategies as st

# Valid payment amounts: positive, max 2 decimal places
valid_amount = st.decimals(
    min_value=Decimal("0.01"),
    max_value=Decimal("100000"),
    places=2,
)

# Supported ISO 4217 currencies
currency_code = st.sampled_from(["USD", "EUR", "GBP", "JPY", "CAD", "AUD"])

# Card number-like patterns (not real PANs)
card_token = st.from_regex(r"tok_[a-z0-9]{16}", fullmatch=True)

# Email for receipt
email = st.emails()

# Idempotency key
idempotency_key = st.uuids().map(str)
```

---

## Property Categories Summary

| Category | Property | Why It Matters |
|----------|----------|----------------|
| Idempotency | Same key = same result | Prevents double-charge on retries |
| Immutability | Success records exact amount | Audit trail accuracy |
| Invariants | Zero/negative rejected | Business rule enforcement |
| Boundedness | Refund ≤ charge | Prevents over-refunding |
| Consistency | Currency preserved | Cross-border correctness |
| Aggregation | Partial refund sum ≤ total | Accumulation correctness |

---

## Integration with CI

```yaml
# .github/workflows/test.yml (excerpt)
- name: Run property-based tests
  run: |
    pytest tests/properties/ -v --hypothesis-seed=0 --hypothesis-show-statistics
```

Use `--hypothesis-seed=0` for reproducible failures. Use `--hypothesis-show-statistics` to monitor coverage of generated inputs.

---

## Tips

- **Shrink failures**: Hypothesis automatically shrinks failing inputs to minimal examples. Capture the `@reproduce_failure` decorator output for regression tests.
- **Profile generation**: Use `@settings(max_examples=500)` for critical paths; 100 is fine for less critical properties.
- **Stateful testing**: For multi-step workflows (charge → partial refund → void), use `hypothesis.stateful.RuleBasedStateMachine`.
- **Database strategies**: If the processor persists to a DB, use `hypothesis[database]` to cache corpus across runs.
