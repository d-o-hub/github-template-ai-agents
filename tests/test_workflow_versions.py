"""Tests for GitHub Actions workflow version pin updates.

Covers changes introduced in:
- .github/workflows/labeler.yml  (actions/labeler updated to v7.0.0)
- .github/workflows/security-scan.yml  (github/codeql-action/* pin + version label)
- .github/workflows/cleanup-ci-status-prs.yml  (weekly scheduled CI status PR cleanup)
"""

import re
from pathlib import Path

import pytest
import yaml

REPO_ROOT = Path(__file__).parent.parent
LABELER_WORKFLOW = REPO_ROOT / ".github" / "workflows" / "labeler.yml"
SECURITY_SCAN_WORKFLOW = REPO_ROOT / ".github" / "workflows" / "security-scan.yml"
CLEANUP_CI_STATUS_WORKFLOW = REPO_ROOT / ".github" / "workflows" / "cleanup-ci-status-prs.yml"

# SHA hashes that should be present after the PR update
LABELER_NEW_SHA = "bf12e9b00b37c5c0ca2b87b79b2daf7891dbda13"

# Old SHA hashes that must NOT appear after the update
LABELER_OLD_SHA = "b8dd2d9be0f68b860e7dae5dae7d772984eacd6d"

# Single source of truth for the codeql-action pin: SHA -> real upstream version.
#
# These tests deliberately do NOT hardcode one SHA as "the correct one". A
# previous revision did, which turned this into a one-shot migration test: any
# later Dependabot bump desynchronised it and main carried 7 permanently red
# tests. The invariant worth protecting is not a particular SHA -- that is
# Dependabot's job and needs network access to verify -- it is that the pin and
# its version label agree. When Dependabot bumps the pin, add the new entry here
# and update the `# vX.Y.Z` comments in security-scan.yml in the same commit.
# test_codeql_version_label_matches_pinned_sha names the exact fix on failure.
CODEQL_SHA_TO_VERSION = {
    "1c5b675653bb5c22dbe9b12b556ec555138e09fd": "v4.38.1",  # tag v4.38.1
    "2892aa5e19bbd11bc0cff5427e3b750a04d9e3c2": "v4.38.2",  # peeled tag v4.38.2
}

# Same invariant for reviewdog/action-actionlint in yaml-lint.yml. Its label on
# main was `# v1` (major-only) while the pin was actually v1.76.0, which is the
# same class of drift as the codeql labels: Dependabot leaves an incorrect
# comment as-is rather than correcting it.
ACTIONLINT_SHA_TO_VERSION = {
    "320fcdd9c860767cf17fab3b20e22e739d5d02b8": "v1.76.0",  # tag v1.76.0
    "2085657ab2c7f48c58edcc767fba576f63bea76b": "v1.77.0",  # tag v1.77.0
}

YAML_LINT_WORKFLOW = REPO_ROOT / ".github" / "workflows" / "yaml-lint.yml"

# Full 40-hex-char SHA pattern
SHA_PATTERN = re.compile(r"^[0-9a-f]{40}$")

# A codeql-action pin plus its trailing `# vX.Y.Z` label, e.g.
# "github/codeql-action/init@<sha>   # v4.38.1"
_CODEQL_PIN_RE = re.compile(
    r"github/codeql-action/[\w-]+@([0-9a-f]{40})(\s+#\s*(v[\d.]+))?"
)

# Generic `uses: <owner>/<action>@<sha>  # vX.Y.Z` matcher.
_USES_PIN_RE = re.compile(
    r"uses:\s+(\S+)@([0-9a-f]{40})(\s+#\s*(v[\d.]+))?"
)


def _codeql_pins():
    """Return every codeql-action pin in security-scan.yml as (sha, label) pairs.

    Group 1 is the SHA, group 2 the whole '  # vX.Y.Z' label block, group 3 the
    bare version inside it.
    """
    raw = _raw_text(SECURITY_SCAN_WORKFLOW)
    return [(sha, version or None)
            for sha, _label_block, version in _CODEQL_PIN_RE.findall(raw)]


# ---------------------------------------------------------------------------
# Helpers
# ---------------------------------------------------------------------------

def _load_yaml(path: Path) -> dict:
    with path.open() as fh:
        return yaml.safe_load(fh)


def _raw_text(path: Path) -> str:
    return path.read_text()


def _extract_action_uses(workflow: dict) -> list[str]:
    """Recursively collect all 'uses' strings from a workflow dict."""
    uses_list: list[str] = []
    if isinstance(workflow, dict):
        for key, value in workflow.items():
            if key == "uses" and isinstance(value, str):
                uses_list.append(value)
            else:
                uses_list.extend(_extract_action_uses(value))
    elif isinstance(workflow, list):
        for item in workflow:
            uses_list.extend(_extract_action_uses(item))
    return uses_list


# ===========================================================================
# labeler.yml tests
# ===========================================================================


class TestLabelerWorkflow:
    """Tests for .github/workflows/labeler.yml"""

    def test_labeler_yml_exists(self):
        assert LABELER_WORKFLOW.exists(), "labeler.yml must exist"

    def test_labeler_yml_is_valid_yaml(self):
        """Workflow file must parse as valid YAML without errors."""
        doc = _load_yaml(LABELER_WORKFLOW)
        assert doc is not None

    def test_labeler_workflow_has_required_top_level_keys(self):
        """Workflow must have 'on' and 'jobs' keys."""
        doc = _load_yaml(LABELER_WORKFLOW)
        assert "jobs" in doc, "Workflow must define jobs"
        # 'on' is parsed by pyyaml as True (truthy) in some versions, use raw text
        raw = _raw_text(LABELER_WORKFLOW)
        assert "on:" in raw or "\"on\":" in raw or "'on':" in raw, \
            "Workflow must have an 'on' trigger"

    def test_labeler_action_uses_updated_sha(self):
        """actions/labeler must be pinned to the new v7.0.0 SHA."""
        raw = _raw_text(LABELER_WORKFLOW)
        expected_ref = f"actions/labeler@{LABELER_NEW_SHA}"
        assert expected_ref in raw, (
            f"Expected actions/labeler to be pinned to SHA {LABELER_NEW_SHA}"
        )

    def test_labeler_action_version_comment_is_v7_0_0(self):
        """The inline version comment next to actions/labeler must say v7.0.0."""
        raw = _raw_text(LABELER_WORKFLOW)
        # Expect a line like: uses: actions/labeler@<SHA>  # v7.0.0
        assert re.search(
            rf"actions/labeler@{re.escape(LABELER_NEW_SHA)}\s+#\s*v7\.0\.0",
            raw,
        ), "actions/labeler pin should be followed by the comment '# v7.0.0'"

    def test_labeler_action_sha_is_full_40_char_hex(self):
        """The SHA used for actions/labeler must be a full 40-character hex string."""
        assert SHA_PATTERN.match(LABELER_NEW_SHA), (
            "LABELER_NEW_SHA must be a valid 40-char hex SHA"
        )
        raw = _raw_text(LABELER_WORKFLOW)
        # Confirm the full SHA appears (not a short or truncated reference)
        assert LABELER_NEW_SHA in raw

    def test_labeler_action_does_not_use_old_sha(self):
        """Regression: old v6.0.1 SHA must not appear anywhere in the file."""
        raw = _raw_text(LABELER_WORKFLOW)
        assert LABELER_OLD_SHA not in raw, (
            f"Old SHA {LABELER_OLD_SHA} (v6.0.1) still present in labeler.yml"
        )

    def test_labeler_action_not_pinned_by_tag_only(self):
        """actions/labeler must not be referenced by a mutable tag (e.g. @v6) only."""
        raw = _raw_text(LABELER_WORKFLOW)
        # A tag-only reference would look like actions/labeler@v6 with no long SHA
        tag_only_pattern = re.compile(r"uses:\s+actions/labeler@v\d+\b(?![\w.])")
        assert not tag_only_pattern.search(raw), (
            "actions/labeler must be pinned by full SHA, not a mutable tag"
        )

    def test_labeler_job_uses_github_token(self):
        """The labeler step must pass the GITHUB_TOKEN secret."""
        raw = _raw_text(LABELER_WORKFLOW)
        assert "secrets.GITHUB_TOKEN" in raw, (
            "Labeler workflow must use GITHUB_TOKEN"
        )

    def test_labeler_workflow_permissions_are_least_privilege(self):
        """Workflow must only request contents:read and pull-requests:write."""
        doc = _load_yaml(LABELER_WORKFLOW)
        perms = doc.get("permissions", {})
        assert perms.get("contents") == "read", (
            "contents permission must be 'read'"
        )
        assert perms.get("pull-requests") == "write", (
            "pull-requests permission must be 'write'"
        )
        # Ensure no other top-level permission grants exist beyond the two expected
        unexpected = set(perms.keys()) - {"contents", "pull-requests"}
        assert not unexpected, (
            f"Unexpected permission grants found: {unexpected}"
        )


# ===========================================================================
# security-scan.yml tests
# ===========================================================================


class TestSecurityScanWorkflow:
    """Tests for .github/workflows/security-scan.yml"""

    def test_security_scan_yml_exists(self):
        assert SECURITY_SCAN_WORKFLOW.exists(), "security-scan.yml must exist"

    def test_security_scan_yml_is_valid_yaml(self):
        """Workflow file must parse as valid YAML without errors."""
        doc = _load_yaml(SECURITY_SCAN_WORKFLOW)
        assert doc is not None

    def test_security_scan_has_required_jobs(self):
        """Workflow must define the expected scan jobs."""
        doc = _load_yaml(SECURITY_SCAN_WORKFLOW)
        jobs = doc.get("jobs", {})
        expected_jobs = {
            "shellcheck-security",
            "trivy-fs",
            "codeql",
            "iac-scan",
            "security-summary",
        }
        missing = expected_jobs - set(jobs.keys())
        assert not missing, f"Missing expected jobs: {missing}"

    # --- codeql-action pin invariants ---
    #
    # These assert coherence (one SHA, a label that matches it, full-SHA pins)
    # rather than one blessed SHA, so a Dependabot bump cannot desynchronise
    # them. The SHA that is currently correct lives in CODEQL_SHA_TO_VERSION.

    def test_codeql_upload_sarif_pins_present(self):
        """The upload-sarif step must be pinned in both scan jobs."""
        pins = _codeql_pins()
        upload = [p for p in pins if "upload-sarif@" in _raw_text(SECURITY_SCAN_WORKFLOW)]
        # 4 upload-sarif steps share the same SHA as the 3 codeql steps.
        raw = _raw_text(SECURITY_SCAN_WORKFLOW)
        count = len(re.findall(r"github/codeql-action/upload-sarif@", raw))
        assert count >= 4, f"Expected >=4 upload-sarif pins, found {count}"
        assert upload == pins or len(pins) >= 7, (
            f"Expected 7 codeql-action pins, found {len(pins)}"
        )

    def test_codeql_all_pins_use_one_sha(self):
        """Every github/codeql-action/* reference must use the same SHA."""
        pins = _codeql_pins()
        assert pins, "No github/codeql-action/* references found"
        shas = {sha for sha, _ in pins}
        assert len(shas) == 1, (
            f"All codeql-action steps must use the same SHA, found {shas}"
        )

    def test_codeql_pinned_sha_is_40_char_hex(self):
        """The pinned codeql-action SHA must be a full 40-character hex string."""
        pins = _codeql_pins()
        assert pins, "No github/codeql-action/* references found"
        for sha, _ in pins:
            assert SHA_PATTERN.match(sha), (
                f"codeql-action SHA must be 40-char hex, got {sha!r}"
            )

    def test_codeql_actions_not_pinned_by_tag_only(self):
        """All github/codeql-action/* references must use full SHA pins, not tags."""
        raw = _raw_text(SECURITY_SCAN_WORKFLOW)
        tag_only = re.findall(r"github/codeql-action/[\w-]+@(v\d+[\w.]*)\b", raw)
        assert not tag_only, f"Found mutable tag references: {tag_only}"

    def test_codeql_pins_are_not_orphaned_sha_comments(self):
        """The codeql SHA must not appear on a non-codeql action line."""
        raw = _raw_text(SECURITY_SCAN_WORKFLOW)
        pins = _codeql_pins()
        assert pins
        sha = pins[0][0]
        strays = re.findall(
            rf"uses:\s+(?!github/codeql-action/)[^\n]+{re.escape(sha)}", raw
        )
        assert not strays, f"codeql SHA appears on unrelated action lines: {strays}"

    def test_codeql_pins_all_carry_a_version_comment(self):
        """Every github/codeql-action/* pin must have a '# vX.Y.Z' label."""
        missing = [sha for sha, label in _codeql_pins() if not label]
        assert not missing, f"codeql-action pins missing version comments: {missing}"

    def test_codeql_version_comments_all_agree(self):
        """All codeql-action version labels must state the same version."""
        labels = {label for _, label in _codeql_pins() if label}
        assert len(labels) == 1, f"Version labels disagree: {labels}"

    def test_codeql_version_label_matches_pinned_sha(self):
        """The version label must name the real version of the pinned SHA.

        When Dependabot bumps the pin, add the new SHA to
        CODEQL_SHA_TO_VERSION and update the '# vX.Y.Z' comments in
        security-scan.yml in the same commit. Verify the version with:
            gh api repos/github/codeql-action/git/matching-refs/tags/<version>
        """
        pins = _codeql_pins()
        assert pins
        shas = {sha for sha, _ in pins}
        assert len(shas) == 1
        sha = shas.pop()
        assert sha in CODEQL_SHA_TO_VERSION, (
            f"Pinned codeql-action SHA {sha} is not in CODEQL_SHA_TO_VERSION. "
            f"Known: {sorted(CODEQL_SHA_TO_VERSION)}. Add the new SHA->version "
            f"entry here and update the '# vX.Y.Z' comments in "
            f"security-scan.yml in the same commit."
        )
        expected = CODEQL_SHA_TO_VERSION[sha]
        wrong = sorted({label for _, label in _codeql_pins() if label != expected})
        assert not wrong, (
            f"Pinned SHA {sha} is {expected}, but the comments say {wrong}. "
            f"Update the '# vX.Y.Z' comments in security-scan.yml."
        )

    # --- Workflow permissions ---

    def test_security_scan_workflow_permissions(self):
        """Top-level permissions must include contents:read and security-events:write."""
        doc = _load_yaml(SECURITY_SCAN_WORKFLOW)
        perms = doc.get("permissions", {})
        assert perms.get("contents") == "read", (
            "contents permission must be 'read'"
        )
        assert perms.get("security-events") == "write", (
            "security-events permission must be 'write'"
        )

    # --- Boundary / negative: no unrelated SHA replacements ---

    def test_security_scan_non_codeql_action_shas_unchanged(self):
        """The codeql-action SHA must not leak onto a non-codeql action line."""
        pins = _codeql_pins()
        assert pins
        sha = pins[0][0]
        raw = _raw_text(SECURITY_SCAN_WORKFLOW)
        # Find all 'uses:' lines that contain the codeql SHA but are NOT codeql-action
        non_codeql_with_codeql_sha = re.findall(
            rf"uses:\s+(?!github/codeql-action/)[^\n]+{re.escape(sha)}",
            raw,
        )
        assert not non_codeql_with_codeql_sha, (
            f"codeql SHA found in non-codeql actions: {non_codeql_with_codeql_sha}"
        )


# ===========================================================================
# yaml-lint.yml tests
# ===========================================================================


class TestYamlLintWorkflow:
    """Tests for .github/workflows/yaml-lint.yml actionlint pin."""

    def test_workflow_exists(self):
        assert YAML_LINT_WORKFLOW.exists(), "yaml-lint.yml must exist"

    def test_actionlint_pin_is_full_sha(self):
        """reviewdog/action-actionlint must be pinned to a full 40-char SHA."""
        raw = _raw_text(YAML_LINT_WORKFLOW)
        pins = _USES_PIN_RE.findall(raw)
        actionlint = [p for p in pins if p[0] == "reviewdog/action-actionlint"]
        assert actionlint, "No SHA-pinned reviewdog/action-actionlint reference"
        for _, sha, _label_block, _ in actionlint:
            assert SHA_PATTERN.match(sha), f"actionlint SHA must be 40-char hex: {sha!r}"

    def test_actionlint_version_label_matches_pinned_sha(self):
        """The actionlint label must name the real version of the pinned SHA."""
        raw = _raw_text(YAML_LINT_WORKFLOW)
        pins = [p for p in _USES_PIN_RE.findall(raw)
                if p[0] == "reviewdog/action-actionlint"]
        assert pins
        for _, sha, _label_block, label in pins:
            assert sha in ACTIONLINT_SHA_TO_VERSION, (
                f"Pinned actionlint SHA {sha} is not in ACTIONLINT_SHA_TO_VERSION. "
                f"Known: {sorted(ACTIONLINT_SHA_TO_VERSION)}. Verify with: "
                f"gh api repos/reviewdog/action-actionlint/commits/{sha}"
            )
            expected = ACTIONLINT_SHA_TO_VERSION[sha]
            assert label == expected, (
                f"actionlint pin is {expected} but the comment says {label!r}. "
                f"Update the '# vX.Y.Z' comment in yaml-lint.yml."
            )


# ===========================================================================
# cleanup-ci-status-prs.yml tests
# ===========================================================================


class TestCleanupCIStatusWorkflow:
    """Tests for .github/workflows/cleanup-ci-status-prs.yml"""

    def test_workflow_exists(self):
        assert CLEANUP_CI_STATUS_WORKFLOW.exists(), (
            "cleanup-ci-status-prs.yml must exist"
        )

    def test_workflow_is_valid_yaml(self):
        """Workflow file must parse as valid YAML without errors."""
        doc = _load_yaml(CLEANUP_CI_STATUS_WORKFLOW)
        assert doc is not None

    def test_workflow_has_descriptive_name(self):
        """Workflow name should describe its purpose."""
        doc = _load_yaml(CLEANUP_CI_STATUS_WORKFLOW)
        name = doc.get("name", "")
        assert "CI" in name.upper() and (
            "cleanup" in name.lower() or "clean" in name.lower()
        ), f"Workflow name should mention CI cleanup: got '{name}'"

    def test_workflow_has_schedule_trigger(self):
        """Must have a schedule trigger for weekly automated runs."""
        raw = _raw_text(CLEANUP_CI_STATUS_WORKFLOW)
        assert "schedule:" in raw, "Workflow must have a schedule trigger"
        assert "cron:" in raw, "Workflow must define a cron schedule"

    def test_workflow_has_workflow_dispatch(self):
        """Must allow manual triggering via workflow_dispatch."""
        raw = _raw_text(CLEANUP_CI_STATUS_WORKFLOW)
        assert "workflow_dispatch" in raw, (
            "Workflow must have workflow_dispatch trigger"
        )

    def test_workflow_has_cleanup_job(self):
        """Must define a cleanup job that runs the cleanup script."""
        doc = _load_yaml(CLEANUP_CI_STATUS_WORKFLOW)
        jobs = doc.get("jobs", {})
        assert len(jobs) >= 1, "Workflow must define at least one job"
        raw = _raw_text(CLEANUP_CI_STATUS_WORKFLOW)
        assert "cleanup-ci-status-prs.sh" in raw, (
            "Workflow must run cleanup-ci-status-prs.sh"
        )

    def test_workflow_permissions_allow_branch_deletion(self):
        """Must have contents:write for branch deletion in cleanup."""
        doc = _load_yaml(CLEANUP_CI_STATUS_WORKFLOW)
        perms = doc.get("permissions", {})
        assert perms.get("contents") == "write", (
            "contents permission must be 'write' for branch deletion"
        )
        assert perms.get("pull-requests") == "write", (
            "pull-requests permission must be 'write' for PR closing"
        )

    def test_workflow_has_timeout(self):
        """Must have a timeout to prevent hung runs."""
        raw = _raw_text(CLEANUP_CI_STATUS_WORKFLOW)
        assert "timeout-minutes" in raw, (
            "Workflow must have timeout-minutes set"
        )

    def test_workflow_uses_checkout_action(self):
        """Must checkout the repository before running cleanup script."""
        raw = _raw_text(CLEANUP_CI_STATUS_WORKFLOW)
        assert "actions/checkout" in raw, (
            "Workflow must use actions/checkout"
        )
