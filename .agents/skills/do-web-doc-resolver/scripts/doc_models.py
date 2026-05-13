import re
from dataclasses import dataclass, field
from pathlib import Path

REPO_ROOT = Path(__file__).resolve().parent.parent

EXTERNAL_PACKAGES = frozenset(
    {"pytest", "ruff", "black", "mypy", "pip", "requests", "cargo", "npm", "npx", "node", "gh"}
)


@dataclass
class Issue:
    severity: str
    category: str
    doc: str
    detail: str
    line: int | None = None

    def __str__(self):
        loc = f":{self.line}" if self.line else ""
        return f"[{self.severity.upper()}] {self.doc}{loc} ({self.category}): {self.detail}"

    @property
    def key(self):
        return (self.category, self.doc, self.detail, self.line)


@dataclass
class Report:
    issues: list[Issue] = field(default_factory=list)
    _seen: set = field(default_factory=set)

    def add(self, severity, category, doc, detail, line=None):
        issue = Issue(severity, category, doc, detail, line)
        if issue.key not in self._seen:
            self._seen.add(issue.key)
            self.issues.append(issue)

    @property
    def counts(self):
        return {
            "error": len([i for i in self.issues if i.severity == "error"]),
            "warning": len([i for i in self.issues if i.severity == "warning"]),
        }

    def to_dict(self):
        return {"issues": [vars(i) for i in self.issues], "counts": self.counts}


def read_file(path: Path) -> str:
    return path.read_text(encoding="utf-8")


def extract_markdown_links(content: str) -> list[tuple[int, str, str]]:
    links = []
    for line_no, line in enumerate(content.splitlines(), 1):
        for match in re.finditer(r"\[([^\]]+)\]\(([^)]+)\)", line):
            links.append((line_no, match.group(1), match.group(2)))
    return links


def extract_code_blocks(content: str) -> list[tuple[int, str, str]]:
    blocks = []
    for match in re.finditer(r"```(\w+)?\n(.*?)\n```", content, re.DOTALL):
        start_pos = content[: match.start()].count("\n") + 1
        blocks.append((start_pos, match.group(1) or "", match.group(2)))
    return blocks
