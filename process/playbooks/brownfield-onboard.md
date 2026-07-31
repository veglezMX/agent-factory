---
case: brownfield-onboard
name: Brownfield Onboard
trigger: Existing foreign codebase + thin packet
entry_criteria:
  - a running (or runnable) foreign codebase exists, NOT built by this pipeline
  - a thin packet exists under 00-packet/ naming the system, its owners, and what is known
  - no canonical docs/ baseline exists yet (nothing to diff against)
  - no prior run open (handoff-protocol §6.1)
agents: [01,02,03,04,05,06,07,08,10,11,12,13,14,15,16,17,18,19,20,21,22,26,27,28]
skills: [creating-stakeholder-packet]
gates: [scope, design, release]
baseline: produces
closure: >
  Gate 3 (baseline-approval variant, protocol §3.4) signed: the reconstructed
  requirements, glossary, architecture, contracts, and data model are validated
  by characterization tests and promoted to canonical docs/; every code-vs-packet
  discrepancy resolved as an answered open question; zero open risks (protocol §6.1, §6.3)
---

# Playbook — Brownfield Onboard

**Purpose:** Take an existing codebase this pipeline did **not** build, plus a thin packet, and reconstruct the canonical baseline — requirements, glossary, architecture, contracts, data model — by reverse-engineering the running system, validating that reconstruction against actual behavior, getting it approved, and promoting it to `docs/`. This case **produces** the baseline that a later `greenfield` increment run consumes. It does **not** add features and it does **not** change behavior. It is the on-ramp for a foreign system to enter the pipeline.

**Legend:**

- `[H]` — human gate: the run blocks until the approver acts.
- `↺` — loop-back: findings return work to an earlier agent (full table in `../agent-handoff-protocol.md` §4).
- All ordering reflects dependency, never duration. No stage carries a time estimate.

---

## When to use / when NOT

Use brownfield-onboard exactly once per foreign system: the first time a codebase built outside this pipeline needs to enter it, and no canonical `docs/` baseline exists to diff against.

Do **not** use brownfield-onboard when:

- The product was built by this pipeline and canonical `docs/` already exist → run **greenfield**'s increment variant; the baseline is already canonical, so reconstruction is wasted work.
- There is no product yet — building from zero → **greenfield**.
- The work is a defect in shipped behavior of an already-onboarded system → `defect` (planned), a lighter lane.
- You actually want to *add* a feature to the foreign system. Onboard first to establish the baseline, **then** the change runs as a `greenfield` increment against it. This case never carries the feature.

See `README.md` for the case picker.

---

## Entry criteria

Before issuing handoff `0001`, the Orchestrator verifies:

- The foreign codebase is present and either running or runnable locally — reconstruction is grounded in observed behavior, not in reading source alone.
- A **thin packet** exists, frozen under `00-packet/`. "Thin" means it names the system identity (§1), known users/roles (§2), and whatever business truth the current owners can state — but it is expected to be incomplete and partly wrong. Use the `creating-stakeholder-packet` skill to capture what the owners *can* state; the gaps it leaves are the reconstruction's job to fill from the code, not to invent.
- No canonical `docs/` baseline exists (if one does, this is the wrong case — see above).
- No other run is open (protocol §6.1).

The thin packet is not the source of truth here — the running system is. Where the two disagree, the disagreement is the deliverable (see the key invariant below), never a silent choice in favour of either side.

---

## Run at a glance

```text
[Human invokes 01-delivery-orchestrator with the thin packet + the foreign codebase]

PHASE 0 — RECONSTRUCTION & DESIGN
  02-requirements-analyst          thin packet + observed behavior → reconstructed requirements
                                   + glossary + discrepancy questions (code vs packet)
  [H] GATE 1: scope approval (the reconstructed requirements are what the system DOES)
  03-ux-flow-designer (~)          observed screens → screen & flow inventory   (skip if headless/API-only)
  04-solution-designer             read the code → as-built architecture + data-ownership + integration inventory
  08-architecture-guardian         as-built review: does the doc match the code?  ↺ 04 on mismatch
  22-infrastructure-guardian (~)   as-built infra/deploy review                   ↺ 04 on mismatch
  26-privacy-compliance-officer(~) observed data flows → privacy/retention map of what IS collected
  [H] GATE 2: design approval (the as-built architecture is accurate)
  05-bundle-compiler               reconstruction plan → characterization-task bundle (pin behavior, add nothing)
  06-bundle-intake-validator       coverage report: every observed behavior reaches a characterization task  ↺ 05

PHASE 1 — PLANNING
  07-product-planner               per-area reconstruction plans (which surfaces to characterize, in what order)

PHASE 2 — CHARACTERIZATION (reconstruct only what EXISTS — no new behavior)
  10-contract-client-guardian      reverse-engineer contracts from live endpoints; generate clients/mocks
  11-data-migration-engineer       reverse-engineer schema + invariants from the running database (read-first)
  12-integration-engineer (~)      observe external touchpoints → fakes that mirror real provider behavior
  15-security-engineer (review #1) observed auth/permission model (document, do not harden)
  13-backend-domain-implementer    characterization tests pinning current backend behavior (no behavior change)
  14-frontend-feature-builder      characterization tests pinning current frontend/route-state behavior
  (any code-vs-packet gap here → blocking open_question, never a silent assumption)

PHASE 3 — VALIDATION
  16-observability-engineer (~)    document existing signals/health surface (what IS emitted)
  28-product-analytics-engineer(~) document existing product events/funnels (what IS tracked)
  27-accessibility-auditor (~)     as-built a11y audit of the observed UI → findings, no fixes
  23 — NOT USED (no perf budget to establish on an as-built baseline)
  17-validation-test-engineer      run the characterization ladder: does the reconstructed baseline reproduce
                                   the system's actual behavior?                  ↺ 04/10/11 on doc-vs-code drift
  18-code-reviewer                 review the reconstruction (docs+tests) for fidelity, not for code quality  ↺ owners

PHASE 4 — BASELINE PROMOTION
  19-cicd-deployment-engineer      wire the characterization suite into CI as the regression net
  21-infrastructure-platform-eng(~) capture as-built provisioning/runtime as baseline infra docs
  20-documentation-runbook-writer  assemble the reconstructed baseline doc set (strictly from observed behavior)
  [H] GATE 3: baseline-approval (protocol §3.4)  — sign off the reconstructed baseline; no new deployment
  01-delivery-orchestrator         promote reconstruction to canonical docs/ (§6.3); the actual change now
                                   runs as a greenfield increment against this baseline
```

---

## Phase-by-phase

Each step names what the agent receives and produces *in this case*. Agent scope is defined once in the roster; this is not restated here. The constant below every step is the **key invariant**: reconstruct only what exists. Characterization tests pin current behavior; no new behavior is introduced anywhere in this run. Every discrepancy between the code and the thin packet becomes a blocking `open_question` routed to the human via `01` — never a silent assumption about which side is "right".

### Phase 0 — Reconstruction & Design

1. **Orchestrator boot (`01`).** Human invokes the Orchestrator with the thin packet and a pointer to the foreign codebase. It creates the run workspace (protocol §1), registers the gates (Gate 3 is the baseline-approval variant, §3.4), and routes the thin packet plus the codebase to the Requirements Analyst. From here the human talks to the Orchestrator.
2. **Requirements Analyst (`02`).** Receives the thin packet and the running system. Produces the **reconstructed** requirements document and glossary describing what the system *does today* — derived from observed behavior, with the thin packet as a hint, not as truth. Every place the code contradicts the thin packet (a rule the packet states but the system doesn't enforce, a behavior the system has that the packet omits) becomes a batched `open_question`. It reconstructs; it never designs or improves.
   - **`[H]` GATE 1 — Scope.** Approver confirms the reconstructed requirements faithfully describe current behavior and answers every discrepancy question. Approval here means "yes, this is what it does" — not "this is what it should do".
3. **UX Flow Designer (`03`, conditional).** Receives the reconstructed requirements and the running UI. Produces the screen and route-state inventory **as it exists today** — including the non-happy states the system actually has. **Skipped for headless or API-only systems.**
4. **Solution Designer (`04`).** Receives the reconstructed requirements and reads the code. Produces the **as-built** architecture: the actual service decomposition, the real data-ownership map, the dependency directions that exist (including the ones that violate good design — recorded as findings, not fixed), and the integration inventory of touchpoints the system actually calls. This is documentation of reality, not a target design.
5. **Architecture Guardian review (`08`).** Reviews the as-built architecture for *fidelity to the code*, not for cleanliness. The question is "does this document match what the code does?", not "is this a good architecture?". **↺** Inaccuracies return to `04`; re-review until the document is faithful. Genuine architectural smells are logged as findings for the future increment, never repaired here.
6. **Infrastructure Guardian review (`22`, conditional).** When the system ships with its own infrastructure/deploy definition, reviews the as-built infra description for fidelity the same way `08` reviews the application architecture. **↺** Inaccuracies return to `04`. Skipped when there is no infra to reconstruct.
7. **Privacy & Compliance Officer (`26`, conditional).** Maps the data the system *actually* collects, stores, and sends to providers against the thin packet's stated privacy posture. Discrepancies (data collected that the packet never mentioned; retention that differs from stated) become `open_questions`, not silent corrections. Engaged when the system handles regulated or personal data; otherwise skipped.
   - **`[H]` GATE 2 — Design.** Approver confirms the as-built architecture (and infra/privacy maps, if present) accurately describe the system. This gate certifies accuracy of the reverse-engineering, not the approval of a new design.
8. **Bundle Compiler (`05`).** Receives the approved reconstruction. Produces a **characterization-task bundle**: one task per observable behavior to be pinned by a test, plus contract-reconstruction, schema-reconstruction, and documentation tasks. It seeds *characterization* tasks, not feature tasks — there is no new behavior to build. The dependency graph and execution order are emitted as usual.
9. **Bundle Intake Validator (`06`).** Checks coverage in the brownfield sense: every observed behavior in the reconstruction reaches a characterization task, every live endpoint reaches a contract-reconstruction task, every screen reaches a frontend characterization task; no orphans, no tasks that would *add* behavior. **↺** Blocking gaps return to `05`; non-blocking gaps logged in `state.md`.

### Phase 1 — Planning

10. **Product Planner (`07`).** Receives the validated bundle. Produces per-area reconstruction plans (which surfaces to characterize first, ordered by risk and by what the future increment will touch). Each plan: goal, scope (pin existing behavior), out-of-scope (any change), affected artifacts, sequence, validation strategy, risks. No time estimates.

### Phase 2 — Characterization

This phase reverse-engineers and pins. Foundation Engineer (`09`) is **not used**: the repo, tooling, and runtime already exist — onboarding adopts them as-is rather than building them. Every agent below works read-first and treats any code-vs-packet gap as a blocking `open_question`.

11. **Contract & Client Guardian (`10`).** Reverse-engineers the API contracts from the live endpoints (observed request/response shapes), authoring them in glossary terms, then generates typed clients and contract-aligned mocks. From here, the *reconstructed* contract is the API truth of the baseline. It documents the contract the system has; it does not redesign it.
12. **Data & Migration Engineer (`11`).** Reverse-engineers the schema and the data invariants from the running database — structure, constraints, the invariants the data actually upholds. Operates read-first; it writes only the reconstructed schema documentation and, where the pipeline needs them later, non-destructive forward representations. It never ships a migration that changes the foreign data in this run.
13. **Integration Engineer (`12`, conditional).** For each external touchpoint the system actually calls, builds a deterministic fake that mirrors the *observed* provider behavior (the success/failure/abandon shapes the system already handles). Skipped when the system has no external integrations.
14. **Security review #1 (`15`).** Documents the system's *observed* auth flow, token lifecycle, and role/permission model as they exist. It records weaknesses as findings for the future increment; it does **not** harden anything in this run (hardening is new behavior). High-severity findings are raised as risks the baseline carries forward, named and tracked.
15. **Backend Domain Implementer (`13`).** Writes **characterization tests** that pin the current backend behavior — capturing what each service returns today, including quirks and bugs, as the reference. It does not change service code. Where behavior is ambiguous or undocumented, that ambiguity is an `open_question`, never a guess encoded into a test.
16. **Frontend Feature Builder (`14`).** Writes characterization tests pinning the current frontend behavior and the route states that actually exist (including the missing or broken non-happy paths — documented, not fixed). It consumes the reconstructed clients; it does not alter UI behavior.

### Phase 3 — Validation

17. **Observability Engineer (`16`, conditional).** Documents the signals the system *already* emits — existing logs, metrics, health surface — and the redaction (or lack of it) that is in place. It adds no instrumentation in this run; gaps are findings for the future increment. Skipped when there is nothing to document.
18. **Product Analytics & Instrumentation Engineer (`28`, conditional).** Documents the product instrumentation that **already exists** — the event taxonomy actually emitted, where it is sent, which funnels or KPIs are currently derived from it, and what personal data those events carry. Follows the same rule as `15` and `16`: record, do not improve. Untracked journeys and un-redacted event payloads are findings for the future increment, and an event carrying personal data the thin packet never disclosed is a code-vs-packet discrepancy routed to `26` and to the human. Skipped when the system emits no product analytics.
19. **Accessibility Auditor (`27`, conditional).** Audits the UI **as it exists today** against the screen inventory from `03`, producing the as-built accessibility baseline: keyboard reachability, focus order, announced states, contrast, reflow. It fixes nothing — remediation is new behavior, which this case forbids. Findings are carried forward as named, accepted risks so the future increment inherits a known starting point rather than discovering it. Skipped for headless or API-only systems, exactly as `03` is.
20. **Performance & Load Engineer (`23`) — not used.** A brownfield baseline records what the system does, not a performance budget it should meet; there is no target to validate against. Performance characterization belongs to the later increment that introduces a budget.
21. **Validation & Test Engineer (`17`).** Runs the characterization ladder: do the reconstructed contracts, schema, and tests faithfully reproduce the running system's behavior? A test that fails because the *doc* is wrong (not the code) is doc-vs-code drift and routes back to the producing agent (`↺ 04 / 10 / 11`); the reconstruction is corrected to match reality, the system is never changed to match the reconstruction.
22. **Code Reviewer (`18`).** Reviews the reconstruction — the docs and the characterization tests — for **fidelity**, not for code quality of the foreign system. Blocking findings (a test that asserts behavior the system doesn't have, a contract that misdescribes an endpoint) `↺` to the producing agent. Architecture smells route to `08`, security smells to `15` — but only ever as recorded findings for the increment, never as in-run fixes.

### Phase 4 — Baseline Promotion

Delivery here promotes a *baseline*, not a deployment. Gate 3 is the **baseline-approval** variant (protocol §3.4): it certifies the reconstructed baseline, it does not authorize a release.

23. **CI/CD & Deployment Engineer (`19`).** Wires the characterization suite into CI as the regression net so that the future increment can detect when it changes baseline behavior. It builds no new deploy path and ships nothing to production in this run.
24. **Infrastructure & Platform Engineer (`21`, conditional).** Captures the system's as-built provisioning and runtime as baseline infrastructure documentation, so the increment has an accurate starting point. It provisions nothing new. Skipped when there is no infrastructure to capture.
25. **Documentation & Runbook Writer (`20`).** Assembles the reconstructed baseline document set — requirements, glossary, architecture, contracts, data model, and the carried-forward findings/limitations list (which now includes the accessibility and analytics findings from `27` and `28`) — strictly from observed behavior. This is the artifact Gate 3 signs.
26. **Baseline approval (`[H]` GATE 3, §3.4) + Orchestrator close-out (`01`).** The approver signs off that the reconstructed baseline is accurate and complete (every discrepancy resolved, every characterization test green, zero open risks). The Orchestrator then promotes requirements, glossary, architecture, contracts, and data model into canonical `docs/` (§6.3). With a baseline now in force, the actual change runs as a **greenfield increment** against it.

---

## Loop-backs used

| Finding | Detected by | Routed to |
|---|---|---|
| Code-vs-packet discrepancy (any gap between system and thin packet) | 02, or anyone later | Human via Orchestrator (blocking open_question) |
| Reconstructed architecture does not match the code | 08 | 04 |
| Reconstructed infra does not match the deploy definition | 22 | 04 |
| Observed data flow contradicts the packet's privacy posture | 26 | Human via Orchestrator (blocking) |
| Existing analytics event carries personal data the thin packet never disclosed | 28 | 26, then Human via Orchestrator (blocking) |
| Bundle gap (observed behavior with no characterization task) | 06 | 05 |
| Reconstructed contract misdescribes a live endpoint | 18 / 17 | 10 |
| Reconstructed schema/invariant misdescribes the database | 18 / 17 | 11 |
| Characterization test asserts behavior the system lacks (doc-vs-code drift) | 17 | Producing agent (04 / 10 / 11 / 13 / 14) |
| Reconstruction infidelity in review | 18 | Producing agent |
| Anything ambiguous, undocumented, or untraceable to observed behavior | Anyone | Human via Orchestrator (blocking) |

Full semantics: `../agent-handoff-protocol.md` §4. Note the asymmetry unique to this case: drift is always resolved by correcting the *reconstruction*, never by changing the *system* — changing the system would be new behavior, which this case forbids.

---

## Closure criteria

A brownfield-onboard run is closed when (protocol §6.1, with the §3.4 baseline-approval gate standing in for the release gate): Gate 3 is `approved` and signed (or the run is formally cancelled per §6.4); every risk ID is terminal (resolved, or formally accepted by the gate approver's name — including security/architecture smells carried forward as accepted risks for the future increment); every code-vs-packet discrepancy is an answered open question, with zero unanswered open questions in the final `state.md`; the characterization ladder is green, proving the baseline reproduces actual behavior. At closure the Orchestrator promotes the reconstructed requirements, glossary, architecture, contracts, and data model into canonical `docs/` (§6.3) so the subsequent increment run has a baseline to diff against.

## Worked example

none yet
