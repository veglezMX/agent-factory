# Contributing to agents-factory

Thanks for helping. This repository is documentation and prompts: the deliverable *is* the
text, read by people and by AI agents on half a dozen harnesses. Changes therefore have to be
consistent across many files at once, and most of the rules below exist to make that
consistency checkable by a machine instead of by a careful reviewer.

- **Humans:** read this file.
- **AI coding agents** working on this repository: read [`AGENTS.md`](AGENTS.md). It is the
  same rules written as operating instructions; this file stays the reference.
- **Maintainers cutting a release:** [`docs/RELEASING.md`](docs/RELEASING.md).

---

## 1. The one rule: `.github/` is the source of truth

```text
.github/agents/     ->  .claude/agents/  ·  agents/  ·  .cursor/rules/<name>.mdc
.github/skills/     ->  .claude/skills/  ·  skills/  ·  .cursor/rules/skill-<name>.mdc  ·  .cursor/skills/
.github/commands/   ->  .claude/commands/  ·  commands/
```

Everything on the right is **generated** by `scripts/install.sh`. Never hand-edit it: the next
regeneration silently discards your change, and a reviewer cannot tell an intentional edit
from a stale one. After changing anything under `.github/`:

```bash
scripts/install.sh --target repo --dry-run   # preview
scripts/install.sh --target repo             # apply  (or: just regen)
```

It is idempotent — a clean tree reports `0 written` — and CI fails a pull request whose
derived directories do not match. If you rename or delete an agent, skill, or command, the
installer reports the leftover derived file as an `ORPHAN`; delete it in the same change.

`process/`, `templates/`, `README.md`, `PORTABILITY.md`, and `CHANGELOG.md` are hand-written
and not generated. `runs/` holds a real run workspace kept as reference material — do not
modify it.

---

## 2. Setting up

You need nothing beyond Git to edit prose — CI runs every gate on your pull request. To run
the gates locally (recommended before every push):

| Tool | Why | Install |
|---|---|---|
| [uv](https://docs.astral.sh/uv/) | runs the Python test and release tooling (dev-only; nothing Python ships) | `curl -LsSf https://astral.sh/uv/install.sh \| sh` |
| [just](https://just.systems) | task runner wrapping the same commands CI runs | `uv tool install rust-just`, or your package manager |
| bash 3.2+ | `scripts/install.sh` | preinstalled on macOS and Linux |

```bash
uv sync          # creates .venv with pytest, pyyaml, ruff, pyright
just check       # lint, derived-dir check, version gate, pyright, pytest — what CI runs
just --list      # every recipe
```

No `just`? Each recipe is one line in [`justfile`](justfile); run it directly, e.g.
`uv run pytest`.

---

## 3. Workflow

### Branches

Work branches off **`dev`** and comes back to it through a pull request. `main` only
receives release and hotfix merges (see [RELEASING.md §3](docs/RELEASING.md#3-branches)).

| Branch | For |
|---|---|
| `feature/<topic>` | a new agent, case, skill, command, install target, or capability |
| `fix/<topic>` | a defect in prose, the installer, or tooling |
| `docs/<topic>` | documentation only |
| `chore/<topic>` | tooling, CI, refactors with no consumer-visible change |

Keep branches short-lived and **one concern per pull request**. A roster change and an
installer fix are two pull requests.

### Commits

Use [Conventional Commits](https://www.conventionalcommits.org/) — the history already does:

```text
<type>(<optional scope>): <imperative summary, ≤ 72 chars>

<body: what and why, wrapped at 72>
```

Types: `feat`, `fix`, `docs`, `test`, `refactor`, `chore`, `ci`. Common scopes: `agents`,
`skills`, `commands`, `process`, `playbooks`, `install`, `tests`, `release`. Mark a breaking
change to the public interface ([RELEASING.md §2](docs/RELEASING.md#2-versioning)) with
`!` after the type and a `BREAKING CHANGE:` footer.

### Pull requests

Target `dev`. The template asks for the checklist below; CI enforces most of it.

- [ ] Derived directories regenerated (`scripts/install.sh --target repo`).
- [ ] `CHANGELOG.md` entry under `[Unreleased]` for any change to `.github/{agents,skills,commands}`,
      `process/`, `templates/`, or `scripts/` (gate R2).
- [ ] Every changed skill's `version:` raised (gate R1).
- [ ] Counts and cross-references updated where your change moves them (README, roster,
      manifests, playbook matrix) — the tests name the file when one is stale.
- [ ] `just check` green locally.

Do **not** bump `.claude-plugin/plugin.json` in a feature pull request; the version moves only
in a release branch.

### Review and merge

- Every pull request needs a green CI run and one approving review.
- Agent-authored pull requests are reviewed by a human before merge, like any other.
- Reviewers check what the tests cannot: whether a boundary is sound, whether prose is clear
  and project-agnostic, whether a change over-claims. "Say what is real" (§6) is the bar.
- Squash-merge or merge-commit into `dev` at the author's choice; release branches merge into
  `main` with a merge commit.

---

## 4. Adding to the framework

### An agent

Use the `authoring-an-agent` skill (or `/new-agent <slug>`); it encodes these rules and is
kept in step with them. It expects the [`prompt-anatomy`](https://github.com/veglezMX/veglez-skills)
skill for the body's component structure.

1. **Claim a roster number** in `process/agent-roster.md` first: the overview row (one posture
   token from the legend) plus a `### NN — Name` entry with Does / Scope / Tools / Invocation.
2. **Write `.github/agents/<slug>.agent.md`.** Frontmatter: `name` (= filename stem),
   `description`, `argument-hint`, `tools` (canonical order `read, search, web, edit,
   execute, agent, todo`).
3. **Match the section template** — fifteen `##` sections in a fixed order, plus
   `## Terminal Discipline` if and only if `tools` includes `execute`.
4. **Copy the shared `## Invocation` paragraph verbatim** from a sibling.
5. **Route it** — add it to the relevant playbooks' `agents:` lists and to the case × agent
   matrix in `process/playbooks/README.md`, in both directions.
6. **Regenerate**, update counts, add the CHANGELOG entry. A new agent is a MINOR change.

### A case (playbook)

Use the `authoring-a-playbook` skill. One file conforming to
`process/playbooks/playbook-schema.md`, plus a matrix column and a legend entry in
`process/playbooks/README.md`. The roster and protocol never change to add a case; if a case
needs an agent the roster lacks, the agent comes first, as its own pull request.

### A skill or command

Author `.github/skills/<name>/SKILL.md` (frontmatter `name`, `description` starting
"Use when …", `version: 0.1.0`, optional `prerequisites`) or `.github/commands/<name>.md`
(`description`, `argument-hint`, `allowed-tools`), then regenerate. Skills and process docs
stay harness-neutral; commands are Claude Code drivers and may name its tools.

### An install target

Add the converter to `scripts/install.sh`, its row to `PORTABILITY.md`, its line to the README
quick start and `--help`, and a parametrized case to `tests/test_installer.py` that installs
into a temporary directory and parses the output. Generated files must go through `emit` (or
`sync_dir`) so `--dry-run` and `--check` hold.

---

## 5. Invariants and the tests that enforce them

| Invariant | Enforced by |
|---|---|
| Roster IDs `01`–`NN` ↔ agent files, one-to-one | `tests/test_roster.py` |
| Roster posture is one legend token and matches the `tools:` grant | `tests/test_roster.py` |
| Only 01 and 18 carry `agent`; only 18 routes to specialists | `tests/test_roster.py` |
| Agent frontmatter, section template, shared Invocation paragraph | `tests/test_agents.py` |
| Playbook frontmatter, body sections, roster IDs, skills, gate filenames | `tests/test_playbooks.py` |
| Matrix cell `x`/`~` ⇔ agent ID in that playbook's `agents:` | `tests/test_matrix.py` |
| Closed, versioned skill frontmatter | `tests/test_skills.py` |
| Commands exist, are well formed, and are documented | `tests/test_commands.py` |
| Manifests agree; stated counts are true; version ↔ CHANGELOG ↔ tag | `tests/test_manifests.py` |
| Links and protocol/contract `§` citations resolve; README counts true | `tests/test_docs.py` |
| Process docs and skills are harness-neutral; no absolute home paths | `tests/test_harness_neutral.py` |
| Derived directories match `.github/` | `tests/test_derived_sync.py`, CI `--check` |
| Every install target produces valid, idempotent output | `tests/test_installer.py` |
| Skill changes bump the skill; content changes add a CHANGELOG entry | `tools/check_versions.py` (CI) |

When you change a convention on purpose, change the test in the same pull request and say so
in the description. A test that encodes an outgrown rule is friction; a convention nobody
checks is drift.

---

## 6. Style

- **Project-agnostic.** Agents, playbooks, skills, and process docs never name a specific
  product, stack, or company. Project specifics live in `process/examples/` and `runs/`.
- **Harness-neutral.** Process docs and skills describe capabilities ("your harness's
  structured-question tool"), not one vendor's tool names. Platform specifics belong in
  `PORTABILITY.md`, the installer, and the Claude Code commands.
- **References, never redefinitions.** A playbook names roster agents by ID and links protocol
  sections; it does not restate an agent's scope or a gate's semantics.
- **No time estimates.** Ordering expresses dependency, never duration.
- **Say what is real.** If a worked example describes work that was never executed, label it.
  A document that over-claims is worse than a missing one.

---

## 7. Reporting issues and security

Use the issue templates for bugs (include the install target, scope, platform, and harness)
and for proposals (a new agent, case, skill, command, or target). Report security problems
privately as described in [`SECURITY.md`](SECURITY.md), not in a public issue.

By contributing you agree that your contribution is licensed under the repository's
[MIT License](LICENSE).
