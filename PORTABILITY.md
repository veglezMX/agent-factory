# Portability & Setup

This framework is authored once and run on several AI coding platforms. This document is the honest answer to *"if I copy `.github/agents` and the skills, does it just work?"* — and what to do for each platform.

## What is portable vs platform-specific

| Layer | Portable? | Notes |
|---|---|---|
| **Process spine** (`process/`, `templates/`) | ✅ Fully | Plain Markdown the agents read. Copy verbatim. |
| **Skills** (`SKILL.md` + references) | ⚠️ Format portable | The `name` + `description` frontmatter is the Anthropic skill format (native on Claude Code). Copilot/Cursor need it as a prompt or manual invoke. |
| **Agent definitions** (bodies) | ✅ The prose is | Role, boundaries, output contract, etc. are platform-neutral. |
| **Agent `tools:` frontmatter** | ❌ Platform-specific | `["read","search","edit","execute"]` are VS Code tool ids. Claude Code uses `Read, Grep, Glob, Edit, Bash`. The **posture** (R/E/E+T/O) is the contract; the literal list is not. |
| **Agent directory + filename** | ❌ Platform-specific | `.github/agents/*.agent.md` (Copilot) vs `.claude/agents/*.md` (Claude) vs `.cursor/rules/*.mdc` (Cursor). |
| **Orchestration** (01 invoking others) | ⚠️ Platform-specific, but never blocking | Depends on whether your harness lets one agent call another, or only the main loop dispatches. Where it does neither, the `routing-a-step` skill makes *you* the transport — the run state was always on disk, so nothing is lost but automation. |

**Bottom line:** the *thinking* is fully portable; the *wiring* is not. `scripts/install.sh` handles the wiring for Claude Code, Cursor, Zoo Code / Roo Code (native `.roomodes`), OpenAI Codex, Hermes Agent, and the generic `.agents` format; Copilot is already native.

---

## Directory mapping

| Artifact | Claude Code | GitHub Copilot / VS Code | Cursor | Zoo Code / Roo Code (native) | Generic `.agents` |
|---|---|---|---|---|---|
| Agents | `.claude/agents/*.md` *(generated)* | `.github/agents/*.agent.md` *(source of truth)* | `.cursor/rules/*.mdc` *(reference)* | `.roomodes` or global `custom_modes.yaml` *(generated, single `customModes:` file)* | `.agents/*.yaml` *(generated, one file per agent)* |
| Skills | `.claude/skills/<name>/SKILL.md` *(generated)* | `.github/skills/<name>/SKILL.md` *(source of truth)* | `.cursor/rules/skill-<name>.mdc` *(generated, `@`-mentionable)* + `.cursor/skills/<name>/` for companion files | `.roo/skills/<name>/SKILL.md` + `SKILLS-INDEX.md` *(manual invoke)* | `.agents/skills/<name>/SKILL.md` + `SKILLS-INDEX.md` |
| Commands | `.claude/commands/*.md` *(generated)* | `.github/commands/*.md` *(source of truth)* | n/a | n/a | n/a |
| Orchestrator start | `/run-delivery <run-id>` (main loop) | invoke `delivery-orchestrator` agent | drive in main chat | switch to the `delivery-orchestrator` mode | switch to the `delivery-orchestrator` mode |
| Pipeline run state | `runs/<run-id>/` | `runs/<run-id>/` | `runs/<run-id>/` | `runs/<run-id>/` | `runs/<run-id>/` |
| Process docs | `process/`, `templates/` | same | same | same | same |

**Skill-shaped platforms** — OpenAI Codex and Hermes Agent have no per-agent definition format at all, only a skills runtime. Each agent therefore ships *as a skill*:

| Artifact | OpenAI Codex | Hermes Agent (Nous) |
|---|---|---|
| Agents | `$CODEX_HOME/skills/<name>/SKILL.md` *(generated; default `~/.codex`)* | `$HERMES_HOME/skills/<name>/SKILL.md` *(generated; default `~/.hermes`)* |
| Skills | same directory, alongside the agent skills | same directory, alongside the agent skills |
| Commands | n/a | n/a |
| Orchestrator start | load the `delivery-orchestrator` skill in the main session | load the `delivery-orchestrator` skill in the main session |
| Tool posture | not enforceable per agent — carried as prose + a session sandbox flag | not enforceable per agent — carried as prose + a session flag |

---

## Tool-posture → platform tool mapping

The roster assigns each agent a **posture**, not a fixed tool list. Translate the posture to your platform:

| Posture | Meaning | VS Code / Copilot ids | Claude Code tools | Roo Code groups | Codex / Hermes (session-level) |
|---|---|---|---|---|---|
| `R` | read-only | `read`, `search` | `Read, Grep, Glob` | `read` | `codex --sandbox read-only` / `hermes --safe-mode` |
| `R+route` | read-only + routing-only `agent` | `read`, `search`, `agent` | `Read, Grep, Glob, Task` | `read` | same as `R` |
| `E` | edit | `read`, `search`, `edit` | `Read, Grep, Glob, Edit, Write` | `read, edit` | `--sandbox workspace-write`; no-terminal is prose-only |
| `E+T` | edit + terminal | `read`, `search`, `edit`, `execute`, `todo` | `Read, Grep, Glob, Edit, Write, Bash, TodoWrite` | `read, edit, command` | `--sandbox workspace-write --ask-for-approval on-request` |
| `O` | orchestration | `read`, `search`, `agent`, `todo` | `Read, Grep, Glob, Task, TodoWrite` — **must run as the main loop on Claude Code** | `read` (Roo switches modes natively) | main session only |

On Codex and Hermes the posture is **not enforced per agent** — both grant tools per session. The converter therefore writes a `## Tool posture` block into each generated `SKILL.md` naming the posture, the rule in plain language, and the session flag that does enforce it. Degradation is honest: `R` becomes enforceable via the sandbox flag, while "edit but never run commands" (`E`) survives only as an instruction.

`R+route` and `O` each describe exactly one agent — the Code Reviewer (18) and the Delivery Orchestrator (01). They are separate postures because both carry the `agent` tool for different reasons and with different limits; see the legend in `process/agent-roster.md`. Tool ids within a definition are written in the canonical order `read`, `search`, `web`, `edit`, `execute`, `agent`, `todo`, and the converters preserve that order in their output.

The converter applies this id→name map automatically:

```
Claude Code:  read → Read   |   search → Grep, Glob   |   edit → Edit, Write
              execute → Bash   |   todo → TodoWrite   |   agent → Task   |   web/fetch → WebFetch, WebSearch
Roo Code:     read/search → read   |   edit → edit   |   execute → command   |   web/fetch → browser
              todo, agent, vscode → (no group; Roo's groups are coarse — read, edit, browser, command, mcp)
```

---

## Per-platform setup

### Claude Code

1. Run `scripts/install.sh --target claude`. By default it installs **globally** to `~/.claude` (available in every project); add `--scope project --path <dir>` to install into one project's `.claude/` instead. It:
   - reads every `.github/agents/*.agent.md`,
   - writes `agents/<name>.md` with the `tools:` line rewritten to Claude tool names and `argument-hint` dropped,
   - syncs the skills from `.github/skills/` into `skills/`,
   - syncs the commands from `.github/commands/` into `commands/`.
2. For a **global** install nothing needs copying. For a **project** install, also copy `process/`, `templates/`, and (when you start) `runs/` into that project.
3. Start a run with **`/run-delivery <run-id>`**. This is the key step: it makes your **main Claude session act as the Delivery Orchestrator**, because a Claude subagent cannot invoke other subagents — only the main loop can `Task`-dispatch the roster.
4. Direct human use of any single agent works via the picker / `Task` with `mode: standalone`, a bounded task, and a target; no run ID or handoff is required.

### GitHub Copilot / VS Code

1. Run `scripts/install.sh --target copilot`. The agents are **already in the native `*.agent.md` format**, so it copies (no conversion) the agents and skills into the Copilot CLI personal dir `~/.copilot/{agents,skills}` by default (override the location with the `COPILOT_HOME` env var). Add `--scope project --path <dir>` to install into a repo's project-level `.github/{agents,skills}` instead.
2. Skills install as their `SKILL.md` folders (`~/.copilot/skills/` globally, `.github/skills/` per project). Run `/skills list` in the CLI to confirm they're picked up. If your Copilot build has no skills runtime, open `creating-stakeholder-packet/SKILL.md` and follow it manually before the first run.
3. **VS Code note:** the global dir above is the **Copilot CLI** convention. VS Code reads a repo's `.github/` (use `--scope project`) or its own profile dir; if you need a custom user-level folder there, point `chat.agentFilesLocations` / `chat.agentSkillsLocations` at it with an **absolute** path (VS Code does not expand `~`).
4. Start a run by invoking the **`delivery-orchestrator`** agent and pasting/pointing at the packet.
5. **Caveat:** whether `delivery-orchestrator` can invoke the other agents depends on your Copilot version's agent-to-agent support. If it can't, drive the sequence yourself: invoke each agent in playbook order, pasting the prior handoff as input.
6. For standalone work, invoke the desired specialist directly with `mode: standalone`, a bounded task, and a target. No Orchestrator or handoff is involved.

### Cursor

1. Run `scripts/install.sh --target cursor`. By default it installs **globally** to `~/.cursor/rules`; add `--scope project --path <dir>` for one project's `.cursor/rules/`. It writes `<name>.mdc` — each agent body as a reference rule with `alwaysApply: false`, so you can `@`-mention the one you need.
2. **Skills install as rules too.** Cursor has no skills runtime, but a skill is just Markdown: each one becomes `skill-<name>.mdc`, `@`-mentionable like an agent (`@skill-conducting-a-gate`). Companion reference files stay on disk under `.cursor/skills/<name>/`, and the rule links to them.
3. **Posture is stated, not enforced.** A Cursor rule has no tools field, so each generated rule opens with a `## Tool posture` block naming the posture and what it forbids. Read-only agents stay read-only only if you review their proposed edits instead of applying them.
4. Cursor has no native multi-agent orchestrator. Drive the run in the main chat with `@skill-routing-a-step` as the router: it reads the run state, names the next agent, writes the inbound handoff, and gives you the envelope to paste. One fresh chat per step — a reused chat leaks the previous agent's reasoning past the handoff boundary.
5. For standalone work, `@`-mention only the desired specialist rule and provide `mode: standalone`, a bounded task, and a target; do not create a run workspace or handoff.

### OpenAI Codex

Codex has **no agent format** — no per-agent file, no per-agent tool grants — but it does auto-discover skills at `$CODEX_HOME/skills/<name>/SKILL.md` (default `~/.codex/skills`; project-level `.codex/skills`). The roster ships through that runtime.

1. Run `scripts/install.sh --target codex`. It installs **globally** to `$CODEX_HOME` (default `~/.codex`); add `--scope project --path <dir>` for `<dir>/.codex/skills`. Each agent becomes `skills/<name>/SKILL.md` — frontmatter `name` + `description`, then a generated preamble (tool posture, invocation modes, expected inputs), then the agent body verbatim. The framework skills land in the same directory.
2. Use one agent by naming it: *"use the `ux-flow-designer` skill to inventory the checkout screens"*. That is standalone mode — no run id, no packet, no handoff.
3. **Posture is prose here.** Match it at the session level: `codex --sandbox read-only` for the read-only agents (Architecture Guardian, Infrastructure Guardian, Bundle Intake Validator, Product Planner, Code Reviewer), `--sandbox workspace-write --ask-for-approval on-request` for the builders.
4. **No agent-to-agent dispatch.** For a governed run, use the `routing-a-step` skill: it reads the run state, picks the next agent from the playbook, writes the inbound handoff, and gives you the invocation to paste. Run state stays in `runs/<run-id>/`, which is what makes the sequence resumable across sessions. Use a fresh session per step.
5. Repo-level rules still come from `AGENTS.md`; keep the agent instructions in the skills, not in `AGENTS.md`, or every session inherits all 29 of them.

### Hermes Agent (Nous Research)

Same shape as Codex: no file-based roster, but a native skills runtime at `$HERMES_HOME/skills/<name>/SKILL.md` (default `~/.hermes/skills`).

1. Run `scripts/install.sh --target hermes` (global, honours `HERMES_HOME`), or `--scope project --path <dir>` for `<dir>/.hermes/skills` — for the project layout, launch with `HERMES_HOME=<dir>/.hermes`. Generated frontmatter carries `name`, `description`, and `metadata.hermes.tags` so the agents are searchable next to the bundled skills. Confirm with `hermes skills list`.
2. Use one agent by naming its skill. Standalone mode applies exactly as elsewhere.
3. **Posture is prose here too** — `hermes --safe-mode` for read-only work; otherwise the ownership boundary in the body is the only limit.
4. **Subagents exist but are prompt-spawned, not roster-loaded.** Hermes can delegate: the orchestrator names the agent skill inside the subagent's prompt (*"load the `security-engineer` skill and audit …"*), which gets you real parallel fan-out without an agent-to-agent registry. Handoffs still land in `runs/<run-id>/handoffs/`. Where you drive the sequence by hand instead, use the `routing-a-step` skill.
5. `SOUL.md` is a single global persona, not a roster slot — the installer never touches it. To dedicate a whole profile to one agent, use `hermes profile create <name>` and paste that agent's body into the profile's `SOUL.md` by hand.

### Zoo Code / Roo Code (native `.roomodes`)

> **Note on names.** Roo Code was archived in 2026; its active community successor is **Zoo Code** (`ZooCodeOrganization.zoo-code`). Zoo Code keeps the same format and filenames — `.roomodes`, `custom_modes.yaml`, the `customModes:` array — so this one target covers both. `--target roo` and `--target zoo` are aliases.

These extensions natively read a **single `.roomodes`** file at the workspace root with a top-level `customModes:` array. This target emits exactly that file — no manual merge step.

1. Run `scripts/install.sh --target roo --scope project --path <dir>`. It writes `<dir>/.roomodes` with one `customModes:` entry per agent, each a custom-mode object: `slug`, `name`, `roleDefinition` (the agent's `You are …` persona), `whenToUse` (the agent's description), `groups` (the posture mapped to the `read`/`edit`/`command`/`browser` groups), and `customInstructions` (the full agent body verbatim). Skills install as their `SKILL.md` folders under `<dir>/.roo/skills/` — there is no native skills runtime, so invoke them manually (open `creating-stakeholder-packet/SKILL.md` and follow it before the first run).
2. **Global vs project:**
   - **Project** (`--scope project --path <dir>`) writes `<dir>/.roomodes` at the workspace root — read natively.
   - **Global** (`--scope global`, the default) writes the real global modes file, `custom_modes.yaml`, inside the editor's VS Code globalStorage for the extension (`…/globalStorage/zoocodeorganization.zoo-code/settings/`, or legacy `…/rooveterinaryinc.roo-cline/settings/`) — **not** `~/.roomodes`. The script auto-detects that dir across both extension ids and both install layouts: **desktop** editors (VS Code, Insiders, VSCodium, Cursor, Windsurf) and **remote/server** ones (`~/.vscode-server/data/User/...` over SSH, WSL, devcontainers, Codespaces, or code-server). It writes to every editor that has the extension installed. If none is found it fails with the candidate paths; open Zoo Code once so the dir exists, set `ROO_SETTINGS_DIR=<that settings dir>` to point at it explicitly, or fall back to a project install. Reload the editor window after installing.
3. Start a run by switching to the **`delivery-orchestrator`** mode (slug `delivery-orchestrator`) and pointing it at the packet. The same agent-to-agent caveat as Copilot applies: if your harness can't let one mode invoke another, drive the sequence yourself in playbook order, writing handoff files under `runs/<run-id>/`.

### Generic `.agents` harness

Some harnesses load a **directory of per-agent files** rather than one platform config. This target emits the roster in the same custom-mode format — but **one YAML file per agent** — which those loaders consume as-is.

1. Run `scripts/install.sh --target agents`. By default it installs **globally** to `~/.agents`; add `--scope project --path <dir>` for one project's `.agents/`. It writes `<name>.yaml` for each agent with the same fields as the Roo target above. Skills install as their `SKILL.md` folders under `.agents/skills/`.
2. If your target is Roo Code itself, prefer `--target roo` (above) — it produces the native single-file `.roomodes` directly and skips the manual merge.
3. Start a run as with the Roo target: switch to the **`delivery-orchestrator`** mode and point it at the packet; the agent-to-agent caveat applies the same way.

### Generic / any agent harness

The framework is a **specification**, not a binding. To port it:
- Map each agent's **posture** to your harness's tool permissions (table above).
- Place agent bodies wherever your harness loads system prompts / personas.
- Satisfy the orchestration requirement three ways, in descending order of automation: your harness lets one agent invoke another (wire 01 to call the rest); your main control loop plays the orchestrator and dispatches the rest; or **a human transports the payload** using the `routing-a-step` skill. The last one costs nothing in fidelity — handoffs are files, and every agent is required to work from a cold context.
- Implement both modes from `process/agent-invocation-contract.md`: direct standalone calls return to the human, while pipeline calls use the Orchestrator.
- For pipeline mode, use `runs/<run-id>/` as the on-disk state store and the handoff payload format from protocol §2. Standalone mode needs neither unless explicitly requested.

---

## The run process (entry point)

Regardless of platform, a governed pipeline run is:

1. **Packet** — author/freeze the Stakeholder Input Packet under `runs/<run-id>/00-packet/` (skill: `creating-stakeholder-packet`).
2. **Boot** — invoke the orchestrator; it creates the run workspace (protocol §1) and routes the packet to the Requirements Analyst.
3. **Phases** — the playbook for your case (default `greenfield`) sequences the agents; each emits an append-only handoff file under `runs/<run-id>/handoffs/`.
4. **Gates** — the run halts at human gates; you sign the record under `runs/<run-id>/gates/`.
5. **Closure** — at the terminal gate the orchestrator promotes canonical artifacts to `docs/` so the next increment has a baseline.

Full semantics: [`process/agent-handoff-protocol.md`](process/agent-handoff-protocol.md). Pick your case: [`process/playbooks/README.md`](process/playbooks/README.md).

---

## Keeping copies in sync

**`.github/` is the source of truth** — `agents/`, `skills/`, and `commands/`. Everything else is derived.

After editing anything under `.github/`, run one command:

```bash
scripts/install.sh --target repo
```

`repo` regenerates every derived directory this repository tracks — the plugin components (`agents/`, `skills/`, `commands/`), `.claude/`, and `.cursor/` — in a single pass. It is idempotent: a second run reports `0 written`. Use `--dry-run` first to see what would change without writing anything.

In CI, use `--check` instead: it is `--dry-run` plus a non-zero exit when anything is stale, orphaned, or warned about, so a commit that edits `.github/` without regenerating fails the build rather than drifting quietly.

```bash
scripts/install.sh --target repo --check
```

Do not hand-edit a derived file. The installer overwrites `agents/`, `.claude/`, and `.cursor/` unconditionally, and it overwrites skills and commands too (pass `--keep-existing` if you have deliberately customised a destination copy). If you rename or delete an agent, the installer reports the leftover derived file as an `ORPHAN` rather than deleting it for you — remove it by hand.

The per-platform targets (`--target claude|cursor|copilot|codex|hermes|roo|agents`) install *outward*, to `$HOME` or to another project. `--target repo` and `--target plugin` write only into this repository and reject `--path`.
