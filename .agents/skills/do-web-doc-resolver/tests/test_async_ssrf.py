"""Async SSRF guard coverage and sync/async parity.

`scripts.utils.async_http` keeps its own copies of `_getaddrinfo_cached`,
`_normalize_host`, and `is_safe_url`, while `scripts.utils` re-exports the sync
versions from `scripts.utils.http`. Coverage that imports `scripts.utils`
therefore exercises only the sync copy and leaves the async path — which
validates every redirect hop in `async_safe_request` — unexercised.

These tests pin the async copy to the same encodings as the sync one, and add a
parity guard so a future fix to one copy fails loudly until the other matches.
"""

import os
import sys

sys.path.insert(0, os.path.join(os.path.dirname(__file__), ".."))

from scripts.utils.async_http import _normalize_host as normalize_async
from scripts.utils.async_http import is_safe_url as is_safe_url_async
from scripts.utils.http import _normalize_host as normalize_sync
from scripts.utils.http import is_safe_url as is_safe_url_sync

# Every spelling of loopback / private space the validator is expected to reject.
# `0.0.0.0` and the metadata IP resolve without a nameserver, so no test here
# depends on DNS.
BLOCKED_LITERALS = [
    "127.0.0.1",
    "127.1",
    "2130706433",  # decimal integer
    "0x7f000001",  # hex integer
    "017700000001",  # leading-zero octal integer
    "0o17700000001",  # explicit octal integer
    "0177.0.0.1",  # dotted octal octet
    "0x7f.0.0.1",  # dotted hex octet
    "::ffff:127.0.0.1",  # IPv4-mapped IPv6
    "0.0.0.0",
    "10.0.0.1",
    "100.64.0.1",  # carrier-grade NAT
    "169.254.169.254",  # cloud metadata
]

PUBLIC_LITERALS = [
    "93.184.215.69",  # example.com, as a literal to stay off DNS
    "8.8.8.8",
]


class TestAsyncBlocksEncodedLoopback:
    def test_decimal_ip_blocked(self):
        assert is_safe_url_async("http://2130706433/") is False

    def test_hex_ip_blocked(self):
        assert is_safe_url_async("http://0x7f000001/") is False

    def test_octal_ip_blocked(self):
        assert is_safe_url_async("http://017700000001/") is False
        assert is_safe_url_async("http://0177.0.0.1/") is False
        assert is_safe_url_async("http://0o17700000001/") is False

    def test_mapped_ipv6_blocked(self):
        assert is_safe_url_async("http://[::ffff:127.0.0.1]/") is False

    def test_every_blocked_literal(self):
        for host in BLOCKED_LITERALS:
            url = f"http://[{host}]/" if ":" in host else f"http://{host}/"
            assert is_safe_url_async(url) is False, host

    def test_public_literals_allowed(self):
        for host in PUBLIC_LITERALS:
            assert is_safe_url_async(f"http://{host}/") is True, host


class TestSyncAsyncParity:
    """The two copies must not drift: identical fixtures, identical answers."""

    def test_normalize_host_agrees(self):
        for host in BLOCKED_LITERALS + PUBLIC_LITERALS:
            assert normalize_sync(host) == normalize_async(host), host

    def test_is_safe_url_agrees(self):
        for host in BLOCKED_LITERALS + PUBLIC_LITERALS:
            url = f"http://[{host}]/" if ":" in host else f"http://{host}/"
            assert is_safe_url_sync(url) is is_safe_url_async(url), host
