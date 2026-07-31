---
description: Scaffold a new roster-conformant agent definition under .github/agents/, with its roster entry and playbook routing, then regenerate every derived directory.
argument-hint: <slug> [one-line purpose]   e.g. localization-engineer "owns i18n and locale correctness"
allowed-tools: Read, Write, Edit, Grep, Glob, Bash, AskUserQuestion
---

Create a new agent named **$1** in this repository.

Follow the `authoring-an-agent` skill exactly — it holds the conventions this repository
upholds by convention alone, and a definition that diverges from them is invisible to every
check the rest of the roster relies on. Do not compose a definition from scratch.

## Before writing anything

1. **Read `process/agent-roster.md` end to end** and confirm the proposed agent owns something
   no existing agent owns. Overlap between two boundaries is the failure mode this framework's
   `Scope & Boundaries` sections exist to prevent. If the scope substantially overlaps an
   incumbent, say so and stop — recommend extending that agent, or a skill, instead.
2. **Ask the human** — with `AskUserQuestion`, in one batch — for anything the arguments leave
   undetermined:
   - the tool posture (`R`, `R+route`, `E`, `E+T`, `O`)
   - the phase it belongs to
   - which case playbooks route to it, and whether it is conditional (`~`) in each
   - the neighbouring agents whose scope it must not cross
3. **Pick the sibling to mirror** — the existing agent closest in posture and phase — and say
   which one you chose.

## Then, in this order

1. **Claim the roster entry first.** Add the overview-table row and the `### NN — Name` entry
   with all four facts (Does / Scope / Tools / Invocation) to `process/agent-roster.md`. Take
   the next free number. The roster is the registry; an agent file without a roster entry is an
   error.
2. **Write `.github/agents/$1.agent.md`** — frontmatter (`name`, `description`,
   `argument-hint`, `tools` in canonical id order `read, search, web, edit, execute, agent,
   todo`), the persona line stating `agent NN in the delivery roster`, then the fifteen `##`
   sections in the fixed order, plus `## Terminal Discipline` **iff** `tools` includes
   `"execute"`.
3. **Include the shared invocation-contract paragraph** under `## Invocation`, copied verbatim
   from the sibling, followed by this agent's own trigger paragraph. End with
   `You call no other agents.` unless the roster entry explicitly grants otherwise.
4. **Route it** into every playbook that uses it: the `agents:` frontmatter list (conditional
   agents included), the **Run at a glance** flow, a numbered **Phase-by-phase** entry — with
   the following entries renumbered — any **Loop-backs used** row, and the case × agent matrix
   in `process/playbooks/README.md`. The matrix and the `agents:` lists must agree in both
   directions.
5. **Regenerate:** `scripts/install.sh --target repo`
6. **Update the counts.** "29 agents" appears in `README.md`, `process/agent-roster.md`,
   `.claude-plugin/plugin.json`, and `.claude-plugin/marketplace.json`. Bump the plugin
   **minor** version and add a `CHANGELOG.md` entry — a roster change with an unbumped version
   is the specific defect the versioning rule exists to prevent.

## Verify before reporting done

```bash
grep -c '^## ' .github/agents/$1.agent.md        # 15, or 16 with Terminal Discipline
diff <(grep '^## ' .github/agents/$1.agent.md) <(grep '^## ' .github/agents/<sibling>.agent.md)
grep '^tools:' .claude/agents/$1.md               # the generated tool line
scripts/install.sh --target repo                  # must report 0 written on a second run
```

Report what you created, which sibling you mirrored, which playbooks now route to it, and any
verification that did not come back clean. Do not claim conformance you have not checked.
