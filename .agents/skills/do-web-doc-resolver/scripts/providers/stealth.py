"""Stealth fetch provider — placeholder for anti-bot escalation tier.

TODO: Implement using playwright-stealth or curl-impersonate.
Returns an empty result so the cascade skips it gracefully
via the existing circuit-breaker error path.
"""

import logging

from scripts.models import ResolvedResult

logger = logging.getLogger(__name__)


def resolve_with_stealth(url: str, max_chars: int) -> ResolvedResult:
    """Stealth browser fetch (anti-bot bypass).

    Returns an empty result until a concrete implementation is chosen.
    The cascade will treat this as a failed provider and move on.
    """
    logger.warning(
        "Stealth provider not yet implemented — skipping %s "
        "(candidates: playwright-stealth, curl-impersonate, camoufox)",
        url,
    )
    return ResolvedResult(
        source="stealth",
        url=url,
        content="",
        metadata={"error": "stealth provider not yet implemented"},
    )
