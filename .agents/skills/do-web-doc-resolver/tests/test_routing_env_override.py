import importlib
import os
import unittest
from unittest.mock import patch

import scripts.routing
from scripts.routing import ResolutionBudget


class TestRoutingEnvOverride(unittest.TestCase):
    def test_threshold_logic_respected(self):
        # High quality free result (0.8) meets threshold (0.7) -> skip paid
        budget = ResolutionBudget(3, 1, 10000, min_free_quality_to_skip_paid=0.7)
        score = 0.8
        self.assertTrue(score >= budget.min_free_quality_to_skip_paid)

        # High quality free result (0.8) DOES NOT meet threshold (0.9) -> continue to paid
        budget = ResolutionBudget(3, 1, 10000, min_free_quality_to_skip_paid=0.9)
        self.assertFalse(score >= budget.min_free_quality_to_skip_paid)

    def test_env_override_respected(self):
        with patch.dict(os.environ, {"DO_WDR_MIN_FREE_QUALITY_TO_SKIP_PAID": "0.99"}):
            importlib.reload(scripts.routing)
            self.assertEqual(scripts.routing.DEFAULT_MIN_FREE_QUALITY, 0.99)
            budget = scripts.routing.ResolutionBudget(3, 1, 10000)
            self.assertEqual(budget.min_free_quality_to_skip_paid, 0.99)

        # Restore
        importlib.reload(scripts.routing)

    def test_env_override_extreme_float_value(self):
        """Valid float env override with extreme value should work."""
        with patch.dict(os.environ, {"DO_WDR_MIN_FREE_QUALITY_TO_SKIP_PAID": "1e-10"}):
            importlib.reload(scripts.routing)
            self.assertAlmostEqual(scripts.routing.DEFAULT_MIN_FREE_QUALITY, 1e-10)
            budget = scripts.routing.ResolutionBudget(3, 1, 10000)
            self.assertAlmostEqual(budget.min_free_quality_to_skip_paid, 1e-10)

        importlib.reload(scripts.routing)

    def test_env_override_unset_uses_default(self):
        """When env var is not set, default 0.70 is used."""
        # Pop only the key we care about to avoid nuking PATH/HOME/etc
        with patch.dict(os.environ, {}, clear=False) as env:
            env.pop("DO_WDR_MIN_FREE_QUALITY_TO_SKIP_PAID", None)
            importlib.reload(scripts.routing)
            self.assertEqual(scripts.routing.DEFAULT_MIN_FREE_QUALITY, 0.70)

        importlib.reload(scripts.routing)

    def test_env_override_zero_value(self):
        """Zero env override should produce 0.0 threshold."""
        with patch.dict(os.environ, {"DO_WDR_MIN_FREE_QUALITY_TO_SKIP_PAID": "0"}):
            importlib.reload(scripts.routing)
            self.assertEqual(scripts.routing.DEFAULT_MIN_FREE_QUALITY, 0.0)
            budget = scripts.routing.ResolutionBudget(3, 1, 10000)
            # 0 threshold means any free result can skip paid
            self.assertTrue(0.0 >= budget.min_free_quality_to_skip_paid)

        importlib.reload(scripts.routing)

    def test_all_profile_budgets_have_valid_keys(self):
        """All profile budgets must have required keys with valid types."""
        required_keys = {
            "max_provider_attempts": int,
            "max_paid_attempts": int,
            "max_total_latency_ms": int,
            "min_free_quality_to_skip_paid": float,
            "allow_paid": bool,
        }
        for profile_name, budget in scripts.routing.PROFILE_BUDGETS.items():
            for key, expected_type in required_keys.items():
                self.assertIn(key, budget, f"{profile_name} missing key: {key}")
                self.assertIsInstance(
                    budget[key],
                    expected_type,
                    f"{profile_name}.{key} expected {expected_type}, got {type(budget[key])}",
                )


if __name__ == "__main__":
    unittest.main()
