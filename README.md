# Agents Factory

A **project-agnostic, multi-agent software-delivery framework**. It takes a plain-language description of a product (a *Stakeholder Input Packet*) and carries it to a deployed full-stack application through a roster of specialized AI agents, coordinated by a strict handoff protocol and per-case playbooks.

It is **not** an app. It is a reusable set of agent definitions, skills, process docs, and templates you copy into your own AI coding environment (Claude Code, GitHub Copilot / VS Code, Cursor, or any agent harness) and run against your own project.

> **Portability.** Copying `.github/agents` and the skills folders is a starting point, not a complete install. The agent *definitions* are portable across harnesses; the directory layout, the `tools:` frontmatter, and the orchestration model are platform-specific and need conversion. **[PORTABILITY.md](PORTABILITY.md)** documents per-platform setup and `scripts/install.sh` performs the conversion. This README explains the model; PORTABILITY explains the setup.

---

## The mental model — four pillars

| Pillar | What it is | Where |
|---|---|---|
| **Packet** | The single source of business truth — a structured, plain-language brief. Everything traces back to it. | [`templates/stakeholder-input-packet.md`](templates/stakeholder-input-packet.md) + the `creating-stakeholder-packet` skill |
| **Roster** | 26 specialized agents (orchestrator, requirements, design, build, hardening, delivery + expansion agents). Each has one job and hard boundaries. | [`process/agent-roster.md`](process/agent-roster.md) |
| **Playbooks** | Per-**case** recipes — which agents run, in what order, with which gates. 9 cases (greenfield, defect, incident, refactor, …). | [`process/playbooks/`](process/playbooks/README.md) |
| **Handoff protocol** | How work moves between agents: payload format, run workspace, gates, escalation, context budget. | [`process/agent-handoff-protocol.md`](process/agent-handoff-protocol.md) |

A run is driven by the **Delivery Orchestrator** (agent 01): it picks the next agent per the playbook, carries context via append-only handoff files, halts at human **gates**, and records everything under `runs/<run-id>/` so any agent can be invoked cold and reconstruct state from disk alone.

---

## Repository layout

```text
.github/agents/      28 agent definitions — Copilot/VS Code `.agent.md` format. SOURCE OF TRUTH.
.github/skills/      skills in Copilot/manual form
.claude/skills/      the same skills, Claude Code layout
.claude/agents/      Claude Code agents — GENERATED from .github/agents by scripts/install.sh
.claude/commands/    run-delivery — the orchestrator driver for Claude Code
process/             the spine: agent-roster.md, agent-handoff-protocol.md, playbooks/
templates/           the Stakeholder Input Packet template
runs/                per-run workspaces — the live state store (packet, requirements, gates, handoffs)
scripts/             install.sh — install/convert the roster for your platform
PORTABILITY.md       per-platform setup, directory map, tool-posture mapping
```

`.github/agents/` is the **source of truth**. Other platforms' agent folders are derived from it — regenerate them with `scripts/install.sh`, don't hand-edit, or they drift.

---

## Quick start

### 1. Install for your platform

```bash
# Claude Code — generates .claude/agents/ (tools frontmatter rewritten) + ensures .claude/skills/
scripts/install.sh --target claude

# Cursor — generates .cursor/rules/ reference rules
scripts/install.sh --target cursor

# GitHub Copilot / VS Code — agents are already native in .github/agents/ (no conversion)
scripts/install.sh --target copilot   # prints guidance only
```

Copy the relevant folders (`.claude/`, `.github/`, or `.cursor/`) plus `process/` and `templates/` into your project. See [PORTABILITY.md](PORTABILITY.md) for exactly which folders each platform needs.

### 2. Create the packet

Use the `creating-stakeholder-packet` skill (it interviews you), or copy [`templates/stakeholder-input-packet.md`](templates/stakeholder-input-packet.md) and fill it. Resolve every `OPEN` item. Freeze it under `runs/<run-id>/00-packet/`.

### 3. Start a run

- **Claude Code:** `/run-delivery <run-id>` — the main session becomes the Delivery Orchestrator and drives the roster.
- **Copilot / VS Code:** invoke the `delivery-orchestrator` agent and point it at the packet.
- **Cursor / generic:** drive the orchestrator in your main chat; see PORTABILITY for the invocation caveat.

The run pauses at each **human gate** (scope, design, release, …) until you sign the gate record — an intentional checkpoint where a human reviews and approves before work continues.

---

## What's covered

- **28 agents** — see the [roster](process/agent-roster.md). Core 01–20 + expansion 21–28 (infrastructure, performance, visual/design-system, AI/prompt, privacy/compliance, accessibility, product-analytics).
- **9 cases** — see the [playbook index](process/playbooks/README.md): `greenfield` (+`increment`), `brownfield-onboard`, `defect`, `incident`, `refactor`, `dependency-upgrade`, `spike`, `deprecation`, `data-operation`.

---

## Limitations & prerequisites

- **Orchestration model.** The framework assumes the orchestrator can invoke the other agents. On Claude Code, subagents cannot spawn subagents — so the orchestrator must run as the **main loop** (the `/run-delivery` driver does this). On Copilot/Cursor, agent-to-agent invocation is version-dependent; see PORTABILITY.
- **`tools:` frontmatter is platform-specific.** The R / E / E+T / O **posture** is the portable contract; the literal tool names differ per platform. The converter rewrites them for Claude Code.
- **Gates need a human.** Runs halt for sign-off by design; a stalled-looking run waiting at a gate is the framework working as intended, not a failure to recover from.
- **`runs/` is the state store.** Keep it in the repo (or a sibling repo for pre-repo phases). Statelessness depends on it.
- **No language/stack is assumed.** Agents adapt to your stack via the packet and design; nothing here is tied to a framework.

---

## Extending it

Adding an agent or a case is a drop-in — see the conformance rules in [`process/agent-roster.md`](process/agent-roster.md), [`process/playbooks/playbook-schema.md`](process/playbooks/playbook-schema.md), and the handoff [conformance checklist](process/agent-handoff-protocol.md). Agents follow the `prompt-anatomy` component structure; mirror an existing sibling of the same tool posture.
