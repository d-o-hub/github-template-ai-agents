"""Stealth fetch provider — placeholder for anti-bot escalation tier.

TODO: Implement using playwright-stealth or curl-impersonate.
Currently raises NotImplementedError so cascade skips it gracefully
via the existing circuit-breaker error path.
"""

import logging

from scripts.models import ResolvedResult

logger = logging.getLogger(__name__)


def resolve_with_stealth(url: str, max_chars: int) -> ResolvedResult:
    """Stealth browser fetch (anti-bot bypass).

    Raises:
        NotImplementedError: Until a concrete implementation is chosen.
    """
    raise NotImplementedError(
        "stealth provider not yet implemented — "
        "candidates: playwright-stealth, curl-impersonate, camoufox"
    )
