"""Tests for DORA report generation script."""
import os
import json
import tempfile
import shutil
import pytest
import sys

# Add parent directory to path to import generate_report
sys.path.insert(0, os.path.dirname(os.path.abspath(__file__)))
from generate_report import load_metrics_from_directory, update_counters


class TestUpdateCounters:
    """Test the update_counters function."""
    
    def test_update_counters_completed(self):
        """Test counting completed tasks."""
        counters = {"completed": 0, "failed": 0, "partial": 0, "skills": 0, "tokens": 0}
        entry = {
            "timestamp": "2026-05-01T10:00:00Z",
            "status": "completed",
            "skill_used": "test-skill",
            "tokens_used": 100
        }
        update_counters(entry, "2026-05", counters)
        assert counters["completed"] == 1
        assert counters["skills"] == 1
        assert counters["tokens"] == 100
    
    def test_update_counters_failed(self):
        """Test counting failed tasks."""
        counters = {"completed": 0, "failed": 0, "partial": 0, "skills": 0, "tokens": 0}
        entry = {
            "timestamp": "2026-05-01T10:00:00Z",
            "status": "failed",
            "tokens_used": 50
        }
        update_counters(entry, "2026-05", counters)
        assert counters["failed"] == 1
        assert counters["tokens"] == 50
        assert counters["skills"] == 0  # No skill used
    
    def test_update_counters_partial(self):
        """Test counting partial tasks."""
        counters = {"completed": 0, "failed": 0, "partial": 0, "skills": 0, "tokens": 0}
        entry = {
            "timestamp": "2026-05-01T10:00:00Z",
            "status": "partial"
        }
        update_counters(entry, "2026-05", counters)
        assert counters["partial"] == 1
    
    def test_update_counters_wrong_month(self):
        """Test that entries from wrong month are ignored."""
        counters = {"completed": 0, "failed": 0, "partial": 0, "skills": 0, "tokens": 0}
        entry = {
            "timestamp": "2026-04-01T10:00:00Z",
            "status": "completed"
        }
        update_counters(entry, "2026-05", counters)
        assert counters["completed"] == 0
    
    def test_update_counters_invalid_entry(self):
        """Test that invalid entries are handled gracefully."""
        counters = {"completed": 0, "failed": 0, "partial": 0, "skills": 0, "tokens": 0}
        # Should not raise an error
        update_counters("not a dict", "2026-05", counters)
        update_counters(None, "2026-05", counters)
        assert counters["completed"] == 0


class TestLoadMetricsFromDirectory:
    """Test the load_metrics_from_directory function."""
    
    def setup_method(self):
        """Set up test directory."""
        self.test_dir = tempfile.mkdtemp()
    
    def teardown_method(self):
        """Clean up test directory."""
        shutil.rmtree(self.test_dir)
    
    def test_load_from_empty_directory(self):
        """Test loading from empty directory."""
        counters = load_metrics_from_directory(self.test_dir, "2026-05")
        assert counters["completed"] == 0
        assert counters["failed"] == 0
        assert counters["partial"] == 0
    
    def test_load_from_nonexistent_directory(self):
        """Test loading from nonexistent directory."""
        counters = load_metrics_from_directory("/nonexistent/path", "2026-05")
        assert counters["completed"] == 0
    
    def test_load_multiple_files(self):
        """Test loading and aggregating multiple JSON files."""
        # Create test files
        files = [
            {
                "filename": "2026-05-01_task1.json",
                "data": {
                    "timestamp": "2026-05-01T10:00:00Z",
                    "status": "completed",
                    "skill_used": "test-skill",
                    "tokens_used": 100
                }
            },
            {
                "filename": "2026-05-02_task2.json",
                "data": {
                    "timestamp": "2026-05-02T10:00:00Z",
                    "status": "completed",
                    "tokens_used": 200
                }
            },
            {
                "filename": "2026-05-03_task3.json",
                "data": {
                    "timestamp": "2026-05-03T10:00:00Z",
                    "status": "failed",
                    "tokens_used": 50
                }
            },
            {
                "filename": "2026-04-01_task4.json",
                "data": {
                    "timestamp": "2026-04-01T10:00:00Z",
                    "status": "completed"
                }
            }
        ]
        
        for file_info in files:
            filepath = os.path.join(self.test_dir, file_info["filename"])
            with open(filepath, "w", encoding="utf-8") as f:
                json.dump(file_info["data"], f)
        
        counters = load_metrics_from_directory(self.test_dir, "2026-05")
        
        assert counters["completed"] == 2
        assert counters["failed"] == 1
        assert counters["partial"] == 0
        assert counters["skills"] == 1
        assert counters["tokens"] == 350
    
    def test_skip_invalid_json_files(self):
        """Test that invalid JSON files are skipped."""
        # Create a valid file
        valid_file = os.path.join(self.test_dir, "valid.json")
        with open(valid_file, "w", encoding="utf-8") as f:
            json.dump({"timestamp": "2026-05-01T10:00:00Z", "status": "completed"}, f)
        
        # Create an invalid file
        invalid_file = os.path.join(self.test_dir, "invalid.json")
        with open(invalid_file, "w", encoding="utf-8") as f:
            f.write("{ invalid json")
        
        counters = load_metrics_from_directory(self.test_dir, "2026-05")
        
        # Should only count the valid file
        assert counters["completed"] == 1
    
    def test_skip_non_json_files(self):
        """Test that non-JSON files are skipped."""
        # Create a valid JSON file
        valid_file = os.path.join(self.test_dir, "valid.json")
        with open(valid_file, "w", encoding="utf-8") as f:
            json.dump({"timestamp": "2026-05-01T10:00:00Z", "status": "completed"}, f)
        
        # Create a non-JSON file
        text_file = os.path.join(self.test_dir, "notes.txt")
        with open(text_file, "w", encoding="utf-8") as f:
            f.write("This is not JSON")
        
        counters = load_metrics_from_directory(self.test_dir, "2026-05")
        
        # Should only count the valid JSON file
        assert counters["completed"] == 1


if __name__ == "__main__":
    pytest.main([__file__, "-v"])
