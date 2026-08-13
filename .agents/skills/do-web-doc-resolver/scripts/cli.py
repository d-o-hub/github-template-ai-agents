#!/usr/bin/env python3
"""
CLI entrypoint for Web Doc Resolver.
"""

import argparse
import asyncio
import json
import logging
import os

# Persist learned per-domain provider preferences across CLI runs (AUDIT #25).
# Must be set before importing scripts.state (via scripts.resolve), which builds
# the routing-memory singleton at import time.
from scripts.constants import CACHE_DIR

os.environ.setdefault("DO_WDR_ROUTING_MEMORY_PATH", os.path.join(CACHE_DIR, "routing_memory.json"))

from scripts.models import Profile, ProviderType  # noqa: E402
from scripts.resolve import (  # noqa: E402
    MAX_CHARS,
    is_url,
    resolve_direct,
    resolve_query_stream,
    resolve_url_stream_async,
    resolve_with_order,
)


async def _async_main(args):
    """Async main function for URL resolution."""
    profile = Profile(args.profile)
    skip = set(args.skip) if args.skip else None

    if args.provider:
        results = [resolve_direct(args.input, ProviderType(args.provider), args.max_chars)]
    elif args.providers_order:
        order = [ProviderType(p.strip()) for p in args.providers_order.split(",")]
        results = [resolve_with_order(args.input, order, args.max_chars)]
    else:
        if is_url(args.input):
            # Use async URL resolver
            results = []
            async for res in resolve_url_stream_async(
                args.input, args.max_chars, profile, skip_providers=skip
            ):
                results.append(res)
        else:
            results = list(resolve_query_stream(args.input, args.max_chars, skip, profile))
    return results


def main():
    parser = argparse.ArgumentParser(description="Web Doc Resolver")
    parser.add_argument("input", nargs="?", help="URL or query")
    parser.add_argument("--max-chars", type=int, default=MAX_CHARS)
    parser.add_argument("--json", action="store_true")
    parser.add_argument(
        "--profile", type=str, choices=[p.value for p in Profile], default="balanced"
    )
    parser.add_argument("--skip", action="append")
    parser.add_argument("--provider", type=str, choices=[p.value for p in ProviderType])
    parser.add_argument("--providers-order", type=str)
    parser.add_argument("--log-level", default="INFO")
    args = parser.parse_args()
    logging.basicConfig(level=getattr(logging, args.log_level))
    if not args.input:
        parser.error("Input required")

    # Use asyncio.run for URL resolution
    if is_url(args.input) and not args.provider and not args.providers_order:
        results = asyncio.run(_async_main(args))
    else:
        profile = Profile(args.profile)
        skip = set(args.skip) if args.skip else None
        if args.provider:
            results = [resolve_direct(args.input, ProviderType(args.provider), args.max_chars)]
        elif args.providers_order:
            order = [ProviderType(p.strip()) for p in args.providers_order.split(",")]
            results = [resolve_with_order(args.input, order, args.max_chars)]
        else:
            results = list(resolve_query_stream(args.input, args.max_chars, skip, profile))

    final_result = None
    for res in results:
        if not args.json and res.get("source") != "partial":
            print(f"--- Source: {res.get('source')} ---")
            print(res.get("content", "")[:500] + "...")
        final_result = res
    if args.json:
        print(
            json.dumps(
                final_result,
                indent=2,
                default=lambda o: o.__dict__ if hasattr(o, "__dict__") else str(o),
            )
        )
    else:
        print("\n=== FINAL RESULT ===")
        if final_result:
            print(final_result.get("content", ""))


if __name__ == "__main__":
    main()
