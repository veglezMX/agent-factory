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
| **Orchestration** (01 invoking others) | ❌ Platform-specific | Depends on whether your harness lets one agent call another, or only the main loop dispatches. |

**Bottom line:** the *thinking* is fully portable; the *wiring* is not. `scripts/install.sh` handles the wiring for Claude Code, Cursor, Zoo Code / Roo Code (native `.roomodes`), and the generic `.agents` format; Copilot is already native.

---

## Directory mapping

| Artifact | Claude Code | GitHub Copilot / VS Code | Cursor | Zoo Code / Roo Code (native) | Generic `.agents` |
|---|---|---|---|---|---|
| Agents | `.claude/agents/*.md` *(generated)* | `.github/agents/*.agent.md` *(source of truth)* | `.cursor/rules/*.mdc` *(reference)* | `.roomodes` or global `custom_modes.yaml` *(generated, single `customModes:` file)* | `.agents/*.yaml` *(generated, one file per agent)* |
| Skills | `.claude/skills/<name>/SKILL.md` *(generated)* | `.github/skills/<name>/SKILL.md` *(source of truth)* | manual prompt | `.roo/skills/<name>/SKILL.md` *(manual invoke)* | `.agents/skills/<name>/SKILL.md` |
| Commands | `.claude/commands/*.md` *(generated)* | `.github/commands/*.md` *(source of truth)* | n/a | n/a | n/a |
| Orchestrator start | `/run-delivery <run-id>` (main loop) | invoke `delivery-orchestrator` agent | drive in main chat | switch to the `delivery-orchestrator` mode | switch to the `delivery-orchestrator` mode |
| Pipeline run state | `runs/<run-id>/` | `runs/<run-id>/` | `runs/<run-id>/` | `runs/<run-id>/` | `runs/<run-id>/` |
| Process docs | `process/`, `templates/` | same | same | same | same |

---

## Tool-posture → platform tool mapping

The roster assigns each agent a **posture**, not a fixed tool list. Translate the posture to your platform:

| Posture | Meaning | VS Code / Copilot ids | Claude Code tools | Roo Code groups |
|---|---|---|---|---|
| `R` | read-only | `read`, `search` | `Read, Grep, Glob` | `read` |
| `R+route` | read-only + routing-only `agent` | `read`, `search`, `agent` | `Read, Grep, Glob, Task` | `read` |
| `E` | edit | `read`, `search`, `edit` | `Read, Grep, Glob, Edit, Write` | `read, edit` |
| `E+T` | edit + terminal | `read`, `search`, `edit`, `execute`, `todo` | `Read, Grep, Glob, Edit, Write, Bash, TodoWrite` | `read, edit, command` |
| `O` | orchestration | `read`, `search`, `agent`, `todo` | `Read, Grep, Glob, Task, TodoWrite` — **must run as the main loop on Claude Code** | `read` (Roo switches modes natively) |

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
2. Cursor has no native multi-agent orchestrator. Drive the run in the main chat: act as the orchestrator yourself (or paste the `delivery-orchestrator` rule), invoke each agent rule in playbook order, and write handoff files under `runs/<run-id>/` between steps.
3. For standalone work, `@`-mention only the desired specialist rule and provide `mode: standalone`, a bounded task, and a target; do not create a run workspace or handoff.

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
- Satisfy the orchestration requirement: either your harness lets one agent invoke another (wire 01 to call the rest), **or** your main control loop plays the orchestrator and dispatches the rest.
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

`repo` regenerates every derived directory this repository tracks — the plugin components (`agents/`, `skills/`, `commands/`), `.claude/`, and `.cursor/rules/` — in a single pass. It is idempotent: a second run reports `0 written`. Use `--dry-run` first to see what would change without writing anything.

Do not hand-edit a derived file. The installer overwrites `agents/`, `.claude/`, and `.cursor/` unconditionally, and it overwrites skills and commands too (pass `--keep-existing` if you have deliberately customised a destination copy). If you rename or delete an agent, the installer reports the leftover derived file as an `ORPHAN` rather than deleting it for you — remove it by hand.

The per-platform targets (`--target claude|cursor|copilot|roo|agents`) install *outward*, to `$HOME` or to another project. `--target repo` and `--target plugin` write only into this repository and reject `--path`.
