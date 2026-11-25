"""
URL utilities for the Web Doc Resolver.
"""

import logging
from urllib.parse import parse_qs, urlencode, urlparse

logger = logging.getLogger(__name__)

_TRACKING_PARAMS = {
    # UTM parameters
    "utm_source",
    "utm_medium",
    "utm_campaign",
    "utm_term",
    "utm_content",
    # Social/tracking parameters
    "fbclid",
    "gclid",
    "gclsrc",
    "dclid",
    "msclkid",
    "twclid",
    "li_fat_id",
    "mc_cid",
    "mc_eid",
    # Referral/tracking
    "ref",
    "ref_src",
    "ref_url",
    "source",
    "via",
    # Session/tracking
    "session_id",
    "sid",
    "_ga",
    "_gl",
    # Misc tracking
    "hsa_cam",
    "hsa_grp",
    "hsa_mt",
    "hsa_src",
    "hsa_ad",
    "hsa_acc",
    "hsa_net",
    "hsa_kw",
    "hsa_tgt",
    "hsa_ver",
}


def is_url(input_str: str) -> bool:
    if not input_str:
        return False
    trimmed = input_str.strip()
    if not trimmed:
        return False
    # Fast path: must start with http (case-insensitive check without full lower() allocation)
    prefix = trimmed[:8].lower()
    if not prefix.startswith(("http://", "https://")):
        return False
    try:
        result = urlparse(trimmed)
        return all([result.scheme in {"http", "https"}, result.netloc])
    except Exception:
        logger.debug("URL parsing failed: %s", trimmed, exc_info=True)
        return False


def normalize_url(url: str) -> str:
    """Normalize URL by stripping tracking params, anchors, and common aliases."""
    try:
        parsed = urlparse(url)
        # Strip all known tracking params
        if parsed.query:
            params = parse_qs(parsed.query)
            filtered_params = {
                k: v
                for k, v in params.items()
                if k.lower() not in _TRACKING_PARAMS and not k.startswith("utm_")
            }
            query = urlencode(filtered_params, doseq=True)
        else:
            query = ""

        # Normalize fragment: strip if empty or just a section ref
        fragment = "" if not parsed.fragment else parsed.fragment

        # Normalize trailing slash (keep for root, strip for paths)
        path = parsed.path
        if path and path != "/" and path.endswith("/"):
            path = path.rstrip("/")

        # Normalize netloc: lowercase, strip default ports
        netloc = parsed.netloc.lower()
        if netloc.endswith(":80") and parsed.scheme == "http":
            netloc = netloc[:-3]
        elif netloc.endswith(":443") and parsed.scheme == "https":
            netloc = netloc[:-4]

        # Reconstruct
        normalized = parsed._replace(
            scheme=parsed.scheme.lower(), netloc=netloc, path=path, query=query, fragment=fragment
        ).geturl()
        return normalized.strip()
    except Exception:
        logger.debug("URL normalization failed: %s", url, exc_info=True)
        return url.lower().strip()


def normalize_query(query: str) -> str:
    """Normalize search query."""
    # Lowercase, trim whitespace, and collapse multiple spaces
    # Using split() and join() is significantly faster than re.sub for collapsing whitespace
    return " ".join(query.lower().split())


def score_result(url: str | None, content: str) -> float:
    score = 0.5
    if url:
        try:
            domain = urlparse(url).netloc.lower()
            if any(domain.endswith(tld) for tld in [".edu", ".gov", ".org", ".rs", ".io"]):
                score += 0.2
            if any(
                site in domain
                for site in ["github.com", "stackoverflow.com", "docs.rs", "mozilla.org"]
            ):
                score += 0.2
        except Exception:
            logger.debug("URL domain scoring failed", exc_info=True)
    word_count = len(content.split())
    if word_count > 500:
        score += 0.1
    elif word_count < 50:
        score -= 0.2
    return max(0.0, min(1.0, score))
