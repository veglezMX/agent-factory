"""Behavioural tests of tools/check_versions.py against throwaway git repositories."""

import subprocess
import sys
from pathlib import Path

import pytest

sys.path.insert(0, str(Path(__file__).resolve().parent.parent / "tools"))
import check_versions as cv  # noqa: E402

SKILL = "---\nname: demo\ndescription: Use when testing.\nversion: {v}\n---\n\nBody {b}\n"


def _git(repo: Path, *args: str) -> str:
    return subprocess.run(
        ["git", *args], cwd=repo, check=True, capture_output=True, text=True
    ).stdout.strip()


def _commit(repo: Path, files: dict[str, str], msg: str = "c") -> str:
    for rel, content in files.items():
        p = repo / rel
        p.parent.mkdir(parents=True, exist_ok=True)
        p.write_text(content)
    _git(repo, "add", "-A")
    _git(repo, "commit", "-q", "-m", msg)
    return _git(repo, "rev-parse", "HEAD")


@pytest.fixture
def repo(tmp_path: Path) -> Path:
    _git(tmp_path, "init", "-q")
    _git(tmp_path, "config", "user.email", "t@example.com")
    _git(tmp_path, "config", "user.name", "t")
    _commit(
        tmp_path,
        {
            ".github/skills/demo/SKILL.md": SKILL.format(v="0.1.0", b=1),
            "process/doc.md": "doc\n",
            "CHANGELOG.md": "# Changelog\n",
            "README.md": "readme\n",
        },
    )
    return tmp_path


def run(repo: Path, base: str | None) -> list[str]:
    return cv.check(base, "HEAD", cwd=repo)


def test_r1_fails_when_skill_changes_without_bump(repo):
    base = _git(repo, "rev-parse", "HEAD")
    _commit(
        repo,
        {
            ".github/skills/demo/SKILL.md": SKILL.format(v="0.1.0", b=2),
            "CHANGELOG.md": "# Changelog\n- x\n",
        },
    )
    errors = run(repo, base)
    assert any(e.startswith("R1") for e in errors)


def test_r1_passes_when_skill_bumps(repo):
    base = _git(repo, "rev-parse", "HEAD")
    _commit(
        repo,
        {
            ".github/skills/demo/SKILL.md": SKILL.format(v="0.1.1", b=2),
            "CHANGELOG.md": "# Changelog\n- x\n",
        },
    )
    assert run(repo, base) == []


def test_r1_rejects_a_downgrade_and_a_prerelease_of_the_same_version(repo):
    base = _git(repo, "rev-parse", "HEAD")
    _commit(
        repo,
        {
            ".github/skills/demo/SKILL.md": SKILL.format(v="0.1.0-rc.1", b=2),
            "CHANGELOG.md": "# Changelog\n- x\n",
        },
    )
    assert any(e.startswith("R1") for e in run(repo, base))


def test_r1_companion_file_change_also_requires_bump(repo):
    base = _git(repo, "rev-parse", "HEAD")
    _commit(repo, {".github/skills/demo/guide.md": "extra\n", "CHANGELOG.md": "# C\n- x\n"})
    assert any(e.startswith("R1") for e in run(repo, base))


def test_r2_fails_without_changelog(repo):
    base = _git(repo, "rev-parse", "HEAD")
    _commit(repo, {"process/doc.md": "doc 2\n"})
    errors = run(repo, base)
    assert errors and all(e.startswith("R2") for e in errors)


def test_r2_passes_with_changelog(repo):
    base = _git(repo, "rev-parse", "HEAD")
    _commit(repo, {"process/doc.md": "doc 2\n", "CHANGELOG.md": "# Changelog\n- doc\n"})
    assert run(repo, base) == []


def test_r2_ignores_non_distributed_files(repo):
    base = _git(repo, "rev-parse", "HEAD")
    _commit(repo, {"README.md": "readme 2\n", "tests/test_x.py": "x = 1\n"})
    assert run(repo, base) == []


@pytest.mark.parametrize("base", [None, "", "0" * 40, "deadbeef"])
def test_no_usable_base_skips(repo, base):
    with pytest.raises(SystemExit) as exc:
        run(repo, base)
    assert exc.value.code == 0


@pytest.mark.parametrize(
    ("lo", "hi"),
    [
        ("0.1.0", "0.1.1"),
        ("0.1.9", "0.2.0"),
        ("0.9.0", "1.0.0"),
        ("1.0.0-rc.1", "1.0.0"),
        ("1.0.0-rc.2", "1.0.0-rc.10"),
        ("1.0.0-alpha", "1.0.0-beta"),
    ],
)
def test_semver_order(lo, hi):
    assert cv.semver_key(lo) < cv.semver_key(hi)
