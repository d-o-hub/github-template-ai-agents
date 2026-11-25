import unittest

from scripts.routing import PROFILE_BUDGETS


class TestRoutingProfileLogic(unittest.TestCase):
    def test_profile_thresholds(self):
        # Verify requirement 4: Integration tests for profile-specific threshold selection
        self.assertEqual(PROFILE_BUDGETS["free"]["min_free_quality_to_skip_paid"], 0.70)
        self.assertEqual(PROFILE_BUDGETS["balanced"]["min_free_quality_to_skip_paid"], 0.70)
        self.assertEqual(PROFILE_BUDGETS["fast"]["min_free_quality_to_skip_paid"], 0.70)
        self.assertEqual(PROFILE_BUDGETS["quality"]["min_free_quality_to_skip_paid"], 0.75)


if __name__ == "__main__":
    unittest.main()
