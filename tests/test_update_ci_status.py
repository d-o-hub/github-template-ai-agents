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

        # Create dummy ci-status.json and ci-summary.md
        with open("ci-status.json", "w") as f:
            f.write("{}")
        with open("ci-summary.md", "w") as f:
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

        with open("ci-status.json", "r") as f:
            data = json.load(f)
            self.assertEqual(data["status"], "passing")
            self.assertEqual(data["failing_jobs"], [])

        with open("ci-summary.md", "r") as f:
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

        with open("ci-status.json", "r") as f:
            data = json.load(f)
            self.assertEqual(data["status"], "failing")
            self.assertEqual(data["failing_jobs"], ["job2"])

        with open("ci-summary.md", "r") as f:
            content = f.read()
            self.assertIn("Latest CI status: **failing**", content)
            self.assertIn("❌ failure", content)

    def test_with_cancelled(self):
        needs = {
            "job1": {"result": "cancelled"}
        }
        res = self.run_script(needs)
        self.assertEqual(res.returncode, 0)

        with open("ci-status.json", "r") as f:
            data = json.load(f)
            self.assertEqual(data["status"], "failing")

if __name__ == "__main__":
    unittest.main()
