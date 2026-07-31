---
case: greenfield
name: Greenfield Full Build
trigger: Stakeholder Input Packet
entry_criteria:
  - packet exists under 00-packet/, all OPEN items resolved
  - no prior run open (handoff-protocol §6.1; first run has nothing to close)
agents: [01,02,03,04,05,06,07,08,09,10,11,12,13,14,15,16,17,18,19,20,21,22,23,24,25,26,27,28,29]
skills: [creating-stakeholder-packet]
gates: [scope, design, release]
baseline: produces
closure: >
  Gate 3 approved, every risk ID terminal, zero open questions; requirements,
  glossary, architecture, and contracts promoted to canonical docs/ (protocol §6.1, §6.3)
---

# Playbook — Greenfield Full Build

**Purpose:** Take a complete Stakeholder Input Packet for a product that does not yet exist and carry it to a deployed full-stack application. This is the default case and the only one that runs the full roster. Every other case is a narrowing of this one.

**Legend:**

- `[H]` — human gate: the run blocks until the approver acts.
- `↺` — loop-back: findings return work to an earlier agent (full table in `../agent-handoff-protocol.md` §4).
- All ordering reflects dependency, never duration. No stage carries a time estimate.

---

## When to use / when NOT

Use greenfield when the product is being built from zero — no prior run, no canonical `docs/` baseline to diff against.

Do **not** use greenfield when:

- The product already exists and was built by this pipeline, and you are adding a feature → run an **increment** (the greenfield variant below; consumes the canonical baseline).
- The product exists but was **not** built by this pipeline and has no canonical baseline → `brownfield-onboard` (planned) to reconstruct the baseline first, then increment.
- The work is a defect in shipped behavior → `defect` (planned), a lighter lane.

See `README.md` for the case picker.

---

## Entry criteria

Before issuing handoff `0001`, the Orchestrator verifies:

- The packet exists, frozen under `00-packet/`, and all `OPEN` items are resolved (use the `creating-stakeholder-packet` skill if the packet is incomplete).
- No other run is open (protocol §6.1).

---

## Run at a glance

```text
[Human invokes 01-delivery-orchestrator with the packet]

PHASE 0 — DISCOVERY & DESIGN
  02-requirements-analyst          packet → requirements doc + glossary + questions
  [H] GATE 1: scope approval
  03-ux-flow-designer              journeys → screen & flow inventory   (skip if headless/API-only)
  24-visual-design-system-designer branding + a11y → design tokens + component visual specs  (skip if headless)
  29-ui-layout-designer             screens + design system + available data → responsive page layouts + visual baselines  (skip if headless)
  04-solution-designer             requirements + UX → architecture + stack + integration inventory
  08-architecture-guardian         design review                          ↺ 04 on violations
  27-accessibility-auditor         UX + design-system + page-layout a11y review (§10)  ↺ 03/24/29 on findings  (skip if headless)
  [H] GATE 2: design approval
  05-bundle-compiler               plan + design → task bundle
  06-bundle-intake-validator       bundle readiness report                ↺ 05 on blocking gaps

PHASE 1 — PLANNING
  07-product-planner               per-slice implementation plans

PHASE 2 — BUILD
  09-foundation-engineer           repo, tooling, shared, local runtime
  10-contract-client-guardian      contracts + generated clients + mocks
  11-data-migration-engineer       schemas, migrations, seeds, invariants
  12-integration-engineer          provider fakes first, real adapters stubbed
  15-security-engineer (review #1) auth design & integration egress review
  26-privacy-compliance-officer    data obligations review                (conditional: regulated/PII)
  13-backend-domain-implementer    services in dependency order, leaf services last
  25-ai-prompt-engineer            prompts, evals, guardrails per AI feature (conditional: AI in packet)
  14-frontend-feature-builder      shared foundation → shells → screens → composition
  (10/11 re-called on any contract or schema change during build)

PHASE 3 — HARDENING
  16-observability-engineer        logs, metrics, health checks, redaction
  28-product-analytics-engineer    event taxonomy, KPIs/funnels (§1/§3/§4/§13), consent-gated (§9)
  23-performance-load-engineer     load/stress/soak vs budget (§11)       ↺ owning impl on regressions
  29-ui-layout-designer             implemented-page fidelity review       ↺ 14 on implementation gaps; 24 on system gaps
  27-accessibility-auditor         implemented UI a11y audit (WCAG, §10)  ↺ 14 on findings  (skip if headless)
  17-validation-test-engineer      invariants → contract → integration → E2E
                                   → conformance → acceptance gate
  18-code-reviewer                 full diff review                       ↺ 13/14 on blockers
  15-security-engineer (review #2) final security pass                    ↺ 13/12 on findings

PHASE 4 — DELIVERY
  21-infrastructure-platform-eng   provision network, data stores, secrets, DNS/TLS, IAM
  22-infrastructure-guardian       IaC review                             ↺ 21 on findings
  19-cicd-deployment-engineer      pipelines, containers, staging deploy
  20-documentation-runbook-writer  docs, runbooks, release notes
  23-performance-load-engineer     pre-release load gate vs budget
  19-cicd-deployment-engineer      release execution readiness
  [H] GATE 3: release approval
  01-delivery-orchestrator         final delivery summary + canonical promotion (§6.3)
```

---

## Phase-by-phase

Each step names what the agent receives and produces *in this case*. Agent scope is defined once in the roster; this is not restated here.

### Phase 0 — Discovery & Design

1. **Orchestrator boot (`01`).** Human invokes the Orchestrator with the packet. It creates the run workspace (protocol §1), registers the gates, and routes the packet to the Requirements Analyst. From here the human talks to the Orchestrator; specialists are reached through it.
2. **Requirements Analyst (`02`).** Receives the packet. Produces the structured requirements document, the glossary promoted to ubiquitous language (every later artifact uses these words, no synonyms), and a **batched** list of open questions. Ambiguity and contradiction become questions, never guesses.
   - **`[H]` GATE 1 — Scope.** Approver answers the questions and signs the requirements. Nothing downstream starts first.
3. **UX Flow Designer (`03`).** Receives approved requirements, journeys, device constraints. Produces the screen inventory per shell with route-level states (loading / empty / error / unauthorized / success). **Skipped for headless or API-only products.**
   - **3a. Visual & Design-System Designer (`24`).** Receives the UX inventory and packet §10 (branding & accessibility). Produces the design system — tokens (color, type scale, spacing, radius, elevation, motion), component visual specs and states, light/dark theming, responsive breakpoints, and contrast/focus compliance — attached to 03's screens so `14` implements to spec instead of improvising. **Skipped for headless or API-only products.**
   - **3b. UI Layout Designer (`29`).** Receives the UX inventory, design system, relevant data requirements and any already-defined endpoint/client shapes. Produces per-page data-to-UI mappings, responsive compositions, state layouts, interaction notes, and visual acceptance baselines under `02-design/ui-layouts/`. Any missing data is recorded as a dependency rather than invented. **Skipped for headless or API-only products.**
4. **Solution Designer (`04`).** Receives requirements, glossary, UX inventory, UI layouts/data dependencies, constraints, and reliability posture. Produces service decomposition with a data-ownership map, dependency directions, the consistency decision, the integration inventory (fake-first), frontend topology, contract/schema skeletons that reconcile approved UI data needs, and a stack decision record with packet-traceable rationale.
5. **Architecture Guardian review (`08`).** Reviews the design for boundary completeness, dependency directions, no service owning another's data, fake/adapter symmetry, frontend isolation. **↺** Violations return to `04`; re-review until clean.
   - **5a. Accessibility Auditor (`27`) — design-gate review.** Receives 24's design-system accessibility spec, 03's route-state inventory, and 29's responsive/state layouts. Audits them before UI build. **↺** Findings return to `24` (system), `03` (flow), or `29` (page composition); re-review until clean. **Skipped for headless or API-only products.**
   - **`[H]` GATE 2 — Design.** Approver confirms stack and architecture. Cost-relevant choices surface here against the packet's constraints section.
6. **Bundle Compiler (`05`).** Receives approved requirements + design. Produces the task bundle (intake, contracts, data, foundation, shared, integrations, services, frontend, security, observability, validation, containerization, CI/CD, deployment, documentation, release) plus the dependency graph and execution order. Validation tasks are seeded from business rules (invariants), journeys (E2E), and the packet's acceptance examples.
7. **Bundle Intake Validator (`06`).** Checks that every journey reaches an E2E task, every business rule reaches an invariant test, and every screen/layout/visual baseline reaches a frontend or validation task; no orphans or duplicates; execution order respects the graph. **↺** Blocking gaps return to `05`; non-blocking gaps are logged in `state.md`.

### Phase 1 — Planning

8. **Product Planner (`07`).** Receives the validated bundle. Produces implementation plans per **vertical slice** (ordered by business value), not per layer. Each plan: goal, scope, out-of-scope, affected artifacts, sequence, testing strategy, risks. No time estimates.

### Phase 2 — Build

9. **Foundation Engineer (`09`).** Repo layout, package management, lint/format, shared primitives, environment contracts, database/gateway foundations, local runtime. **Exit check:** a fresh clone reaches a running local environment via documented commands.
10. **Contract & Client Guardian (`10`).** Authors the contracts from design skeletons using glossary terms verbatim, generates typed clients, seeds contract-aligned mocks. **From here, every API change routes back through `10` — no inline edits.**
11. **Data & Migration Engineer (`11`).** Schemas + migrations with rollback notes. Invariants made structural where possible (append-only, uniqueness, non-negative constraints enforced at the database layer). Deterministic seed data.
12. **Integration Engineer (`12`).** Each external provider built twice behind one interface: a deterministic fake (success / failure / abandon scenarios) first, the real adapter stubbed for later. Error mapping, retry/timeout policy, and data-minimization toward providers defined per provider.
13. **Security review #1 (`15`).** Checkpoint before domain implementation: auth flow design (rate limiting, expiry, lockout), token lifecycle, the role/permission matrix from the packet, and integration egress (minimum data to each provider). Findings become constraints on the next step.
    - **13a. Privacy & Compliance Officer (`26`) — conditional (regulated/PII).** Reviews packet §9 obligations alongside security #1: lawful basis, data minimization toward providers, retention/deletion enforceability, residency, and data-subject rights. Findings become constraints, the same way 15's do. Engaged only when the packet involves regulated or PII-heavy data.
14. **Backend Domain Implementer (`13`).** Services implemented in dependency order — shared utilities first, leaf/consumer services last (a service that consumes others comes after them). Each lands with service-level tests. Any contract or schema change triggers `↺ 10` / `↺ 11`, never an inline edit.
    - **14a. AI & Prompt Engineer (`25`) — conditional (AI in packet).** For each AI/LLM feature named in packet §4/§7: designs and versions prompts, selects the model with a decision record, builds the eval harness (golden sets + regression), wires guardrails (injection defense, output validation, fallback), and sets token/cost budgets. Consumes `12`'s raw provider adapter; never reimplements it. Runs only on AI-bearing products.
15. **Frontend Feature Builder (`14`).** Starts as soon as contracts are stable (mock-backed; does not wait for all services): shared foundation → shells → screens and route states implementing 29's approved compositions and 24's system rules. All API access uses generated clients; every user-facing string uses i18n; supplied visual baselines receive component/visual-regression coverage when tooling exists.

### Phase 3 — Hardening

16. **Observability Engineer (`16`).** Structured logs with correlation IDs across the critical chain, health checks per service, metrics on the peak that matters, redaction rules from the packet's privacy section.
    - **16a. Performance & Load Engineer (`23`).** Derives performance budgets/SLOs from packet §11 and the §3 critical journeys; runs load / stress / soak / spike suites against the local or staging runtime (provider fakes); profiles hot paths; validates latency, throughput, and headroom against budget. Consumes 16's signals as measurement input. Regressions `↺` to the owning implementer; budgets are never quietly raised to pass.
    - **16b. Product Analytics & Instrumentation Engineer (`28`).** Triangulates a product-measurement plan from §1 (north-star KPI), §3 (funnels/drop-off), §4 (priority-weighted adoption), and §13 (success conditions); implements a consent-gated event taxonomy and KPI/funnel dashboards, with payload redaction and retention from §9. Distinct lens from 16 (operator diagnosis vs product measurement); consumes 16's telemetry but never owns it. Behavior changes `↺` to `13`; unclear lawful basis routes to `26`.
    - **16c. UI Layout Designer (`29`) — fidelity review.** Compares implemented pages against the data-to-UI maps, responsive/state layouts, and visual baselines. **↺** Implementation gaps return to `14`; global token/component gaps return to `24`; re-review until clean. **Skipped for headless or API-only products.**
    - **16d. Accessibility Auditor (`27`) — implementation review.** Audits 14's implemented shells, screens, and route-level states against packet §10 (WCAG POUR, keyboard/screen-reader completion of §3 journeys, reflow/zoom, state announcements). **↺** Findings return to `14`, `29`, or `24` according to ownership; re-review until clean. **Skipped for headless or API-only products.**
17. **Validation & Test Engineer (`17`).** Runs the ladder in order: (1) stub conformance, (2) invariants (business rules as executable tests), (3) contract tests (services and mocks vs the contract truth), (4) frontend integration (route states incl. non-happy paths), (5) E2E (journeys incl. failure paths), (6) conformance sweep, (7) acceptance gate (the packet's examples, executed literally). Failures route to the owning implementer; the ladder restarts from the failed rung.
18. **Code Reviewer (`18`).** Full-diff review. Blocking findings `↺` to the owning implementer; security smells route to `15`, boundary smells to `08`. Re-review after fixes.
19. **Security review #2 (`15`).** Final pass: permission-matrix enforcement spot-checks, secret handling, CORS, rate limits, audit-log coverage. High findings block release.

### Phase 4 — Delivery

- **Provisioning, before any deploy — Infrastructure & Platform Engineer (`21`) + Infrastructure Guardian (`22`).** `21` provisions the platform as IaC from the design and packet §11/§14/§9: network, managed data stores, secret store, DNS/TLS, CDN, least-privilege IAM, and the compute/runtime targets — plan-before-apply, no destructive or shared/prod apply without recorded approval. `22` reviews the plan/change-set for least privilege, public surface, destructive changes, drift, and cost sizing; **↺** findings return to `21`. Boundary: `21` provisions the targets, `19` deploys onto them.
20. **CI/CD pipeline pass (`19`).** Pipelines (lint → typecheck → unit → contract → integration → E2E against fakes → image build → dependency/image scan → publish), deployment config for staging and production with rollback, migration job wired before app rollout, staging deploy smoke-checked.
21. **Documentation & Runbook Writer (`20`).** Developer setup, local-run guide, API notes, operator runbook, deployment/rollback notes, release notes, known-limitations list — strictly from implemented behavior.
22. **Release readiness (`19`, second pass) + `[H]` GATE 3.** The CI/CD agent assembles release evidence (bundle conformance, contracts aligned, migrations validated with rollback, security findings resolved or accepted, infrastructure reviewed by `22` with no destructive surprises, performance budgets met under peak (§11, from `23`), observability on critical flows, full ladder green, acceptance gate green, staging verified, rollback documented, runbook updated, limitations documented). Approver authorizes; CI/CD executes.
23. **Orchestrator close-out (`01`).** Final delivery summary; promotes requirements, glossary, architecture, and contracts into canonical `docs/` (protocol §6.3) so the next increment has a baseline to diff against. Archives the open-question seed for the next packet.

---

## Loop-backs used

| Finding | Detected by | Routed to |
|---|---|---|
| Requirement ambiguity or contradiction | 02, or anyone later | Human via Orchestrator (blocking) |
| Architecture violation in design | 08 | 04 |
| Architecture violation in code | 08 / 18 | 13 or 14 |
| Bundle gap | 06 | 05 |
| Needed API change during build | 13 / 14 | 10 |
| Needed schema change during build | 13 | 11 |
| Security finding | 15 | Owning implementer (12 / 13 / 14) |
| Infrastructure finding (IAM, exposure, destructive change) | 22 | 21 |
| Performance regression vs budget (§11) | 23 | Owning implementer |
| Page-layout fidelity or responsive/state mismatch | 29 | 14 for implementation; 24 for global system gap; 03 for flow gap |
| Privacy / compliance finding | 26 | Owning implementer (11 / 12 / 13) |
| Failing invariant / E2E / acceptance | 17 | Owning implementer |
| Review blocker | 18 | Owning implementer |
| Anything untraceable to packet or design | Anyone | Human via Orchestrator (blocking) |

Full semantics: `../agent-handoff-protocol.md` §4.

## Parallelization notes

Safe to run concurrently once contracts are stable: frontend (mock-backed) alongside backend services; integration fakes alongside data work; documentation drafting alongside hardening (finalized only after behavior stabilizes). Never parallelize: anything across an unresolved gate, two agents editing the same boundary, or implementation against an unapproved contract change.

---

## Growing the product after release — see `increment.md`

Greenfield builds a product that does not yet exist. Once it is released, further scope runs as an **increment**: the same roster, phases, and gates, with the inputs shrunk to a delta and the baseline relationship inverted from `produces` to `consumes`. That is its own case — [`increment.md`](increment.md) — because greenfield's defining assumption, that nothing exists yet, is precisely what an increment contradicts.

---

## Closure criteria

A greenfield run is closed when (protocol §6.1): Gate 3 is `approved` and signed (or the run is formally cancelled per §6.4); every risk ID is terminal (resolved or formally accepted by the gate approver's name); every gate condition is closed; zero unanswered open questions remain in the final `state.md`. At closure the Orchestrator promotes canonical artifacts (§6.3).

## Worked example

`../examples/comedor-greenfield.md` — this recipe applied to the Comedor Vecinal community-canteen product, linking the real run workspace under `runs/2026-06-comedor-vecinal/`.
