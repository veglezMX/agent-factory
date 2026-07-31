# Changelog

All notable changes to this project are recorded here. The version lives in
`.claude-plugin/plugin.json`: **minor** for a change to the roster, the playbook set, or the
skill/command set; **patch** for documentation and installer fixes.

The format follows [Keep a Changelog](https://keepachangelog.com/en/1.1.0/) loosely.
Versions before `0.2.0` were not tagged; their entries are reconstructed from git history.

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
  and `deprecation`; and `28 × spike` is corrected to "not used". All 261 cells now
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

## [0.1.0] — 2026-06-14

First packaged release.

### Added

- The 29-agent roster (core `01`–`20`, expansion `21`–`29`), each conforming to the prompt
  anatomy, with `.github/agents/` as the source of truth.
- The process spine: agent roster, handoff protocol, invocation contract (`pipeline` and
  `standalone` modes), and the standalone invocation cheat sheet.
- Nine case playbooks plus `playbook-schema.md`.
- The Stakeholder Input Packet template and the `creating-stakeholder-packet` skill.
- `scripts/install.sh` with `claude`, `cursor`, `copilot`, `agents` (Roo custom-mode), and
  `plugin` targets; global-by-default installation with `--scope project`.
- Packaging as a Claude Code marketplace plugin (`.claude-plugin/`).
- `README.md` and `PORTABILITY.md`.
- One worked example and one real run workspace, `runs/2026-06-comedor-vecinal/`, live
  through Phase 0.
