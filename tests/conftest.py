"""Shared parsers for the agents-factory invariant suite.

Every test reads the repository as it is on disk. Nothing here writes to the tree;
tests that need to run the installer do so into pytest's ``tmp_path``.
"""

from __future__ import annotations

import json
import re
import subprocess
from dataclasses import dataclass
from functools import cache
from pathlib import Path

import pytest
import yaml

ROOT = Path(__file__).resolve().parent.parent
AGENTS_DIR = ROOT / ".github" / "agents"
SKILLS_DIR = ROOT / ".github" / "skills"
COMMANDS_DIR = ROOT / ".github" / "commands"
PLAYBOOKS_DIR = ROOT / "process" / "playbooks"
ROSTER = ROOT / "process" / "agent-roster.md"
CHANGELOG = ROOT / "CHANGELOG.md"
PLUGIN_JSON = ROOT / ".claude-plugin" / "plugin.json"
MARKETPLACE_JSON = ROOT / ".claude-plugin" / "marketplace.json"
INSTALL_SH = ROOT / "scripts" / "install.sh"

CANONICAL_TOOL_ORDER = ["read", "search", "web", "edit", "execute", "agent", "todo"]
POSTURES = {"R", "R+route", "E", "E+T", "O"}

AGENT_SECTIONS = [
    "Role",
    "Objective",
    "Context",
    "Inputs",
    "Responsibilities",
    "Task Instructions",
    "Scope & Boundaries",
    "Decision Policy",
    "Reasoning Instructions",
    "Output Contract",
    "Output Style",
    "Quality Criteria",
    "Failure & Uncertainty Handling",
    "Invocation",
    "Handoff",
]
TERMINAL_SECTION = "Terminal Discipline"
TERMINAL_AFTER = "Scope & Boundaries"

PLAYBOOK_SECTIONS = [
    "When to use / when NOT",
    "Entry criteria",
    "Run at a glance",
    "Phase-by-phase",
    "Loop-backs used",
    "Closure criteria",
    "Worked example",
]

SEMVER = re.compile(
    r"^(0|[1-9]\d*)\.(0|[1-9]\d*)\.(0|[1-9]\d*)(?:-([0-9A-Za-z.-]+))?(?:\+[0-9A-Za-z.-]+)?$"
)


# --------------------------------------------------------------------------- frontmatter
def split_frontmatter(text: str) -> tuple[dict, str]:
    """Return (frontmatter, body). Raises ValueError if the file has no frontmatter block."""
    text = text.replace("\r\n", "\n")
    if not text.startswith("---\n"):
        raise ValueError("no frontmatter block")
    end = text.find("\n---\n", 4)
    if end == -1:
        raise ValueError("unterminated frontmatter block")
    data = yaml.safe_load(text[4:end]) or {}
    if not isinstance(data, dict):
        raise ValueError("frontmatter is not a mapping")
    return data, text[end + 5 :]


def raw_frontmatter_keys(text: str) -> list[str]:
    """Top-level keys in source order (yaml.safe_load loses ordering guarantees we assert on)."""
    block = text.replace("\r\n", "\n")[4:].split("\n---\n", 1)[0]
    return re.findall(r"^([A-Za-z_][\w-]*):", block, re.M)


def h2_sections(body: str) -> list[str]:
    """``## `` headings outside fenced code blocks."""
    out, fenced = [], False
    for line in body.splitlines():
        if line.startswith("```"):
            fenced = not fenced
            continue
        if not fenced and line.startswith("## "):
            out.append(line[3:].strip())
    return out


# --------------------------------------------------------------------------- agents
@dataclass(frozen=True)
class Agent:
    path: Path
    slug: str
    meta: dict
    body: str
    text: str

    @property
    def tools(self) -> list[str]:
        return list(self.meta.get("tools") or [])

    @property
    def posture(self) -> str:
        return posture_from_tools(self.tools)


def posture_from_tools(tools: list[str]) -> str:
    s = set(tools)
    if "agent" in s and "edit" not in s:
        return "O" if "todo" in s else "R+route"
    if "edit" in s:
        return "E+T" if "execute" in s else "E"
    return "R"


@cache
def agents() -> tuple[Agent, ...]:
    out = []
    for p in sorted(AGENTS_DIR.glob("*.agent.md")):
        text = p.read_text(encoding="utf-8")
        meta, body = split_frontmatter(text)
        out.append(Agent(p, p.name.removesuffix(".agent.md"), meta, body, text))
    return tuple(out)


# --------------------------------------------------------------------------- roster
@dataclass(frozen=True)
class RosterRow:
    id: str
    name: str
    phase: str
    posture_cell: str
    called_by: str
    may_call: str

    @property
    def posture(self) -> str:
        """The canonical legend token: the first backticked token in the posture cell."""
        m = re.search(r"`([^`]+)`", self.posture_cell)
        return m.group(1) if m else self.posture_cell.split()[0]


@cache
def roster_rows() -> tuple[RosterRow, ...]:
    rows = []
    for line in ROSTER.read_text(encoding="utf-8").splitlines():
        m = re.match(r"^\|\s*(\d\d)\s*\|(.+)\|\s*$", line)
        if not m:
            continue
        cells = [c.strip() for c in m.group(2).split("|")]
        if len(cells) != 5:
            continue
        rows.append(RosterRow(m.group(1), *cells))
    return tuple(rows)


@cache
def roster_slug_by_id() -> dict[str, str]:
    """Map roster id -> agent slug, using the 'agent NN' statement in each definition's Role."""
    out = {}
    for a in agents():
        m = re.search(r"\bagent (\d\d)\b", a.body)
        if m:
            out[m.group(1)] = a.slug
    return out


# --------------------------------------------------------------------------- playbooks
@dataclass(frozen=True)
class Playbook:
    path: Path
    case: str
    meta: dict
    body: str
    text: str

    @property
    def agent_ids(self) -> set[str]:
        return {f"{int(x):02d}" for x in self.meta.get("agents") or []}


@cache
def playbooks() -> tuple[Playbook, ...]:
    out = []
    for p in sorted(PLAYBOOKS_DIR.glob("*.md")):
        if p.name in {"README.md", "playbook-schema.md"}:
            continue
        text = p.read_text(encoding="utf-8")
        # agents: [01,02] must stay strings; parse that one key by hand so 08/09 survive.
        meta, body = split_frontmatter(text)
        m = re.search(r"^agents:\s*\[([^\]]*)\]", text, re.M)
        if m:
            meta["agents"] = [x.strip() for x in m.group(1).split(",") if x.strip()]
        out.append(Playbook(p, p.stem, meta, body, text))
    return tuple(out)


@dataclass(frozen=True)
class Matrix:
    columns: list[str]  # abbreviations, header order
    abbrev_to_case: dict[str, str]
    rows: dict[str, dict[str, str]]  # agent id -> {abbrev: cell}


@cache
def matrix() -> Matrix:
    text = (PLAYBOOKS_DIR / "README.md").read_text(encoding="utf-8")
    sect = text[text.index("## Case × agent matrix") :]
    legend = dict(re.findall(r"`([a-z]{2})` ([a-z-]+)", sect.split("\n|", 1)[0]))
    header = next(ln for ln in sect.splitlines() if ln.startswith("| # | Agent |"))
    cols = [c.strip() for c in header.strip().strip("|").split("|")][2:]
    rows: dict[str, dict[str, str]] = {}
    for line in sect.splitlines():
        m = re.match(r"^\|\s*(\d\d)\s*\|[^|]*\|(.*)\|\s*$", line)
        if not m:
            continue
        cells = [c.strip() for c in m.group(2).split("|")]
        rows[m.group(1)] = dict(zip(cols, cells, strict=False))
        rows[m.group(1)]["__ncells__"] = str(len(cells))
    return Matrix(cols, legend, rows)


# --------------------------------------------------------------------------- skills / commands
@dataclass(frozen=True)
class Skill:
    dir: Path
    name: str
    meta: dict
    keys: list[str]
    body: str


@cache
def skills() -> tuple[Skill, ...]:
    out = []
    for d in sorted(p for p in SKILLS_DIR.iterdir() if p.is_dir()):
        text = (d / "SKILL.md").read_text(encoding="utf-8")
        meta, body = split_frontmatter(text)
        out.append(Skill(d, d.name, meta, raw_frontmatter_keys(text), body))
    return tuple(out)


@cache
def commands() -> dict[str, dict]:
    out = {}
    for p in sorted(COMMANDS_DIR.glob("*.md")):
        meta, _ = split_frontmatter(p.read_text(encoding="utf-8"))
        out[p.stem] = meta
    return out


# --------------------------------------------------------------------------- release metadata
def plugin_manifest() -> dict:
    return json.loads(PLUGIN_JSON.read_text(encoding="utf-8"))


def marketplace_manifest() -> dict:
    return json.loads(MARKETPLACE_JSON.read_text(encoding="utf-8"))


def changelog_versions() -> list[str]:
    """Released versions in CHANGELOG order (newest first), excluding [Unreleased]."""
    text = CHANGELOG.read_text(encoding="utf-8")
    return re.findall(r"^## \[(\d+\.\d+\.\d+(?:-[0-9A-Za-z.-]+)?)\]", text, re.M)


def git(*args: str, cwd: Path = ROOT) -> str:
    return subprocess.run(
        ["git", *args], cwd=cwd, check=True, capture_output=True, text=True
    ).stdout


def tracked_files() -> list[Path]:
    return [ROOT / p for p in git("ls-files").splitlines() if (ROOT / p).is_file()]


@pytest.fixture(scope="session")
def repo_root() -> Path:
    return ROOT
