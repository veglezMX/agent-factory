"""Plugin manifests, CHANGELOG, and (on a tag build) the tag agree with each other and the tree."""

import os
import re

from conftest import (
    CHANGELOG,
    SEMVER,
    agents,
    changelog_versions,
    commands,
    marketplace_manifest,
    playbooks,
    plugin_manifest,
    skills,
)

WORDS = {
    "one": 1,
    "two": 2,
    "three": 3,
    "four": 4,
    "five": 5,
    "six": 6,
    "seven": 7,
    "eight": 8,
    "nine": 9,
    "ten": 10,
    "eleven": 11,
    "twelve": 12,
}


def _counts(desc: str) -> dict[str, int]:
    out = {}
    for num, noun in re.findall(
        r"\b(\d+|[a-z]+)\s+(?:[\w-]+\s+){0,3}?"
        r"(specialists|agents|skills|commands|case playbooks|playbooks)\b",
        desc,
    ):
        n = int(num) if num.isdigit() else WORDS.get(num)
        if n is not None:
            out[noun] = n
    return out


def test_descriptions_agree():
    plugin = plugin_manifest()["description"]
    market = marketplace_manifest()["plugins"][0]["description"]
    assert plugin == market


def test_description_counts_match_tree():
    counts = _counts(plugin_manifest()["description"])
    assert counts, "description states no counts — the test cannot check it"
    actual = {
        "specialists": len(agents()),
        "agents": len(agents()),
        "skills": len(skills()),
        "commands": len(commands()),
        "case playbooks": len(playbooks()),
        "playbooks": len(playbooks()),
    }
    for noun, n in counts.items():
        assert actual[noun] == n, f"description says {n} {noun}, tree has {actual[noun]}"


def test_names_and_source():
    assert plugin_manifest()["name"] == "agents-factory"
    entry = marketplace_manifest()["plugins"][0]
    assert entry["name"] == plugin_manifest()["name"]
    assert entry["source"] == "./"


def test_version_is_semver_and_matches_changelog():
    version = plugin_manifest()["version"]
    assert SEMVER.match(version)
    released = changelog_versions()
    assert released, "CHANGELOG has no released sections"
    assert released[0] == version, (
        f"plugin.json is {version} but the newest released CHANGELOG section is {released[0]}"
    )


def test_changelog_shape():
    text = CHANGELOG.read_text(encoding="utf-8")
    assert re.search(r"^## \[Unreleased\]$", text, re.M), "an [Unreleased] section must exist"
    released = changelog_versions()
    assert len(released) == len(set(released)), "duplicate version section"
    keys = [tuple(int(p) for p in v.split("-")[0].split(".")) for v in released]
    assert keys == sorted(keys, reverse=True), "versions must be newest first"
    for v in released:
        assert re.search(rf"^## \[{re.escape(v)}\] — \d{{4}}-\d{{2}}-\d{{2}}$", text, re.M), (
            f"[{v}] heading must be '## [{v}] — YYYY-MM-DD'"
        )


def test_changelog_compare_links():
    text = CHANGELOG.read_text(encoding="utf-8")
    links = dict(re.findall(r"^\[([^\]]+)\]: (\S+)$", text, re.M))
    base = "https://github.com/veglezMX/agent-factory/"
    released = changelog_versions()
    assert links.get("Unreleased") == f"{base}compare/v{released[0]}...HEAD"
    for newer, older in zip(released, released[1:], strict=False):
        assert links.get(newer) == f"{base}compare/v{older}...v{newer}"
    assert links.get(released[-1]) == f"{base}releases/tag/v{released[-1]}"


def test_tag_matches_version_on_tag_builds():
    ref = os.environ.get("GITHUB_REF", "")
    if not ref.startswith("refs/tags/v"):
        return
    tag = ref.removeprefix("refs/tags/")
    assert tag == f"v{plugin_manifest()['version']}" or tag.startswith(
        f"v{plugin_manifest()['version']}-rc."
    ), f"tag {tag} does not match plugin.json {plugin_manifest()['version']}"
