import unittest
import os
import tempfile
import json
import datetime
import sys
import subprocess

class TestDoraReportGeneration(unittest.TestCase):
    def setUp(self):
        self.test_dir = tempfile.TemporaryDirectory()
        self.repo_root = self.test_dir.name
        os.makedirs(os.path.join(self.repo_root, ".agents"))
        self.metrics_file = os.path.join(self.repo_root, ".agents/metrics.jsonl")

        self.reports_dir = os.path.join(self.repo_root, "agents-docs/dora-reports")
        self.script_path = os.path.abspath(os.path.join(os.path.dirname(__file__), "../.agents/skills/dora-report/scripts/generate_report.py"))

    def tearDown(self):
        self.test_dir.cleanup()

    def run_script(self, args=None):
        script_copy_dir = os.path.join(self.repo_root, ".agents/skills/dora-report/scripts")
        os.makedirs(script_copy_dir, exist_ok=True)
        script_copy_path = os.path.join(script_copy_dir, "generate_report.py")

        with open(self.script_path, "r", encoding="utf-8") as f:
            content = f.read()

        with open(script_copy_path, "w", encoding="utf-8") as f:
            f.write(content)

        cmd = [sys.executable, script_copy_path]
        if args:
            cmd.extend(args)
        result = subprocess.run(cmd, capture_output=True, text=True, cwd=self.repo_root)
        return result

    def test_aggregation_and_filtering(self):
        now = datetime.datetime.now()
        month_year = now.strftime("%Y-%m")

        metrics = [
            {"timestamp": f"{month_year}-01T10:00:00Z", "status": "completed", "tokens_used": 100, "skill_used": "test"},
            {"timestamp": f"{month_year}-02T11:00:00Z", "status": "failed", "tokens_used": 50, "skill_used": None},
            {"timestamp": f"{month_year}-03T12:00:00Z", "status": "partial", "tokens_used": 75, "skill_used": "test"},
            {"timestamp": f"{month_year}-04T13:00:00Z", "status": "completed", "tokens_used": "invalid", "skill_used": "test"}
        ]

        with open(self.metrics_file, "w", encoding="utf-8") as f:
            for m in metrics:
                f.write(json.dumps(m) + "\n")

        res = self.run_script()
        self.assertEqual(res.returncode, 0, res.stderr)

        report_path = os.path.join(self.reports_dir, f"{month_year}.md")
        self.assertTrue(os.path.exists(report_path))

        with open(report_path, "r", encoding="utf-8") as f:
            content = f.read()

        self.assertIn("| Tasks Completed | 2 |", content)
        self.assertIn("| Partial Tasks | 1 |", content)
        self.assertIn("| Failed Tasks | 1 |", content)
        self.assertIn("| Success Rate | 50.0% |", content)

    def test_custom_month_filtering(self):
        target_month = "2024-01"
        m = {"timestamp": "2024-01-15T10:00:00Z", "status": "completed", "tokens_used": 1000}

        with open(self.metrics_file, "w", encoding="utf-8") as f:
            f.write(json.dumps(m) + "\n")

        res = self.run_script(["--month", target_month])
        self.assertEqual(res.returncode, 0, res.stderr)

        report_path = os.path.join(self.reports_dir, f"{target_month}.md")
        self.assertTrue(os.path.exists(report_path))
        self.assertIn("DORA & Agentic Metrics Report - 2024-01", open(report_path).read())

if __name__ == "__main__":
    unittest.main()
