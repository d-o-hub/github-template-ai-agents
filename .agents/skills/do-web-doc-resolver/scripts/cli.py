#!/usr/bin/env python3
"""
CLI entrypoint for Web Doc Resolver.
"""

import argparse
import json
import logging

from scripts.models import Profile, ProviderType
from scripts.resolve import (
    MAX_CHARS,
    is_url,
    resolve_direct,
    resolve_query_stream,
    resolve_url_stream,
    resolve_with_order,
)


def main():
    parser = argparse.ArgumentParser(description="Web Doc Resolver")
    parser.add_argument("input", nargs="?", help="URL or query")
    parser.add_argument("--max-chars", type=int, default=MAX_CHARS)
    parser.add_argument("--json", action="store_true")
    parser.add_argument(
        "--profile", type=str, choices=[p.value for p in Profile], default="balanced"
    )
    parser.add_argument("--skip", action="append")
    parser.add_argument("--provider", type=str)
    parser.add_argument("--providers-order", type=str)
    parser.add_argument("--log-level", default="INFO")
    args = parser.parse_args()
    logging.basicConfig(level=getattr(logging, args.log_level))
    if not args.input:
        parser.error("Input required")
    profile = Profile(args.profile)
    skip = set(args.skip) if args.skip else None
    if args.provider:
        results = [resolve_direct(args.input, ProviderType(args.provider), args.max_chars)]
    elif args.providers_order:
        order = [ProviderType(p.strip()) for p in args.providers_order.split(",")]
        results = [resolve_with_order(args.input, order, args.max_chars)]
    else:
        if is_url(args.input):
            results = resolve_url_stream(args.input, args.max_chars, profile)
        else:
            results = resolve_query_stream(args.input, args.max_chars, skip, profile)
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
