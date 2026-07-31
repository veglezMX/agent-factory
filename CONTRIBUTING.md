# Contributing to agents-factory

This repository is documentation and prompts. There is no build, no test suite, and no
runtime — the deliverable *is* the text. That makes one rule more important than any
other, and it is the rule newcomers break first.

---

## The one rule: `.github/` is the source of truth

```text
.github/agents/     ->  .claude/agents/  ·  agents/  ·  .cursor/rules/
.github/skills/     ->  .claude/skills/  ·  skills/
.github/commands/   ->  .claude/commands/  ·  commands/
```

Everything on the right is **generated**. Never hand-edit it — the next regeneration
silently discards your change, and a reviewer reading the diff cannot tell an intentional
edit from a stale one.

After changing anything under `.github/`:

```bash
scripts/install.sh --target repo --dry-run   # preview
scripts/install.sh --target repo             # apply
```

One command regenerates every derived directory. It is idempotent — running it on a clean
tree reports `0 written`. A pull request whose `.github/` changes are not accompanied by
the regenerated output is incomplete.

If you rename or delete an agent, the installer reports the leftover derived file as an
`ORPHAN`; delete it yourself. The installer never deletes for you.

---

## Adding an agent

Use the `authoring-an-agent` skill (or `/new-agent <name>`) — it encodes the rules below
and is kept in step with them.

1. **Claim a roster number.** Add the row to `process/agent-roster.md` first: the overview
   table plus a `### NN — Name` entry stating the four facts (Does / Scope / Tools /
   Invocation). The roster is the registry; an agent file without a roster entry is an error.
2. **Write `.github/agents/<slug>.agent.md`.** Frontmatter carries `name` (matching the
   filename stem), `description`, `argument-hint`, and `tools`. Tool ids go in the canonical
   order `read, search, web, edit, execute, agent, todo`.
3. **Match the section template exactly.** Fifteen `##` sections in a fixed order, plus
   `## Terminal Discipline` if and only if `tools` includes `execute`. Mirror an existing
   sibling of the same posture rather than composing from scratch.
4. **State the invocation contract.** Every agent carries the shared `## Invocation`
   paragraph referencing `process/agent-invocation-contract.md` §5.
5. **Route it.** An agent in no playbook is unreachable in pipeline mode. Add it to the
   relevant `process/playbooks/*.md` and to the case × agent matrix in
   `process/playbooks/README.md` — and keep those two in agreement, in both directions.
6. **Regenerate.**

## Adding a playbook (a new case)

Use the `authoring-a-playbook` skill. A case is a drop-in: one file conforming to
`process/playbooks/playbook-schema.md`, plus a matrix column in
`process/playbooks/README.md`. The roster and the handoff protocol never change to add a
case. If a case needs an agent the roster lacks, the roster gets the agent **first**, as its
own change.

## Adding a skill or a command

Author under `.github/skills/<name>/SKILL.md` or `.github/commands/<name>.md`, then
regenerate. Do not create the `.claude/` copy by hand.

---

## Consistency invariants

These hold across the repository. Nothing enforces them automatically — they are
review-time checks, and the two authoring skills exist to make them hard to miss.

| Invariant | Where it can break |
|---|---|
| Every roster ID `01`–`29` has exactly one agent file, and vice versa | `process/agent-roster.md` ↔ `.github/agents/` |
| Every playbook `agents:` ID exists in the roster | `playbook-schema.md` §1 |
| A matrix cell marked `x` or `~` appears in that playbook's `agents:` list, and vice versa | `playbooks/README.md` ↔ each playbook |
| Declared posture matches the `tools:` frontmatter | roster ↔ agent file, via `PORTABILITY.md` |
| Derived directories match their `.github/` source | fixed by `--target repo` |
| Documents describe artifacts that exist | worked examples drifting from `runs/` |

Two useful spot-checks:

```bash
scripts/install.sh --target repo --dry-run   # 0 would change == derived dirs in sync
# 15 sections per agent, 16 for the E+T agents that carry Terminal Discipline:
for f in .github/agents/*.agent.md; do printf '%s %s\n' "$(grep -c '^## ' "$f")" "$f"; done | sort -n
```

---

## Style

- **Project-agnostic.** Agents, playbooks, and process docs never name a specific product,
  stack, or company. Project specifics live in `process/examples/` (narrative) and `runs/`
  (real artifacts).
- **References, never redefinitions.** A playbook names roster agents by ID and links
  protocol sections; it does not restate an agent's scope or a gate's semantics.
- **No time estimates.** Ordering expresses dependency, never duration.
- **Say what is real.** If a worked example describes work that was never executed, label
  it. A document that over-claims is worse than a missing one.

## Versioning

`.claude-plugin/plugin.json` carries the version. Bump the **minor** when the roster, the
playbook set, or the skill/command set changes; bump the **patch** for documentation and
installer fixes. Record the change in `CHANGELOG.md` in the same commit — an unbumped
version on a roster change is the defect that motivated writing this down.
