# Agents Factory

A **project-agnostic, multi-agent software-delivery framework**. It takes a plain-language description of a product (a *Stakeholder Input Packet*) and carries it to a deployed full-stack application through a roster of specialized AI agents, coordinated by a strict handoff protocol and per-case playbooks.

It is **not** an app. It is a reusable set of agent definitions, skills, process docs, and templates you copy into your own AI coding environment (Claude Code, GitHub Copilot / VS Code, Cursor, or any agent harness) and run against your own project.

> **Portability.** Copying `.github/agents` and the skills folders is a starting point, not a complete install. The agent *definitions* are portable across harnesses; the directory layout, the `tools:` frontmatter, and the orchestration model are platform-specific and need conversion. **[PORTABILITY.md](PORTABILITY.md)** documents per-platform setup and `scripts/install.sh` performs the conversion. This README explains the model; PORTABILITY explains the setup.

---

## The mental model — four pillars

| Pillar | What it is | Where |
|---|---|---|
| **Packet** | The pipeline source of business truth — a structured, plain-language brief. Standalone calls instead use the direct task and selected local references. | [`templates/stakeholder-input-packet.md`](templates/stakeholder-input-packet.md) + the `creating-stakeholder-packet` skill |
| **Roster** | 29 specialized agents (orchestrator, requirements, UX/UI design, build, hardening, delivery + expansion agents). Each has one job and hard boundaries. | [`process/agent-roster.md`](process/agent-roster.md) |
| **Playbooks** | Per-**case** recipes — which agents run, in what order, with which gates. 10 cases (greenfield, increment, defect, incident, refactor, …). | [`process/playbooks/`](process/playbooks/README.md) |
| **Invocation + handoff contracts** | How agents run independently or in a governed pipeline; payload format, run workspace, gates, escalation, and context budget. | [`process/agent-invocation-contract.md`](process/agent-invocation-contract.md) + [`process/agent-handoff-protocol.md`](process/agent-handoff-protocol.md) |

A run is driven by the **Delivery Orchestrator** (agent 01): it picks the next agent per the playbook, carries context via append-only handoff files, halts at human **gates**, and records everything under `runs/<run-id>/` so any agent can be invoked cold and reconstruct state from disk alone.

---

## Repository layout

```text
.github/agents/      29 agent definitions — Copilot/VS Code `.agent.md` format. SOURCE OF TRUTH.
.github/skills/      5 skills (SKILL.md folders).                              SOURCE OF TRUTH.
.github/commands/    run-delivery + run-advisory + run-status + new-agent.     SOURCE OF TRUTH.
.claude/             Claude Code agents/skills/commands — GENERATED from .github
.cursor/rules/       Cursor reference rules — GENERATED from .github
.claude-plugin/      plugin.json + marketplace.json — the Claude Code marketplace plugin
agents/ skills/ commands/   plugin component dirs (Claude Code format) — GENERATED from .github
process/             the spine: roster, invocation contract, handoff protocol, playbooks/
templates/           the Stakeholder Input Packet template
runs/                per-run workspaces — the live state store (packet, requirements, gates, handoffs)
scripts/             install.sh — install/convert the roster for your platform
PORTABILITY.md       per-platform setup, directory map, tool-posture mapping
CONTRIBUTING.md      the source-of-truth rule and how to add an agent, skill, playbook, or case
```

**`.github/` is the source of truth** — agents, skills, and commands. Every other directory above marked GENERATED is derived from it. After editing anything under `.github/`, regenerate them all with one command:

```bash
scripts/install.sh --target repo          # add --dry-run to preview
```

Don't hand-edit a generated file; the next regeneration overwrites it.

---

## Quick start

### 1. Install for your platform

Installs **globally by default** (user-level config: `~/.claude`, `~/.cursor`) so the roster is available in every project. Use `--scope project --path <dir>` to install into a single project instead.

```bash
# Claude Code — global install -> ~/.claude/agents + ~/.claude/skills + ~/.claude/commands
scripts/install.sh --target claude

# …or scope it to one project -> <dir>/.claude/
scripts/install.sh --target claude --scope project --path /path/to/your/project

# Cursor — global install -> ~/.cursor/rules  (add --scope project --path <dir> for one project)
scripts/install.sh --target cursor

# GitHub Copilot CLI — copies native agents + skills -> ~/.copilot/ (no conversion)
scripts/install.sh --target copilot   # add --scope project --path <dir> for a repo's .github/

# Zoo Code / Roo Code — native single .roomodes (customModes: array). 'roo' and 'zoo' are aliases.
scripts/install.sh --target roo --scope project --path /path/to/your/project   # -> <dir>/.roomodes (recommended)
scripts/install.sh --target roo   # global -> custom_modes.yaml in the editor's globalStorage (Zoo/Roo, auto-detected)

# Generic ".agents" harness — one custom-mode YAML per agent -> ~/.agents/
scripts/install.sh --target agents    # add --scope project --path <dir> for one project

# Claude Code marketplace plugin — regenerates this repo's root agents/ skills/ commands/
scripts/install.sh --target plugin

# …or regenerate EVERY derived dir in this repo at once (plugin + .claude/ + .cursor/)
scripts/install.sh --target repo
```

A global install needs nothing copied — every project picks up `~/.claude` (or `~/.cursor`) automatically. For a **project-scoped** install, also copy `process/` and `templates/` into that project. See [PORTABILITY.md](PORTABILITY.md) for exactly which folders each platform needs.

### 2. Create the packet

Use the `creating-stakeholder-packet` skill (it interviews you), or copy [`templates/stakeholder-input-packet.md`](templates/stakeholder-input-packet.md) and fill it. Resolve every `OPEN` item. Freeze it under `runs/<run-id>/00-packet/`.

### 3. Start a run

- **Claude Code:** `/run-delivery <run-id>` — the main session becomes the Delivery Orchestrator and drives the roster.
- **Copilot / VS Code:** invoke the `delivery-orchestrator` agent and point it at the packet.
- **Cursor / generic:** drive the orchestrator in your main chat; see PORTABILITY for the invocation caveat.

The run pauses at each **human gate** (scope, design, release, …) until you sign the gate record — an intentional checkpoint where a human reviews and approves before work continues.

### Or: a review without a build — `/run-advisory`

To analyze or review an existing codebase instead of building, run the lightweight advisory path — a chain of read-only/review agents, hand-offs recorded as files under `agents-run/`, no `runs/` workspace:

```text
/run-advisory "auth review" architecture-guardian, security-engineer, code-reviewer
```

Omit the agent list to let the orchestrator pick the chain. For one specialist with no hand-off, just invoke that agent directly (it writes nothing). Full guide: [advisory-pipeline-usage.md](process/advisory-pipeline-usage.md).

### Or run one agent independently

Invoke any specialist directly with `mode: standalone`, a bounded `task`, and a concrete `target`. Standalone calls do not require a run ID, packet, prior handoff, gate, or Orchestrator. For example, call `ui-layout-designer` with a page plus selected endpoint/client methods to design, review, or explicitly apply a layout improvement. See [`process/standalone-invocation.md`](process/standalone-invocation.md).

---

## Use as a Claude Code plugin (CLI & web)

The roster also ships as a **Claude Code marketplace plugin** — the repo is both the plugin and a single-plugin marketplace (`.claude-plugin/plugin.json` + `marketplace.json`). Regenerate the bundled component dirs after editing any agent with `scripts/install.sh --target repo`.

**CLI** — add the marketplace, then install:

```bash
# from a local clone…
/plugin marketplace add /path/to/agent-factory
# …or straight from GitHub
/plugin marketplace add veglezMX/agent-factory
/plugin install agents-factory@agents-factory
```

**Web (claude.ai/code)** — there is no `/plugin` UI; plugins load only from committed settings, the marketplace repo must be **public**, and web clones `main`. In each project you want the roster in, commit `.claude/settings.json`:

```json
{
  "extraKnownMarketplaces": {
    "agents-factory": { "source": { "source": "github", "repo": "veglezMX/agent-factory" } }
  },
  "enabledPlugins": { "agents-factory@agents-factory": true }
}
```

Name map: the GitHub repo is `agent-factory` (the `repo` field); the marketplace and plugin are both named `agents-factory` (the `<plugin>@<marketplace>` key).

---

## What's covered

- **29 agents** — see the [roster](process/agent-roster.md). Core 01–20 + expansion 21–29, including the standalone-friendly UI Layout Designer.
- **10 cases** — see the [playbook index](process/playbooks/README.md): `greenfield`, `increment`, `brownfield-onboard`, `defect`, `incident`, `refactor`, `dependency-upgrade`, `spike`, `deprecation`, `data-operation`.
- **5 skills** — `creating-stakeholder-packet` (author the packet by interview), `authoring-an-agent` and `authoring-a-playbook` (extend the framework without drifting from its conventions), `conducting-a-gate` (assemble evidence and write the gate record), `resuming-a-run` (reconstruct a run's state from disk alone).
- **4 commands** — `/run-delivery <run-id>` drives a governed run, `/run-advisory` chains read-only/review agents over an existing codebase, `/run-status <run-id>` reports where a run stands read-only, `/new-agent <slug>` scaffolds a conformant agent.
- **Two ways to run** — a full **delivery run** (`/run-delivery`, builds & ships, state under `runs/`) and a lightweight **advisory review** (`/run-advisory`, read-only/review agents chained over an existing codebase, hand-offs as files under `agents-run/`). See [advisory-pipeline-usage.md](process/advisory-pipeline-usage.md) for when to use which.

---

## Limitations & prerequisites

- **Orchestration model.** The framework assumes the orchestrator can invoke the other agents. On Claude Code, subagents cannot spawn subagents — so the orchestrator must run as the **main loop** (the `/run-delivery` driver does this). On Copilot/Cursor, agent-to-agent invocation is version-dependent; see PORTABILITY.
- **`tools:` frontmatter is platform-specific.** The R / E / E+T / O **posture** is the portable contract; the literal tool names differ per platform. The converter rewrites them for Claude Code.
- **Gates need a human.** Runs halt for sign-off by design; a stalled-looking run waiting at a gate is the framework working as intended, not a failure to recover from.
- **`runs/` is the state store.** Keep it in the repo (or a sibling repo for pre-repo phases). Statelessness depends on it.
- **This repo ships one real run workspace.** `runs/2026-06-comedor-vecinal/` is committed on purpose, as reference material for what a live run looks like on disk — it is the artifact the worked example links. It is also the largest non-agent payload here and it downloads with the plugin. Delete the directory if you install the roster into a project and want it gone; nothing depends on it at runtime. Note that it was executed against the 20-agent roster and does not conform to today's `greenfield` playbook — see the callout in [`process/examples/comedor-greenfield.md`](process/examples/comedor-greenfield.md).
- **No language/stack is assumed.** Agents adapt to your stack via the packet and design; nothing here is tied to a framework.

---

## Extending it

Adding an agent or a case is a drop-in — see the conformance rules in [`process/agent-roster.md`](process/agent-roster.md), [`process/agent-invocation-contract.md`](process/agent-invocation-contract.md), [`process/playbooks/playbook-schema.md`](process/playbooks/playbook-schema.md), and the handoff [conformance checklist](process/agent-handoff-protocol.md). Agents follow the `prompt-anatomy` component structure; mirror an existing sibling of the same tool posture.
