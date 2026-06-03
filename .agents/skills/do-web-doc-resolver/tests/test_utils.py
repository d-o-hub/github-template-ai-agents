"""Edge case tests for utility functions in scripts/utils.py."""

from scripts.models import ErrorType
from scripts.utils import (
    _detect_error_type,
    compact_content,
    is_safe_url,
    is_url,
    normalize_query,
)

# ─── is_url ──────────────────────────────────────────────────────────────


class TestIsUrl:
    def test_standard_http_url(self):
        assert is_url("http://example.com") is True

    def test_standard_https_url(self):
        assert is_url("https://example.com/path?query=1") is True

    def test_empty_string(self):
        assert is_url("") is False

    def test_whitespace_only(self):
        assert is_url("   ") is False

    def test_missing_scheme(self):
        assert is_url("example.com") is False

    def test_ftp_scheme_rejected(self):
        assert is_url("ftp://example.com") is False

    def test_file_scheme_rejected(self):
        assert is_url("file:///etc/passwd") is False

    def test_javascript_scheme_rejected(self):
        assert is_url("javascript:alert(1)") is False

    def test_url_with_leading_whitespace(self):
        assert is_url("  https://example.com") is True

    def test_url_with_trailing_whitespace(self):
        assert is_url("https://example.com  ") is True

    def test_no_netloc(self):
        assert is_url("https://") is False

    def test_long_url(self):
        path = "/a" * 500
        assert is_url(f"https://example.com{path}") is True


# ─── is_safe_url ──────────────────────────────────────────────────────────


class TestIsSafeUrl:
    def test_standard_https_safe(self):
        assert is_safe_url("https://example.com") is True

    def test_file_scheme_blocked(self):
        assert is_safe_url("file:///etc/passwd") is False

    def test_javascript_scheme_blocked(self):
        assert is_safe_url("javascript:void(0)") is False

    def test_data_scheme_blocked(self):
        assert is_safe_url("data:text/html,<script>alert(1)</script>") is False

    def test_localhost_ipv4_blocked(self):
        assert is_safe_url("http://127.0.0.1/admin") is False

    def test_localhost_ipv6_blocked(self):
        assert is_safe_url("http://[::1]/admin") is False

    def test_localhost_name_blocked(self):
        assert is_safe_url("http://localhost:3000") is False

    def test_private_ip_10_blocked(self):
        assert is_safe_url("http://10.0.0.1") is False

    def test_private_ip_192_168_blocked(self):
        assert is_safe_url("http://192.168.1.1") is False

    def test_private_ip_172_blocked(self):
        assert is_safe_url("http://172.16.0.1") is False

    def test_zero_ip_blocked(self):
        assert is_safe_url("http://0.0.0.0") is False

    def test_link_local_blocked(self):
        assert is_safe_url("http://169.254.1.1") is False

    def test_local_tld_blocked(self):
        assert is_safe_url("http://myapp.local") is False

    def test_internal_tld_blocked(self):
        assert is_safe_url("http://service.internal") is False

    def test_no_hostname(self):
        assert is_safe_url("http://") is False

    def test_non_http_scheme(self):
        assert is_safe_url("ftp://safe.com") is False

    def test_exception_returns_false(self):
        # Passing something completely invalid that would crash parsing
        result = is_safe_url(None)
        assert result is False

    def test_normal_public_ip_safe(self):
        assert is_safe_url("https://8.8.8.8") is True


# ─── normalize_query ──────────────────────────────────────────────────────


class TestNormalizeQuery:
    def test_lowercases(self):
        assert normalize_query("PYTHON Tutorial") == "python tutorial"

    def test_collapses_multiple_spaces(self):
        assert normalize_query("python    tutorial  guide") == "python tutorial guide"

    def test_strips_leading_trailing(self):
        assert normalize_query("  python  ") == "python"

    def test_preserves_single_spaces(self):
        assert normalize_query("python tutorial") == "python tutorial"

    def test_empty_string(self):
        assert normalize_query("") == ""

    def test_only_spaces(self):
        assert normalize_query("   ") == ""

    def test_tabs_collapsed(self):
        assert normalize_query("python\ttutorial") == "python tutorial"

    def test_newlines_collapsed(self):
        result = normalize_query("python\ntutorial")
        assert "python" in result
        assert "tutorial" in result


# ─── compact_content ──────────────────────────────────────────────────────


class TestCompactContent:
    def test_removes_duplicate_lines(self):
        content = "line A\nline B\nline A\nline C\n"
        result = compact_content(content, 10000)
        assert result.count("line A") == 1
        assert result.count("line B") == 1
        assert result.count("line C") == 1

    def test_preserves_blank_lines(self):
        content = "line A\n\nline B\n"
        result = compact_content(content, 10000)
        assert "" in result.splitlines()

    def test_truncates_to_max_chars(self):
        content = "a" * 5000
        result = compact_content(content, 100)
        assert len(result) <= 100

    def test_trims_whitespace_per_line(self):
        content = "  line A  \n  line B  \n"
        result = compact_content(content, 10000)
        assert result.count("line A") == 1
        # Trimmed lines should not have leading/trailing whitespace
        for line in result.splitlines():
            if line:
                assert line == line.strip()

    def test_empty_content(self):
        result = compact_content("", 100)
        assert result == ""

    def test_preserves_unique_ordering(self):
        content = "z\nb\na\nz\n"
        result = compact_content(content, 10000)
        lines = [line for line in result.splitlines() if line]
        assert lines == ["z", "b", "a"]

    def test_max_chars_zero(self):
        result = compact_content("hello", 0)
        assert result == ""

    def test_only_duplicates(self):
        content = "same\nsame\nsame\n"
        result = compact_content(content, 10000)
        assert result.count("same") == 1


# ─── _detect_error_type ───────────────────────────────────────────────────


class TestDetectErrorType:
    def test_rate_limit_429(self):
        err = Exception("HTTP 429 Too Many Requests")
        assert _detect_error_type(err) == ErrorType.RATE_LIMIT

    def test_rate_limit_text(self):
        err = Exception("rate limit exceeded")
        assert _detect_error_type(err) == ErrorType.RATE_LIMIT

    def test_auth_error(self):
        err = Exception("invalid api key")
        assert _detect_error_type(err) == ErrorType.AUTH_ERROR

    def test_quota_exhausted(self):
        err = Exception("credit exhausted")
        assert _detect_error_type(err) == ErrorType.QUOTA_EXHAUSTED

    def test_timeout(self):
        err = Exception("connection timed out")
        assert _detect_error_type(err) == ErrorType.TIMEOUT

    def test_network_error(self):
        err = Exception("network unreachable")
        assert _detect_error_type(err) == ErrorType.NETWORK_ERROR

    def test_not_found(self):
        err = Exception("404 not found")
        assert _detect_error_type(err) == ErrorType.NOT_FOUND

    def test_ssrf_blocked(self):
        err = Exception("SSRF blocked: localhost")
        assert _detect_error_type(err) == ErrorType.SSRF_BLOCKED

    def test_content_too_large(self):
        err = Exception("content size exceeds limit")
        assert _detect_error_type(err) == ErrorType.CONTENT_TOO_LARGE

    def test_unknown_error(self):
        err = Exception("something completely unexpected")
        assert _detect_error_type(err) == ErrorType.UNKNOWN

    def test_case_insensitive(self):
        err = Exception("RATE LIMIT EXCEEDED")
        assert _detect_error_type(err) == ErrorType.RATE_LIMIT
