import os
import subprocess
import shutil
import sys

def run(cmd, env=None):
    process = subprocess.Popen(cmd, shell=True, stdout=subprocess.PIPE, stderr=subprocess.PIPE, env={**os.environ, **(env or {})})
    stdout, stderr = process.communicate()
    return process.returncode, stdout.decode(), stderr.decode()

def cleanup():
    for d in [".claude/skills", ".qwen/skills"]:
        if os.path.exists(d):
            for f in os.listdir(d):
                if f in ["eu-ai-act-compliance", "durable-objects"]:
                    path = os.path.join(d, f)
                    if os.path.islink(path):
                        os.unlink(path)
                    elif os.path.isdir(path):
                        shutil.rmtree(path)

def test():
    print("Running Optional Skills Verification Tests...")

    # Test 1: Default skip
    cleanup()
    code, out, err = run("./scripts/setup-skills.sh")
    if "skip (optional): .claude/skills/eu-ai-act-compliance" in out:
        print("✓ Test 1 Passed: skipped optional skill by default")
    else:
        print("✗ Test 1 Failed: optional skill not skipped")
        print(out)
        return False

    # Test 2: LINK_OPTIONAL=true
    cleanup()
    code, out, err = run("./scripts/setup-skills.sh", env={"LINK_OPTIONAL": "true"})
    if "linked: .claude/skills/eu-ai-act-compliance" in out:
        print("✓ Test 2 Passed: linked optional skill when requested")
    else:
        print("✗ Test 2 Failed: optional skill not linked")
        print(out)
        return False

    # Test 3: validate-skills.sh passes when missing
    cleanup()
    code, out, err = run("./scripts/validate-skills.sh")
    if code == 0:
        print("✓ Test 3 Passed: validate-skills.sh handles missing optional skills")
    else:
        print(f"✗ Test 3 Failed: validate-skills.sh returned {code}")
        print(out)
        print(err)
        return False

    # Test 4: validate-skills.sh format check
    skill_md = ".agents/skills/eu-ai-act-compliance/SKILL.md"
    bak_md = skill_md + ".bak"
    os.rename(skill_md, bak_md)
    with open(skill_md, "w") as f:
        f.write("Invalid content\n")

    code, out, err = run("./scripts/validate-skills.sh")
    os.remove(skill_md)
    os.rename(bak_md, skill_md)

    if code == 2 and "Must start with '---'" in err:
        print("✓ Test 4 Passed: validate-skills.sh still checks SKILL.md format")
    else:
        print(f"✗ Test 4 Failed: validate-skills.sh did not report error (code {code})")
        print(err)
        return False

    # Test 5: AIActLogger check
    if os.path.exists(".agents/skills/eu-ai-act-compliance/eu-ai-act-compliance.ts"):
        print("✓ Test 5 Passed: AIActLogger implementation exists")
    else:
        print("✗ Test 5 Failed: AIActLogger implementation missing")
        return False

    print("\nAll Optional Skills Tests Passed!")
    return True

if __name__ == "__main__":
    if not test():
        sys.exit(1)
