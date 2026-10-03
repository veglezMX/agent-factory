#!/usr/bin/env python3
"""Release helper for agents-factory (docs/RELEASING.md).

  prep X.Y.Z [--date YYYY-MM-DD]   bump .claude-plugin/plugin.json, turn [Unreleased] into
                                   [X.Y.Z], open a fresh [Unreleased], update compare links
  verify [--tag vX.Y.Z]            plugin.json == newest CHANGELOG release (== tag, if given)
  notes X.Y.Z                      print that version's CHANGELOG section (release notes)

The plugin version is the single release version. Tags are `vX.Y.Z` (or `vX.Y.Z-rc.N`
for a release candidate of X.Y.Z, cut after `prep`).
"""

from __future__ import annotations

import argparse
import datetime as dt
import json
import re
import sys
from pathlib import Path

ROOT = Path(__file__).resolve().parent.parent
REPO_URL = "https://github.com/veglezMX/agent-factory"
SEMVER = re.compile(r"^(0|[1-9]\d*)\.(0|[1-9]\d*)\.(0|[1-9]\d*)$")
RC_TAG = re.compile(r"^v(?P<version>\d+\.\d+\.\d+)(?:-rc\.(?P<rc>[1-9]\d*))?$")
HEADING = re.compile(r"^## \[(?P<v>[^\]]+)\](?: — (?P<date>\d{4}-\d{2}-\d{2}))?\s*$", re.M)


class ReleaseError(Exception):
    pass


def _key(v: str) -> tuple[int, int, int]:
    m = SEMVER.match(v)
    if not m:
        raise ReleaseError(f"{v!r} is not a release version (X.Y.Z)")
    return int(m[1]), int(m[2]), int(m[3])


def plugin_version(root: Path) -> str:
    return json.loads((root / ".claude-plugin/plugin.json").read_text(encoding="utf-8"))["version"]


def sections(changelog: str) -> list[tuple[str, int, int]]:
    """(version-or-'Unreleased', start, end) for each '## [...]' section, in file order."""
    heads = list(HEADING.finditer(changelog))
    links = re.search(r"^\[[^\]]+\]: http", changelog, re.M)
    tail = links.start() if links else len(changelog)
    out = []
    for i, h in enumerate(heads):
        end = heads[i + 1].start() if i + 1 < len(heads) else tail
        out.append((h["v"], h.start(), end))
    return out


def released_versions(changelog: str) -> list[str]:
    return [v for v, _, _ in sections(changelog) if v != "Unreleased"]


def section_body(changelog: str, version: str) -> str:
    for v, start, end in sections(changelog):
        if v == version:
            body = changelog[start:end].split("\n", 1)[1] if "\n" in changelog[start:end] else ""
            return body.strip("\n") + "\n"
    raise ReleaseError(f"CHANGELOG has no [{version}] section")


def rewrite_links(changelog: str, versions: list[str]) -> str:
    """Replace the trailing link-reference block with one derived from `versions`."""
    lines = [f"[Unreleased]: {REPO_URL}/compare/v{versions[0]}...HEAD"]
    for newer, older in zip(versions, versions[1:], strict=False):
        lines.append(f"[{newer}]: {REPO_URL}/compare/v{older}...v{newer}")
    lines.append(f"[{versions[-1]}]: {REPO_URL}/releases/tag/v{versions[-1]}")
    body = re.sub(r"(\n\[[^\]]+\]: http\S*)+\s*$", "", changelog.rstrip("\n"))
    return body.rstrip("\n") + "\n\n" + "\n".join(lines) + "\n"


def prep(root: Path, version: str, date: str | None = None) -> None:
    new = _key(version)
    current = plugin_version(root)
    if new <= _key(current):
        raise ReleaseError(f"{version} must be greater than the current version {current}")
    path = root / "CHANGELOG.md"
    text = path.read_text(encoding="utf-8")
    secs = sections(text)
    if not secs or secs[0][0] != "Unreleased":
        raise ReleaseError("CHANGELOG must start with an [Unreleased] section")
    _, start, end = secs[0]
    if not re.search(r"^- ", text[start:end], re.M):
        raise ReleaseError("[Unreleased] has no entries — nothing to release")
    if version in released_versions(text):
        raise ReleaseError(f"CHANGELOG already has a [{version}] section")
    day = date or dt.datetime.now(dt.UTC).date().isoformat()
    heading = f"## [Unreleased]\n\n## [{version}] — {day}\n"
    text = text[:start] + heading + text[start + len("## [Unreleased]\n") :]
    text = rewrite_links(text, released_versions(text))
    path.write_text(text, encoding="utf-8")

    pj = root / ".claude-plugin/plugin.json"
    raw = pj.read_text(encoding="utf-8")
    raw, n = re.subn(r'("version":\s*")[^"]+(")', rf"\g<1>{version}\g<2>", raw, count=1)
    if n != 1:
        raise ReleaseError("could not find the version field in plugin.json")
    pj.write_text(raw, encoding="utf-8")
    print(f"prepared {version} ({current} -> {version}, dated {day})")


def verify(root: Path, tag: str | None = None) -> str:
    version = plugin_version(root)
    _key(version)
    released = released_versions((root / "CHANGELOG.md").read_text(encoding="utf-8"))
    if not released or released[0] != version:
        newest = released[0] if released else "none"
        raise ReleaseError(f"plugin.json is {version}; newest CHANGELOG release is {newest}")
    if tag:
        m = RC_TAG.match(tag)
        if not m or m["version"] != version:
            raise ReleaseError(
                f"tag {tag} does not match plugin.json {version} "
                f"(expected v{version} or v{version}-rc.N)"
            )
    print(f"ok: version {version}" + (f", tag {tag}" if tag else ""))
    return version


def notes(root: Path, version: str) -> str:
    return section_body((root / "CHANGELOG.md").read_text(encoding="utf-8"), version)


def main(argv: list[str] | None = None) -> int:
    ap = argparse.ArgumentParser(description=(__doc__ or "").split("\n\n", 1)[0])
    sub = ap.add_subparsers(dest="cmd", required=True)
    p = sub.add_parser("prep")
    p.add_argument("version")
    p.add_argument("--date")
    v = sub.add_parser("verify")
    v.add_argument("--tag")
    n = sub.add_parser("notes")
    n.add_argument("version")
    args = ap.parse_args(argv)
    try:
        if args.cmd == "prep":
            prep(ROOT, args.version, args.date)
        elif args.cmd == "verify":
            verify(ROOT, args.tag)
        else:
            sys.stdout.write(notes(ROOT, args.version))
    except ReleaseError as e:
        print(f"release: {e}", file=sys.stderr)
        return 1
    return 0


if __name__ == "__main__":
    sys.exit(main())
