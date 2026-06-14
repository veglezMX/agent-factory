# Playbook Schema

**Purpose:** The contract every case-playbook obeys. The roster (`../agent-roster.md`) defines *who* the agents are; the handoff protocol (`../agent-handoff-protocol.md`) defines *how* work moves between them. A **playbook** defines *which* agents and skills a given **case** uses, in *what order*, with *which gates* and *loop-backs*. One file per case.

A "case" is a class of work with its own trigger, entry criteria, and agent subset — e.g. `greenfield`, `brownfield-onboard`, `defect`. Not every case calls every agent. Adding a new case is a drop-in: author one `playbooks/<case>.md` that conforms to this schema and add a row to `README.md`'s matrix. The roster and protocol never change to add a case.

---

## 1. Frontmatter (required, machine-checkable)

Every playbook opens with YAML frontmatter:

```yaml
---
case: greenfield                 # unique slug; matches the filename and the README matrix column
name: Greenfield Full Build      # human title
trigger: Stakeholder Input Packet   # the artifact or event that starts a run of this case
entry_criteria:                  # preconditions the Orchestrator checks before issuing handoff 0001
  - packet exists, all OPEN items resolved
agents: [01,02,03,04,05,06,07,08,09,10,11,12,13,14,15,16,17,18,19,20]
skills: [creating-stakeholder-packet]   # skills the case relies on; [] if none
gates: [scope, design, release]  # ordered list of human gates; [] if the case has none
baseline: produces               # produces | consumes | none — relationship to canonical docs
closure: >                       # one line: what makes a run of this case "done"
  Gate 3 approved, zero open risks, zero open questions (handoff-protocol §6.1)
---
```

### Field rules

- **`case`** — unique across all playbooks; equals the filename stem; equals the matrix column header in `README.md`.
- **`agents`** — the subset of roster IDs (`01`–`20`) this case uses. Every ID **must** exist in the roster overview table. An ID not in the roster is an error (a conformance checker is a future drop-in; until then it is a review-time check).
- **`skills`** — skill names the case relies on (e.g. `creating-stakeholder-packet`). Must exist in the skill set.
- **`gates`** — ordered gate slugs. A case may legitimately have fewer gates than greenfield, or none. Gate semantics live in handoff-protocol §3.
- **`baseline`** — `produces` (the case promotes requirements/glossary/architecture into canonical `docs/` at its terminal gate), `consumes` (the case diffs against existing canonical docs), or `none`.
- **`closure`** — the case-specific definition of a closed run, traceable to handoff-protocol §6.1 or a documented variant.

---

## 2. Body sections (fixed order, all required, "none" is a valid value)

```markdown
## When to use / when NOT     # entry test; explicit pointers to the other case when this one is wrong
## Entry criteria             # expanded preconditions; what the Orchestrator verifies before 0001
## Run at a glance            # ASCII phase/agent flow with gate [H] and loop-back ↺ markers
## Phase-by-phase             # per agent in this case: what it receives, produces, where it sits
## Loop-backs used            # the subset of the protocol's escalation table this case exercises
## Closure criteria           # what makes a run of this case done (matches frontmatter `closure`)
## Worked example             # link to examples/<case>-<project>.md, or "none yet"
```

---

## 3. Hard rules

- **Project-agnostic.** A playbook describes the case, never a specific project. Project specifics live in `examples/` (narrative) and `runs/` (real workspace artifacts).
- **References, never redefinitions.** A playbook names roster agents by ID and links protocol sections; it never restates an agent's scope or a gate's semantics. Single source of truth stays the roster and protocol.
- **No time estimates.** Ordering reflects dependency only, never duration — same rule as the roster and protocol.
- **Drop-in, not rewire.** A new case adds a playbook + a matrix row. If a case needs an agent the roster lacks, the roster gets the agent first (its own change), then the playbook references it.
