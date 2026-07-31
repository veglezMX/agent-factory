---
case: increment
name: Increment Run
trigger: Delta packet naming a baseline run and the new scope
entry_criteria:
  - the prior run on this product is CLOSED (handoff-protocol §6.1) and its closure evidence is cited
  - a delta packet exists under 00-packet/ naming baseline_run and the canonical artifacts in force
  - canonical docs/ baseline exists to diff against (handoff-protocol §6.3)
  - the new scope is genuinely new or intentionally changes shipped behavior — not a defect
agents: [01,02,03,04,05,06,07,08,09,10,11,12,13,14,15,16,17,18,19,20,21,22,23,24,25,26,27,28,29]
skills: [creating-stakeholder-packet, conducting-a-gate, resuming-a-run]
gates: [scope, design, release]
baseline: consumes
closure: >
  Gate 3 approved, every risk ID terminal (including any risk superseding a prior run's
  accepted risk), zero open questions; the canonical requirements, glossary, architecture,
  and contracts UPDATED with the delta rather than replaced (protocol §6.1, §6.3, §6.5)
---

# Playbook — Increment Run

**Purpose:** Grow a released product. A new module, journey, or capability is never absorbed into a closed run and never delivered from chat — it is a full run with its own run-id, its own workspace, and its own gates. The roster, the phases, and the gates are identical to `greenfield`; **only the inputs shrink to the delta and the baseline relationship inverts** from `produces` to `consumes`. This playbook exists to hold the differences in one place rather than as a footnote to a case whose defining assumption — that nothing exists yet — is exactly what an increment contradicts.

**Legend:**

- `[H]` — human gate: the run blocks until the approver acts.
- `↺` — loop-back: findings return work to an earlier agent (full table in `../agent-handoff-protocol.md` §4).
- All ordering reflects dependency, never duration. No stage carries a time estimate.

---

## When to use / when NOT

Use increment when a **released** product built by this pipeline gains new scope: a new role, journey, feature, business rule, or capability — or an intentional change to shipped behavior.

Do **not** use increment when:

- Shipped behavior is **wrong** and a canonical doc already says what it should be → `defect.md`. Restoring intended behavior is not new scope; it runs without scope or design gates.
- Production is down or degrading → `incident.md`, which acts first and approves retroactively.
- Nothing exists yet → `greenfield.md`. There is no baseline to consume.
- The product was not built by this pipeline and has no canonical baseline → `brownfield-onboard.md` first, to reconstruct one; the change then runs as an increment against it.
- Internal structure changes with **no** behavior change → `refactor.md`.
- A feature request arrives while a run is already active → it does not open an increment. Either fold it into the current run as a §3.3 packet amendment, or queue it as the next increment once the current run closes (§6.6).

See `README.md` for the case picker.

---

## Entry criteria

Before issuing handoff `0001`, the Orchestrator verifies:

- **The prior run is closed** (protocol §6.1) — its Gate 3 record is `approved`, or a cancellation record exists (§6.4); every risk ID is terminal; the final `state.md` shows zero open questions. **One run at a time is a hard rule.** The Orchestrator refuses `0001` while the previous run is unclosed; there is no "we'll fix it in the next increment". Use the `resuming-a-run` skill to establish closure from the workspace rather than from recollection.
- **The first handoff cites that closure evidence** — the prior Gate 3 (or cancellation) record and the final `state.md`. An increment handoff without the citation is invalid, and the receiving agent refuses it exactly as it would refuse work with no inbound handoff at all.
- **A delta packet is frozen** under `00-packet/` (§6.2). It is not a copy of the original packet:

  ```yaml
  ---
  packet: delta
  baseline_run: 2026-06-comedor-mvp        # the closed run this builds on
  baseline_artifacts:                      # canonical docs in force (§6.3)
    - docs/architecture.md
    - docs/glossary.md
    - docs/requirements.md
  ---
  ```

  It covers **only** the new scope, plus any shipped behavior it intentionally changes, stated explicitly. Use `creating-stakeholder-packet` to author it; the same freeze rule applies, and mid-run changes produce amendments (§3.3).
- **The canonical baseline exists** in `docs/` (§6.3). Increment `consumes` it.

---

## Run at a glance

```text
[Human invokes 01-delivery-orchestrator with the delta packet + prior-run closure citation]

PHASE 0 — DELTA DISCOVERY & DESIGN
  02-requirements-analyst          delta packet + canonical requirements/glossary
                                   → DELTA review; contradiction with shipped behavior
                                     becomes an open question, never a silent override
  [H] GATE 1: scope approval (of the delta)
  03-ux-flow-designer (~)          new/changed screens only; existing inventory is context   (skip if headless)
  24-visual-design-system-designer(~) EXTEND the canonical design system; do not re-found it (skip if headless)
  29-ui-layout-designer (~)        layouts for new/changed pages only                        (skip if headless)
  04-solution-designer             delta design against the canonical architecture:
                                   which existing components the increment touches
  08-architecture-guardian         impact review vs CANONICAL architecture      ↺ 04 on violations
  27-accessibility-auditor (~)     a11y review of new/changed surfaces          ↺ 03/24/29    (skip if headless)
  26-privacy-compliance-officer(~) only if the delta changes data handling
  [H] GATE 2: design approval (of the impact, not of a new architecture)
  05-bundle-compiler               NEW AND CHANGED tasks only; unchanged shipped
                                   behavior is out of bundle scope
  06-bundle-intake-validator       coverage of the delta + regression reach       ↺ 05

PHASE 1 — PLANNING
  07-product-planner               per-slice plans for the delta, ordered by value

PHASE 2 — BUILD  (09 normally NOT USED — the foundation already exists)
  10-contract-client-guardian      contract delta; breaking-change detection vs the
                                   in-force contract is the case-critical step
  11-data-migration-engineer (~)   forward migration + rollback against live data
  12-integration-engineer (~)      new providers only; existing fakes are reused
  13-backend-domain-implementer    the delta's service behavior
  14-frontend-feature-builder (~)  the delta's screens and states
  25-ai-prompt-engineer (~)        only if the delta specifies AI behavior
  15-security-engineer             review of the delta's surfaces

PHASE 3 — HARDENING
  16-observability-engineer (~)    signals for new behavior
  28-product-analytics-engineer(~) events for new behavior; existing funnels stay intact
  23-performance-load-engineer (~) only if the delta touches a budgeted path
  17-validation-test-engineer      the delta's tests GREEN + the FULL inherited
                                   regression suite GREEN — the case invariant
  18-code-reviewer                 delta diff review                              ↺ owners

PHASE 4 — DELIVERY
  21-infrastructure-platform-eng(~) only if the delta needs new platform resources
  22-infrastructure-guardian (~)   review of any infra delta
  20-documentation-runbook-writer  UPDATE canonical docs; release notes for the delta
  19-cicd-deployment-engineer      ship, with rollback for a live product
  [H] GATE 3: release approval
  01-delivery-orchestrator         summary + canonical docs/ UPDATED with the delta (§6.3)
```

---

## Phase-by-phase

Each step names what the agent receives and produces *in this case*. Agent scope is defined once in the roster; this is not restated here. Only the steps that **differ from `greenfield`** are described in detail — for every other step, `greenfield.md`'s entry applies unchanged, with the delta substituted for the packet.

**KEY INVARIANT: shipped behavior is protected.** Every step consumes the canonical baseline and may extend it; no step may silently change or discard it. A contradiction between the delta and shipped behavior is an `open_question` for the human, never a decision an agent makes on its own.

### Phase 0 — Delta discovery & design

1. **Orchestrator boot (`01`).** Receives the delta packet and the prior run's closure citation. **Refuses to proceed if the prior run is not closed** (§6.1). Creates the run workspace, registers the gates, and routes the delta.
2. **Requirements Analyst (`02`) — delta review.** Receives the delta packet plus the **canonical** requirements and glossary. Produces a delta review: which requirements are new, which shipped ones this intentionally changes, and which glossary terms the delta adds or redefines. A new requirement that contradicts shipped behavior becomes an `open_question` — never a silent override. Terms already in the canonical glossary are reused verbatim; a synonym introduced here is a defect in the making.
   - **`[H]` GATE 1 — Scope.** The approver signs the **delta**, explicitly including any shipped behavior it changes.
3. **UX / design chain (`03`, `24`, `29`, conditional).** Each works on **new and changed surfaces only**, with the existing inventory as context. `24` **extends** the canonical design system — a new token or component variant, not a re-founding; a change to an existing token is a change to every shipped screen and must be called out as such at Gate 2. All three are skipped for headless or API-only deltas.
4. **Solution Designer (`04`) — delta design.** Receives the approved delta and the canonical architecture. Produces the impact design: which existing components the increment touches, which boundaries it crosses, what it adds. It does **not** re-derive the architecture. A delta that cannot fit the canonical architecture is a finding for the human, not a licence to redesign the product inside an increment.
5. **Architecture Guardian (`08`) — impact review.** Reviews against the **canonical** architecture rather than greenfield: are the touched components correctly identified, are dependency directions preserved, does the delta introduce a boundary violation the baseline did not have? **↺** to `04`.
   - **`27` (conditional)** audits new and changed surfaces. **`26` (conditional)** engages only when the delta changes what data is collected, retained, or sent to a provider.
   - **`[H]` GATE 2 — Design.** The approver confirms the *impact*, not a new architecture.
6. **Bundle Compiler (`05`).** Emits **only new and changed tasks**. Unchanged shipped behavior is out of bundle scope — but the regression suite that protects it is not, which is the next step's concern.
7. **Bundle Intake Validator (`06`).** Checks delta coverage in both directions: every new requirement reaches a task, **and** every task that touches shipped behavior reaches a regression check. A bundle that covers the delta but leaves the inherited suite unreferenced is incomplete. **↺** to `05`.

### Phase 1 — Planning

8. **Product Planner (`07`).** Per-slice plans for the delta, ordered by value. Each plan's out-of-scope list is load-bearing here in a way it is not in greenfield: it names the shipped behavior this slice must leave alone.

### Phase 2 — Build

**Foundation Engineer (`09`) — normally not used.** The repository, tooling, shared primitives, and local runtime already exist; an increment adopts them. `09` is engaged only when the delta genuinely requires a new shared primitive or a change to the environment contract, and that is a Gate 2 decision, not a build-time one.

9. **Contract & Client Guardian (`10`).** The case-critical step. The contract in force has **live consumers**, so this agent's breaking-change detection is doing real work rather than guarding a hypothetical. Additive change proceeds; a breaking change requires a versioned path and a consumer-migration order, exactly as in `deprecation`. Every contract change routes here — no inline edits.
10. **Data & Migration Engineer (`11`, conditional).** Migrations now run against **live data**. Forward migration plus a rollback note; a destructive migration still requires explicit human approval.
11. **Integration Engineer (`12`, conditional).** New providers only. Existing fakes and adapters are reused, not re-authored.
12. **Implementers (`13`, `14`, `25`).** Build the delta. `greenfield.md`'s entries apply, with one addition: a change to a shared or already-shipped component is a boundary touch and is recorded as such in the handoff.
13. **Security Engineer (`15`).** Reviews the delta's surfaces, plus any shipped surface the delta re-exposes.

### Phase 3 — Hardening

14. **Observability and analytics (`16`, `28`, conditional).** Signals and events for new behavior. `28` extends the existing taxonomy; an event rename breaks a live funnel and is treated as a breaking change, not a cleanup.
15. **Performance & Load Engineer (`23`, conditional).** Engaged when the delta touches a path with an existing budget — the budget is inherited from the baseline, not re-derived.
16. **Validation & Test Engineer (`17`) — the case invariant.** The delta's own tests must be green **and the full inherited regression suite must be green**. A green delta with any inherited test red is not an increment; it is a regression. **↺** Any red routes to the owning implementer.
17. **Code Reviewer (`18`).** Delta-diff review, with a case-specific lens: does anything in this diff change shipped behavior that Gate 1 did not approve?

### Phase 4 — Delivery

18. **Infrastructure (`21`, `22`, conditional).** Engaged only if the delta needs new platform resources; `22` reviews any infra delta.
19. **Documentation & Runbook Writer (`20`).** **Updates** the canonical document set rather than authoring a new one, and writes release notes covering the delta and anything it changed.
20. **CI/CD (`19`) + `[H]` GATE 3 — Release.** Ships to a **live** product: rollback is a first-class requirement, and the migration job (if any) is wired before app rollout.
21. **Orchestrator close-out (`01`).** Final summary; promotes the delta into canonical `docs/` (§6.3) by **updating** requirements, glossary, architecture, and contracts — not replacing them — so the next increment diffs against a baseline that includes this one.

---

## Loop-backs used

| Finding | Detected by | Routed to |
|---|---|---|
| Prior run not closed (open risk / question / unsigned Gate 3) | 01, at boot | Human via Orchestrator (blocking; the increment does not open) |
| Delta contradicts shipped behavior | 02 | Human via Orchestrator (blocking open_question) |
| Delta redefines an existing glossary term | 02 | Human via Orchestrator (blocking) |
| Delta does not fit the canonical architecture | 04 / 08 | Human via Orchestrator (blocking; not an in-run redesign) |
| Boundary violation the baseline did not have | 08 | 04 |
| Design-system token change affects shipped screens | 24 | Human via Orchestrator, at Gate 2 |
| Accessibility finding on a new or changed surface | 27 | 03 / 24 / 29 |
| Breaking contract change with live consumers | 10 | 04 (versioned path + migration order) |
| Needed contract or schema change during build | 13 / 14 | 10 / 11 |
| Inherited regression test red | 17 | Owning implementer |
| Diff changes shipped behavior Gate 1 did not approve | 18 | Owning implementer, or Human via Orchestrator if scope |
| Increment touches the area of a prior run's accepted risk | Anyone | New risk ID with `supersedes:`, re-accepted at this run's gate (§6.5) |
| Anything untraceable to the delta packet or canonical baseline | Anyone | Human via Orchestrator (blocking) |

Full semantics: `../agent-handoff-protocol.md` §4.

**Accepted risks do not transfer.** A risk formally accepted in a prior run does not cover new work. When an increment touches its area, the first agent to detect it raises a **new** risk ID referencing the old one (e.g. `supersedes: R-011 @ 2026-06-comedor-mvp`), and this run's gate approver must re-accept or resolve it (§6.5).

---

## Closure criteria

An increment run is closed when (protocol §6.1): Gate 3 is `approved` and signed (or the run is formally cancelled per §6.4); every risk ID is terminal — including any risk raised under §6.5 to supersede a prior acceptance; every gate condition is closed; zero unanswered open questions remain in the final `state.md`. At closure the Orchestrator **updates** the canonical artifacts (§6.3) with the delta, leaving a baseline that includes this increment for the next one to diff against.

## Worked example

none yet
