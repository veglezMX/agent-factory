# Agent Handoff Protocol

**Purpose:** The roster defines *who* the agents are; the playbook defines *when* they run. This document defines *how* work moves between them: the handoff payload format, the run workspace layout, gate semantics, escalation rules, and context-budget discipline. Without this contract, multi-agent workflows degrade into lossy chat history — agents repeat work, lose decisions, and silently drop risks.

This protocol is project-agnostic. Teams adopt it verbatim or adapt field names, but every run should preserve the four properties it exists to guarantee:

1. **Traceability** — every artifact traces to a packet section, a design decision, or a bundle task.
2. **Statelessness** — any agent can be invoked cold and reconstruct what it needs from the run workspace alone.
3. **Auditability** — a human can replay why each decision was made from handoff files, without reading chat transcripts.
4. **Containment** — no agent exceeds its boundary without an explicit, recorded handoff.

---

## 1. Run Workspace

Every run gets a directory, committed to the repository (or a sibling repo for pre-repo phases):

```text
runs/
└── <run-id>/                        e.g. 2026-06-comedor-mvp
    ├── 00-packet/
    │   └── stakeholder-input-packet.md      (frozen copy; never edited mid-run)
    ├── 01-requirements/
    │   ├── requirements.md
    │   ├── glossary.md
    │   └── open-questions.md
    ├── 02-design/
    │   ├── ux-inventory.md
    │   ├── architecture.md
    │   ├── stack-decision-record.md
    │   └── integration-inventory.md
    ├── 03-bundle/                            (compiled task bundle)
    ├── handoffs/
    │   ├── 0001-orchestrator-to-requirements-analyst.md
    │   ├── 0002-requirements-analyst-to-orchestrator.md
    │   └── ...                               (sequential, never renumbered)
    ├── gates/
    │   ├── gate-1-scope.md
    │   ├── gate-2-design.md
    │   └── gate-3-release.md
    ├── findings/
    │   ├── architecture/
    │   ├── security/
    │   └── review/
    └── state.md                              (rolling run state; orchestrator-owned)
```

Rules:

- The packet copy under `00-packet/` is **frozen**. Scope changes mid-run produce a packet amendment file and re-trigger the affected gates; they never edit the original.
- Handoff files are **append-only and sequentially numbered**. A correction is a new handoff, not an edit.
- `state.md` is owned exclusively by the Orchestrator. Specialists read it; only the Orchestrator writes it.

---

## 2. Handoff Payload

Every transfer of work between agents is one markdown file with YAML frontmatter. The frontmatter is machine-checkable; the body is for humans and for the receiving agent's context.

### 2.1 Schema

```yaml
---
handoff: 0014                       # sequential within the run
run: 2026-06-comedor-mvp
from: 13-backend-domain-implementer
to: 10-contract-client-guardian     # specialists may only name 01 or the
                                    # agent the orchestrator routed them to
task: 07-services/ordering/place-order
status: blocked                     # complete | blocked | needs-review | partial
gate_impact: none                   # none | gate-1 | gate-2 | gate-3
inputs:                             # what this agent worked FROM (paths)
  - runs/.../03-bundle/07-services/ordering.yaml
  - contracts/openapi/ordering.yaml
outputs:                            # what this agent PRODUCED (paths)
  - services/ordering/src/place_order.ts
  - services/ordering/tests/place_order.test.ts
decisions:                          # one line each, traceable
  - "Price snapshot stored on order row per business rule 3 (packet §5.3)"
risks:
  - id: R-011
    severity: medium
    text: "Refund path untested under concurrent cancellation"
open_questions: []                  # questions ONLY a human can answer
next_recommended: 10-contract-client-guardian
---
```

### 2.2 Body sections (in order, all required, "none" is a valid value)

```markdown
## Context summary        (≤ 30 lines; see §5 Context Budget)
## What was done
## What was NOT done and why
## Boundary touches       (anything near or at another agent's scope)
## Verification performed (commands run, tests passing/failing)
## Notes for the receiver
```

### 2.3 Hard rules

- **No handoff, no work.** An agent invoked without an inbound handoff file (or the packet, for the Requirements Analyst) must refuse and ask the Orchestrator to issue one.
- **`status: complete` requires verification.** An implementer claiming completion must list the commands it ran and their results under *Verification performed*. "It should work" is `partial`, not `complete`.
- **`blocked` must name the blocker.** Either an `open_questions` entry (human-blocked) or a `next_recommended` agent (dependency-blocked). Never both empty.
- **Decisions are sentences, not paragraphs.** Each decision line names what was decided and cites its source (packet section, design doc, or finding ID). Undecidable items go to `open_questions`.
- **Risks are never deleted.** A risk is closed by a later handoff that references its ID and states how it was resolved or formally accepted — accepted risks require the gate approver's name.

---

## 3. Gates

A gate is a named checkpoint where the run halts until a recorded human decision exists in `gates/`.

### 3.1 Standard gates

| Gate | After | Approves | Blocks until |
|---|---|---|---|
| **Gate 1 — Scope** | Requirements Analyst | Requirements doc, glossary, all open questions answered | Approver signs `gates/gate-1-scope.md` |
| **Gate 2 — Design** | Architecture Guardian's clean design review | Architecture, stack, integration inventory, cost-relevant choices | Approver signs `gates/gate-2-design.md` |
| **Gate 3 — Release** | Release evidence assembled | Production release | Approver signs `gates/gate-3-release.md` |

### 3.2 Gate record format

```markdown
# Gate 2 — Design
run: 2026-06-comedor-mvp
decision: approved            # approved | approved-with-conditions | rejected
approver: <name from packet §16>
evidence_reviewed:
  - runs/.../02-design/architecture.md
  - runs/.../findings/architecture/review-002.md   (clean)
conditions: []                # binding; orchestrator tracks them as risks
notes: ...
```

### 3.3 Gate semantics

- A `rejected` gate routes back to the producing agent with the rejection notes as a new inbound handoff.
- `approved-with-conditions` lets the run proceed; each condition becomes a tracked risk that must be closed before Gate 3.
- **Mid-run scope change re-opens Gate 1.** The amendment flows: packet amendment → Requirements Analyst delta review → Gate 1 re-approval → Bundle Compiler delta → Intake Validator. Implementers never absorb scope changes directly from chat.

---

## 4. Escalation & Loop-Back Rules

Specialists never argue with each other and never route around the Orchestrator. The universal escalation table:

| Situation | Action |
|---|---|
| Requirement is ambiguous, contradictory, or missing | `status: blocked`, add `open_questions`, route to 01 → human. **Never guess.** |
| Work requires touching another agent's boundary | Stop at the boundary; handoff with `next_recommended` set to the owner |
| Reviewer issues a blocking finding | Finding file in `findings/`, handoff to owning implementer via 01 |
| Implementer disagrees with a finding | Disagreement recorded in the handoff body; 01 routes to the human. Findings are never silently dropped |
| Two agents need the same file | 01 serializes; the protocol forbids concurrent edits inside one boundary |
| Test fails and the fix is unclear whose | 17 assigns ownership in the finding; 01 routes. Tests are never weakened to resolve ambiguity |
| Anything untraceable to packet, design, or bundle | Blocked → human. This is the system's last-resort integrity check |

---

## 5. Context Budget

Long runs die from context exhaustion before they die from bad decisions. Three disciplines:

1. **The 30-line context summary.** Every handoff body opens with at most 30 lines telling the receiver everything it needs that is not in its `inputs` files. The receiver reads: its inbound handoff + the files in `inputs` + `state.md`. It does not read chat history or prior handoffs unless its inbound handoff explicitly points to one.
2. **`state.md` is a digest, not a log.** The Orchestrator keeps it under ~100 lines: current phase, active task, open risks by ID, open questions, gate status, and the last 5 handoffs by number. Detail lives in the handoff files; `state.md` only points.
3. **Fresh sessions are the default.** Each agent invocation should assume a cold context window. If an agent cannot do its job from the run workspace alone, the previous handoff was deficient — fix the handoff, don't lean on session memory.

---

## 6. Conformance Checklist for Agent Authors

When writing each `*.agent.md` file from the roster, verify the agent's prompt enforces this protocol:

- [ ] Refuses to work without an inbound handoff (or the packet, for 02).
- [ ] Reads only: inbound handoff, listed inputs, `state.md`.
- [ ] Writes outputs only inside its roster boundary.
- [ ] Ends every session by writing a handoff file with full frontmatter.
- [ ] Marks `complete` only with verification evidence.
- [ ] Escalates ambiguity as `open_questions` instead of guessing.
- [ ] Recommends a next agent; never invokes specialists directly (01 excepted).
- [ ] Never edits frozen artifacts (`00-packet/`, prior handoffs, gate records).
- [ ] Cites packet sections, design docs, or finding IDs in every decision line.
- [ ] Contains no time estimates in any plan, sequence, or phase description.
