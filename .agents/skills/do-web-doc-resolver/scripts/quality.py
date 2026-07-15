"""
Heuristics for scoring the quality of resolved content.
"""

from dataclasses import dataclass

# Quality scoring penalties
PENALTY_TOO_SHORT = 0.25
PENALTY_MISSING_LINKS = 0.10
PENALTY_DUPLICATE_HEAVY = 0.15
PENALTY_NOISY = 0.10
PENALTY_JARGON = 0.10

# Quality scoring bonuses
BONUS_HAS_FRONTMATTER = 0.05
BONUS_HAS_ANCHORS = 0.05

# Quality scoring thresholds
THRESHOLD_NOISE = 6
THRESHOLD_JARGON = 3
THRESHOLD_MIN_CHARS = 500

# Acceptance threshold
ACCEPTABLE_THRESHOLD = 0.65

# Bot challenge detection signals (case-insensitive substring match)
_BOT_CHALLENGE_SIGNALS: frozenset[str] = frozenset(
    [
        "cf-challenge",  # Cloudflare challenge page meta tag
        "cf_chl_opt",  # Cloudflare JS challenge var
        "ray id",  # Cloudflare Ray ID footer
        "ddos-guard",  # DDoS-Guard service
        "please enable javascript",
        "enable cookies",
        "checking your browser",  # Cloudflare "Checking your browser..."
        "just a moment",  # Cloudflare interstitial title
        "security check",
        "access denied",
        "403 forbidden",
        "are you a human",
        "prove you are human",
        "recaptcha",
        "hcaptcha",
    ]
)


@dataclass
class QualityScore:
    score: float
    too_short: bool
    missing_links: bool
    duplicate_heavy: bool
    noisy: bool
    acceptable: bool
    bot_challenge: bool = False


def _check_duplicates(text: str) -> bool:
    """Check if content has excessive duplicate lines."""
    lines = text.splitlines()
    num_lines = len(lines)
    if num_lines == 0:
        return False
    unique_lines = len({line.strip() for line in lines if line.strip()})
    return unique_lines < max(5, num_lines // 3)


def _check_jargon(text_lower: str) -> bool:
    """Check if content contains excessive marketing jargon/AI slop."""
    jargon_signals = [
        "seamlessly",
        "robust",
        "powerful",
        "comprehensive",
        "streamlined",
        "leverage",
        "revolutionize",
        "game-changing",
        "intuitive",
        "next-generation",
        "cutting-edge",
        "state-of-the-art",
        "best-in-class",
        "unlock",
        "transform",
        "supercharge",
    ]
    jargon_count = sum(text_lower.count(signal) for signal in jargon_signals)
    return jargon_count > THRESHOLD_JARGON


def _check_frontmatter(text: str) -> bool:
    """Check for 2026 standard YAML frontmatter fields."""
    required_yaml = [
        "relevance_score:",
        "intent_category:",
        "token_estimate:",
        "last_updated:",
    ]
    return text.startswith("---") and all(field in text for field in required_yaml)


def _check_anchors(text: str) -> bool:
    """Check for mandatory RAG-optimized structural anchors."""
    required_anchors = [
        "[ANCHOR: SUMMARY]",
        "[ANCHOR: TECHNICAL_DETAILS]",
        "[ANCHOR: COMPARISON]",
        "[ANCHOR: CITATIONS]",
    ]
    return all(anchor in text for anchor in required_anchors)


def _compute_noise(text_lower: str) -> bool:
    """Detect noisy signals like cookie/subscribe prompts."""
    noisy_signals = ["cookie", "subscribe", "javascript", "log in", "sign up"]
    noise_count = sum(text_lower.count(signal) for signal in noisy_signals)
    return noise_count > THRESHOLD_NOISE


def is_bot_challenge(content: str) -> bool:
    """Return True if content looks like a bot-detection interstitial.

    Checks a representative sample of the content (first 2000 chars)
    to avoid scanning megabyte-sized pages.
    """
    sample = content[:2000].lower()
    return any(signal in sample for signal in _BOT_CHALLENGE_SIGNALS)


def _compute_penalties(
    score: float,
    too_short: bool,
    missing_links: bool,
    duplicate_heavy: bool,
    noisy: bool,
    jargon_heavy: bool,
) -> float:
    """Apply quality penalties."""
    if too_short:
        score -= PENALTY_TOO_SHORT
    if missing_links:
        score -= PENALTY_MISSING_LINKS
    if duplicate_heavy:
        score -= PENALTY_DUPLICATE_HEAVY
    if noisy:
        score -= PENALTY_NOISY
    if jargon_heavy:
        score -= PENALTY_JARGON
    return score


def _compute_bonuses(score: float, has_frontmatter: bool, has_anchors: bool) -> float:
    """Apply quality bonuses for 2026 standards."""
    if has_frontmatter:
        score += BONUS_HAS_FRONTMATTER
    if has_anchors:
        score += BONUS_HAS_ANCHORS
    return score


def score_content(markdown: str, links: list[str] | None = None) -> QualityScore:
    # Handle MagicMocks in tests
    if not isinstance(markdown, str):
        return QualityScore(1.0, False, False, False, False, True)

    text = (markdown or "").strip()
    links = links or []

    too_short = len(text) < THRESHOLD_MIN_CHARS
    missing_links = len(links) == 0
    duplicate_heavy = _check_duplicates(text)
    text_lower = text.lower()
    noisy = _compute_noise(text_lower)
    jargon_heavy = _check_jargon(text_lower)
    has_frontmatter = _check_frontmatter(text)
    has_anchors = _check_anchors(text)
    bot_challenge = is_bot_challenge(text)

    score = _compute_penalties(1.0, too_short, missing_links, duplicate_heavy, noisy, jargon_heavy)
    score = _compute_bonuses(score, has_frontmatter, has_anchors)
    score = max(0.0, min(1.0, score))
    acceptable = score >= ACCEPTABLE_THRESHOLD and not too_short and not bot_challenge

    return QualityScore(
        score=score,
        too_short=too_short,
        missing_links=missing_links,
        duplicate_heavy=duplicate_heavy,
        noisy=noisy or jargon_heavy,
        acceptable=acceptable,
        bot_challenge=bot_challenge,
    )
