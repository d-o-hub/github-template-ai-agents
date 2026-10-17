"""Mutation coverage for the two gate validators.

`scripts/check-lessons-consistency.sh` and `scripts/check-agents-md-skills.sh`
guard the three-way lesson record and the AGENTS.md skill inventory. They had
no tests, so nothing proved they still detect drift after an edit — and a
"perf" refactor of a checker can silently neuter it while CI stays green,
because CI runs the neutered checker.

Each test builds a throwaway repo tree, drops the real script into it, mutates
one input, and asserts the script exits 1 naming the right drift class. The
scripts derive REPO_ROOT from their own path, so the copy is what makes them
hermetic.
"""

import re
import shutil
import subprocess
from pathlib import Path

import pytest

REPO_ROOT = Path(__file__).resolve().parent.parent
LESSONS_SCRIPT = REPO_ROOT / "scripts" / "check-lessons-consistency.sh"
SKILLS_SCRIPT = REPO_ROOT / "scripts" / "check-agents-md-skills.sh"


def build_repo(tmp_path: Path, scripts: tuple[Path, ...]) -> Path:
    """Create a minimal repo tree and install copies of the scripts under it."""
    (tmp_path / "scripts").mkdir()
    for script in scripts:
        shutil.copy(script, tmp_path / "scripts" / script.name)
    return tmp_path


def run_script(repo: Path, name: str) -> subprocess.CompletedProcess:
    return subprocess.run(
        ["bash", str(repo / "scripts" / name)],
        capture_output=True,
        text=True,
        check=False,
    )


@pytest.fixture
def lessons_repo(tmp_path: Path) -> Path:
    repo = build_repo(tmp_path, (LESSONS_SCRIPT,))
    docs = repo / "agents-docs"
    docs.mkdir()
    (docs / "LESSONS.md").write_text(
        "# Lessons\n\n### LESSON-001 — One\n\nbody\n\n"
        "### LESSON-002 — Two\n\nbody\n",
        encoding="utf-8",
    )
    (docs / "lessons.jsonl").write_text(
        '{"id":"LESSON-001","date":"2026-01-01","component":"x",'
        '"title":"One","severity":"Low","tags":["x"]}\n'
        '{"id":"LESSON-002","date":"2026-01-02","component":"x",'
        '"title":"Two","severity":"Low","tags":["x"]}\n',
        encoding="utf-8",
    )
    (docs / "self-learning-rules.md").write_text(
        "# Rules\n\n- **LESSON-001 — One**: note\n"
        "- **LESSON-002 — Two**: note\n",
        encoding="utf-8",
    )
    return repo


@pytest.fixture
def skills_repo(tmp_path: Path) -> Path:
    repo = build_repo(tmp_path, (SKILLS_SCRIPT,))
    for name in ("alpha-skill", "beta-skill"):
        skill_dir = repo / ".agents" / "skills" / name
        skill_dir.mkdir(parents=True)
        (skill_dir / "SKILL.md").write_text(f"# {name}\n", encoding="utf-8")
    (repo / "AGENTS.md").write_text(
        "# AGENTS.md\n\n## Skills\n\n"
        "| Category | Skills |\n|----------|--------|\n"
        "| **Test** | `alpha-skill`, `beta-skill` |\n",
        encoding="utf-8",
    )
    return repo


class TestCleanTreePasses:
    def test_lessons_consistency_is_green(self, lessons_repo):
        result = run_script(lessons_repo, "check-lessons-consistency.sh")
        assert result.returncode == 0, result.stdout + result.stderr

    def test_agents_md_skills_is_green(self, skills_repo):
        result = run_script(skills_repo, "check-agents-md-skills.sh")
        assert result.returncode == 0, result.stdout + result.stderr


class TestLessonDriftIsCaught:
    def test_catalog_entry_without_a_jsonl_row(self, lessons_repo):
        path = lessons_repo / "agents-docs" / "LESSONS.md"
        path.write_text(
            path.read_text(encoding="utf-8") + "\n### LESSON-003 — Three\n\nbody\n",
            encoding="utf-8",
        )
        result = run_script(lessons_repo, "check-lessons-consistency.sh")
        assert result.returncode == 1
        assert "LESSON-003 is in LESSONS.md but has no lessons.jsonl row" in result.stdout

    def test_jsonl_row_without_a_catalog_entry(self, lessons_repo):
        path = lessons_repo / "agents-docs" / "lessons.jsonl"
        path.write_text(
            path.read_text(encoding="utf-8").rstrip("\n")
            + "\n"
            + '{"id":"LESSON-004","date":"2026-01-04","component":"x",'
            '"title":"Four","severity":"Low","tags":["x"]}\n',
            encoding="utf-8",
        )
        result = run_script(lessons_repo, "check-lessons-consistency.sh")
        assert result.returncode == 1
        assert "LESSON-004 has a lessons.jsonl row but no LESSONS.md entry" in result.stdout

    def test_rules_reference_with_no_record_anywhere(self, lessons_repo):
        path = lessons_repo / "agents-docs" / "self-learning-rules.md"
        path.write_text(
            path.read_text(encoding="utf-8") + "\n- **LESSON-005 — Five**: orphan\n",
            encoding="utf-8",
        )
        result = run_script(lessons_repo, "check-lessons-consistency.sh")
        assert result.returncode == 1
        assert "in neither LESSONS.md nor lessons-archive.md" in result.stdout


class TestSkillInventoryDriftIsCaught:
    def test_skill_listed_twice(self, skills_repo):
        path = skills_repo / "AGENTS.md"
        path.write_text(
            path.read_text(encoding="utf-8").replace(
                "`alpha-skill`, `beta-skill`", "`alpha-skill`, `alpha-skill`, `beta-skill`"
            ),
            encoding="utf-8",
        )
        result = run_script(skills_repo, "check-agents-md-skills.sh")
        assert result.returncode == 1
        assert "listed 2 times" in result.stdout

    def test_table_names_a_skill_that_does_not_exist(self, skills_repo):
        path = skills_repo / "AGENTS.md"
        path.write_text(
            path.read_text(encoding="utf-8").replace(
                "`alpha-skill`, `beta-skill`", "`alpha-skill`, `beta-skill`, `gamma-skill`"
            ),
            encoding="utf-8",
        )
        result = run_script(skills_repo, "check-agents-md-skills.sh")
        assert result.returncode == 1
        assert "gamma-skill is listed in AGENTS.md but no longer exists" in result.stdout

    def test_catalog_skill_missing_from_the_table(self, skills_repo):
        path = skills_repo / "AGENTS.md"
        path.write_text(
            path.read_text(encoding="utf-8").replace(
                "`alpha-skill`, `beta-skill`", "`beta-skill`"
            ),
            encoding="utf-8",
        )
        result = run_script(skills_repo, "check-agents-md-skills.sh")
        assert result.returncode == 1
        assert "alpha-skill exists in .agents/skills/ but is absent" in result.stdout


class TestTheSuiteCatchesANeuteredChecker:
    """A checker that cannot fail must not look like a checker that passed.

    Disabling `fail()` still prints every drift line, so a human reading the
    output sees the problem and a machine reading the exit code does not. That
    split is why the tests above assert `returncode` first: it is the only part
    of the contract a neutered checker breaks, and the part CI acts on.
    """

    def test_disabled_fail_function_keeps_the_text_and_loses_the_verdict(self, lessons_repo):
        script = lessons_repo / "scripts" / "check-lessons-consistency.sh"
        script.write_text(
            re.sub(
                r"(fail\(\) \{\n\s*echo[^\n]*\n\s*)EXIT_CODE=1",
                r"\1EXIT_CODE=0",
                script.read_text(encoding="utf-8"),
            ),
            encoding="utf-8",
        )
        catalog = lessons_repo / "agents-docs" / "LESSONS.md"
        catalog.write_text(
            catalog.read_text(encoding="utf-8") + "\n### LESSON-003 — Three\n\nbody\n",
            encoding="utf-8",
        )
        result = run_script(lessons_repo, "check-lessons-consistency.sh")
        assert "no lessons.jsonl row" in result.stdout
        assert result.returncode == 0
        assert "Lesson catalog, machine index, and runtime index agree" in result.stdout
