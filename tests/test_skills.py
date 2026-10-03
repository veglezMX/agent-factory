"""Framework skills carry a closed, versioned frontmatter."""

import pytest
from conftest import SEMVER, skills

ALLOWED = ["name", "description", "version", "prerequisites"]
REQUIRED = ["name", "description", "version"]


def test_six_or_more_skills():
    assert len(skills()) >= 6


@pytest.mark.parametrize("skill", skills(), ids=lambda s: s.name)
def test_frontmatter_is_closed(skill):
    assert set(skill.keys) <= set(ALLOWED), f"unexpected keys {set(skill.keys) - set(ALLOWED)}"
    for k in REQUIRED:
        assert k in skill.meta, f"missing {k}"
    order = [k for k in ALLOWED if k in skill.keys]
    assert skill.keys == order, f"keys must appear in the order {ALLOWED}"


@pytest.mark.parametrize("skill", skills(), ids=lambda s: s.name)
def test_name_and_version(skill):
    assert skill.meta["name"] == skill.name
    assert SEMVER.match(str(skill.meta["version"])), (
        f"version {skill.meta['version']!r} is not semver"
    )


@pytest.mark.parametrize("skill", skills(), ids=lambda s: s.name)
def test_description_is_a_usable_trigger(skill):
    desc = skill.meta["description"]
    assert isinstance(desc, str) and len(desc) >= 120
    assert desc.lower().startswith("use when"), "lead with when to use it"


@pytest.mark.parametrize("skill", skills(), ids=lambda s: s.name)
def test_prerequisites_shape(skill):
    pre = skill.meta.get("prerequisites")
    if pre is None:
        return
    assert isinstance(pre, list) and pre
    for item in pre:
        assert isinstance(item, dict) and {"skill", "source"} <= set(item), item
