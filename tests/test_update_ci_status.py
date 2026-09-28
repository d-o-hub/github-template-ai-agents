import unittest
import json
import os
import sys
import subprocess
import tempfile
from datetime import datetime

class TestUpdateCIStatus(unittest.TestCase):
    def setUp(self):
        self.test_dir = tempfile.TemporaryDirectory()
        self.old_cwd = os.getcwd()
        os.chdir(self.test_dir.name)

        # Create dummy ci-status.json and ci-summary.md in subdirectory
        ci_dir = os.path.join(self.test_dir.name, ".github", "ci-status")
        os.makedirs(ci_dir, exist_ok=True)
        with open(os.path.join(ci_dir, "ci-status.json"), "w") as f:
            f.write("{}")
        with open(os.path.join(ci_dir, "ci-summary.md"), "w") as f:
            f.write("")

        # Path to the script
        self.script_path = os.path.join(self.old_cwd, "scripts/update-ci-status.py")

    def tearDown(self):
        os.chdir(self.old_cwd)
        self.test_dir.cleanup()

    def run_script(self, needs_json, workflow_url="https://test"):
        env = os.environ.copy()
        env["NEEDS_JSON"] = json.dumps(needs_json)
        env["WORKFLOW_URL"] = workflow_url
        # Path is derived from internal test state and sys.executable is trusted
        result = subprocess.run([sys.executable, self.script_path], env=env, capture_output=True, text=True) # nosec
        return result

    def test_all_passing(self):
        needs = {
            "job1": {"result": "success"},
            "job2": {"result": "success"}
        }
        res = self.run_script(needs)
        self.assertEqual(res.returncode, 0)

        ci_dir = os.path.join(self.test_dir.name, ".github", "ci-status")
        with open(os.path.join(ci_dir, "ci-status.json"), "r") as f:
            data = json.load(f)
            self.assertEqual(data["status"], "passing")
            self.assertEqual(data["validated"], True)
            self.assertEqual(data["skipped_jobs"], [])
            self.assertEqual(data["unallowed_skips"], [])
            self.assertEqual(data["failing_jobs"], [])
            self.assertEqual(data["succeeded_jobs"], ["job1", "job2"])

        with open(os.path.join(ci_dir, "ci-summary.md"), "r") as f:
            content = f.read()
            self.assertIn("Latest CI status: **passing**", content)
            self.assertIn("✅ success", content)

    def test_with_failure(self):
        needs = {
            "job1": {"result": "success"},
            "job2": {"result": "failure"}
        }
        res = self.run_script(needs)
        self.assertEqual(res.returncode, 0)

        ci_dir = os.path.join(self.test_dir.name, ".github", "ci-status")
        with open(os.path.join(ci_dir, "ci-status.json"), "r") as f:
            data = json.load(f)
            self.assertEqual(data["status"], "failing")
            # `validated` now means "the gate was certified green", so a run
            # that contains a failure is never validated (was True pre-ADR-035).
            self.assertEqual(data["validated"], False)
            self.assertEqual(data["skipped_jobs"], [])
            self.assertEqual(data["failing_jobs"], ["job2"])

        with open(os.path.join(ci_dir, "ci-summary.md"), "r") as f:
            content = f.read()
            self.assertIn("Latest CI status: **failing**", content)
            self.assertIn("❌ failure", content)

    def test_with_cancelled(self):
        needs = {
            "job1": {"result": "cancelled"}
        }
        res = self.run_script(needs)
        self.assertEqual(res.returncode, 0)

        ci_dir = os.path.join(self.test_dir.name, ".github", "ci-status")
        with open(os.path.join(ci_dir, "ci-status.json"), "r") as f:
            data = json.load(f)
            self.assertEqual(data["status"], "failing")
            self.assertEqual(data["validated"], False)
            self.assertEqual(data["skipped_jobs"], [])
            # `cancelled` keeps its own bucket instead of being collapsed away.
            self.assertEqual(data["cancelled_jobs"], ["job1"])

    def test_all_unknown_not_skipped(self):
        needs = {
            "job1": {"result": "unexpected_value"},
            "job2": {"result": "weird"}
        }
        res = self.run_script(needs)
        self.assertEqual(res.returncode, 0)

        ci_dir = os.path.join(self.test_dir.name, ".github", "ci-status")
        with open(os.path.join(ci_dir, "ci-status.json"), "r") as f:
            data = json.load(f)
            self.assertEqual(data["status"], "unknown")
            self.assertEqual(data["validated"], False)
            self.assertEqual(data["skipped_jobs"], [])
            self.assertEqual(sorted(data["unknown_jobs"]), ["job1", "job2"])

    def test_all_skipped_is_not_passing(self):
        needs = {
            "job1": {"result": "skipped"},
            "job2": {"result": "skipped"}
        }
        res = self.run_script(needs)
        self.assertEqual(res.returncode, 0)

        ci_dir = os.path.join(self.test_dir.name, ".github", "ci-status")
        with open(os.path.join(ci_dir, "ci-status.json"), "r") as f:
            data = json.load(f)
            self.assertNotEqual(data["status"], "passing")
            # Tri-state only: an all-skipped run validated nothing -> unknown.
            self.assertEqual(data["status"], "unknown")
            self.assertEqual(data["validated"], False)
            self.assertEqual(set(data["skipped_jobs"]), {"job1", "job2"})
            self.assertEqual(sorted(data["unallowed_skips"]), ["job1", "job2"])

    def test_mixed_skip_and_success_is_not_passing(self):
        """Regression: an unallowlisted skip must never yield `passing`.

        GitHub reports an `if:`-skipped job as "Success" and does not block
        merging even as a required check, so the previous "any success" rule
        shipped a false green (`status: passing` alongside `skipped_jobs`).
        """
        needs = {
            "job1": {"result": "success"},
            "job2": {"result": "skipped"}
        }
        res = self.run_script(needs)
        self.assertEqual(res.returncode, 0)

        ci_dir = os.path.join(self.test_dir.name, ".github", "ci-status")
        with open(os.path.join(ci_dir, "ci-status.json"), "r") as f:
            data = json.load(f)
            self.assertNotEqual(data["status"], "passing")
            self.assertEqual(data["status"], "unknown")
            self.assertEqual(data["validated"], False)
            self.assertEqual(data["skipped_jobs"], ["job2"])
            self.assertEqual(data["unallowed_skips"], ["job2"])
            self.assertEqual(data["allowed_skips"], [])

if __name__ == "__main__":
    unittest.main()
