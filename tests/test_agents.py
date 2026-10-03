"""Agent definitions follow the fixed frontmatter and section template."""

import pytest
from conftest import (
    AGENT_SECTIONS,
    TERMINAL_AFTER,
    TERMINAL_SECTION,
    agents,
    h2_sections,
    raw_frontmatter_keys,
)

FRONTMATTER = ["name", "description", "argument-hint", "tools"]
INVOCATION_LEAD = "Follow `process/agent-invocation-contract.md`."


@pytest.mark.parametrize("agent", agents(), ids=lambda a: a.slug)
def test_frontmatter_schema(agent):
    assert raw_frontmatter_keys(agent.text) == FRONTMATTER
    assert agent.meta["name"] == agent.slug, "name must equal the filename stem"
    assert isinstance(agent.meta["tools"], list)
    assert isinstance(agent.meta["description"], str) and len(agent.meta["description"]) >= 80


@pytest.mark.parametrize("agent", agents(), ids=lambda a: a.slug)
def test_section_template(agent):
    expected = list(AGENT_SECTIONS)
    if "execute" in agent.tools:
        expected.insert(expected.index(TERMINAL_AFTER) + 1, TERMINAL_SECTION)
    assert h2_sections(agent.body) == expected


@pytest.mark.parametrize("agent", agents(), ids=lambda a: a.slug)
def test_invocation_paragraph_references_contract(agent):
    section = agent.body.split("## Invocation", 1)[1].split("\n## ", 1)[0]
    assert INVOCATION_LEAD in section


def test_invocation_paragraph_is_identical_across_roster():
    paras = set()
    for a in agents():
        section = a.body.split("## Invocation", 1)[1].split("\n## ", 1)[0].strip()
        paras.add(section.split("\n\n", 1)[0])
    assert len(paras) == 1, "the shared contract paragraph must be verbatim across all agents"
