# Releasing agents-factory

This document is the release methodology for this repository: what a version means, how
work flows from a branch to a tagged release, which gates guard each step, and the exact
runbook a maintainer (human or agent) follows to cut a release. Contribution mechanics —
setting up, branching, writing a pull request — live in [CONTRIBUTING.md](../CONTRIBUTING.md);
this page assumes them.

---

## 1. What is released

agents-factory ships **one distributable**: the roster, skills, commands, and framework docs,
consumed either as the `agents-factory` Claude Code plugin or through `scripts/install.sh`.
Nothing is built or packaged. **A release is a tagged commit on `main`** plus a GitHub
Release whose notes are that version's `CHANGELOG.md` section. Consumers pin a release by
pinning the tag.

| Fact | Source of truth |
|---|---|
| The release version | `version` in `.claude-plugin/plugin.json` |
| What changed in it | its `## [X.Y.Z] — YYYY-MM-DD` section in `CHANGELOG.md` |
| Which commit it is | the `vX.Y.Z` tag |
| Each skill's revision | `version:` in `.github/skills/<name>/SKILL.md` |

These must agree. `tests/test_manifests.py` and `tools/release.py verify` fail when they
do not, and the release workflow refuses to publish.

---

## 2. Versioning

The release version follows [Semantic Versioning 2.0.0](https://semver.org/). What counts as
the public interface here is not code but **contracts**: the things a consumer's runs,
installs, or own agents depend on.

**The public interface**

- the roster: agent slugs, roster numbers, postures, and what each agent owns;
- the handoff payload schema, gate record format, and run-workspace layout
  (`process/agent-handoff-protocol.md`);
- the invocation contract (`process/agent-invocation-contract.md`);
- the playbook set and the playbook frontmatter schema;
- skill and command names and their arguments;
- agent, skill, and playbook frontmatter schemas;
- `scripts/install.sh` targets, flags, and where each target writes.

**While the major version is 0** (now — the framework stays pre-1.0 until a delivery run has
gone end to end through build, hardening, and release):

| Bump | When |
|---|---|
| **MINOR** `0.X.0` | the roster, playbook set, skill set, or command set changes; or any change to the public interface above that could break an existing run, install, or custom agent |
| **PATCH** `0.x.Y` | fixes, documentation, prose improvements inside an agent's existing scope, installer bug fixes, tooling and CI |

**From 1.0.0 on:** MAJOR for a breaking change to the public interface (a renamed or removed
agent, skill, command, or install target; an incompatible handoff schema; a changed run
layout); MINOR for backwards-compatible additions (a new agent, case, skill, command, or
target); PATCH as above.

**Skill versions.** Each framework skill carries its own SemVer `version:`. It exists for
visibility — so a consumer can tell which revision of `conducting-a-gate` they run — not for
independent distribution. Any change to a skill's directory must raise it (gate R1 below):
PATCH for wording, MINOR for a new step or changed behaviour, MAJOR (post-1.0) for a change
that invalidates how the skill was used before.

**Pre-releases.** A release candidate is `X.Y.Z-rc.N`, tagged on the release branch after
`prep`. `plugin.json` already says `X.Y.Z`; the `-rc.N` lives only in the tag.

---

## 3. Branches

```text
feature/*  fix/*  docs/*  chore/*        short-lived; one concern each
        │  PR (squash or merge)
        ▼
       dev ─────────────────────────────  integration branch; always green
        │  release/vX.Y.Z  (cut from dev)
        ▼  PR, merge commit
      main ─────────────────────────────  released history only; every tag lives here
        ▲
        │  hotfix/vX.Y.Z  (cut from main) — PR into main, then back-merged into dev
```

- **`dev`** is where work lands. Every pull request targets `dev` unless it is a release or
  hotfix. `dev` is always releasable: CI must be green to merge.
- **`main`** only receives release and hotfix branches, through a pull request merged with a
  **merge commit** (not squash), so the tag points at a commit whose history contains every
  change it releases.
- **After every release or hotfix, merge `main` back into `dev`** so the version bump and the
  rotated CHANGELOG are not lost.
- Never rewrite published history on `main` or `dev`: no force-push, no rebase of merged
  commits.

**Recommended branch protection** (set by a repository owner in GitHub settings — it cannot
be configured from the repository itself): on `main` and `dev`, require a pull request,
require the `ci / check` status to pass, and block force-pushes and deletion. On `main`,
also restrict who can push to maintainers.

---

## 4. Gates

Every pull request and every push to `main`/`dev` runs `.github/workflows/ci.yml`. Each step
fails on its own, with a cause you can name:

| Gate | Command | Fails when |
|---|---|---|
| Lint | `ruff`, `shellcheck`, `actionlint` | tooling code, the installer, or a workflow has a defect |
| Derived trees | `scripts/install.sh --target repo --check` | `.github/` was edited without regenerating `.claude/`, `.cursor/`, `agents/`, `skills/`, `commands/` |
| R1 — skill bump | `tools/check_versions.py --base <ref>` | a skill's files changed and its `version:` did not increase |
| R2 — changelog | `tools/check_versions.py --base <ref>` | distributed content (`.github/{agents,skills,commands}`, `process/`, `templates/`, `scripts/`) changed and `CHANGELOG.md` did not |
| Types | `pyright` | `tools/` or `tests/` has a type error |
| Invariants | `pytest` | a repository invariant broke — see the table in CONTRIBUTING.md |

R1 and R2 compare against the pull request's base (or the push's previous head). Without a
usable base they skip rather than guess, so they never block local work. R2 is deliberately
coarse: it makes a missing changelog entry visible; it does not judge the entry.

`just check` runs the same gates locally, in the same order.

---

## 5. The changelog

`CHANGELOG.md` follows [Keep a Changelog 1.1](https://keepachangelog.com/en/1.1.0/):

- An `## [Unreleased]` section always exists at the top.
- **Every pull request that changes distributed content adds its entry there**, under
  `### Added`, `### Changed`, `### Deprecated`, `### Removed`, `### Fixed`, or `### Security`.
  Write for a consumer: what changed and why it matters to them, not which files moved.
- Released sections are headed `## [X.Y.Z] — YYYY-MM-DD`, newest first, and are never edited
  after release except to correct a factual error (say so in the next release's notes).
- Link references at the bottom (`[X.Y.Z]: …/compare/vA...vX.Y.Z`) are maintained by
  `tools/release.py`; `tests/test_manifests.py` checks them.

---

## 6. Cutting a release

Prerequisites: `dev` is green, `[Unreleased]` describes everything since the last tag, and you
can push tags. The steps are the same for a human or an agent; an agent does them only when
the task it was given is "cut release X.Y.Z".

1. **Choose the version** from §2: MINOR if `[Unreleased]` changes the roster, playbook,
   skill, or command set or a contract; otherwise PATCH.
2. **Cut the release branch and prepare it.**
   ```bash
   git switch dev && git pull
   git switch -c release/vX.Y.Z
   just release-prep X.Y.Z          # bumps plugin.json, rotates CHANGELOG, runs every gate
   git commit -am "chore(release): vX.Y.Z"
   git push -u origin release/vX.Y.Z
   ```
   Read the new `[X.Y.Z]` section as release notes. Tighten wording now; it becomes the
   GitHub Release body verbatim.
3. **Optional release candidate.** For a release that changes contracts, tag
   `vX.Y.Z-rc.1` on the release branch and push it. The workflow publishes a pre-release;
   try the install from the tag (`git checkout vX.Y.Z-rc.1 && scripts/install.sh …`, or
   `/plugin marketplace add veglezMX/agent-factory@vX.Y.Z-rc.1`). Fix forward on the release
   branch and tag `-rc.2` if needed.
4. **Open the pull request** `release/vX.Y.Z` → `main`, titled `Release vX.Y.Z`, body = the
   CHANGELOG section. When CI is green and it is approved, **merge with a merge commit**.
5. **Tag the merge commit on `main`** — a lightweight tag, with plain `git tag`:
   ```bash
   git switch main && git pull
   just release-verify vX.Y.Z      # tag, plugin.json, and CHANGELOG agree
   git tag vX.Y.Z
   git push origin vX.Y.Z
   ```
   Lightweight, not annotated: should the marketplace entry ever pin a commit, an annotated
   tag resolves to a tag object rather than the commit and Claude Code refuses the install.
6. **The release workflow publishes.** `.github/workflows/release.yml` re-runs every gate on
   the tagged commit, verifies the tag, and creates the GitHub Release from the CHANGELOG
   section. Check the Releases page.
7. **Back-merge** so `dev` carries the bump:
   ```bash
   git switch dev && git pull && git merge --no-ff origin/main && git push
   ```

**Hotfix.** For an urgent fix to a released version: branch `hotfix/vX.Y.Z` from `main`, fix,
add the CHANGELOG entry under `[Unreleased]`, run `just release-prep X.Y.Z` (PATCH), PR into
`main`, then steps 5–7.

**If the workflow fails after the tag is pushed,** fix the cause on `main` through a normal
pull request; do not move the tag. If the tagged commit itself is wrong, release the next
PATCH instead. Deleting or moving a published tag breaks anyone who pinned it.

**Republishing a release** for an existing tag (for example after editing notes): run the
`release` workflow manually with that tag.

---

## 7. Retroactive tags

`0.1.0` and `0.2.0` were released before tags existed. They were tagged after the fact, as
lightweight tags on the commits that set those versions in `plugin.json`:

| Tag | Commit | Note |
|---|---|---|
| `v0.1.0` | `2c0dc9b` | first packaged release |
| `v0.2.0` | `dd0de1a` | the consolidation release; the Roo/Zoo target and `/run-advisory` landed on `main` after this commit and are released in `0.3.0` |

Their GitHub Releases were published with the `release` workflow's manual trigger and the
`historical` option, which skips the gates and version checks (the tooling did not exist at
those commits) and takes the notes from the current CHANGELOG. They are marked as not-latest.

---

## 8. What a consumer sees

- **Plugin:** `/plugin marketplace add veglezMX/agent-factory` tracks the default branch;
  `/plugin marketplace add veglezMX/agent-factory@vX.Y.Z` pins a release. In a committed
  `.claude/settings.json` (the claude.ai/code route), pin with
  `"source": {"source": "github", "repo": "veglezMX/agent-factory", "ref": "vX.Y.Z"}`.
- **Installer:** `git clone … && git checkout vX.Y.Z && scripts/install.sh --target …`.
  Re-running a newer installer updates agents, skills, and docs in place and reports any
  file a previous version installed that no longer has a source.
- **Release notes:** the GitHub Release for each tag, identical to the CHANGELOG section.
