"""
Two-stage synthesis gating logic for the Web Doc Resolver.
"""

import logging
from difflib import SequenceMatcher

from .models import ResolvedResult

logger = logging.getLogger(__name__)

# Constants for synthesis gating
SIMILARITY_THRESHOLD = 0.2
CONTENT_SIMILARITY_LIMIT = 2000


def _content_similarity(a: str, b: str) -> float:
    """Compute similarity ratio between two strings (0.0 to 1.0)."""
    if not a or not b:
        return 0.0

    # Truncate to limit to ensure performance if called with large strings
    a_trunc = a[:CONTENT_SIMILARITY_LIMIT]
    b_trunc = b[:CONTENT_SIMILARITY_LIMIT]

    matcher = SequenceMatcher(None, a_trunc, b_trunc)
    if matcher.real_quick_ratio() < SIMILARITY_THRESHOLD:
        return 0.0
    if matcher.quick_ratio() < SIMILARITY_THRESHOLD:
        return 0.0
    return matcher.ratio()


def _has_conflicts(results: list[ResolvedResult]) -> bool:
    """Check if results contain conflicting information."""
    if len(results) < 2:
        return False

    # Pre-truncate content to avoid redundant slicing in the O(N^2) loop
    contents = [
        r.content[:CONTENT_SIMILARITY_LIMIT] if r.content else "" for r in results
    ]

    for i in range(len(contents)):
        content_i = contents[i]
        for j in range(i + 1, len(contents)):
            # _content_similarity also truncates, but it's now cheap since strings are already short
            similarity = _content_similarity(content_i, contents[j])
            if similarity < SIMILARITY_THRESHOLD:
                return True
    return False


def _is_fragmented(results: list[ResolvedResult], min_chars: int = 500) -> bool:
    """Check if results are too fragmented individually."""
    short_count = sum(1 for r in results if len(r.content) < min_chars)
    return short_count > len(results) / 2


def synthesis_gate_decision(
    results: list[ResolvedResult], threshold: float = 0.8
) -> tuple[bool, str]:
    """
    Two-stage synthesis gate: decide whether to call LLM based on result quality.

    Returns (should_call, reason).
    """
    if not results:
        return False, "no_results"

    if len(results) == 1:
        score = results[0].score
        if score >= threshold:
            logger.info("synthesis_gate decision=skip reason=single_high_quality score=%.2f", score)
            return False, "single_high_quality"
        logger.info("synthesis_gate decision=call reason=single_low_quality score=%.2f", score)
        return True, "single_low_quality"

    if _has_conflicts(results):
        logger.info("synthesis_gate decision=call reason=conflicts sources=%d", len(results))
        return True, "conflicts"

    if _is_fragmented(results):
        logger.info("synthesis_gate decision=call reason=fragmented sources=%d", len(results))
        return True, "fragmented"

    total_len = sum(len(r.content) for r in results if r.content)
    if total_len < 1000:
        logger.info("synthesis_gate decision=call reason=insufficient_content total=%d", total_len)
        return True, "insufficient_content"

    logger.info(
        "synthesis_gate decision=skip reason=complete sources=%d total_chars=%d",
        len(results),
        total_len,
    )
    return False, "complete"


def should_call_llm_synthesis(results: list[ResolvedResult], threshold: float = 0.8) -> bool:
    """Decide whether to call LLM synthesis. Wrapper around synthesis_gate_decision."""
    should_call, _reason = synthesis_gate_decision(results, threshold)
    return should_call


def deterministic_merge(results: list[ResolvedResult]) -> str:
    """
    Deterministically merge multiple results without an LLM.
    Deduplicates content and merges with source attribution.
    """
    if not results:
        return ""
    if len(results) == 1:
        return results[0].content

    merged = []
    seen_lines: set[str] = set()

    for i, res in enumerate(results):
        lines = res.content.splitlines()
        unique_lines = []
        for line in lines:
            stripped = line.strip()
            if stripped and stripped not in seen_lines:
                unique_lines.append(line)
                seen_lines.add(stripped)
            elif not stripped:
                unique_lines.append("")
        content = "\n".join(unique_lines).strip()
        if content:
            source_label = res.source.replace("_", " ").title()
            merged.append(f"### Source {i + 1}: {source_label}\n{content}")

    return "\n\n---\n\n".join(merged)

import datetime

import requests


def synthesize_results(query: str, results: list[ResolvedResult], api_key: str, model: str) -> str:
    """
    Synthesize multiple results into a cohesive, LLM-ready markdown document.
    Follows 2026 LLM-Readable-Doc standards.
    """
    if not results:
        return "No results to synthesize."

    if not should_call_llm_synthesis(results):
        return deterministic_merge(results)

    context = "".join(
        [
            f"\nResult {i + 1}:\nURL: {res.url or 'unk'}\nContent: {res.content}\n---\n"
            for i, res in enumerate(results)
        ]
    )

    current_date = datetime.date.today().isoformat()

    system_prompt = (
        "You are an expert research assistant. Synthesize the provided context into a high-quality, "
        "LLM-ready markdown document following the 2026 LLM-Readable-Doc standards.\n\n"
        "REQUIRED FORMAT:\n"
        "1. Include Token-Efficiency Headers (YAML frontmatter):\n"
        "---\n"
        "relevance_score: <0.0-1.0>\n"
        "intent_category: <Technical|Informational|Comparative|Debugging>\n"
        "token_estimate: <int>\n"
        f"last_updated: {current_date}\n"
        "---\n\n"
        "2. Use Structural Anchors to partition the content for RAG performance:\n"
        "- [ANCHOR: SUMMARY] - High-level synthesis of findings.\n"
        "- [ANCHOR: TECHNICAL_DETAILS] - Specs, code, or architecture details.\n"
        "- [ANCHOR: COMPARISON] - Trade-offs and alternatives (if applicable).\n"
        "- [ANCHOR: CITATIONS] - Source URL mapping.\n\n"
        "3. Adhere to strict formatting requirements:\n"
        "- Use strict CommonMark for maximum compatibility.\n"
        "- Aggressively deduplicate redundant information across sources.\n"
        "- Ensure citation precision: follow claims with bracketed indices (e.g., [1]) matching the CITATIONS anchor."
    )

    user_prompt = f"Query: '{query}'\n\nContext:\n{context}"

    try:
        resp = requests.post(
            "https://api.mistral.ai/v1/chat/completions",
            headers={
                "Authorization": f"Bearer {api_key}",
                "Content-Type": "application/json",
            },
            json={
                "model": model,
                "messages": [
                    {"role": "system", "content": system_prompt},
                    {"role": "user", "content": user_prompt},
                ],
                "temperature": 0.3,
            },
            timeout=30,
        )
        resp.raise_for_status()
        content = resp.json()["choices"][0]["message"]["content"]
        return str(content)
    except Exception as e:
        logger.error(f"LLM Synthesis failed: {e}")
        return deterministic_merge(results)
