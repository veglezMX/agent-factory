#!/usr/bin/env python3
"""Bump-on-change gate for agents-factory (docs/RELEASING.md, "Gates").

Compares two git revisions and enforces:

  R1  skill bump   — if any file under .github/skills/<name>/ changed, that skill's
                     `version:` frontmatter must strictly increase (SemVer order).
  R2  changelog    — if any distributed content changed (.github/{agents,skills,commands},
                     process/, templates/, scripts/), CHANGELOG.md must change too.

Both rules are skipped when no usable base revision is given, so the script never
obstructs local work: it is a CI gate. Exit status 0 = pass or skipped, 1 = violation.

Usage:
  python tools/check_versions.py --base <rev> [--head <rev>]
"""

from __future__ import annotations

import argparse
import re
import subprocess
import sys
from pathlib import Path

ROOT = Path(__file__).resolve().parent.parent
SKILLS_PREFIX = ".github/skills/"
DISTRIBUTED = (
    ".github/agents/",
    ".github/skills/",
    ".github/commands/",
    "process/",
    "templates/",
    "scripts/",
)
CHANGELOG = "CHANGELOG.md"
ZERO_SHA = re.compile(r"^0+$")
SEMVER = re.compile(
    r"^(0|[1-9]\d*)\.(0|[1-9]\d*)\.(0|[1-9]\d*)(?:-([0-9A-Za-z.-]+))?(?:\+[0-9A-Za-z.-]+)?$"
)


def git(*args: str, cwd: Path = ROOT, check: bool = True) -> subprocess.CompletedProcess[str]:
    return subprocess.run(["git", *args], cwd=cwd, capture_output=True, text=True, check=check)


def rev_exists(rev: str, cwd: Path) -> bool:
    return (
        git(
            "rev-parse", "--verify", "--quiet", f"{rev}^{{commit}}", cwd=cwd, check=False
        ).returncode
        == 0
    )


def changed_files(base: str, head: str, cwd: Path) -> list[str]:
    out = git("diff", "--name-only", base, head, cwd=cwd).stdout
    return [line for line in out.splitlines() if line]


def show(rev: str, path: str, cwd: Path) -> str | None:
    r = git("show", f"{rev}:{path}", cwd=cwd, check=False)
    return r.stdout if r.returncode == 0 else None


def skill_version(text: str | None) -> str | None:
    if text is None or not text.startswith("---"):
        return None
    block = text.split("\n---", 1)[0]
    m = re.search(r"^version:\s*['\"]?([^'\"\s]+)['\"]?\s*$", block, re.M)
    return m.group(1) if m else None


def semver_key(v: str) -> tuple:
    m = SEMVER.match(v)
    if not m:
        raise ValueError(f"not semver: {v!r}")
    major, minor, patch, pre = m.groups()
    # A release outranks any of its pre-releases; identifiers compare per SemVer §11.
    pre_key: tuple = (
        (1,)
        if pre is None
        else (0, *((0, int(p)) if p.isdigit() else (1, p) for p in pre.split(".")))
    )
    return (int(major), int(minor), int(patch), pre_key)


def check(base: str | None, head: str = "HEAD", cwd: Path = ROOT) -> list[str]:
    """Return a list of violations; empty means pass. Raises SystemExit(0) on skip."""
    if not base or ZERO_SHA.match(base) or not rev_exists(base, cwd):
        print(f"check_versions: no usable base revision ({base!r}) — skipping R1 and R2.")
        raise SystemExit(0)
    files = changed_files(base, head, cwd)
    errors: list[str] = []

    # R1 — every changed skill bumps its version.
    skills = sorted(
        {
            f[len(SKILLS_PREFIX) :].split("/", 1)[0]
            for f in files
            if f.startswith(SKILLS_PREFIX) and f.count("/") >= 3
        }
    )
    for name in skills:
        path = f"{SKILLS_PREFIX}{name}/SKILL.md"
        new = skill_version(show(head, path, cwd))
        old = skill_version(show(base, path, cwd))
        if show(head, path, cwd) is None:
            continue  # skill removed; R2 covers the changelog
        if new is None:
            errors.append(f"R1: {path} has no `version:` frontmatter")
            continue
        if not SEMVER.match(new):
            errors.append(f"R1: {path} version {new!r} is not SemVer")
            continue
        if old is None or not SEMVER.match(old):
            continue  # new skill, or first time a version is declared
        if semver_key(new) <= semver_key(old):
            errors.append(
                f"R1: skill '{name}' changed but its version did not increase "
                f"({old} -> {new}); bump it in {path}"
            )

    # R2 — distributed content changes come with a changelog entry.
    touched = [f for f in files if f.startswith(DISTRIBUTED)]
    if touched and CHANGELOG not in files:
        sample = ", ".join(touched[:3]) + (" …" if len(touched) > 3 else "")
        errors.append(
            f"R2: distributed content changed ({sample}) but {CHANGELOG} did not; "
            "add an entry under [Unreleased]"
        )
    return errors


def main(argv: list[str] | None = None) -> int:
    ap = argparse.ArgumentParser(description=(__doc__ or "").split("\n\n", 1)[0])
    ap.add_argument("--base", default=None, help="base revision (PR base SHA or push 'before')")
    ap.add_argument("--head", default="HEAD", help="head revision (default: HEAD)")
    args = ap.parse_args(argv)
    errors = check(args.base, args.head)
    for e in errors:
        print(f"check_versions: {e}", file=sys.stderr)
    if errors:
        return 1
    print(f"check_versions: OK ({args.base}..{args.head})")
    return 0


if __name__ == "__main__":
    sys.exit(main())
