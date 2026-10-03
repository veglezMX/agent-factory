"""Playbooks conform to process/playbooks/playbook-schema.md."""

import re

import pytest
from conftest import PLAYBOOK_SECTIONS, h2_sections, playbooks, raw_frontmatter_keys, roster_rows

FIELDS = [
    "case",
    "name",
    "trigger",
    "entry_criteria",
    "agents",
    "skills",
    "gates",
    "baseline",
    "closure",
]
BASELINE = {"produces", "consumes", "none"}


def test_there_are_playbooks():
    assert len(playbooks()) >= 10


@pytest.mark.parametrize("pb", playbooks(), ids=lambda p: p.case)
def test_frontmatter(pb):
    assert raw_frontmatter_keys(pb.text) == FIELDS
    assert pb.meta["case"] == pb.path.stem
    assert pb.meta["baseline"] in BASELINE
    assert isinstance(pb.meta["entry_criteria"], list) and pb.meta["entry_criteria"]
    assert isinstance(pb.meta["gates"], list)
    assert isinstance(pb.meta["closure"], str) and pb.meta["closure"].strip()


@pytest.mark.parametrize("pb", playbooks(), ids=lambda p: p.case)
def test_agent_ids_exist_in_roster(pb):
    ids = {r.id for r in roster_rows()}
    assert pb.agent_ids <= ids, f"unknown ids {sorted(pb.agent_ids - ids)}"
    assert "01" in pb.agent_ids, "every case is driven by the Delivery Orchestrator"


@pytest.mark.parametrize("pb", playbooks(), ids=lambda p: p.case)
def test_skills_exist(pb, repo_root):
    for s in pb.meta.get("skills") or []:
        assert (repo_root / ".github" / "skills" / s / "SKILL.md").is_file(), f"no skill {s}"


@pytest.mark.parametrize("pb", playbooks(), ids=lambda p: p.case)
def test_body_sections_in_order(pb):
    assert [s for s in h2_sections(pb.body) if s in PLAYBOOK_SECTIONS] == PLAYBOOK_SECTIONS


@pytest.mark.parametrize("pb", playbooks(), ids=lambda p: p.case)
def test_gate_filenames_follow_protocol(pb):
    for name in re.findall(r"gates/(gate-[\w-]+\.md)", pb.text):
        assert re.fullmatch(r"gate-(\d+|[a-z])-[a-z0-9-]+\.md|gate-N-[a-z-]+\.md", name), (
            f"{name}: gate records are gates/gate-<n>-<slug>.md (protocol §3.2)"
        )
