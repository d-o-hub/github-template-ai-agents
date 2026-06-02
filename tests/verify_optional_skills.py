import os
import subprocess
import shutil
import sys

QWEN_SKILLS_DIR = ".qwen/skills"
QWEN_DIR = ".qwen"
VALIDATE_SKILLS_SCRIPT = "./scripts/validate-skills.sh"
CLAUDE_SKILLS_DIR = ".claude/skills"

OPTIONAL_SKILLS = ["eu-ai-act-compliance", "durable-objects"]
SKILL_MD = ".agents/skills/eu-ai-act-compliance/SKILL.md"
SKILL_IMPL = ".agents/skills/eu-ai-act-compliance/eu-ai-act-compliance.ts"


def run(cmd, env=None):
    process = subprocess.Popen(cmd, shell=True, stdout=subprocess.PIPE, stderr=subprocess.PIPE, env={**os.environ, **(env or {})})
    stdout, stderr = process.communicate()
    return process.returncode, stdout.decode(), stderr.decode()

def cleanup():
    for d in [CLAUDE_SKILLS_DIR, QWEN_SKILLS_DIR]:
        if os.path.exists(d):
            # We only want to remove the specific optional skills we added
            # to avoid breaking other tests if they run in parallel (unlikely here but good practice)
            for f in OPTIONAL_SKILLS:
                path = os.path.join(d, f)
                if os.path.islink(path):
                    os.unlink(path)
                elif os.path.isdir(path):
                    shutil.rmtree(path)

def _test_default_skip() -> bool:
    """Test 1: Optional skills skipped by default."""
    cleanup()
    _, out, _ = run("./scripts/setup-skills.sh")
    expected_claude = "skip (optional): .claude/skills/eu-ai-act-compliance"
    expected_qwen = f"skip (optional): {QWEN_SKILLS_DIR}/eu-ai-act-compliance"
    if expected_claude in out and expected_qwen in out:
        print("✓ Test 1 Passed: skipped optional skill by default for all CLIs")
        return True
    print("✗ Test 1 Failed: optional skill not skipped correctly")
    print(out)
    return False


def _test_link_optional() -> bool:
    """Test 2: LINK_OPTIONAL=true links optional skills."""
    cleanup()
    _, out, _ = run("./scripts/setup-skills.sh", env={"LINK_OPTIONAL": "true"})
    expected_claude = "linked: .claude/skills/eu-ai-act-compliance"
    expected_qwen = f"linked: {QWEN_SKILLS_DIR}/eu-ai-act-compliance"
    if expected_claude in out and expected_qwen in out:
        print("✓ Test 2 Passed: linked optional skill when requested for all CLIs")
        return True
    print("✗ Test 2 Failed: optional skill not linked correctly")
    print(out)
    return False


def _test_validate_missing_optional() -> bool:
    """Test 3: validate-skills.sh handles missing optional skills."""
    cleanup()
    code, _, err = run(VALIDATE_SKILLS_SCRIPT)
    if code == 0:
        print("✓ Test 3 Passed: validate-skills.sh handles missing optional skills in CLI dirs")
        return True
    print(f"✗ Test 3 Failed: validate-skills.sh returned {code}")
    print(out)
    print(err)
    return False


def _test_validate_skill_format() -> bool:
    """Test 4: validate-skills.sh checks SKILL.md format."""
    if not os.path.exists(SKILL_MD):
        print("✗ Test 4 Skipped: SKILL.md not found")
        return False
    bak_md = SKILL_MD + ".bak"
    os.rename(SKILL_MD, bak_md)
    with open(SKILL_MD, "w") as f:
        f.write("Invalid content\n")
    _, _, err = run(VALIDATE_SKILLS_SCRIPT)
    os.remove(SKILL_MD)
    os.rename(bak_md, SKILL_MD)
    if code == 2 and "Must start with '---'" in err:
        print("✓ Test 4 Passed: validate-skills.sh still checks SKILL.md format")
        return True
    print(f"✗ Test 4 Failed: validate-skills.sh did not report error for invalid SKILL.md (code {code})")
    print(err)
    return False


def _test_ai_act_logger() -> bool:
    """Test 5: AIActLogger implementation exists."""
    if os.path.exists(SKILL_IMPL):
        print("✓ Test 5 Passed: AIActLogger implementation exists")
        return True
    print("✗ Test 5 Failed: AIActLogger implementation missing")
    return False


def _test_missing_cli_dir() -> bool:
    """Test 6: validate-skills.sh handles missing CLI directory."""
    if os.path.exists(QWEN_SKILLS_DIR):
        shutil.rmtree(QWEN_SKILLS_DIR)
    if os.path.exists(QWEN_DIR) and not os.listdir(QWEN_DIR):
        os.rmdir(QWEN_DIR)
    code, _, err = run(VALIDATE_SKILLS_SCRIPT)
    if code == 0:
        print("✓ Test 6 Passed: validate-skills.sh passes when a CLI directory is entirely missing")
        return True
    print(f"✗ Test 6 Failed: validate-skills.sh failed on missing CLI directory (code {code})")
    print(err)
    return False


_TESTS = [
    _test_default_skip,
    _test_link_optional,
    _test_validate_missing_optional,
    _test_validate_skill_format,
    _test_ai_act_logger,
    _test_missing_cli_dir,
]


def test():
    print("Running Optional Skills Verification Tests...")
    for test_fn in _TESTS:
        if not test_fn():
            return False
    print("\nAll Optional Skills Tests Passed!")
    return True

if __name__ == "__main__":
    if not test():
        sys.exit(1)
