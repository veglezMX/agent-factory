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

**Bottom line:** the *thinking* is fully portable; the *wiring* is not. `scripts/install.sh` handles the wiring for Claude Code, Cursor, and the Roo Code / `.agents` format; Copilot is already native.

---

## Directory mapping

| Artifact | Claude Code | GitHub Copilot / VS Code | Cursor | Roo Code / `.agents` |
|---|---|---|---|---|
| Agents | `.claude/agents/*.md` *(generated)* | `.github/agents/*.agent.md` *(source of truth)* | `.cursor/rules/*.mdc` *(reference)* | `.agents/*.yaml` *(generated, custom-mode format)* |
| Skills | `.claude/skills/<name>/SKILL.md` | `.github/prompts/*.prompt.md` or manual | manual prompt | `.agents/skills/<name>/SKILL.md` |
| Orchestrator start | `/run-delivery <run-id>` (main loop) | invoke `delivery-orchestrator` agent | drive in main chat | switch to the `delivery-orchestrator` mode |
| Run state | `runs/<run-id>/` | `runs/<run-id>/` | `runs/<run-id>/` | `runs/<run-id>/` |
| Process docs | `process/`, `templates/` | same | same | same |

---

## Tool-posture → platform tool mapping

The roster assigns each agent a **posture**, not a fixed tool list. Translate the posture to your platform:

| Posture | Meaning | VS Code / Copilot ids | Claude Code tools | Roo Code groups |
|---|---|---|---|---|
| `R` | read-only | `read`, `search` | `Read, Grep, Glob` | `read` |
| `E` | edit | `read`, `search`, `edit` | `Read, Grep, Glob, Edit, Write` | `read, edit` |
| `E+T` | edit + terminal | `read`, `search`, `edit`, `execute`, `todo` | `Read, Grep, Glob, Edit, Write, Bash, TodoWrite` | `read, edit, command` |
| `O` | orchestration | `agent` (+ `read`) | `Task` (+ `Read`) — **must run as the main loop on Claude Code** | `read` (Roo switches modes natively) |

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
   - reads every `.github/agents/*.agent.md` (skipping the `test` scaffold),
   - writes `agents/<name>.md` with the `tools:` line rewritten to Claude tool names and `argument-hint` dropped,
   - ensures the skills exist under `skills/`,
   - copies the `run-delivery` driver into `commands/`.
2. For a **global** install nothing needs copying. For a **project** install, also copy `process/`, `templates/`, and (when you start) `runs/` into that project.
3. Start a run with **`/run-delivery <run-id>`**. This is the key step: it makes your **main Claude session act as the Delivery Orchestrator**, because a Claude subagent cannot invoke other subagents — only the main loop can `Task`-dispatch the roster.
4. Direct human use of any single agent still works via the agent picker / `Task`.

### GitHub Copilot / VS Code

1. Run `scripts/install.sh --target copilot`. The agents are **already in the native `*.agent.md` format**, so it copies (no conversion) the agents and skills into the Copilot CLI personal dir `~/.copilot/{agents,skills}` by default (override the location with the `COPILOT_HOME` env var). Add `--scope project --path <dir>` to install into a repo's project-level `.github/{agents,skills}` instead.
2. Skills install as their `SKILL.md` folders (`~/.copilot/skills/` globally, `.github/skills/` per project). Run `/skills list` in the CLI to confirm they're picked up. If your Copilot build has no skills runtime, open `creating-stakeholder-packet/SKILL.md` and follow it manually before the first run.
3. **VS Code note:** the global dir above is the **Copilot CLI** convention. VS Code reads a repo's `.github/` (use `--scope project`) or its own profile dir; if you need a custom user-level folder there, point `chat.agentFilesLocations` / `chat.agentSkillsLocations` at it with an **absolute** path (VS Code does not expand `~`).
4. Start a run by invoking the **`delivery-orchestrator`** agent and pasting/pointing at the packet.
5. **Caveat:** whether `delivery-orchestrator` can invoke the other agents depends on your Copilot version's agent-to-agent support. If it can't, drive the sequence yourself: invoke each agent in playbook order, pasting the prior handoff as input.

### Cursor

1. Run `scripts/install.sh --target cursor`. By default it installs **globally** to `~/.cursor/rules`; add `--scope project --path <dir>` for one project's `.cursor/rules/`. It writes `<name>.mdc` — each agent body as a reference rule with `alwaysApply: false`, so you can `@`-mention the one you need.
2. Cursor has no native multi-agent orchestrator. Drive the run in the main chat: act as the orchestrator yourself (or paste the `delivery-orchestrator` rule), invoke each agent rule in playbook order, and write handoff files under `runs/<run-id>/` between steps.

### Roo Code / generic `.agents` harness

Some harnesses load a **directory of per-agent files** rather than one platform config. This target emits the roster in **Roo Code's custom-mode format** — one YAML file per agent — which those loaders (and Roo Code itself, after a small step) can consume.

1. Run `scripts/install.sh --target agents`. By default it installs **globally** to `~/.agents`; add `--scope project --path <dir>` for one project's `.agents/`. It writes `<name>.yaml` for each agent, each a single custom-mode object: `slug`, `name`, `roleDefinition` (the agent's `You are …` persona), `whenToUse` (the agent's description), `groups` (the posture mapped to Roo's `read`/`edit`/`command`/`browser`), and `customInstructions` (the full agent body verbatim). Skills install as their `SKILL.md` folders under `.agents/skills/`.
2. **Roo Code caveat:** Roo natively reads a **single `.roomodes`** file at the workspace root with a top-level `customModes:` array — not a folder of files. To use these on Roo directly, merge them into `.roomodes` by listing each file's contents as one entry under `customModes:` (indent each agent object by two spaces beneath the array). Generic `.agents`-style loaders consume the per-file layout as-is.
3. Start a run by switching to the **`delivery-orchestrator`** mode (slug `delivery-orchestrator`) and pointing it at the packet. The same agent-to-agent caveat as Copilot applies: if your harness can't let one mode invoke another, drive the sequence yourself in playbook order, writing handoff files under `runs/<run-id>/`.

### Generic / any agent harness

The framework is a **specification**, not a binding. To port it:
- Map each agent's **posture** to your harness's tool permissions (table above).
- Place agent bodies wherever your harness loads system prompts / personas.
- Satisfy the orchestration requirement: either your harness lets one agent invoke another (wire 01 to call the rest), **or** your main control loop plays the orchestrator and dispatches the rest.
- Use `runs/<run-id>/` as the on-disk state store and the handoff payload format from the protocol §2. As long as those hold, statelessness, auditability, and traceability are preserved.

---

## The run process (entry point)

Regardless of platform, a run is:

1. **Packet** — author/freeze the Stakeholder Input Packet under `runs/<run-id>/00-packet/` (skill: `creating-stakeholder-packet`).
2. **Boot** — invoke the orchestrator; it creates the run workspace (protocol §1) and routes the packet to the Requirements Analyst.
3. **Phases** — the playbook for your case (default `greenfield`) sequences the agents; each emits an append-only handoff file under `runs/<run-id>/handoffs/`.
4. **Gates** — the run halts at human gates; you sign the record under `runs/<run-id>/gates/`.
5. **Closure** — at the terminal gate the orchestrator promotes canonical artifacts to `docs/` so the next increment has a baseline.

Full semantics: [`process/agent-handoff-protocol.md`](process/agent-handoff-protocol.md). Pick your case: [`process/playbooks/README.md`](process/playbooks/README.md).

---

## Keeping copies in sync

`.github/agents/` is the **source of truth**. After editing an agent there, re-run `scripts/install.sh --target claude` (and `--target cursor` / `--target agents`) to regenerate the derived folders. Skills are mirrored in `.github/skills/` and `.claude/skills/`; edit one and copy to the other (they are kept byte-identical). Do not hand-edit the generated `.claude/agents/` or `.agents/` files — your changes will be overwritten on the next conversion.
