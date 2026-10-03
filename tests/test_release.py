"""tools/release.py against a synthetic repository layout."""

import json
import sys
from pathlib import Path

import pytest

sys.path.insert(0, str(Path(__file__).resolve().parent.parent / "tools"))
import release  # noqa: E402

BASE = "https://github.com/veglezMX/agent-factory"

CHANGELOG = f"""# Changelog

Intro.

## [Unreleased]

### Added

- New thing.

## [0.2.0] — 2026-07-31

### Added

- Old thing.

## [0.1.0] — 2026-06-14

- First.

[Unreleased]: {BASE}/compare/v0.2.0...HEAD
[0.2.0]: {BASE}/compare/v0.1.0...v0.2.0
[0.1.0]: {BASE}/releases/tag/v0.1.0
"""


@pytest.fixture
def root(tmp_path: Path) -> Path:
    (tmp_path / ".claude-plugin").mkdir()
    (tmp_path / ".claude-plugin/plugin.json").write_text(
        json.dumps({"name": "agents-factory", "version": "0.2.0", "license": "MIT"}, indent=2)
    )
    (tmp_path / "CHANGELOG.md").write_text(CHANGELOG)
    return tmp_path


def test_prep_rotates_changelog_and_bumps_version(root):
    release.prep(root, "0.3.0", "2026-10-03")
    text = (root / "CHANGELOG.md").read_text()
    assert "## [Unreleased]\n\n## [0.3.0] — 2026-10-03\n\n### Added\n\n- New thing." in text
    assert f"[Unreleased]: {BASE}/compare/v0.3.0...HEAD" in text
    assert f"[0.3.0]: {BASE}/compare/v0.2.0...v0.3.0" in text
    assert f"[0.1.0]: {BASE}/releases/tag/v0.1.0" in text
    assert json.loads((root / ".claude-plugin/plugin.json").read_text())["version"] == "0.3.0"
    assert release.verify(root) == "0.3.0"
    assert "- New thing." in release.notes(root, "0.3.0")
    assert "Old thing" not in release.notes(root, "0.3.0")


@pytest.mark.parametrize("bad", ["0.2.0", "0.1.9", "1.0", "v0.3.0", "0.3.0-rc.1"])
def test_prep_rejects_non_increasing_or_malformed(root, bad):
    with pytest.raises(release.ReleaseError):
        release.prep(root, bad)


def test_prep_refuses_an_empty_unreleased(root):
    release.prep(root, "0.3.0", "2026-10-03")
    with pytest.raises(release.ReleaseError, match="no entries"):
        release.prep(root, "0.3.1", "2026-10-04")


@pytest.mark.parametrize("tag", ["v0.2.0", "v0.2.0-rc.1", "v0.2.0-rc.12"])
def test_verify_accepts_matching_tags(root, tag):
    assert release.verify(root, tag) == "0.2.0"


@pytest.mark.parametrize("tag", ["v0.2.1", "0.2.0", "v0.2.0-rc.0", "v0.2.0-beta", "v0.3.0"])
def test_verify_rejects_mismatched_tags(root, tag):
    with pytest.raises(release.ReleaseError):
        release.verify(root, tag)


def test_verify_rejects_unsynced_changelog(root):
    pj = root / ".claude-plugin/plugin.json"
    pj.write_text(pj.read_text().replace('"0.2.0"', '"0.2.1"'))
    with pytest.raises(release.ReleaseError, match="newest CHANGELOG release"):
        release.verify(root)


def test_notes_for_missing_version(root):
    with pytest.raises(release.ReleaseError):
        release.notes(root, "9.9.9")


def test_real_repository_is_consistent():
    assert release.verify(release.ROOT)
