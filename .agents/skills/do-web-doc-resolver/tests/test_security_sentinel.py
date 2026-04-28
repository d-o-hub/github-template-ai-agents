import pytest
from scripts.utils import score_result

def test_score_result_masquerading():
    # evil.com masquerading as github.com using credentials
    url = "https://github.com@evil.com"
    score = score_result(url, "some content")
    # The default score is 0.5. "some content" is short (<50 words), so -0.2 penalty. Total 0.3.
    # If vulnerable, github.com@evil.com netloc match gives +0.2 bonus. Total 0.5.
    # If fixed, score remains 0.3.
    assert pytest.approx(score) == 0.3

def test_score_result_domain_matching():
    # mygithub.com should not match github.com
    url = "https://mygithub.com"
    # long content (>500 words) gives +0.1 bonus. 0.5 + 0.1 = 0.6.
    content = "word " * 600
    score = score_result(url, content)
    # If vulnerable, "github.com" in "mygithub.com" is True -> 0.6 + 0.2 = 0.8.
    # If fixed, it should be 0.6.
    assert pytest.approx(score) == 0.6

def test_score_result_legitimate_matching():
    # github.com should match
    url = "https://github.com/d-oit/do-web-doc-resolver"
    content = "word " * 600
    score = score_result(url, content)
    # 0.5 (base) + 0.1 (length) + 0.2 (github) = 0.8
    assert pytest.approx(score) == 0.8

from scripts.utils import is_safe_url

def test_is_safe_url_rejects_non_resolvable_hostnames():
    # Test that hostnames that do not resolve are rejected (fail-closed)
    # Using a .local or other TLD that definitely won't resolve in this environment
    assert is_safe_url("https://definitely-does-not-exist.invalid-tld") is False

def test_is_safe_url_allows_standard_public_url():
    # Ensure it still works for legitimate public URLs
    # github.com is highly likely to resolve and be global
    assert is_safe_url("https://github.com/d-oit/do-web-doc-resolver") is True

def test_is_safe_url_rejects_private_ips():
    assert is_safe_url("http://192.168.1.1") is False
    assert is_safe_url("http://10.0.0.1") is False
    assert is_safe_url("http://127.0.0.1") is False
    assert is_safe_url("http://localhost") is False

def test_score_result_subdomain_matching():
    # api.github.com should match
    url = "https://api.github.com"
    content = "word " * 600
    score = score_result(url, content)
    # 0.5 (base) + 0.1 (length) + 0.2 (github) = 0.8
    assert pytest.approx(score) == 0.8
