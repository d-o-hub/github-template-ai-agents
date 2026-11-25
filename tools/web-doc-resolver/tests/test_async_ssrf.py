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
    "::127.0.0.1",  # IPv4-compatible IPv6 (RFC 4291, obsoleted)
    "64:ff9b::127.0.0.1",  # NAT64 well-known prefix
    "2002:7f00:1::",  # 6to4, embeds 127.0.0.1
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


class TestBothCopiesBlock:
    """Parity alone is a weak oracle: two copies can agree on being unsafe.

    Each literal is asserted blocked in each copy independently, so a shared
    bug fails here rather than passing the parity guard above.
    """

    def test_sync_blocks_every_literal(self):
        for host in BLOCKED_LITERALS:
            url = f"http://[{host}]/" if ":" in host else f"http://{host}/"
            assert is_safe_url_sync(url) is False, host

    def test_async_blocks_every_literal(self):
        for host in BLOCKED_LITERALS:
            url = f"http://[{host}]/" if ":" in host else f"http://{host}/"
            assert is_safe_url_async(url) is False, host


class TestFailClosedOnResolution:
    """An unanswerable DNS question must not read as "safe"."""

    def test_sync_denies_when_dns_fails(self, monkeypatch):
        import socket

        from scripts.utils import http as http_mod

        def boom(_host, _port=None):
            raise socket.gaierror(-2, "Name or service not known")

        monkeypatch.setattr(http_mod, "_getaddrinfo_cached", boom)
        assert http_mod.is_safe_url("http://rebinding.example/") is False

    def test_async_denies_when_dns_fails(self, monkeypatch):
        import socket

        from scripts.utils import async_http as async_mod

        def boom(_host, _port=None):
            raise socket.gaierror(-2, "Name or service not known")

        monkeypatch.setattr(async_mod, "_getaddrinfo_cached", boom)
        assert async_mod.is_safe_url("http://rebinding.example/") is False

    def test_sync_still_allows_a_resolved_public_host(self, monkeypatch):
        from scripts.utils import http as http_mod

        def public(_host, _port=None):
            return [(2, 1, 6, "", ("93.184.215.69", 0))]

        monkeypatch.setattr(http_mod, "_getaddrinfo_cached", public)
        assert http_mod.is_safe_url("https://docs.example.com/") is True

    def test_sync_denies_when_dns_rebinds_to_loopback(self, monkeypatch):
        from scripts.utils import http as http_mod

        def loopback(_host, _port=None):
            return [(2, 1, 6, "", ("127.0.0.1", 0))]

        monkeypatch.setattr(http_mod, "_getaddrinfo_cached", loopback)
        assert http_mod.is_safe_url("https://rebinding.example/") is False
