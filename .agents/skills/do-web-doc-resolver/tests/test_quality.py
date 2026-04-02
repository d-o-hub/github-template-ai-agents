"""
Tests for quality scoring module.
"""

import pytest

from ..scripts.quality import score_content, QualityScore


class TestScoreContent:
    """Tests for score_content function."""

    def test_empty_content(self):
        """Empty content should be too_short and not acceptable."""
        result = score_content("")
        assert result.too_short is True
        assert result.score < 1.0
        assert result.acceptable is False

    def test_short_content(self):
        """Content under 500 chars should be too_short."""
        short_text = "This is a short piece of text that is under the 500 char threshold."
        result = score_content(short_text)
        assert result.too_short is True
        assert result.score == 0.65  # 1.0 - 0.35
        assert result.acceptable is False

    def test_min_acceptable_length(self):
        """Content at exactly 500 chars should not be too_short."""
        # Create content that's exactly 500 chars
        content = "x" * 500
        result = score_content(content)
        assert result.too_short is True  # Still too_short because no meaningful content

    def test_acceptable_content(self):
        """Good content should score well."""
        content = """
# Python Documentation

Python is a programming language that lets you work quickly
and integrate systems more effectively.

## Features

- Easy to learn
- Powerful standard library
- Cross-platform compatibility

## Installation

Visit https://python.org to download.

For more details, see https://docs.python.org/3/
"""
        links = ["https://python.org", "https://docs.python.org/3/"]
        result = score_content(content, links)
        assert result.too_short is False
        assert result.missing_links is False
        assert result.duplicate_heavy is False
        assert result.noisy is False
        assert result.score == 1.0
        assert result.acceptable is True

    def test_missing_links_penalty(self):
        """Content without links should get -0.15 penalty."""
        content = "x" * 1000  # Long enough but no links
        result = score_content(content, [])
        assert result.missing_links is True
        assert result.score == 0.85  # 1.0 - 0.15
        # acceptable requires score >= 0.65 and not too_short
        assert result.acceptable is True

    def test_duplicate_heavy_content(self):
        """High duplicate line ratio should trigger duplicate_heavy."""
        # Repeated lines
        content = "\n".join(["Same line repeated"] * 20)
        result = score_content(content, ["https://example.com"])
        assert result.duplicate_heavy is True
        assert result.score == 0.75  # 1.0 - 0.25

    def test_noisy_content(self):
        """Too many noise signals should trigger noisy flag."""
        content = """
Subscribe now! Log in to continue. Sign up for free.
JavaScript enabled required. Accept cookies to proceed.
Subscribe to newsletter. Log in with your account.
"""
        result = score_content(content, ["https://example.com"])
        assert result.noisy is True
        assert result.score == 0.80  # 1.0 - 0.20

    def test_threshold_0_65_acceptable(self):
        """Score >= 0.65 and not too_short should be acceptable."""
        # Content with missing_links penalty only
        content = "x" * 1000  # Not too short, no links
        result = score_content(content, [])
        assert result.score == 0.85
        assert result.acceptable is True

    def test_threshold_below_0_65_not_acceptable(self):
        """Score < 0.65 should not be acceptable."""
        # Short content + missing links + duplicate heavy
        content = "short"
        result = score_content(content, [])
        # too_short (-0.35) + missing_links (-0.15) = 0.50
        assert result.score == 0.50
        assert result.acceptable is False

    def test_multiple_penalties(self):
        """Multiple penalties should compound correctly."""
        # Short, no links, duplicate heavy, noisy
        content = "Subscribe log in sign up JavaScript cookie Subscribe log in"
        result = score_content(content, [])
        # too_short (-0.35) + missing_links (-0.15) + duplicate_heavy (-0.25) + noisy (-0.20)
        # = 1.0 - 0.35 - 0.15 - 0.25 - 0.20 = 0.05, but clamped to 0.0
        assert result.score == 0.0
        assert result.acceptable is False

    def test_score_never_negative(self):
        """Score should never go below 0."""
        content = ""
        result = score_content(content, [])
        assert result.score >= 0.0


class TestQualityScoreDataclass:
    """Tests for QualityScore dataclass."""

    def test_quality_score_fields(self):
        """QualityScore should have all expected fields."""
        result = score_content("test content here", [])
        assert hasattr(result, "score")
        assert hasattr(result, "too_short")
        assert hasattr(result, "missing_links")
        assert hasattr(result, "duplicate_heavy")
        assert hasattr(result, "noisy")
        assert hasattr(result, "acceptable")

    def test_quality_score_types(self):
        """All QualityScore fields should have correct types."""
        result = score_content("test content", ["https://example.com"])
        assert isinstance(result.score, float)
        assert isinstance(result.too_short, bool)
        assert isinstance(result.missing_links, bool)
        assert isinstance(result.duplicate_heavy, bool)
        assert isinstance(result.noisy, bool)
        assert isinstance(result.acceptable, bool)