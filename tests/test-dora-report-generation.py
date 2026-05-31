"""Tests for DORA report generation script with enhanced schema."""
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
    """Test the update_counters function with enhanced schema."""
    
    def test_update_counters_completed_with_arrays(self):
        """Test counting completed tasks with array fields."""
        counters = {"completed": 0, "failed": 0, "partial": 0, "skills": 0, "tokens": 0, "handoffs": 0, "agent_invocations": 0}
        entry = {
            "timestamp": "2026-05-01T10:00:00Z",
            "task_id": "task123",
            "parent_task_id": None,
            "task": "test task",
            "agents": ["jules", "claude"],
            "skills_used": ["test-skill", "another-skill"],
            "status": "completed",
            "tokens_used": 200,
            "duration_seconds": 120,
            "handoff_count": 1,
            "agent_metrics": [
                {"agent": "jules", "tokens": 100, "duration_seconds": 60},
                {"agent": "claude", "tokens": 100, "duration_seconds": 60}
            ],
            "notes": ""
        }
        update_counters(entry, "2026-05", counters)
        assert counters["completed"] == 1
        assert counters["skills"] == 2  # Two skills in array
        assert counters["tokens"] == 200  # Sum from agent_metrics
        assert counters["handoffs"] == 1
        assert counters["agent_invocations"] == 2  # Two agents
    
    def test_update_counters_failed_with_simple_schema(self):
        """Test backward compatibility with simple schema."""
        counters = {"completed": 0, "failed": 0, "partial": 0, "skills": 0, "tokens": 0, "handoffs": 0, "agent_invocations": 0}
        entry = {
            "timestamp": "2026-05-01T10:00:00Z",
            "status": "failed",
            "agent": "jules",
            "skill_used": "test-skill",
            "tokens_used": 50
        }
        update_counters(entry, "2026-05", counters)
        assert counters["failed"] == 1
        assert counters["skills"] == 1  # Backward compatible
        assert counters["tokens"] == 50
        assert counters["agent_invocations"] == 1  # Backward compatible
    
    def test_update_counters_partial_with_handoffs(self):
        """Test counting partial tasks with handoffs."""
        counters = {"completed": 0, "failed": 0, "partial": 0, "skills": 0, "tokens": 0, "handoffs": 0, "agent_invocations": 0}
        entry = {
            "timestamp": "2026-05-01T10:00:00Z",
            "status": "partial",
            "handoff_count": 3
        }
        update_counters(entry, "2026-05", counters)
        assert counters["partial"] == 1
        assert counters["handoffs"] == 3
    
    def test_update_counters_wrong_month(self):
        """Test that entries from wrong month are ignored."""
        counters = {"completed": 0, "failed": 0, "partial": 0, "skills": 0, "tokens": 0, "handoffs": 0, "agent_invocations": 0}
        entry = {
            "timestamp": "2026-04-01T10:00:00Z",
            "status": "completed",
            "skills_used": ["test"]
        }
        update_counters(entry, "2026-05", counters)
        assert counters["completed"] == 0
        assert counters["skills"] == 0
    
    def test_update_counters_invalid_entry(self):
        """Test that invalid entries are handled gracefully."""
        counters = {"completed": 0, "failed": 0, "partial": 0, "skills": 0, "tokens": 0, "handoffs": 0, "agent_invocations": 0}
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
        assert counters["skills"] == 0
        assert counters["handoffs"] == 0
    
    def test_load_from_nonexistent_directory(self):
        """Test loading from nonexistent directory."""
        counters = load_metrics_from_directory("/nonexistent/path", "2026-05")
        assert counters["completed"] == 0
    
    def test_load_multiple_files_with_enhanced_schema(self):
        """Test loading and aggregating multiple JSON files with enhanced schema."""
        # Create test files
        files = [
            {
                "filename": "2026-05-01_task123.json",
                "data": {
                    "timestamp": "2026-05-01T10:00:00Z",
                    "task_id": "task123",
                    "parent_task_id": None,
                    "task": "task 1",
                    "agents": ["jules"],
                    "skills_used": ["skill1", "skill2"],
                    "status": "completed",
                    "tokens_used": null,
                    "duration_seconds": null,
                    "handoff_count": 0,
                    "agent_metrics": [{"agent": "jules", "tokens": 100, "duration_seconds": 60}],
                    "notes": ""
                }
            },
            {
                "filename": "2026-05-02_task456.json",
                "data": {
                    "timestamp": "2026-05-02T10:00:00Z",
                    "task_id": "task456",
                    "parent_task_id": None,
                    "task": "task 2",
                    "agents": ["claude"],
                    "skills_used": ["skill3"],
                    "status": "completed",
                    "tokens_used": null,
                    "duration_seconds": null,
                    "handoff_count": 2,
                    "agent_metrics": [{"agent": "claude", "tokens": 200, "duration_seconds": 120}],
                    "notes": ""
                }
            },
            {
                "filename": "2026-05-03_task789.json",
                "data": {
                    "timestamp": "2026-05-03T10:00:00Z",
                    "task_id": "task789",
                    "parent_task_id": None,
                    "task": "task 3",
                    "agents": ["jules", "claude"],
                    "skills_used": [],
                    "status": "failed",
                    "tokens_used": null,
                    "duration_seconds": null,
                    "handoff_count": 1,
                    "agent_metrics": [
                        {"agent": "jules", "tokens": 50, "duration_seconds": 30},
                        {"agent": "claude", "tokens": 50, "duration_seconds": 30}
                    ],
                    "notes": ""
                }
            },
            {
                "filename": "2026-04-01_task000.json",
                "data": {
                    "timestamp": "2026-04-01T10:00:00Z",
                    "status": "completed",
                    "skills_used": ["old-skill"]
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
        assert counters["skills"] == 3  # skill1, skill2, skill3
        assert counters["tokens"] == 400  # 100 + 200 + 50 + 50
        assert counters["handoffs"] == 3  # 0 + 2 + 1
        assert counters["agent_invocations"] == 4  # jules + claude + jules + claude
    
    def test_skip_invalid_json_files(self):
        """Test that invalid JSON files are skipped."""
        # Create a valid file
        valid_file = os.path.join(self.test_dir, "valid.json")
        with open(valid_file, "w", encoding="utf-8") as f:
            json.dump({"timestamp": "2026-05-01T10:00:00Z", "status": "completed", "skills_used": []}, f)
        
        # Create an invalid file
        invalid_file = os.path.join(self.test_dir, "invalid.json")
        with open(invalid_file, "w", encoding="utf-8") as f:
            f.write("{ invalid json")
        
        counters = load_metrics_from_directory(self.test_dir, "2026-05")
        
        # Should only count the valid file
        assert counters["completed"] == 1
        assert counters["skills"] == 0
    
    def test_skip_non_json_files(self):
        """Test that non-JSON files are skipped."""
        # Create a valid JSON file
        valid_file = os.path.join(self.test_dir, "valid.json")
        with open(valid_file, "w", encoding="utf-8") as f:
            json.dump({"timestamp": "2026-05-01T10:00:00Z", "status": "completed", "skills_used": []}, f)
        
        # Create a non-JSON file
        text_file = os.path.join(self.test_dir, "notes.txt")
        with open(text_file, "w", encoding="utf-8") as f:
            f.write("This is not JSON")
        
        counters = load_metrics_from_directory(self.test_dir, "2026-05")
        
        # Should only count the valid JSON file
        assert counters["completed"] == 1


if __name__ == "__main__":
    pytest.main([__file__, "-v"])
