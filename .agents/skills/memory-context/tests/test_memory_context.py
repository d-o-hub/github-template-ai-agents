"""
Unit and integration tests for memory-context skill contract.
Tests query parsing, JSON output parsing, source freshness verification,
full source text retrieval, token/byte budget bounding, and edge cases.
"""

import json
import os
import shutil
import subprocess
import tempfile
import pytest


def mock_csm_query(query: str, corpus_files: dict, code_aware: bool = False):
    """
    Simulates CSM JSON query output contract.
    Returns candidate matches with path, metadata, preview, id, score.
    """
    results = []
    query_lower = query.lower()
    score = 0.95

    for rel_path, info in corpus_files.items():
        content = info.get("content", "")
        mtime = info.get("mtime", 1000.0)
        heading = info.get("heading", "Overview")

        if query_lower in content.lower() or query_lower in rel_path.lower():
            cid = info.get("id", f"concept_{len(results)+1}")
            preview = content[:200]
            results.append({
                "id": cid,
                "score": score,
                "path": rel_path,
                "preview": preview,
                "metadata": {
                    "mtime": mtime,
                    "heading": heading,
                    "source": rel_path
                }
            })
            score -= 0.1

    return results


def verify_source_freshness(candidate: dict, root_dir: str) -> str:
    """
    Verifies candidate source file freshness.
    Returns 'fresh', 'stale_modified', or 'missing_deleted'.
    """
    rel_path = candidate.get("path")
    if not rel_path:
        return "missing_deleted"

    full_path = os.path.join(root_dir, rel_path)
    if not os.path.exists(full_path):
        return "missing_deleted"

    indexed_mtime = candidate.get("metadata", {}).get("mtime")
    if indexed_mtime is not None:
        current_mtime = os.path.getmtime(full_path)
        if abs(current_mtime - indexed_mtime) > 1e-3:
            return "stale_modified"

    return "fresh"


def bound_json_payload(items, max_bytes=4096):
    """
    Enforces a strict UTF-8 byte budget without breaking JSON structure.
    """
    bounded = []
    current_bytes = 2  # []
    for item in items:
        serialized = json.dumps(item, ensure_ascii=False)
        item_bytes = len(serialized.encode('utf-8')) + (2 if bounded else 0)
        if current_bytes + item_bytes > max_bytes:
            break
        bounded.append(item)
        current_bytes += item_bytes
    return json.dumps(bounded, ensure_ascii=False)


class TestMemoryContextContract:

    def test_fixture_source_text_retrieval_flow(self, tmp_path):
        """
        Verify complete sequence: query JSON -> inspect candidate -> verify freshness -> read source text.
        A fixture lesson's actual text must reach retrieved context.
        """
        docs_dir = tmp_path / "agents-docs"
        docs_dir.mkdir(parents=True)
        lessons_file = docs_dir / "lessons.jsonl"
        lesson_text = "Validation scripts use set +e to collect all errors in a single run."

        lessons_content = json.dumps({
            "id": "LESSON-011",
            "title": lesson_text,
            "tags": ["bash", "validation"]
        }) + "\n"
        lessons_file.write_text(lessons_content, encoding="utf-8")

        mtime = os.path.getmtime(lessons_file)
        corpus = {
            "agents-docs/lessons.jsonl": {
                "id": "LESSON-011",
                "content": lessons_content,
                "mtime": mtime,
                "heading": "LESSON-011"
            }
        }

        # Step 1: Query JSON
        candidates = mock_csm_query("set +e", corpus)
        assert len(candidates) == 1
        candidate = candidates[0]
        assert candidate["id"] == "LESSON-011"

        # Step 2: Verify source freshness
        status = verify_source_freshness(candidate, str(tmp_path))
        assert status == "fresh"

        # Step 3: Read matching source text
        source_full_path = tmp_path / candidate["path"]
        actual_content = source_full_path.read_text(encoding="utf-8")
        assert lesson_text in actual_content

    def test_stale_or_deleted_source_detection(self, tmp_path):
        """
        Deleted/changed source guidance cannot be silently presented as current.
        """
        doc = tmp_path / "SECURITY.md"
        doc.write_text("Pin GitHub actions to 40-character commit SHAs.", encoding="utf-8")
        mtime = os.path.getmtime(doc)

        candidate = {
            "id": "SEC-001",
            "score": 0.9,
            "path": "SECURITY.md",
            "metadata": {"mtime": mtime, "heading": "SHA Pinning"}
        }

        # Fresh
        assert verify_source_freshness(candidate, str(tmp_path)) == "fresh"

        # Deleted
        doc.unlink()
        assert verify_source_freshness(candidate, str(tmp_path)) == "missing_deleted"

        # Modified
        doc.write_text("Updated security guidelines.", encoding="utf-8")
        # Ensure mtime changes
        os.utime(doc, (mtime + 10, mtime + 10))
        assert verify_source_freshness(candidate, str(tmp_path)) == "stale_modified"

    def test_code_aware_retrieval_includes_config(self, tmp_path):
        """
        The code-aware example retrieves a definition actually in the indexed corpus (.agents/config.sh).
        """
        config_dir = tmp_path / ".agents"
        config_dir.mkdir()
        config_file = config_dir / "config.sh"
        config_content = "export MAX_CONTEXT_TOKENS=4096\n"
        config_file.write_text(config_content, encoding="utf-8")

        corpus = {
            ".agents/config.sh": {
                "id": "CFG-001",
                "content": config_content,
                "mtime": os.path.getmtime(config_file),
                "heading": "Config"
            }
        }

        candidates = mock_csm_query("MAX_CONTEXT_TOKENS", corpus, code_aware=True)
        assert len(candidates) == 1
        assert candidates[0]["path"] == ".agents/config.sh"

        status = verify_source_freshness(candidates[0], str(tmp_path))
        assert status == "fresh"

        source_text = (tmp_path / candidates[0]["path"]).read_text(encoding="utf-8")
        assert "export MAX_CONTEXT_TOKENS=4096" in source_text

    def test_empty_results_handling(self):
        """
        Empty query results produce explicit outcomes without fabricated recall.
        """
        corpus = {}
        candidates = mock_csm_query("nonexistent_concept", corpus)
        assert candidates == []

    def test_payload_byte_bounding_valid_json(self):
        """
        Preserves parseable JSON rather than cutting serialized text midway, keeping within byte cap.
        """
        items = [
            {"id": f"ITEM-{i}", "payload": "x" * 100, "unicode_str": "你好, 世界 🌍"}
            for i in range(50)
        ]

        bounded_str = bound_json_payload(items, max_bytes=500)
        parsed = json.loads(bounded_str)
        assert isinstance(parsed, list)
        assert len(parsed) < len(items)
        assert len(bounded_str.encode('utf-8')) <= 500

    @pytest.mark.skipif(shutil.which("csm") is None, reason="CSM CLI binary is not installed")
    def test_real_csm_cli_integration_round_trip(self, tmp_path):
        """
        Integration test exercising real csm binary when available.
        """
        docs_dir = tmp_path / "docs"
        docs_dir.mkdir()
        test_md = docs_dir / "test.md"
        test_md.write_text("## Cleanup\nUse git worktree remove to clean up worktrees.\n", encoding="utf-8")

        db_path = tmp_path / "csm.db"
        # Index dir
        subprocess.run([
            "csm", "index-dir",
            "--glob", str(docs_dir / "*.md"),
            "--db-path", str(db_path)
        ], check=True)

        # Query JSON
        res = subprocess.run([
            "csm", "query", "worktree cleanup",
            "--output-format", "json",
            "--db-path", str(db_path)
        ], capture_output=True, text=True, check=True)

        results = json.loads(res.stdout)
        assert len(results) > 0
        candidate = results[0]
        assert "path" in candidate

        # Verify freshness
        status = verify_source_freshness(candidate, str(tmp_path))
        assert status == "fresh"

        # Read source
        content = (tmp_path / candidate["path"]).read_text(encoding="utf-8")
        assert "git worktree remove" in content
