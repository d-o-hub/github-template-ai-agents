import pytest
from scripts.utils import is_shell_safe_url

def test_shell_safe_urls_allowed():
    # Common safe characters and standard URLs
    safe_urls = [
        "https://example.com/path/to/resource",
        "http://example.com/query?foo=bar&baz=qux",
        "https://example.com/index.php;session=123",
        "https://example.com/path/with(parentheses)",
        "https://example.com/path/with%20space",
        "https://example.com/path/with_underscore-dash.html",
        "https://example.com/path/with,comma",
    ]
    for url in safe_urls:
        assert is_shell_safe_url(url) is True, f"URL should be safe: {url}"

def test_shell_dangerous_urls_blocked():
    # Dangerous shell injection payloads
    dangerous_urls = [
        "https://example.com/foo | grep secret",  # Pipe and space
        "https://example.com/foo;rm -rf /",      # Space and semicolon command
        "https://example.com/foo`whoami`",       # Backticks
        "https://example.com/foo$(whoami)",      # Command substitution ($)
        "https://example.com/foo>output.txt",    # Redirection
        "https://example.com/foo<input.txt",     # Redirection
        "https://example.com/foo\\'bar",         # Single quote
        "https://example.com/foo\\\"bar",        # Double quote
        "https://example.com/foo\\\\bar",        # Backslash
        "https://example.com/foo*bar",           # Wildcard
    ]
    for url in dangerous_urls:
        assert is_shell_safe_url(url) is False, f"URL should be blocked: {url}"
