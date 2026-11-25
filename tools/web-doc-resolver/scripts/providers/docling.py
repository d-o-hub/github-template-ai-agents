"""
Docling and OCR provider implementations.
"""

import asyncio
import logging
import subprocess

from scripts.models import ResolvedResult
from scripts.utils import is_safe_url
from scripts.utils.async_http import is_safe_url as async_is_safe_url

logger = logging.getLogger(__name__)


async def resolve_with_docling_async(url: str, max_chars: int) -> ResolvedResult | None:
    """Async version of Docling resolver using asyncio subprocess."""
    if not async_is_safe_url(url):
        logger.warning("SSRF blocked: %s", url)
        return None
    try:
        proc = await asyncio.create_subprocess_exec(
            "docling",
            "--format",
            "markdown",
            url,
            stdout=asyncio.subprocess.PIPE,
            stderr=asyncio.subprocess.PIPE,
        )
        stdout, stderr = await asyncio.wait_for(proc.communicate(), timeout=60)
        if proc.returncode == 0:
            return ResolvedResult(source="docling", content=stdout.decode()[:max_chars], url=url)
    except TimeoutError:
        logger.warning("Docling timed out for URL: %s", url)
    except (OSError, subprocess.SubprocessError) as e:
        logger.warning("Docling resolution failed: %s: %s", type(e).__name__, e)
    return None


async def resolve_with_ocr_async(url: str, max_chars: int) -> ResolvedResult | None:
    """Async version of OCR resolver using asyncio subprocess."""
    if not async_is_safe_url(url):
        logger.warning("SSRF blocked: %s", url)
        return None
    try:
        proc = await asyncio.create_subprocess_exec(
            "tesseract",
            url,
            "stdout",
            stdout=asyncio.subprocess.PIPE,
            stderr=asyncio.subprocess.PIPE,
        )
        stdout, stderr = await asyncio.wait_for(proc.communicate(), timeout=30)
        if proc.returncode == 0:
            return ResolvedResult(
                source="ocr-tesseract", content=stdout.decode()[:max_chars], url=url
            )
    except TimeoutError:
        logger.warning("OCR timed out for URL: %s", url)
    except (OSError, subprocess.SubprocessError) as e:
        logger.warning("OCR resolution failed: %s: %s", type(e).__name__, e)
    return None


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
