import sys
import os
from unittest.mock import MagicMock, patch

# Add the skill scripts to path
sys.path.append(os.path.abspath(".agents/skills/do-web-doc-resolver"))

from scripts.utils import fetch_llms_txt, normalize_url

def test_fetch_llms_txt_ssrf():
    print("Testing fetch_llms_txt SSRF protection...")
    # This should be blocked by is_safe_url
    assert fetch_llms_txt("http://localhost/something") is None
    assert fetch_llms_txt("http://127.0.0.1/something") is None
    print("  SSRF protection OK")

@patch("scripts.utils.get_session")
@patch("scripts.utils._get_from_cache")
def test_fetch_llms_txt_strips_credentials(mock_cache, mock_get_session):
    print("Testing fetch_llms_txt strips credentials...")
    mock_cache.return_value = None
    mock_session = MagicMock()
    mock_get_session.return_value = mock_session
    mock_response = MagicMock()
    mock_response.status_code = 404
    mock_session.get.return_value = mock_response

    # Test with credentials
    fetch_llms_txt("http://user:pass@example.com/page")

    # Verify that the call to session.get used the URL without credentials
    args, kwargs = mock_session.get.call_args
    requested_url = args[0]
    print(f"  Requested URL: {requested_url}")
    assert "user:pass" not in requested_url
    assert requested_url == "http://example.com/llms.txt"
    print("  Credential stripping OK")

def test_normalize_url_strips_credentials():
    print("Testing normalize_url strips credentials...")
    url1 = "http://user:pass@example.com/page"
    url2 = "http://example.com/page"

    norm1 = normalize_url(url1)
    norm2 = normalize_url(url2)

    print(f"  Normalized 1: {norm1}")
    print(f"  Normalized 2: {norm2}")

    assert norm1 == norm2
    assert "user:pass" not in norm1
    print("  normalize_url OK")

if __name__ == "__main__":
    try:
        test_fetch_llms_txt_ssrf()
        test_fetch_llms_txt_strips_credentials()
        test_normalize_url_strips_credentials()
        print("\nAll targeted verification tests PASSED")
    except Exception as e:
        print(f"\nTargeted verification tests FAILED: {e}")
        import traceback
        traceback.print_exc()
        sys.exit(1)
