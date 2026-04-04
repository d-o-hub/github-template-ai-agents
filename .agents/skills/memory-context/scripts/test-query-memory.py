import os
import subprocess
from pathlib import Path

def run_query(query):
    cmd = ["python", ".agents/skills/memory-context/scripts/query-memory.py", query]
    result = subprocess.run(cmd, capture_output=True, text=True)
    return result.stdout, result.stderr

def test_query_results():
    print("Testing query: 'git worktree cleanup'...")
    stdout, stderr = run_query("git worktree cleanup")

    if "### RETRIEVED MEMORIES" not in stdout:
        print(f"FAILED: Header not found in output.\nSTDOUT: {stdout}\nSTDERR: {stderr}")
        return False

    if "LESSON-010" in stdout or "worktree" in stdout.lower():
        print("SUCCESS: Found relevant worktree memory.")
    else:
        print(f"FAILED: Relevant memory not found.\nSTDOUT: {stdout}")
        return False

    print("\nTesting query: 'MAX_CONTEXT_TOKENS'...")
    stdout, stderr = run_query("MAX_CONTEXT_TOKENS")
    if "MAX_CONTEXT_TOKENS" in stdout:
        print("SUCCESS: Found reference to MAX_CONTEXT_TOKENS in config/docs.")
    else:
        print(f"FAILED: Reference to MAX_CONTEXT_TOKENS not found.\nSTDOUT: {stdout}")
        return False

    print("\nTesting token budget...")
    # This might be harder to test without a lot of docs, but we can check if it runs
    stdout, stderr = run_query("the") # Common word to get many results
    if "### RETRIEVED MEMORIES" in stdout:
        print("SUCCESS: Token budget test (smoke test) passed.")
    else:
        print(f"FAILED: Smoke test failed.\nSTDOUT: {stdout}")
        return False

    return True

if __name__ == "__main__":
    if test_query_results():
        print("\nAll memory-context tests PASSED.")
        exit(0)
    else:
        print("\nSome memory-context tests FAILED.")
        exit(1)
