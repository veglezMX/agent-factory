# Versioning, Gates, and a Test Suite for agents-factory

**Date:** 2026-08-29
**Status:** Implemented in 0.3.0 (see CHANGELOG). The branch model is `main` + `dev`; `docs/RELEASING.md` is the living version of §5.3–§5.4. §5.6 is superseded: the external `prompt-anatomy` prerequisite was removed after 0.3.0, and the anatomy now ships inside the `authoring-an-agent` skill (`.github/skills/authoring-an-agent/prompt-anatomy.md`).
**Scope:** `agents-factory` only. No changes to `veglez-skills`.

---

## 1. Problem

`agents-factory` is a documentation-and-prompts repository: 218 tracked files, one 933-line
bash script, zero tests. `CONTRIBUTING.md` lists six consistency invariants and states plainly
that "nothing enforces them automatically — they are review-time checks."

That is not a theoretical gap. The `0.2.0` changelog is a list of defects that review missed:
a case-agent matrix that over-claimed coverage in six cells, skills that silently never
updated, a worked example that contradicted the run it links, and `PORTABILITY.md` pointing at
a directory that does not exist. Two more are live in the tree today:

- `.claude-plugin/marketplace.json` advertises "five skills"; `.claude-plugin/plugin.json`
  advertises "six". Six is correct.
- Both manifests say "the run-delivery and run-status commands". Four commands exist —
  `/run-delivery`, `/run-advisory`, `/run-status`, `/new-agent`.

There is also no release model. The repository has **zero git tags**. `CHANGELOG.md` names
`0.1.0` and `0.2.0`, and `plugin.json` carries `0.2.0`, but nothing ties those three together
and nothing marks which commit is which release. The six skills carry no version at all, so a
consumer who has the plugin installed cannot tell which revision of `conducting-a-gate` they
are running.

Finally, `README.md:173` states that "Agents follow the `prompt-anatomy` component structure"
without saying what `prompt-anatomy` is or where it comes from. It is a published skill in the
sibling repository `veglezMX/veglez-skills`. That is an undeclared cross-repository dependency:
anyone authoring a new agent is told to conform to a convention they cannot locate.

## 2. Goals

1. Make every invariant `CONTRIBUTING.md` currently asks reviewers to check machine-enforced.
2. Give the repository a real versioning and release model, including per-skill versions.
3. Declare the `prompt-anatomy` dependency explicitly.

## 3. Non-goals

- **Adopting APM.** Investigated and rejected; see §4.
- Replacing or restructuring `scripts/install.sh`. It stays the fan-out engine.
- Changing any agent, playbook, process document, template, or the committed run.
- Publishing skills as independently installable packages.

## 4. Rejected: retiring `install.sh` in favour of APM

The sibling repository `veglez-skills` distributes through Microsoft APM (`apm-cli` 0.28.0).
The obvious move is to do the same here and delete the bash script. It does not work.

APM was probed directly against this repository's source tree. Findings:

| Capability `agents-factory` has today | APM 0.28.0 |
|---|---|
| `.github/agents/*.agent.md` discovery | Yes — native; the probe matched all 29 |
| Deploy agents to `.claude/agents/` | Yes (`claude_formatter.py:186,194`) |
| `.github/skills/` discovery | **No** — only `.apm/skills/` or a root `SKILL.md` |
| `hermes` target | **Inconsistent** — accepted by the `--target` flag, rejected in `apm.yml` `targets:` (`Unknown target 'hermes'`) |
| Zoo/Roo `.roomodes` and `custom_modes.yaml` | **No** — no such target exists |
| The four slash commands | **No** — APM has no command primitive |
| Tool-posture mapping (`R`, `R+route`, `E`, `E+T`, `O`) | **No** — bespoke to this repository |

`apm compile` also fails outright on this tree: it discovers the 29 agents as chatmodes, then
reports `No APM content found to compile` because it emits `AGENTS.md` from *instructions*,
and this repository has none. `veglez-skills` documents the same trap.

Adopting APM would therefore cost the Zoo/Roo and Hermes targets, the four commands, and the
posture contract — a regression across three harnesses — in exchange for packaging machinery
this repository does not need, because it ships **one** plugin rather than six. `install.sh`
stays. The parts of `veglez-skills` worth taking are its *disciplines*: derived-tree gating,
version agreement, and a real test suite. Those are portable without the tool that carries
them there.

## 5. Design

### 5.1 Source of truth is unchanged

`.github/{agents,skills,commands}` remains the single source of truth, and `install.sh`
remains the only generator. `CONTRIBUTING.md`'s headline rule survives intact. Nothing moves
to `.apm/`, and no `packages/` tree is introduced.

### 5.2 New files

```
agents-factory/
  pyproject.toml                 # pytest, ruff, pyright; tooling only, never published
  justfile                       # check, test, lint, fmt, release
  tools/
    check_versions.py            # bump-on-change gate, git-diff driven
  tests/
    conftest.py                  # shared parsers: frontmatter, roster table, matrix
    test_roster.py
    test_agents.py
    test_playbooks.py
    test_matrix.py
    test_skills.py
    test_commands.py
    test_derived_sync.py
    test_manifests.py
    test_harness_neutral.py
    test_check_versions.py
  docs/superpowers/specs/        # this document
```

`pyproject.toml` exists for the test and lint toolchain only. Nothing is published to PyPI,
and no Python ships to a consumer. The distributable remains prose.

### 5.3 Versioning model

The repository ships **one** distributable — the `agents-factory` plugin — so there is one
release version, held in `.claude-plugin/plugin.json`. Skills are versioned independently for
visibility, not for independent distribution.

**Skill versions.** Each `.github/skills/<name>/SKILL.md` gains a `version:` frontmatter key,
all starting at `0.1.0`. The frontmatter schema becomes closed at
`{name, description, version, prerequisites}` — matching `veglez-skills`, where `prerequisites`
is optional. `install.sh` copies skill directories with `cp -R`, so the key reaches
`.claude/skills/`, `skills/`, Codex, Hermes, and Copilot verbatim with no change to the script.
The Cursor `.mdc` companion synthesizes its own frontmatter (`description`, `alwaysApply`) and
correctly omits the version, which Cursor has no field for.

**Release version.** `plugin.json.version` is authoritative. It must equal the newest released
section heading in `CHANGELOG.md`, and — when CI runs on a tag — the tag itself.

**Tags.** One lightweight tag per release, `v<version>`. Lightweight, not annotated: the
marketplace entry uses `source: "./"` today and pins nothing, but should this repository ever
pin a SHA, an annotated tag makes the ref a tag object, `HEAD` compares unequal, and Claude
Code refuses the install. `veglez-skills` learned this the expensive way. Plain `git tag`,
never `claude plugin tag`.

### 5.4 Gates

Three commands, all run in CI, each failing independently with a nameable cause.

| Gate | Command | Catches |
|---|---|---|
| Derived trees | `scripts/install.sh --target repo --check` | source edited without regeneration (existing gate, kept as-is) |
| Bump-on-change | `python tools/check_versions.py --base <ref>` | content changed without a version bump or a changelog entry |
| Invariants | `pytest` | everything in §5.5 |

`tools/check_versions.py` enforces two rules against a git base ref:

- **R1 — skill bump.** If any file under `.github/skills/<name>/` changed, that skill's
  `version:` must strictly increase under semver comparison.
- **R2 — changelog.** If any file under `.github/`, `process/`, `templates/`, or `scripts/`
  changed, `CHANGELOG.md` must be modified in the same diff.

Both rules are skipped when no base ref is available, so the script is a CI gate and never
obstructs local work. R2 is deliberately coarse — requiring a plugin version bump on every
pull request would be noise; requiring the author to say what changed is not.

### 5.5 Test suite

Each file below turns one row of `CONTRIBUTING.md`'s invariant table, or one documented
convention, into a named failing test.

| File | Asserts |
|---|---|
| `test_roster.py` | Roster table and `.github/agents/` are a bijection (29 ↔ 29); each roster posture agrees with that agent's `tools:` frontmatter; tool ids appear in the canonical order `read, search, web, edit, execute, agent, todo`; the `agent` tool appears only on agents 01 and 18 |
| `test_agents.py` | Frontmatter schema `{name, description, argument-hint, tools}`; `name` equals the filename stem; exactly 15 `##` sections, or 16 if and only if the posture is `E+T` (the extra being `## Terminal Discipline`); section titles present in the fixed order |
| `test_playbooks.py` | Frontmatter conforms to `process/playbooks/playbook-schema.md`; the seven body sections appear in the fixed order; every id in `agents:` exists in the roster; every name in `skills:` exists under `.github/skills/` |
| `test_matrix.py` | The case × agent matrix has one column per live case and one row per roster agent; a cell marked `x` holds **if and only if** that agent id appears in that playbook's `agents:` list — the exact defect class that reached `0.2.0` |
| `test_skills.py` | Closed frontmatter `{name, description, version, prerequisites}`; `name` equals the directory name; `version` is valid semver; description meets a length floor |
| `test_commands.py` | Four commands exist; each has valid `allowed-tools` frontmatter; each is referenced by `README.md` |
| `test_derived_sync.py` | `scripts/install.sh --target repo --check` exits 0, surfaced as a named test rather than only a CI step |
| `test_manifests.py` | `plugin.json` and `marketplace.json` descriptions agree with each other; every count stated in either description matches reality (skills, agents, commands); `plugin.json.version` equals the newest released `CHANGELOG.md` section; on a tagged CI run, the tag equals `v<version>` |
| `test_harness_neutral.py` | No Claude-specific vocabulary in `process/` or skill prose; no `/home/veglez` absolute paths anywhere in tracked content |
| `test_check_versions.py` | Behavioural tests of `tools/check_versions.py` against synthetic diffs, covering R1 pass/fail, R2 pass/fail, and the no-base skip |

Two defects already known are fixed as part of this work and locked by `test_manifests.py`:
the "five skills" / "six skills" disagreement, and the two-command claim in a four-command
repository.

### 5.6 The `prompt-anatomy` dependency

`prompt-anatomy` is a skill published from `veglezMX/veglez-skills`. Agent definitions in this
repository conform to its component structure. That is declared in three places:

1. **`README.md:173`** — the bare mention becomes a named dependency with its origin and the
   command that installs it.
2. **`README.md`, "Limitations & prerequisites"** — a bullet stating that authoring a *new*
   agent expects `prompt-anatomy`, and that running a delivery run does not. The dependency is
   authoring-time only.
3. **`.github/skills/authoring-an-agent/SKILL.md`** — a `prerequisites:` frontmatter key plus a
   prose link, so the requirement reaches the person actually authoring an agent at the moment
   they need it.

`CONTRIBUTING.md` gains the same pointer in its agent-authoring section.

No dependency is declared in a manifest, because there is no manifest format here that a
consumer's tooling would act on. The dependency is a convention between two repositories owned
by the same author, and prose is the honest way to record it.

### 5.7 CI

`.github/workflows/derived-dirs.yml` is renamed to `ci.yml` and gains steps. It keeps its
triggers (push to `main` and `development`, plus all pull requests) and gains
`fetch-depth: 0`, which `check_versions.py` needs to diff against the base ref.

Steps, in order:

1. `actions/checkout@v4` with `fetch-depth: 0`
2. Install `uv`
3. `just lint` — ruff over `tools` and `tests`
4. `scripts/install.sh --target repo --check`
5. `python tools/check_versions.py --base <base>` — the base is the pull request's base
   SHA on a pull request, and `github.event.before` on a push. When neither resolves to a
   reachable commit the script skips both rules rather than guessing.
6. `uvx pyright`
7. `just test`

The lint and type-check perimeter is `tools/` and `tests/` only, matching `veglez-skills`.
Prose is not linted.

## 6. What does not change

`scripts/install.sh`'s conversion logic and all nine targets; the 29 agent definitions; the 10
playbooks; everything under `process/`; `templates/stakeholder-input-packet.md`; the committed
run at `runs/2026-06-comedor-vecinal/`; and every derived directory's content, except where a
skill gains a `version:` line and the two manifests have their counts corrected.

## 7. Risks

**A test that encodes a convention the repository later outgrows becomes friction.** The
section-count test (15/16) is the sharpest example: it is a real, documented rule today, but a
future agent with a genuinely different shape would fail it. Mitigation: the rule is already
written down in `authoring-an-agent`, so the test enforces an existing decision rather than
inventing one; changing the convention means changing both, which is the correct cost.

**Adding a Python toolchain to a prose repository raises the contribution bar.** Mitigation:
nothing in `tools/` or `tests/` ships to a consumer, no contributor needs Python to edit an
agent or a playbook, and CI runs the suite so a prose-only contributor never has to.

**`check_versions.py` R2 can be satisfied trivially** by touching `CHANGELOG.md` with an empty
line. Accepted. The gate exists to make the omission visible, not to police sincerity.
