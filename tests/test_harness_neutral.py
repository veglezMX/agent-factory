"""Process docs and framework skills stay project-agnostic and harness-neutral."""

import re

from conftest import ROOT, SKILLS_DIR, tracked_files

# Files whose job is to name harnesses: per-platform docs, contributor/agent guides, and
# the Claude-only command drivers.
NEUTRAL_SCOPE = [ROOT / "process"]
CLAUDE_TERMS = re.compile(r"\b(TodoWrite|AskUserQuestion|subagent_type|CLAUDE\.md|\.claude/)\b")
HOME_PATH = re.compile(r"/(home|Users)/[a-z][\w.-]*/")


def test_process_docs_have_no_claude_tool_vocabulary():
    bad = []
    for p in NEUTRAL_SCOPE[0].rglob("*.md"):
        if "proposals" in p.parts:  # design records of a Claude-specific driver
            continue
        for n, line in enumerate(p.read_text(encoding="utf-8").splitlines(), 1):
            if CLAUDE_TERMS.search(line):
                bad.append(f"{p.relative_to(ROOT)}:{n}: {line.strip()[:100]}")
    assert not bad, "\n".join(bad)


def test_skill_prose_has_no_claude_tool_vocabulary():
    bad = []
    for p in SKILLS_DIR.rglob("*.md"):
        for n, line in enumerate(p.read_text(encoding="utf-8").splitlines(), 1):
            if re.search(r"\b(TodoWrite|AskUserQuestion|subagent_type)\b", line):
                bad.append(f"{p.relative_to(ROOT)}:{n}")
    assert not bad, "\n".join(bad)


def test_no_absolute_home_paths_in_tracked_content():
    bad = []
    for p in tracked_files():
        if p.suffix not in {".md", ".mdc", ".json", ".yml", ".yaml", ".sh", ".py", ".toml"}:
            continue
        if p.is_relative_to(ROOT / "tests"):
            continue
        for n, line in enumerate(p.read_text(encoding="utf-8", errors="replace").splitlines(), 1):
            if HOME_PATH.search(line):
                bad.append(f"{p.relative_to(ROOT)}:{n}")
    assert not bad, "\n".join(bad)
