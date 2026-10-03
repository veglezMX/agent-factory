# Changelog

All notable changes to this project are recorded here. The version lives in
`.claude-plugin/plugin.json`: **minor** for a change to the roster, the playbook set, or the
skill/command set; **patch** for documentation and installer fixes.

The format follows [Keep a Changelog](https://keepachangelog.com/en/1.1.0/) loosely.
`0.1.0` and `0.2.0` were tagged retroactively on the commits that set those versions in
`plugin.json`; their entries are reconstructed from git history. Every release from `0.3.0`
on is tagged and published as described in [`docs/RELEASING.md`](docs/RELEASING.md).

## [Unreleased]

### Added

- **`scripts/install.sh --target codex`** — installs the roster into OpenAI Codex. Codex has
  no agent format, only a skills runtime, so each agent ships as
  `$CODEX_HOME/skills/<name>/SKILL.md` (default `~/.codex`; `--scope project` writes
  `<dir>/.codex/skills`).
- **`scripts/install.sh --target hermes`** — same shape for Hermes Agent (Nous Research):
  `$HERMES_HOME/skills/<name>/SKILL.md`, with `metadata.hermes.tags` so the agents are
  searchable next to the bundled skills.
- **Tool-posture preamble in generated agent-skills.** Neither Codex nor Hermes grants tools
  per agent, so each generated `SKILL.md` states its posture (`R`, `R+route`, `E`, `E+T`,
  `O`), the rule in plain language, and the session flag that actually enforces it
  (`codex --sandbox read-only`, `hermes --safe-mode`). The posture is derived from the
  source agent's `tools:` line, so it cannot drift from the definition.
- **`routing-a-step` skill** — advances a governed run one step on any platform where the
  Delivery Orchestrator cannot dispatch the other agents (Cursor, Codex, Hermes, older
  Copilot/Roo builds). Reads the run state, checks the gate, picks the next agent from the
  playbook, writes the inbound handoff, and emits the paste-ready invocation per platform.
  Requires a fresh session per step, so the protocol's context budget (§5) survives a
  human-transported run. Skill count is now 6.
- **`scripts/install.sh --check`** — `--dry-run` plus a non-zero exit when anything is stale,
  orphaned, or warned about. `scripts/install.sh --target repo --check` is the CI gate for the
  derived-directory contract, which until now was only enforceable by remembering to run it.
- **Skills on platforms with no skills runtime.** Cursor gets each skill as an `@`-mentionable
  `skill-<name>.mdc` rule, with companion reference files staged under `.cursor/skills/<name>/`;
  the Roo/Zoo and generic `.agents` targets get a generated `SKILLS-INDEX.md` next to the staged
  skills so the model can discover and load them.
- **Tool posture in Cursor rules.** A `.mdc` rule has no tools field, so the posture used to be
  dropped entirely on the one platform with no isolation either. Each generated rule now opens
  with the same `## Tool posture` block as the Codex/Hermes skills.
- **Orphan detection for skill-shaped targets.** Generated agent-skills carry a marker
  comment, so a renamed or deleted agent is reported as an `ORPHAN` even though agent-skills
  and framework skills share one directory. A name collision between a framework skill and
  an agent is reported as a warning instead of silently overwriting.

- **`scripts/install.sh --target roo`** (alias `zoo`) — a native Zoo Code / Roo Code
  install: one `.roomodes` file with a `customModes:` array per project, or the editor's
  global `custom_modes.yaml` (auto-detected in VS Code / VS Code Server globalStorage).
  Landed on `main` after `0.2.0` was cut and was not recorded until now.
- **`/run-advisory`** — a lightweight review path that chains read-only/review agents over an
  existing codebase, carrying each hand-off as a file under `agents-run/`. Also landed after
  `0.2.0` without an entry.
- **`process/advisory-pipeline-usage.md`** and the standalone invocation cheat sheet entry for
  the UI Layout Designer.

- **A test suite that machine-enforces the repository's invariants** (`tests/`, run by
  `pytest`): roster ↔ agent files, posture ↔ `tools:`, the agent section template, playbook
  frontmatter and sections, the case × agent matrix in both directions, closed skill
  frontmatter, commands, manifest counts and versions, CHANGELOG shape, relative links and
  protocol/contract section citations, derived-directory sync, and harness neutrality.
  `CONTRIBUTING.md` used to call these "review-time checks"; review missed them.
- **`tools/check_versions.py`** — the bump-on-change gate. R1: a changed skill must raise its
  `version:`. R2: a change to distributed content must come with a `CHANGELOG.md` entry.
- **Per-skill versions.** Every `SKILL.md` carries `version:` (all start at `0.1.0`), and the
  skill frontmatter is closed at `name`, `description`, `version`, `prerequisites`.
- **`prompt-anatomy` declared as a prerequisite** of `authoring-an-agent` (frontmatter and
  prose): an authoring-time dependency on `veglezMX/veglez-skills` that was previously named
  without saying where it comes from.
- **`ci` workflow** (renamed from `derived dirs`): ruff, shellcheck, the derived-directory
  check, the version gate, pyright, and the test suite, on pushes to `main`/`dev` and on
  every pull request. Python tooling (`pyproject.toml`, `uv.lock`, `justfile`) is dev-only;
  nothing Python ships.

- **Framework docs ship with every install.** Every agent cites `process/…` and
  `templates/…`, but a global or plugin install left them behind, so a fresh project had none
  of the documents its agents were told to follow. Platform targets now install them —
  `~/.agents-factory/` globally (honours `AGENTS_FACTORY_HOME`), `<dir>/.agents-factory/` per
  project — and the new `--target docs` installs only them, for plugin users. The shared
  Invocation paragraph in all 29 agents states the resolution order (project root,
  `<project>/.agents-factory/`, `~/.agents-factory/`), and `/run-delivery`, `/run-advisory`,
  `/run-status`, `routing-a-step`, and `resuming-a-run` stop with an install hint when the docs
  are missing instead of proceeding from memory.
- **`scripts/install.sh --force`** — replace a Zoo/Roo modes file the installer did not
  generate, keeping the previous one as `<file>.bak`.
- **Install manifests.** Each platform install records what it wrote in
  `.agents-factory-manifest`, so orphan detection covers removed agents, skills, and commands
  without ever flagging the user's own files in a shared directory like `~/.claude/agents`.
- **`tests/test_installer.py`** — every target run into temporary directories, outputs parsed
  with PyYAML, plus a regression test per installer defect below.

- **A release process.** `docs/RELEASING.md` defines what a version means for a prompt
  framework (the public interface is its contracts), the `main`/`dev` branch model, the CI
  gates, Keep a Changelog discipline, and a step-by-step runbook. `tools/release.py`
  (`just release-prep`, `release-verify`, `release-notes`) bumps `plugin.json`, rotates the
  CHANGELOG, and proves tag, version, and CHANGELOG agree; `.github/workflows/release.yml`
  re-runs every gate on a `v*` tag and publishes the GitHub Release from the CHANGELOG
  section (`-rc.N` tags become pre-releases). `v0.1.0` and `v0.2.0` are tagged
  retroactively.
- **Contributor guidance for humans and agents.** `CONTRIBUTING.md` is rewritten around the
  workflow (branches, Conventional Commits, pull-request checklist, review) and maps every
  invariant to the test that enforces it. `AGENTS.md` gives AI coding agents the same rules as
  operating instructions (`CLAUDE.md` imports it). New pull-request and issue templates and a
  `SECURITY.md`.

### Fixed

- **Manifest descriptions disagreed.** `marketplace.json` claimed five skills and both
  manifests named two of the four commands. Both now carry one identical description with
  the correct counts.
- **The `authoring-a-playbook` matrix check silently checked nothing.** Its embedded script
  listed nine columns against a ten-column matrix, filtered out every row, and printed
  `mismatches: 0`. The check now lives in the test suite; the skill points at it.
- Stale counts and references: "nine existing cases", "Twenty-eight of the 29", the
  `gate-release.md` filename in `incident`, the "orchestrator adds that section" notes in
  `refactor` and `data-operation` (protocol §3.4 exists), "row" vs "column" in
  `playbook-schema.md`, and non-existent protocol §5.2/§5.3 citations in the Delivery
  Orchestrator.
- `README.md` said Cursor's agent-to-agent invocation was version-dependent; it has none.
  `PORTABILITY.md` described skill support on Copilot and Cursor incorrectly.
- The packet template's traceability appendix named no consumer for agents 03, 08, 09, and
  21–29. Every roster agent now appears.
- **Tool postures contradicted each other.** Five roster entries used postures outside the
  five-token legend (`R (+docs)`, `R, E on request`) while their `tools:` granted `edit`;
  `process/standalone-invocation.md` defined three postures and labelled every `E+T` agent
  `E`. Every roster posture is now one legend token — the one its `tools:` line grants — with
  any narrowing stated as a parenthetical, and `tests/test_roster.py` derives and checks it.
- **The Code Reviewer's routing exception was contradicted.** The roster said 18 may call
  exactly 15 and 08, yet listed it (and the CI/CD Engineer, which has no `agent` tool) as a
  caller of 22 and 27. Those now recommend; the Orchestrator routes.
- `creating-stakeholder-packet` named a Claude-only tool; it now describes the capability.
- **`--target roo` wrote on `--dry-run` and `--check` and could destroy user modes.** The
  `.roomodes`/`custom_modes.yaml` writer bypassed the dry-run path, was not counted, and
  overwrote a hand-written global modes file. It now goes through the same write path as every
  other file and refuses to replace a modes file it did not generate unless `--force` is given.
- **The installer exited silently when an optional frontmatter field was missing** (an agent
  without `argument-hint:` or `name:`), under `set -o pipefail`. Frontmatter parsing is now
  scoped to the frontmatter block and never fails on an absent key.
- **`--check` could pass when it should fail.** Warnings raised inside command substitutions
  were lost, and removed skills and commands were never reported as orphans.
- **Every `---` line in a body was deleted**, including horizontal rules and the frontmatter
  example in `authoring-an-agent` (the shipped Cursor rule had lost its delimiters).
- **Tool lists in other YAML shapes were read as read-only** (single quotes, block sequences);
  an unparseable `tools:` is now a fatal error rather than a silent downgrade.
- **YAML escaping**: backslashes in descriptions, single-quoted and folded (`>-`) descriptions,
  and bodies whose first line is indented all produced invalid or wrong YAML. Block scalars now
  carry explicit indentation indicators.
- **CRLF sources** passed `argument-hint` and VS Code tool ids straight into `.claude/agents`.
- **Orphan false positives**: an agent whose `name:` differs from its filename was reported as
  an orphan on Codex/Hermes forever, and global installs flagged the user's own agents.
- **An exported `CDPATH` broke path resolution**, and `--scope "global project"` passed
  validation and installed to `/`.
- `--check --keep-existing` silently skipped the files it was meant to compare; it is now
  refused. A dry run no longer reports "would update" for a destination the real run refuses.
- **The Code Reviewer got `Task` on Claude Code**, where a subagent cannot start another; its
  routing is now dispatched by the `/run-delivery` main loop, as `PORTABILITY.md` documents.
- `CHANGELOG.md` recorded work under `0.1.0` that landed later, and gave the matrix as 261
  cells (it is 290).

## [0.2.0] — 2026-07-31

The consolidation release: the derived-directory contract is now enforceable with one
command, the documents no longer over-claim, and the distribution is legally installable.

### Added

- **`LICENSE` (MIT).** The repository was published to a plugin marketplace with no
  licence, which made it all-rights-reserved — anyone following the README's install
  instructions had no right to use what they installed.
- **`scripts/install.sh --target repo`** — regenerates every derived directory in this
  repository (plugin components, `.claude/`, `.cursor/rules/`) in one pass. Previously this
  took three separate invocations, and forgetting one caused drift.
- **`scripts/install.sh --dry-run`** — reports what would be created or updated, writes
  nothing. A clean tree reports `0 would change`.
- **`scripts/install.sh --keep-existing`** — opt back in to the old never-overwrite
  behaviour for skills and commands at the destination.
- **`.github/commands/`** as the source of truth for slash commands, so the source-of-truth
  rule now covers agents, skills, *and* commands uniformly.
- **Four skills** — `authoring-an-agent`, `authoring-a-playbook`, `conducting-a-gate`,
  `resuming-a-run`. Procedures that previously existed only as prose an agent had to be
  pointed at.
- **Two commands** — `/run-status <run-id>` (read-only run summary) and `/new-agent <name>`
  (scaffold a conformant agent).
- **`process/playbooks/increment.md`** — the tenth case. Previously a variant section inside
  `greenfield.md`, referenced by the README as a live case at a path that did not exist.
- **`CONTRIBUTING.md`** and this changelog.
- **Orphan reporting** — a derived file with no `.github/` source is now reported rather
  than left to rot silently.
- **`R+route` posture** for the Code Reviewer, and a corrected `O` description for the
  Delivery Orchestrator. The four-posture legend could not express either agent, so any
  conformance check written against it would have flagged both as violations.
- Ordinary ignore rules in `.gitignore`, which previously contained only negations.
- `homepage`, `repository`, and `license` in `.claude-plugin/plugin.json`.

### Fixed

- **Skills and commands never updated.** `install_skills()` and the Claude driver copy both
  skipped any destination that already existed, so editing a skill and re-running the
  installer silently did nothing — contradicting the documented sync workflow. They now
  overwrite by default, like agents always did.
- **The case × agent matrix over-claimed coverage.** Six cells marked agents `27`/`28` as
  conditional for cases whose playbooks never routed to them. Agent `27` is now a real step
  in `brownfield-onboard`, `defect`, and `deprecation`; agent `28` in `brownfield-onboard`
  and `deprecation`; and `28 × spike` is corrected to "not used". All 290 cells (29 agents × 10 cases) now
  reconcile with the playbooks' `agents:` frontmatter.
- **The worked example contradicted the run it links.** `process/examples/comedor-greenfield.md`
  described six services and Stripe; `runs/2026-06-comedor-vecinal/` decides an eight-module
  modular monolith and Mercado Pago. Corrected, and labelled with what in it is a real
  artifact, what is illustration, and which of agents `21`–`29` the run predates.
- **`PORTABILITY.md` pointed at `.github/prompts/`**, which does not exist. Copilot skills
  live in `.github/skills/`.
- **`ui-layout-designer` diverged from the agent template** — missing `## Reasoning
  Instructions` and `## Output Style`, with a bespoke `## Invocation Contract` heading no
  peer used. All 29 agents now carry the identical section set and order.
- **Tool-id parsing failed silently.** A valid unquoted YAML list (`tools: [read, search,
  edit]`) matched nothing and defaulted the agent to read-only with no warning; an unmapped
  id was dropped just as quietly. Both now parse correctly or warn.
- **Argument handling.** `--target` was validated only after the banner printed; a missing
  option value aborted with `shift count out of range`; `--scope global` silently discarded
  `--path`; `--target plugin --path /elsewhere` warned that it had produced a broken plugin
  and exited `0`. All now fail fast with a clear message and a non-zero status.
- **macOS portability.** Replaced the bash-4 associative arrays and the GNU-sed-only
  `title_case`, both of which broke on stock macOS bash 3.2 / BSD sed.
- **`--target copilot --scope project --path .`** would have overwritten the source of
  truth. Paths are now resolved to absolute and the case is refused.
- The frontmatter transform is scoped to the frontmatter block, so a body line beginning
  `tools:` or `argument-hint:` can no longer be mangled.
- Cursor `description:` values are quoted, so a description containing `: ` cannot emit
  invalid YAML.
- Only 10 of 29 agents stated their roster number; all 29 now do, in one uniform form.
- Normalised `tools:` frontmatter to a single canonical id order, so two agents with the
  same capability set produce byte-identical generated tool lines.

### Removed

- `.github/agents/test.agent.md`, an unmodified editor scaffold with no roster entry that
  forced a skip-guard in four installer functions and made "29 agent definitions" describe
  a directory of 30 files.
- A stray `.ruff_cache/` from unrelated Python tooling.

### Retroactive notes

These landed between `0.1.0` and `0.2.0` and were originally recorded under `0.1.0` by
mistake. They are part of `0.2.0`:

- Agent `29`, the standalone-friendly UI Layout Designer (2026-07-14).
- `process/agent-invocation-contract.md` (`pipeline` and `standalone` modes) and the
  standalone invocation cheat sheet `process/standalone-invocation.md` (2026-07-10/14).
- `scripts/install.sh`: global-by-default installation with `--scope project` replacing
  `--dest`, Copilot CLI global install to `~/.copilot`, and the `agents` target
  (Roo custom-mode YAML) (2026-06-16).

## [0.1.0] — 2026-06-14

First packaged release (`2c0dc9b`, tagged retroactively).

### Added

- The 28-agent roster (core `01`–`20`, expansion `21`–`28`), each conforming to the prompt
  anatomy, with `.github/agents/` as the source of truth.
- The process spine: agent roster and handoff protocol.
- Nine case playbooks plus `playbook-schema.md`.
- The Stakeholder Input Packet template and the `creating-stakeholder-packet` skill.
- `scripts/install.sh` with `claude`, `cursor`, `copilot`, and `plugin` targets, writing to a
  `--dest` directory.
- Packaging as a Claude Code marketplace plugin (`.claude-plugin/`).
- `README.md` and `PORTABILITY.md`.
- One worked example and one real run workspace, `runs/2026-06-comedor-vecinal/`, live
  through Phase 0.

[Unreleased]: https://github.com/veglezMX/agent-factory/compare/v0.2.0...HEAD
[0.2.0]: https://github.com/veglezMX/agent-factory/compare/v0.1.0...v0.2.0
[0.1.0]: https://github.com/veglezMX/agent-factory/releases/tag/v0.1.0
