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

def test_score_result_subdomain_matching():
    # api.github.com should match
    url = "https://api.github.com"
    content = "word " * 600
    score = score_result(url, content)
    # 0.5 (base) + 0.1 (length) + 0.2 (github) = 0.8
    assert pytest.approx(score) == 0.8
