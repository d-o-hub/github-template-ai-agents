"""Regression suite for the fail-closed CI status tri-state contract.

Covers the false green that shipped as
`{"status": "passing", ..., "skipped_jobs": ["test"]}`: GitHub reports a job
skipped by an `if:` condition as conclusion "Success" and does not block a
merge even as a required check, so a denylist-based classifier certifies green
while the job that mattered never ran.

Scenario coverage required by the fix:
  1. every required job succeeded                 -> passing
  2. required job skipped, not allowlisted       -> unknown (never passing)
  3. required job skipped, allowlisted           -> may be passing
  4. a required job failed                       -> failing
  5. the committed on-disk artifact is not self-contradictory
"""
import importlib.util
import json
import os
import subprocess
import sys
import tempfile
import unittest

REPO_ROOT = os.path.abspath(os.path.join(os.path.dirname(__file__), ".."))
PRODUCER_PATH = os.path.join(REPO_ROOT, "scripts", "update-ci-status.py")
VALIDATOR_PATH = os.path.join(REPO_ROOT, "scripts", "check_ci_status_freshness.sh")
COMMITTED_ARTIFACT = os.path.join(REPO_ROOT, ".github", "ci-status", "ci-status.json")

GATE_JOB = "quality-gate"
TEST_JOB = "test"
PASSING = "passing"
FAILING = "failing"
UNKNOWN = "unknown"
TRISTATE = (PASSING, FAILING, UNKNOWN)
# Effectively disables the freshness window: these tests assert coherence, not age.
NO_STALENESS_LIMIT_SECONDS = 10**9

PASSING_RUN = {GATE_JOB: {"result": "success"}, TEST_JOB: {"result": "success"}}
SKIPPED_TEST_RUN = {GATE_JOB: {"result": "success"}, TEST_JOB: {"result": "skipped"}}
FAILED_RUN = {GATE_JOB: {"result": "success"}, TEST_JOB: {"result": "failure"}}


def load_producer():
    """Import scripts/update-ci-status.py (hyphenated filename needs importlib)."""
    spec = importlib.util.spec_from_file_location("update_ci_status", PRODUCER_PATH)
    module = importlib.util.module_from_spec(spec)
    spec.loader.exec_module(module)
    return module


class TestTriStateDerivation(unittest.TestCase):
    """Pure-function assertions on the derivation rule."""

    def setUp(self):
        self.producer = load_producer()

    def test_1_all_required_jobs_succeeded_is_passing(self):
        derived = self.producer.derive(PASSING_RUN)
        self.assertEqual(derived["status"], PASSING)
        self.assertTrue(derived["validated"])
        self.assertEqual(derived["unallowed_skips"], [])
        self.assertEqual(derived["succeeded_jobs"], [GATE_JOB, TEST_JOB])

    def test_2_unallowlisted_skip_is_never_passing(self):
        derived = self.producer.derive(SKIPPED_TEST_RUN)
        self.assertNotEqual(derived["status"], PASSING)
        self.assertEqual(derived["status"], UNKNOWN)
        self.assertFalse(derived["validated"])
        self.assertEqual(derived["skipped_jobs"], [TEST_JOB])
        self.assertEqual(derived["unallowed_skips"], [TEST_JOB])
        self.assertEqual(derived["allowed_skips"], [])

    def test_2b_allowlist_does_not_leak_to_other_jobs(self):
        """Allowlisting one job must not green-light a different skipped job."""
        needs = {GATE_JOB: {"result": "success"}, "lint": {"result": "skipped"}}
        derived = self.producer.derive(needs, allowed_skips=[TEST_JOB])
        self.assertEqual(derived["status"], UNKNOWN)
        self.assertEqual(derived["unallowed_skips"], ["lint"])

    def test_3_allowlisted_skip_may_be_passing(self):
        derived = self.producer.derive(SKIPPED_TEST_RUN, allowed_skips=[TEST_JOB])
        self.assertEqual(derived["status"], PASSING)
        self.assertTrue(derived["validated"])
        self.assertEqual(derived["skipped_jobs"], [TEST_JOB])
        self.assertEqual(derived["allowed_skips"], [TEST_JOB])
        self.assertEqual(derived["unallowed_skips"], [])

    def test_4_failed_job_is_failing(self):
        derived = self.producer.derive(FAILED_RUN)
        self.assertEqual(derived["status"], FAILING)
        self.assertFalse(derived["validated"])
        self.assertEqual(derived["failing_jobs"], [TEST_JOB])

    def test_4b_failure_beats_allowlisted_skip(self):
        """A failure can never be masked by an allowlisted sibling's skip."""
        needs = {GATE_JOB: {"result": "success"}, TEST_JOB: {"result": "failure"}}
        derived = self.producer.derive(needs, allowed_skips=[TEST_JOB])
        self.assertEqual(derived["status"], FAILING)
        self.assertEqual(derived["failing_jobs"], [TEST_JOB])

    def test_all_skipped_is_unknown_not_passing(self):
        needs = {GATE_JOB: {"result": "skipped"}, TEST_JOB: {"result": "skipped"}}
        derived = self.producer.derive(needs)
        self.assertEqual(derived["status"], UNKNOWN)
        self.assertFalse(derived["validated"])

    def test_cancelled_timed_out_and_stale_stay_distinct(self):
        """`cancelled`/`timed_out` are red; `stale` means unknown."""
        cancelled = self.producer.derive({GATE_JOB: {"result": "cancelled"}})
        self.assertEqual(cancelled["status"], FAILING)
        self.assertEqual(cancelled["cancelled_jobs"], [GATE_JOB])
        self.assertEqual(cancelled["failing_jobs"], [GATE_JOB])

        timed_out = self.producer.derive({GATE_JOB: {"result": "timed_out"}})
        self.assertEqual(timed_out["status"], FAILING)
        self.assertEqual(timed_out["timed_out_jobs"], [GATE_JOB])

        stale = self.producer.derive(
            {GATE_JOB: {"result": "success"}, TEST_JOB: {"result": "stale"}}
        )
        self.assertEqual(stale["status"], UNKNOWN)
        self.assertEqual(stale["unknown_jobs"], [TEST_JOB])
        self.assertEqual(stale["failing_jobs"], [])

    def test_unrecognized_result_is_unknown(self):
        derived = self.producer.derive({GATE_JOB: {"result": "not_a_real_result"}})
        self.assertEqual(derived["status"], UNKNOWN)
        self.assertEqual(derived["unknown_jobs"], [GATE_JOB])

    def test_default_allowlist_is_empty(self):
        self.assertEqual(self.producer.parse_allowed_skips(""), set())
        self.assertEqual(self.producer.DEFAULT_ALLOWED_SKIPS, ())

    def test_allowlist_parsing_accepts_commas_and_spaces(self):
        self.assertEqual(
            self.producer.parse_allowed_skips("test, lint  "), {"test", "lint"}
        )


class TestProducerWritesCoherentArtifact(unittest.TestCase):
    """End-to-end: the written file must never contradict itself."""

    def setUp(self):
        self.temp_dir = tempfile.TemporaryDirectory()
        self.old_cwd = os.getcwd()
        os.chdir(self.temp_dir.name)

    def tearDown(self):
        os.chdir(self.old_cwd)
        self.temp_dir.cleanup()

    def run_producer(self, needs, allowed_skips=""):
        env = os.environ.copy()
        env["NEEDS_JSON"] = json.dumps(needs)
        env["WORKFLOW_URL"] = "https://example.test/actions/runs/1"
        env["CI_STATUS_ALLOWED_SKIPS"] = allowed_skips
        return subprocess.run(
            [sys.executable, PRODUCER_PATH], env=env, capture_output=True, text=True
        )  # nosec B603

    def read_artifact(self):
        with open(
            os.path.join(self.temp_dir.name, ".github", "ci-status", "ci-status.json"),
            encoding="utf-8",
        ) as handle:
            return json.load(handle)

    def test_written_artifact_is_coherent_for_each_state(self):
        for needs, allowed, expected in (
            (PASSING_RUN, "", PASSING),
            (SKIPPED_TEST_RUN, "", UNKNOWN),
            (SKIPPED_TEST_RUN, TEST_JOB, PASSING),
            (FAILED_RUN, "", FAILING),
        ):
            with self.subTest(needs=needs, allowed_skips=allowed):
                result = self.run_producer(needs, allowed)
                self.assertEqual(result.returncode, 0)
                data = self.read_artifact()
                self.assertEqual(data["status"], expected)
                self.assertIn(data["status"], TRISTATE)
                self.assertEqual(
                    sorted(set(data["allowed_skips"]) | set(data["unallowed_skips"])),
                    sorted(data["skipped_jobs"]),
                )
                if data["status"] == PASSING:
                    self.assertEqual(data["failing_jobs"], [])
                    self.assertEqual(data["unallowed_skips"], [])
                    self.assertEqual(data["unknown_jobs"], [])
                    self.assertTrue(data["succeeded_jobs"])
                    self.assertIs(data["validated"], True)

    def test_skipped_run_reports_reason_on_stderr(self):
        result = self.run_producer(SKIPPED_TEST_RUN)
        self.assertIn("skipped outside the allowlist", result.stderr)

    def test_gate_mode_fails_closed_on_unallowlisted_skip(self):
        result = self.run_producer(SKIPPED_TEST_RUN)
        self.assertEqual(result.returncode, 0)
        gate = self.run_producer(SKIPPED_TEST_RUN)
        self.assertEqual(gate.returncode, 0)
        env = os.environ.copy()
        env["NEEDS_JSON"] = json.dumps(SKIPPED_TEST_RUN)
        env["CI_STATUS_ALLOWED_SKIPS"] = ""
        check = subprocess.run(
            [sys.executable, PRODUCER_PATH, "--check"],
            env=env,
            capture_output=True,
            text=True,
        )  # nosec B603
        self.assertEqual(check.returncode, 1)
        self.assertIn(TEST_JOB, check.stderr)

    def test_gate_mode_passes_allowlisted_skip(self):
        env = os.environ.copy()
        env["NEEDS_JSON"] = json.dumps(SKIPPED_TEST_RUN)
        env["CI_STATUS_ALLOWED_SKIPS"] = TEST_JOB
        check = subprocess.run(
            [sys.executable, PRODUCER_PATH, "--check"],
            env=env,
            capture_output=True,
            text=True,
        )  # nosec B603
        self.assertEqual(check.returncode, 0)

    def test_gate_mode_passes_only_on_all_success(self):
        env = os.environ.copy()
        env["CI_STATUS_ALLOWED_SKIPS"] = ""
        for needs, expected_code in (
            (PASSING_RUN, 0),
            (FAILED_RUN, 1),
            ({GATE_JOB: {"result": "skipped"}, TEST_JOB: {"result": "skipped"}}, 1),
            ({}, 1),
        ):
            with self.subTest(needs=needs):
                env["NEEDS_JSON"] = json.dumps(needs)
                check = subprocess.run(
                    [sys.executable, PRODUCER_PATH, "--check"],
                    env=env,
                    capture_output=True,
                    text=True,
                )  # nosec B603
                self.assertEqual(check.returncode, expected_code)

    def test_gate_mode_rejects_undecodable_needs(self):
        env = os.environ.copy()
        env["NEEDS_JSON"] = "not-json"
        check = subprocess.run(
            [sys.executable, PRODUCER_PATH, "--check"],
            env=env,
            capture_output=True,
            text=True,
        )  # nosec B603
        self.assertEqual(check.returncode, 1)


class TestCommittedArtifactIsNotSelfContradictory(unittest.TestCase):
    """Scenario 5: the artifact actually committed to the repo."""

    def setUp(self):
        with open(COMMITTED_ARTIFACT, encoding="utf-8") as handle:
            self.data = json.load(handle)

    def test_status_is_tri_state(self):
        self.assertIn(self.data["status"], TRISTATE)

    def test_passing_never_coexists_with_an_untolerated_problem(self):
        if self.data["status"] != PASSING:
            return
        for field in (
            "failing_jobs",
            "unallowed_skips",
            "unknown_jobs",
            "cancelled_jobs",
            "timed_out_jobs",
        ):
            with self.subTest(field=field):
                self.assertEqual(self.data[field], [])

    def test_skipped_jobs_are_fully_partitioned(self):
        tolerated = set(self.data["allowed_skips"]) | set(self.data["unallowed_skips"])
        self.assertEqual(tolerated, set(self.data["skipped_jobs"]))

    def test_passing_requires_a_succeeded_job(self):
        if self.data["status"] == PASSING:
            self.assertTrue(self.data["succeeded_jobs"])
            self.assertIs(self.data["validated"], True)
        else:
            self.assertIs(self.data["validated"], False)

    def test_no_skip_is_tolerated_implicitly(self):
        """`allowed_skips` must be a subset of the declared allowlist, never a
        silent consequence of `if:` path filtering."""
        if self.data["status"] == PASSING and self.data["skipped_jobs"]:
            self.assertEqual(
                self.data["unallowed_skips"], [], "passing with a tolerated skip"
            )

    def test_validator_accepts_the_committed_artifact(self):
        result = subprocess.run(
            [VALIDATOR_PATH],
            env={
                **os.environ,
                "CI_STATUS_MAX_AGE_SECONDS": str(NO_STALENESS_LIMIT_SECONDS),
            },
            capture_output=True,
            text=True,
        )  # nosec B603
        self.assertEqual(result.returncode, 0, result.stdout + result.stderr)


if __name__ == "__main__":
    unittest.main()
