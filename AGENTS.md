# AGENTS.md — operating instructions for AI agents working on this repository

You are changing **agents-factory**, a framework of agent definitions, skills, commands, and
process documents. The text is the product. These rules apply to any coding agent (Claude
Code, Codex, Copilot, Cursor, Zoo/Roo, Hermes, …). Human contributors follow
[CONTRIBUTING.md](CONTRIBUTING.md), which these rules restate; releases follow
[docs/RELEASING.md](docs/RELEASING.md).

> This file is about working **on** this repository. It is not part of the roster, and
> nothing in it applies when the framework is installed into another project.

## Before you edit

- Read the files you are about to change, and the ones that cite them. A change to an agent,
  playbook, or roster entry usually moves a count or a cross-reference elsewhere.
- Editing under `.github/agents/` → follow the `authoring-an-agent` skill.
  Editing under `process/playbooks/` → follow the `authoring-a-playbook` skill.
- Work on a branch off `dev` (`feature/…`, `fix/…`, `docs/…`, `chore/…`), unless your task
  names another branch. Never commit directly to `main` or `dev`.

## Hard rules

1. **Edit the source, never the derived copy.** Sources: `.github/{agents,skills,commands}`.
   Generated: `.claude/`, `.cursor/`, and the root `agents/`, `skills/`, `commands/`. After any
   source edit run `scripts/install.sh --target repo` and commit the regenerated files with it.
2. **Run the gates before every commit you intend to push:** `just check` (or, without `just`:
   `uv run ruff check tools tests && scripts/install.sh --target repo --check &&
   uv run pyright && uv run pytest`). Never push red. Never skip, delete, or weaken a test to
   get green; if a test encodes a rule your task deliberately changes, change the test and
   say so in the pull request.
3. **Changelog and skill versions travel with the change.** Any change to
   `.github/{agents,skills,commands}`, `process/`, `templates/`, or `scripts/` adds an entry
   under `## [Unreleased]` in `CHANGELOG.md`. Any change inside `.github/skills/<name>/` raises
   that skill's `version:` (PATCH for wording, MINOR for new or changed steps).
4. **Do not release unless the task is a release.** Never edit `version` in
   `.claude-plugin/plugin.json`, create or move tags, or publish GitHub Releases as a side
   effect. When the task *is* a release, follow `docs/RELEASING.md` §6 step by step.
5. **Keep shared prose neutral.** Agents, skills, playbooks, and `process/` stay
   project-agnostic and harness-neutral — no product names, no single vendor's tool names
   (`tests/test_harness_neutral.py`). Platform details go in `PORTABILITY.md`, the installer,
   or the Claude Code commands.
6. **Leave `runs/` alone.** It is a real run kept as reference material.
7. **No secrets, absolute home paths, or model identifiers** in committed content, commit
   messages, or pull request text.
8. **Say what is real.** Do not document behaviour that does not exist, and do not claim a
   check passed unless you ran it and saw it pass.

## Commits and pull requests

- Conventional Commits: `type(scope): imperative summary` — types `feat`, `fix`, `docs`,
  `test`, `refactor`, `chore`, `ci`. Body explains what and why.
- One concern per pull request, targeting `dev`. Fill in `.github/pull_request_template.md`,
  including how you verified the change.
- Follow any attribution or co-author conventions your harness or operator requires.

## Map

| Path | What it is |
|---|---|
| `.github/agents/` | 29 agent definitions — source of truth |
| `.github/skills/`, `.github/commands/` | framework skills and Claude Code commands — source of truth |
| `process/` | roster, invocation contract, handoff protocol, playbooks |
| `templates/` | the Stakeholder Input Packet template |
| `scripts/install.sh` | the only generator; every target, every derived directory |
| `tools/` | `check_versions.py` (R1/R2 gate), `release.py` (release prep/verify/notes) |
| `tests/` | the invariant suite — read a test to learn the rule it enforces |
| `docs/RELEASING.md` | versioning, branches, gates, and the release runbook |
