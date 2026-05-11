import unittest
from unittest.mock import patch, MagicMock
import sys
import os

# Mock dependencies before importing scripts
sys.modules['requests'] = MagicMock()
sys.modules['requests.adapters'] = MagicMock()
sys.modules['urllib3.util.retry'] = MagicMock()

# Now import
from scripts.providers_impl import resolve_with_ocr, resolve_with_docling
from scripts.utils import is_shell_safe_url

class TestSecurityInjection(unittest.TestCase):

    @patch("scripts.providers_impl.download_to_temp_file")
    @patch("subprocess.run")
    def test_ocr_uses_local_file(self, mock_run, mock_download):
        # Setup
        mock_download.return_value = "/tmp/fake_local_file"
        mock_run.return_value = MagicMock(returncode=0, stdout="ocr result")

        # Execute
        url = "https://example.com/image.png"
        resolve_with_ocr(url, 100)

        # Verify
        mock_run.assert_called_once()
        args, kwargs = mock_run.call_args
        cmd = args[0]
        self.assertIn("/tmp/fake_local_file", cmd)
        self.assertNotIn(url, cmd)

    @patch("scripts.providers_impl.download_to_temp_file")
    @patch("subprocess.run")
    def test_docling_uses_local_file(self, mock_run, mock_download):
        # Setup
        mock_download.return_value = "/tmp/fake_local_file"
        mock_run.return_value = MagicMock(returncode=0, stdout="docling result")

        # Execute
        url = "https://example.com/doc.pdf"
        resolve_with_docling(url, 100)

        # Verify
        mock_run.assert_called_once()
        args, kwargs = mock_run.call_args
        cmd = args[0]
        self.assertIn("/tmp/fake_local_file", cmd)
        self.assertNotIn(url, cmd)

    @patch("scripts.providers_impl.is_safe_url")
    @patch("scripts.providers_impl.download_to_temp_file")
    @patch("subprocess.run")
    def test_safe_complex_urls_allowed(self, mock_run, mock_download, mock_safe_url):
        mock_safe_url.return_value = True
        mock_download.return_value = "/tmp/fake_local_file"
        mock_run.return_value = MagicMock(returncode=0, stdout="result")

        complex_urls = [
            "https://example.com/query?a=1&b=2",
            "https://example.com/index.php;session=abc",
            "https://example.com/file(1).pdf",
        ]
        for url in complex_urls:
            self.assertTrue(is_shell_safe_url(url), f"URL should be safe: {url}")

            # Test that providers allow and process them
            res_ocr = resolve_with_ocr(url, 100)
            self.assertTrue(res_ocr.ok)

            res_docling = resolve_with_docling(url, 100)
            self.assertTrue(res_docling.ok)

    @patch("scripts.providers_impl.is_safe_url")
    def test_injection_blocked_by_shell_safe_url(self, mock_safe_url):
        mock_safe_url.return_value = True
        dangerous_urls = [
            "https://example.com/foo | whoami",
            "https://example.com/foo`whoami`",
            "https://example.com/foo$(whoami)",
        ]
        for url in dangerous_urls:
            self.assertFalse(is_shell_safe_url(url), f"URL should be blocked: {url}")

            # Test that providers block it
            res_ocr = resolve_with_ocr(url, 100)
            self.assertFalse(res_ocr.ok)
            self.assertEqual(res_ocr.error, "injection_blocked")

            res_docling = resolve_with_docling(url, 100)
            self.assertFalse(res_docling.ok)
            self.assertEqual(res_docling.error, "injection_blocked")

if __name__ == "__main__":
    unittest.main()
