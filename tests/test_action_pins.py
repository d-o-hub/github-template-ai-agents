"""Tests for SHA-pinned action version resolution (scripts/lib/action_pins.py).

Covers the path that used to fail CI for every dependency-bot bump: a pin the
local cache does not know must be verified against upstream, not rejected for
missing a hand-written cache entry.
"""

import pytest

import action_pins
import test_workflow_versions
from test_workflow_versions import _assert_pin_label

SHA = "1bd86f2fdb4b86187fa4059f16f31a3202acc9ea"
TAG_OBJECT = "e0462179768953fd6790193e15caaef674ff709e"
ACTION = "github/codeql-action"


def _stub_request(monkeypatch, responses):
    """Route _request through a path->payload map; unknown paths return None."""
    monkeypatch.setattr(action_pins, "_request", lambda path: responses.get(path))


def test_lightweight_tag_resolves_to_its_commit(monkeypatch):
    _stub_request(monkeypatch, {f"/repos/{ACTION}/git/ref/tags/v4.39.4":
                                {"object": {"sha": SHA, "type": "commit"}}})
    assert action_pins.resolve_tag_commit(ACTION, "v4.39.4") == SHA


def test_annotated_tag_is_peeled_to_the_commit(monkeypatch):
    _stub_request(monkeypatch, {
        f"/repos/{ACTION}/git/ref/tags/v4.39.4":
            {"object": {"sha": TAG_OBJECT, "type": "tag"}},
        f"/repos/{ACTION}/git/tags/{TAG_OBJECT}":
            {"object": {"sha": SHA, "type": "commit"}},
    })
    assert action_pins.resolve_tag_commit(ACTION, "v4.39.4") == SHA


@pytest.mark.parametrize("action,tag", [("../evil", "v1"), ("a/b", "../../x")])
def test_unsafe_action_or_tag_never_issues_a_request(monkeypatch, action, tag):
    calls: list[str] = []
    monkeypatch.setattr(action_pins, "_request", calls.append)
    assert action_pins.resolve_tag_commit(action, tag) is None
    assert not calls


def test_unreachable_upstream_returns_none(monkeypatch):
    _stub_request(monkeypatch, {})
    assert action_pins.resolve_tag_commit(ACTION, "v4.39.4") is None


TAG_TO_SHA = {"v4.39.4": SHA, "v4.39.3": "33d7b85da1a04171e211befe2c739303b9a4c066"}


def test_uncached_pin_with_correct_label_passes(monkeypatch):
    """The dependency-bot case: new SHA, correct label, empty cache."""
    monkeypatch.setattr(test_workflow_versions, "resolve_tag_commit",
                        lambda action, tag: TAG_TO_SHA.get(tag))
    _assert_pin_label(ACTION, SHA, "v4.39.4", {}, "security-scan.yml")


def test_uncached_pin_with_stale_label_fails(monkeypatch):
    """A bump that leaves the previous version comment behind is still caught."""
    monkeypatch.setattr(test_workflow_versions, "resolve_tag_commit",
                        lambda action, tag: TAG_TO_SHA.get(tag))
    with pytest.raises(AssertionError, match="is not v4.39.3 upstream"):
        _assert_pin_label(ACTION, SHA, "v4.39.3", {}, "security-scan.yml")


def test_cached_pin_label_mismatch_fails_without_network(monkeypatch):
    def unexpected(action, tag):
        raise AssertionError("a cached pin must not hit the network")

    monkeypatch.setattr(test_workflow_versions, "resolve_tag_commit", unexpected)
    with pytest.raises(AssertionError, match="pin is v4.39.4"):
        _assert_pin_label(ACTION, SHA, "v4.39.3", {SHA: "v4.39.4"}, "security-scan.yml")


def test_uncached_pin_without_upstream_skips(monkeypatch):
    monkeypatch.setattr(test_workflow_versions, "resolve_tag_commit", lambda action, tag: None)
    with pytest.raises(pytest.skip.Exception):
        _assert_pin_label(ACTION, SHA, "v4.39.4", {}, "security-scan.yml")
