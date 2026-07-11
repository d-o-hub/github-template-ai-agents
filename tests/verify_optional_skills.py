import os
import shlex
import shutil
import subprocess
import sys

CLAUDE_SKILLS_DIR = ".claude/skills"
VALIDATE_SKILLS_SCRIPT = "./scripts/validate-skills.sh"

# Domain packs skipped unless LINK_OPTIONAL=true
OPTIONAL_SKILLS = [
    "eu-ai-act-compliance",
    "durable-objects",
    "cloudflare-worker-api",
    "turso-db",
]
SKILL_MD = ".agents/skills/eu-ai-act-compliance/SKILL.md"
SKILL_IMPL = ".agents/skills/eu-ai-act-compliance/eu-ai-act-compliance.ts"


def run(cmd, env=None):
    """Run a shell command safely without shell=True."""
    if isinstance(cmd, str):
        cmd = shlex.split(cmd)
    merged_env = {**os.environ, **(env or {})}
    # Popen is invoked with list-form args (never shell=True); inputs are controlled test commands.
    process = subprocess.Popen(  # nosec B603 # noqa: S603
        cmd, stdout=subprocess.PIPE, stderr=subprocess.PIPE, env=merged_env
    )
    stdout, stderr = process.communicate()
    return process.returncode, stdout.decode(), stderr.decode()


def cleanup():
    if not os.path.exists(CLAUDE_SKILLS_DIR):
        return
    for f in OPTIONAL_SKILLS:
        path = os.path.join(CLAUDE_SKILLS_DIR, f)
        if os.path.islink(path):
            os.unlink(path)
        elif os.path.isdir(path):
            shutil.rmtree(path)


def _test_default_skip() -> bool:
    """Test 1: Optional skills skipped by default."""
    cleanup()
    _, out, _ = run("./scripts/setup-skills.sh")
    expected = "skip (optional): .claude/skills/eu-ai-act-compliance"
    if expected in out and ".qwen/skills" not in out:
        print("✓ Test 1 Passed: skipped optional skill by default (Claude only; no .qwen/skills)")
        return True
    print("✗ Test 1 Failed: optional skill not skipped correctly")
    print(out)
    return False


def _test_link_optional() -> bool:
    """Test 2: LINK_OPTIONAL=true links optional skills."""
    cleanup()
    _, out, _ = run("./scripts/setup-skills.sh", env={"LINK_OPTIONAL": "true"})
    expected = "linked: .claude/skills/eu-ai-act-compliance"
    # may also say skip (exists) if left from prior run
    alt = "skip (exists): .claude/skills/eu-ai-act-compliance"
    relinked = "relinked: .claude/skills/eu-ai-act-compliance"
    if expected in out or alt in out or relinked in out:
        if os.path.islink(os.path.join(CLAUDE_SKILLS_DIR, "eu-ai-act-compliance")):
            print("✓ Test 2 Passed: linked optional skill when requested")
            return True
    print("✗ Test 2 Failed: optional skill not linked correctly")
    print(out)
    return False


def _test_validate_missing_optional() -> bool:
    """Test 3: validate-skills.sh handles missing optional skills."""
    cleanup()
    code, out, err = run(VALIDATE_SKILLS_SCRIPT)
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
    try:
        with open(SKILL_MD, "w", encoding="utf-8") as f:
            f.write("Invalid content\n")
        code, out, err = run(VALIDATE_SKILLS_SCRIPT)
        combined = out + err
        if code == 2 and "Must start with '---'" in combined:
            print("✓ Test 4 Passed: validate-skills.sh still checks SKILL.md format")
            return True
        print(
            f"✗ Test 4 Failed: validate-skills.sh did not report error for invalid SKILL.md (code {code})"
        )
        print(combined)
        return False
    finally:
        if os.path.exists(SKILL_MD):
            os.remove(SKILL_MD)
        os.rename(bak_md, SKILL_MD)


def _test_ai_act_logger() -> bool:
    """Test 5: AIActLogger implementation exists."""
    if os.path.exists(SKILL_IMPL):
        print("✓ Test 5 Passed: AIActLogger implementation exists")
        return True
    print("✗ Test 5 Failed: AIActLogger implementation missing")
    return False


def _test_no_qwen_skills_required() -> bool:
    """Test 6: validate-skills.sh does not require .qwen/skills."""
    if os.path.exists(".qwen/skills"):
        shutil.rmtree(".qwen/skills")
    code, out, err = run(VALIDATE_SKILLS_SCRIPT)
    if code == 0 and ".qwen/skills" not in (out + err):
        print("✓ Test 6 Passed: validate-skills.sh does not require .qwen/skills")
        return True
    print(f"✗ Test 6 Failed: validate-skills.sh failed without .qwen/skills (code {code})")
    print(err)
    return False


_TESTS = [
    _test_default_skip,
    _test_link_optional,
    _test_validate_missing_optional,
    _test_validate_skill_format,
    _test_ai_act_logger,
    _test_no_qwen_skills_required,
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
