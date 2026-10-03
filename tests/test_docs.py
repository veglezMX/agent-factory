"""Documents describe artifacts that exist.

Links resolve, section citations resolve, and stated counts are true.
"""

import re
from pathlib import Path

from conftest import ROOT, agents, commands, playbooks, skills, tracked_files

LINK = re.compile(r"(?<!!)\[[^\]]*\]\(([^)\s]+)\)")
DERIVED = ("agents/", "skills/", "commands/", ".claude/", ".cursor/")


def _docs() -> list[Path]:
    return [
        p
        for p in tracked_files()
        if p.suffix == ".md" and not str(p.relative_to(ROOT)).startswith(DERIVED)
    ]


def _section_numbers(path: Path) -> set[str]:
    nums = set()
    for line in path.read_text(encoding="utf-8").splitlines():
        m = re.match(r"^#{2,4} (\d+(?:\.\d+)?)[.\s]", line)
        if m:
            nums.add(m.group(1))
    return nums


def test_relative_links_resolve():
    bad = []
    for p in _docs():
        text = p.read_text(encoding="utf-8")
        text = re.sub(r"```.*?```", "", text, flags=re.S)
        for target in LINK.findall(text):
            if re.match(r"^[a-z]+:", target) or target.startswith("#"):
                continue
            path = target.split("#", 1)[0]
            if "<" in path:  # template placeholder, e.g. ../examples/<case>-<project>.md
                continue
            if not (p.parent / path).exists():
                bad.append(f"{p.relative_to(ROOT)} -> {target}")
    assert not bad, "\n".join(bad)


def _citations(pattern: str, target: Path) -> list[str]:
    valid = _section_numbers(target)
    assert valid, f"no numbered sections parsed in {target}"
    bad = []
    for p in _docs():
        if p == target or p.name == "CHANGELOG.md":  # history may cite what was removed
            continue
        for n, line in enumerate(p.read_text(encoding="utf-8").splitlines(), 1):
            for m in re.finditer(pattern, line):
                for num in re.findall(r"§\s?(\d+(?:\.\d+)?)", m.group(0)):
                    if num not in valid:
                        bad.append(f"{p.relative_to(ROOT)}:{n}: §{num}")
    return bad


def test_handoff_protocol_citations_resolve():
    bad = _citations(
        r"(?i)(?:handoff[- ]protocol|protocol)\)?`?\s*(?:§\s?\d+(?:\.\d+)?[,/ ]*)+",
        ROOT / "process" / "agent-handoff-protocol.md",
    )
    assert not bad, "\n".join(bad)


def test_invocation_contract_citations_resolve():
    bad = _citations(
        r"(?i)invocation[- ]contract(?:\.md)?`?\)?\s*(?:§\s?\d+(?:\.\d+)?[,/ ]*)+",
        ROOT / "process" / "agent-invocation-contract.md",
    )
    assert not bad, "\n".join(bad)


def test_readme_counts_match_tree():
    readme = (ROOT / "README.md").read_text(encoding="utf-8")
    facts = {
        r"\*\*(\d+) agents\*\*": len(agents()),
        r"(\d+) specialized agents": len(agents()),
        r"\*\*(\d+) cases\*\*": len(playbooks()),
        r"(\d+) cases \(": len(playbooks()),
        r"\*\*(\d+) skills\*\*": len(skills()),
        r"\*\*(\d+) commands\*\*": len(commands()),
        r"(\d+) agent definitions": len(agents()),
        r"(\d+) skills \(SKILL\.md": len(skills()),
    }
    seen = 0
    for pattern, actual in facts.items():
        for m in re.finditer(pattern, readme):
            seen += 1
            assert int(m.group(1)) == actual, f"README: '{m.group(0)}' but the tree has {actual}"
    assert seen >= 4, "README count claims not found — update this test with the new wording"


def test_worked_example_and_runs_exist():
    for p in (ROOT / "process" / "examples").glob("*.md"):
        for run in re.findall(r"runs/([\w-]+)/", p.read_text(encoding="utf-8")):
            if "<" in run or run == "run-id":
                continue
            assert (ROOT / "runs" / run).is_dir(), (
                f"{p.name} cites runs/{run}/ which does not exist"
            )
