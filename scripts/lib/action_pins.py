"""Resolve the version a SHA-pinned GitHub Action reference actually points at.

A 40-character SHA says nothing about its version, so the `# vX.Y.Z` label
beside a pin can only be checked against upstream. Workflow tests keep a local
cache of reviewed pins and stay offline for those; a pin the cache does not
know -- the normal shape of a dependency-bot bump -- is resolved here instead
of demanding a hand-maintained cache entry, which would gate every bot PR on
bookkeeping a bot cannot do.
"""

from __future__ import annotations

import json
import os
import re
import urllib.error
import urllib.request

API_ROOT = "https://api.github.com"
TIMEOUT_SECONDS = 10

# Owner/repo and tag come from repository-owned workflow files, not user input;
# these patterns keep a malformed value from escaping the API path it is pasted
# into. The owner/repo shape is required, and `..` is rejected outright.
_SAFE_SLUG = re.compile(r"^[A-Za-z0-9._-]+/[A-Za-z0-9._-]+$")
_SAFE_TAG = re.compile(r"^[A-Za-z0-9._-]+$")
_SHA_LENGTH = 40


def _request(path: str) -> dict | None:
    """GET an api.github.com path, returning None on any failure.

    An unauthenticated request is allowed: the callers only need one or two
    lookups, and the pin labels themselves are public data. A token, when the
    environment provides one, raises the rate limit.
    """
    headers = {"Accept": "application/vnd.github+json"}
    token = os.environ.get("GITHUB_TOKEN") or os.environ.get("GH_TOKEN")
    if token:
        headers["Authorization"] = f"Bearer {token}"
    request = urllib.request.Request(f"{API_ROOT}{path}", headers=headers)
    try:
        with urllib.request.urlopen(request, timeout=TIMEOUT_SECONDS) as response:
            payload = json.load(response)
    except (urllib.error.URLError, OSError, ValueError):
        return None
    return payload if isinstance(payload, dict) else None


def resolve_tag_commit(action: str, tag: str) -> str | None:
    """Return the commit SHA `tag` points at in `action`, or None.

    Annotated tags are peeled to the commit they reference so the result is
    directly comparable with the SHA in a workflow's `uses:` pin. Returns None
    when the tag does not exist, the repository is unreachable, or the response
    carries no usable commit.
    """
    if ".." in action or not _SAFE_SLUG.match(action) or not _SAFE_TAG.match(tag):
        return None
    ref = _request(f"/repos/{action}/git/ref/tags/{tag}")
    if ref is None:
        return None
    target = ref.get("object")
    if not isinstance(target, dict):
        return None
    if target.get("type") == "tag":
        annotated = _request(f"/repos/{action}/git/tags/{target.get('sha')}")
        target = (annotated or {}).get("object")
        if not isinstance(target, dict):
            return None
    sha = target.get("sha")
    if not isinstance(sha, str) or len(sha) != _SHA_LENGTH:
        return None
    return sha
