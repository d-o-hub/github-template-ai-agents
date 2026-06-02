"""Tests for GitHub Actions workflow version pin updates.

Covers changes introduced in:
- .github/workflows/labeler.yml  (actions/labeler updated to v6.1.0)
- .github/workflows/security-scan.yml  (github/codeql-action/* updated to v4.35 new SHA)
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
LABELER_NEW_SHA = "f27b608878404679385c85cfa523b85ccb86e213"
CODEQL_NEW_SHA = "9e0d7b8d25671d64c341c19c0152d693099fb5ba"

# Old SHA hashes that must NOT appear after the update
LABELER_OLD_SHA = "634933edcd8ababfe52f92936142cc22ac488b1b"
CODEQL_OLD_SHA = "e46ed2cbd01164d986452f91f178727624ae40d7"

# Full 40-hex-char SHA pattern
SHA_PATTERN = re.compile(r"^[0-9a-f]{40}$")


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
        """actions/labeler must be pinned to the new v6.1.0 SHA."""
        raw = _raw_text(LABELER_WORKFLOW)
        expected_ref = f"actions/labeler@{LABELER_NEW_SHA}"
        assert expected_ref in raw, (
            f"Expected actions/labeler to be pinned to SHA {LABELER_NEW_SHA}"
        )

    def test_labeler_action_version_comment_is_v6_1_0(self):
        """The inline version comment next to actions/labeler must say v6.1.0."""
        raw = _raw_text(LABELER_WORKFLOW)
        # Expect a line like: uses: actions/labeler@<SHA>  # v6.1.0
        assert re.search(
            rf"actions/labeler@{re.escape(LABELER_NEW_SHA)}\s+#\s*v6\.1\.0",
            raw,
        ), "actions/labeler pin should be followed by the comment '# v6.1.0'"

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

    # --- upload-sarif: shellcheck job ---

    def test_shellcheck_upload_sarif_uses_new_codeql_sha(self):
        """shellcheck-security job: upload-sarif step must use the updated SHA."""
        raw = _raw_text(SECURITY_SCAN_WORKFLOW)
        expected = f"github/codeql-action/upload-sarif@{CODEQL_NEW_SHA}"
        assert raw.count(expected) >= 1, (
            f"Expected at least one reference to upload-sarif@{CODEQL_NEW_SHA}"
        )

    def test_trivy_fs_upload_sarif_uses_new_codeql_sha(self):
        """trivy-fs job: upload-sarif step must use the updated SHA."""
        # Verified indirectly: all 4 upload-sarif occurrences are checked together
        raw = _raw_text(SECURITY_SCAN_WORKFLOW)
        expected = f"github/codeql-action/upload-sarif@{CODEQL_NEW_SHA}"
        # There must be at least 4 upload-sarif references (shellcheck, trivy-fs,
        # codeql-empty, iac-scan)
        count = raw.count(expected)
        assert count >= 4, (
            f"Expected >=4 upload-sarif references with new SHA, found {count}"
        )

    # --- codeql job: init, autobuild, analyze ---

    def test_codeql_init_uses_new_sha(self):
        """codeql job: Initialize CodeQL step must use the updated SHA."""
        raw = _raw_text(SECURITY_SCAN_WORKFLOW)
        assert f"github/codeql-action/init@{CODEQL_NEW_SHA}" in raw, (
            f"codeql-action/init must be pinned to {CODEQL_NEW_SHA}"
        )

    def test_codeql_autobuild_uses_new_sha(self):
        """codeql job: Autobuild step must use the updated SHA."""
        raw = _raw_text(SECURITY_SCAN_WORKFLOW)
        assert f"github/codeql-action/autobuild@{CODEQL_NEW_SHA}" in raw, (
            f"codeql-action/autobuild must be pinned to {CODEQL_NEW_SHA}"
        )

    def test_codeql_analyze_uses_new_sha(self):
        """codeql job: Perform CodeQL Analysis step must use the updated SHA."""
        raw = _raw_text(SECURITY_SCAN_WORKFLOW)
        assert f"github/codeql-action/analyze@{CODEQL_NEW_SHA}" in raw, (
            f"codeql-action/analyze must be pinned to {CODEQL_NEW_SHA}"
        )

    # --- Total count of codeql-action usages ---

    def test_security_scan_total_codeql_action_count(self):
        """All 7 codeql-action references must use the new SHA (no leftovers)."""
        raw = _raw_text(SECURITY_SCAN_WORKFLOW)
        # Count every occurrence of the new SHA tied to codeql-action
        # Use [\w-]+ to match hyphenated action names like upload-sarif
        count = len(re.findall(
            rf"github/codeql-action/[\w-]+@{re.escape(CODEQL_NEW_SHA)}",
            raw,
        ))
        assert count == 7, (
            f"Expected exactly 7 github/codeql-action/* references with new SHA, "
            f"found {count}"
        )

    # --- Regression: old SHA must be gone ---

    def test_security_scan_does_not_contain_old_codeql_sha(self):
        """Regression: old codeql-action SHA must not appear anywhere in the file."""
        raw = _raw_text(SECURITY_SCAN_WORKFLOW)
        assert CODEQL_OLD_SHA not in raw, (
            f"Old SHA {CODEQL_OLD_SHA} still present in security-scan.yml"
        )

    # --- Consistency: all codeql-action pins use the same SHA ---

    def test_security_scan_all_codeql_action_shas_are_consistent(self):
        """Every github/codeql-action/* reference must use the same SHA."""
        raw = _raw_text(SECURITY_SCAN_WORKFLOW)
        # Extract all SHAs following github/codeql-action/<subaction>@
        # Use [\w-]+ to match hyphenated names like upload-sarif
        shas = re.findall(r"github/codeql-action/[\w-]+@([0-9a-f]{40})", raw)
        assert len(shas) > 0, "No github/codeql-action/* references found"
        unique_shas = set(shas)
        assert len(unique_shas) == 1, (
            f"All codeql-action steps must use the same SHA, "
            f"but found multiple: {unique_shas}"
        )
        assert unique_shas.pop() == CODEQL_NEW_SHA

    # --- SHA format validation ---

    def test_codeql_sha_is_full_40_char_hex(self):
        """The updated codeql-action SHA must be a valid 40-character hex string."""
        assert SHA_PATTERN.match(CODEQL_NEW_SHA), (
            "CODEQL_NEW_SHA must be a valid 40-char hex SHA"
        )

    def test_security_scan_codeql_actions_not_pinned_by_tag_only(self):
        """All github/codeql-action/* references must use full SHA pins, not tags."""
        raw = _raw_text(SECURITY_SCAN_WORKFLOW)
        # A tag-only reference would look like codeql-action/<name>@v4 without a SHA
        # Use [\w-]+ to match hyphenated names like upload-sarif
        tag_only = re.findall(
            r"github/codeql-action/[\w-]+@(v\d+[\w.]*)\b",
            raw,
        )
        assert not tag_only, (
            f"Found mutable tag references for codeql-action: {tag_only}"
        )

    # --- Version comment consistency ---

    def test_security_scan_codeql_version_comments_say_v4_35(self):
        """Every github/codeql-action/* SHA pin must have a '# v4.35' comment."""
        raw = _raw_text(SECURITY_SCAN_WORKFLOW)
        # Each pin line should look like: uses: github/codeql-action/...@<SHA>  # v4.35
        # Use [\w-]+ to match hyphenated names like upload-sarif
        pins = re.findall(
            rf"github/codeql-action/[\w-]+@{re.escape(CODEQL_NEW_SHA)}(\s+#\s*v[\d.]+)?",
            raw,
        )
        missing_comment = [p for p in pins if not p.strip()]
        assert not missing_comment, (
            "Some codeql-action SHA pins are missing version comments"
        )
        # Verify they all say v4.35
        version_comments = re.findall(
            rf"github/codeql-action/[\w-]+@{re.escape(CODEQL_NEW_SHA)}\s+#\s*(v[\d.]+)",
            raw,
        )
        for comment in version_comments:
            assert comment == "v4.35", (
                f"Expected version comment 'v4.35', got '{comment}'"
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
        """Non-codeql action SHAs in security-scan.yml must not include the new codeql SHA."""
        raw = _raw_text(SECURITY_SCAN_WORKFLOW)
        # Confirm that the new codeql SHA only appears in codeql-action references
        # Find all 'uses:' lines that contain the new SHA but are NOT codeql-action
        non_codeql_with_new_sha = re.findall(
            rf"uses:\s+(?!github/codeql-action/)[^\n]+{re.escape(CODEQL_NEW_SHA)}",
            raw,
        )
        assert not non_codeql_with_new_sha, (
            f"New codeql SHA found in non-codeql actions: {non_codeql_with_new_sha}"
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
