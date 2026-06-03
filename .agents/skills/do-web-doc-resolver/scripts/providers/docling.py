"""
Docling and OCR provider implementations.
"""

import logging
import subprocess

from scripts.models import ResolvedResult
from scripts.utils import is_safe_url

logger = logging.getLogger(__name__)


def resolve_with_docling(url: str, max_chars: int) -> ResolvedResult | None:
    if not is_safe_url(url):
        logger.warning("SSRF blocked: %s", url)
        return None
    try:
        res = subprocess.run(
            ["docling", "--format", "markdown", url],
            capture_output=True,
            text=True,
            timeout=60,
            check=False,
        )
        if res.returncode == 0:
            return ResolvedResult(source="docling", content=res.stdout[:max_chars], url=url)
    except (subprocess.SubprocessError, OSError) as e:
        logger.warning("Docling resolution failed: %s: %s", type(e).__name__, e)
    return None


def resolve_with_ocr(url: str, max_chars: int) -> ResolvedResult | None:
    if not is_safe_url(url):
        logger.warning("SSRF blocked: %s", url)
        return None
    try:
        res = subprocess.run(
            ["tesseract", url, "stdout"], capture_output=True, text=True, timeout=30, check=False
        )
        if res.returncode == 0:
            return ResolvedResult(source="ocr-tesseract", content=res.stdout[:max_chars], url=url)
    except (subprocess.SubprocessError, OSError) as e:
        logger.warning("OCR resolution failed: %s: %s", type(e).__name__, e)
    return None
