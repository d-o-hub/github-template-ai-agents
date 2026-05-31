import unittest
import os
import tempfile
import json
import datetime
import sys
from unittest.mock import patch

# Add the script directory to sys.path to import main or other functions if they were exported
# Since generate_report.py is a script with a main() function, we might need to modify it
# to be more testable or use subprocess.

import subprocess

class TestDoraReportGeneration(unittest.TestCase):
    def setUp(self):
        self.test_dir = tempfile.TemporaryDirectory()
        self.repo_root = self.test_dir.name
        self.metrics_dir = os.path.join(self.repo_root, ".agents")
        os.makedirs(self.metrics_dir)
        self.metrics_file = os.path.join(self.metrics_dir, "metrics.jsonl")

        self.reports_dir = os.path.join(self.repo_root, "agents-docs/dora-reports")
        # Script path
        self.script_path = os.path.abspath(os.path.join(os.path.dirname(__file__), "../.agents/skills/dora-report/scripts/generate_report.py"))

    def tearDown(self):
        self.test_dir.cleanup()

    def run_script(self):
        # We need to trick the script into thinking the repo root is self.repo_root
        # The script calculates repo_root relative to its own location.
        # This is tricky because the script is in the real repo.
        # I'll create a copy of the script in the temp dir and run it there.

        script_copy_dir = os.path.join(self.repo_root, ".agents/skills/dora-report/scripts")
        os.makedirs(script_copy_dir)
        script_copy_path = os.path.join(script_copy_dir, "generate_report.py")

        with open(self.script_path, "r") as f:
            content = f.read()

        with open(script_copy_path, "w") as f:
            f.write(content)

        result = subprocess.run([sys.executable, script_copy_path], capture_output=True, text=True)
        return result

    def test_aggregation_and_filtering(self):
        now = datetime.datetime.now()
        month_year = now.strftime("%Y-%m")
        prev_month = (now.replace(day=1) - datetime.timedelta(days=1)).strftime("%Y-%m")

        metrics = [
            {"timestamp": f"{month_year}-01T10:00:00Z", "status": "completed", "tokens_used": 100, "skill_used": "test"},
            {"timestamp": f"{month_year}-02T11:00:00Z", "status": "failed", "tokens_used": 50, "skill_used": None},
            {"timestamp": f"{month_year}-03T12:00:00Z", "status": "partial", "tokens_used": 75, "skill_used": "test"},
            {"timestamp": f"{prev_month}-15T10:00:00Z", "status": "completed", "tokens_used": 1000, "skill_used": "old"},
            "INVALID JSON",
            {"timestamp": f"{month_year}-04T13:00:00Z", "status": "completed", "tokens_used": "invalid", "skill_used": "test"}
        ]

        with open(self.metrics_file, "w") as f:
            for m in metrics:
                if isinstance(m, dict):
                    f.write(json.dumps(m) + "\n")
                else:
                    f.write(m + "\n")

        res = self.run_script()
        self.assertEqual(res.returncode, 0, res.stderr)

        report_path = os.path.join(self.reports_dir, f"{month_year}.md")
        self.assertTrue(os.path.exists(report_path))

        with open(report_path, "r") as f:
            content = f.read()

        # Expected: 2 completed (one with invalid token count), 1 failed.
        # Token sum: 100 + 50 + 75 = 225?
        # Current script logic:
        # tasks_completed = 2 (01T, 04T)
        # failed_tasks = 1 (02T)
        # skill_invocations = 3 (01T, 03T, 04T)
        # total_tokens = 100 + 50 + 75 = 225
        # success_rate = 2 / 3 * 100 = 66.7%

        self.assertIn("| Tasks Completed | 2 |", content)
        self.assertIn("| Partial Tasks | 1 |", content)
        self.assertIn("| Failed Tasks | 1 |", content)
        self.assertIn("| Skill Invocations | 3 |", content)
        self.assertIn("| Total Tokens Used | 225 |", content)
        # 2 completed / 4 total (completed, failed, partial, completed) = 50%
        self.assertIn("| Success Rate | 50.0% |", content)

    def test_partial_status(self):
        now = datetime.datetime.now()
        month_year = now.strftime("%Y-%m")

        metrics = [
            {"timestamp": f"{month_year}-01T10:00:00Z", "status": "partial", "tokens_used": 10}
        ]

        with open(self.metrics_file, "w") as f:
            for m in metrics:
                f.write(json.dumps(m) + "\n")

        res = self.run_script()
        report_path = os.path.join(self.reports_dir, f"{month_year}.md")

        with open(report_path, "r") as f:
            content = f.read()

        self.assertIn("| Success Rate | 0.0% |", content)
        self.assertIn("| Tasks Completed | 0 |", content)
        self.assertIn("| Partial Tasks | 1 |", content)

if __name__ == "__main__":
    unittest.main()
