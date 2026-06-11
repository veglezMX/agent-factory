# Execution Playbook — Comedor Vecinal

**Purpose:** A worked, end-to-end run of the agent roster against the Comedor Vecinal Stakeholder Input Packet. It shows the exact order in which agents are called, what each one receives and produces in this specific project, where the human gates sit, and where loops back occur.

**Assumptions:**

- The Stakeholder Input Packet exists, is complete, and all `OPEN` items have been answered (Stripe confirmed as payment provider; SMS provider to be proposed; cost ceiling confirmed).
- Agent numbering follows the Development Agent Roster (01–20).
- The human approver is the single contact named in packet §16.

**Legend:**

- `[H]` — human gate: the run blocks until the approver acts.
- `↺` — loop-back: findings return work to an earlier agent.
- All ordering reflects dependency, never duration. No stage carries a time estimate.

---

## The Run at a Glance

```text
[Human invokes 01-delivery-orchestrator with the packet]

PHASE 0 — DISCOVERY & DESIGN
  02-requirements-analyst          packet → requirements doc + glossary + questions
  [H] GATE 1: scope approval
  03-ux-flow-designer              journeys → screen & flow inventory
  04-solution-designer             requirements + UX → architecture + stack + integration inventory
  08-architecture-guardian         design review                          ↺ 04 on violations
  [H] GATE 2: design approval
  05-bundle-compiler               plan + design → task bundle
  06-bundle-intake-validator       bundle readiness report                ↺ 05 on blocking gaps

PHASE 1 — PLANNING
  07-product-planner               per-slice implementation plans

PHASE 2 — BUILD
  09-foundation-engineer           repo, tooling, shared, local runtime
  10-contract-client-guardian      contracts + generated clients + mocks
  11-data-migration-engineer       schemas, migrations, seeds, invariants
  12-integration-engineer          payment fake, SMS fake, registry importer
  15-security-engineer (review #1) auth design & integration egress review
  13-backend-domain-implementer    shared → identity → menu → credit-ledger
                                   → notification → poll → ordering
  14-frontend-feature-builder      shared → resident shell → operator shell
                                   → screens → composition
  (10/11 re-called on any contract or schema change during build)

PHASE 3 — HARDENING
  16-observability-engineer        logs, metrics, health checks, redaction
  17-validation-test-engineer      invariants → contract → integration → E2E
                                   → conformance → acceptance gate
  18-code-reviewer                 full diff review                       ↺ 13/14 on blockers
  15-security-engineer (review #2) final security pass                    ↺ 13/12 on findings

PHASE 4 — DELIVERY
  19-cicd-deployment-engineer      pipelines, containers, staging deploy
  20-documentation-runbook-writer  docs, runbooks, release notes
  19-cicd-deployment-engineer      release execution readiness
  [H] GATE 3: release approval
  01-delivery-orchestrator         final delivery summary
```

---

## Phase 0 — Discovery & Design

### Step 1 — Orchestrator boot (`01`)

The human invokes the Delivery Orchestrator with the packet. The Orchestrator creates the run log, registers the three gates, and routes the packet to the Requirements Analyst. From this point on, the human talks to the Orchestrator; specialists are reached through it.

### Step 2 — Requirements Analyst (`02`)

**Receives:** the full packet.
**Produces for this project:**

- A structured requirements document: 3 roles, 5 journeys (A, A′, B, C, D, E), 11 MUST features, the 9 plain-language business rules restated as candidate invariants.
- The glossary (credit, registry, cycle, the four order states, published/draft) promoted to ubiquitous language — every later artifact must use these words and no synonyms.
- Open questions, batched. Example findings for this packet even though it is "complete": *Journey D says cancellation refunds automatically, §8 says operators can never modify balances — confirm the refund is system-initiated, not operator-initiated. §6 says votes are anonymous but tracks "who voted" — confirm participation is recorded separately from ballot content.*

**`[H]` GATE 1 — Scope approval.** The approver answers the batched questions and signs off the requirements document. Nothing downstream starts before this.

### Step 3 — UX Flow Designer (`03`)

**Receives:** approved requirements, journeys, device constraints (§10, §12).
**Produces:**

- **Resident shell** (mobile browser, Android-first, large text): Login (phone → OTP), Today's Menu, Order Confirmation, My Orders, Wallet (balance + history + top-up entry), Top-up Result, Polls, Poll Results, Notifications.
- **Operator shell** (shared tablet): Order Queue (oldest-first per Journey D), Menu Editor (draft/publish), Poll Admin.
- **Admin area** (desktop): Resident Registry (import/sync), Roles, All Transactions, Audit View.
- Route-state inventory: every screen specified with loading / empty / error / unauthorized / success states; the insufficient-credits path of Journey A′ specified as a first-class state of Order Confirmation, not an error toast.

### Step 4 — Solution Designer (`04`)

**Receives:** requirements, glossary, UX inventory, constraints (§14), reliability posture (§11: correctness over availability).
**Produces:**

- **Service decomposition (6):** identity, menu, credit-ledger, notification, poll, ordering — with a data-ownership map (e.g., ordering stores a *price snapshot* at placement per business rule 3; credit-ledger is the only writer of credit movements; ordering *coordinates* deduction through the ledger's API, never writes ledger rows).
- **Dependency directions:** ordering → menu (read), ordering → credit-ledger (command), ordering → notification (event); poll → identity (eligibility read); nothing depends on ordering.
- **Consistency decision:** synchronous, transactional ledger writes — derived directly from §11's "wrong balances are worse than downtime."
- **Integration inventory (3):** payment provider (Stripe; fake first), SMS provider (proposal included; fake first), registry importer (file-based, matching the admins' existing spreadsheet per §14).
- **Frontend topology:** two shells + admin area, shared frontend foundation, generated API clients only, MSW mocks contract-aligned.
- **Stack decision record** with packet-traceable rationale for each choice.

### Step 5 — Architecture Guardian review (`08`)

**Receives:** the full design.
**Checks:** boundary completeness against requirements, dependency directions, no service owning another's data, fake/adapter symmetry, frontend isolation from backend internals.
**↺ Loop:** violations return to the Solution Designer with findings; the Guardian re-reviews the revision. Repeats until clean.

**`[H]` GATE 2 — Design approval.** The approver confirms the stack and architecture. Cost-relevant choices (hosting, SMS provider) surface here against §14.

### Step 6 — Bundle Compiler (`05`)

**Receives:** approved requirements + approved design.
**Produces:** the task bundle — intake, contracts (6 OpenAPI specs), data (schemas for residents, menus, orders, ledger, polls, notifications), foundation, shared, integrations (3), services (6), frontend (2 shells + admin), security, observability, validation (invariant suite seeded from the 9 business rules; E2E suite seeded from journeys A–E; acceptance gate seeded from §13's 8 examples), containerization, CI/CD, deployment, documentation, release — plus the dependency graph and execution order.

### Step 7 — Bundle Intake Validator (`06`)

**Receives:** the compiled bundle.
**Checks:** every journey reaches at least one E2E task; every business rule reaches at least one invariant test; every screen in the UX inventory reaches a frontend task; no orphans, no duplicates; execution order respects the dependency graph.
**↺ Loop:** blocking gaps return to the Bundle Compiler. Non-blocking gaps are logged in the run state.

---

## Phase 1 — Planning

### Step 8 — Product Planner (`07`)

**Receives:** validated bundle.
**Produces:** implementation plans per vertical slice rather than per layer, in this order of business value: (1) access — registry import + OTP login; (2) menu — draft/publish/view; (3) credits — ledger + top-up with fake payment; (4) ordering — place/accept/deliver/cancel with refund; (5) notifications; (6) polls. Each plan lists goal, scope, out-of-scope, affected artifacts, sequence, testing strategy, and risks. The Orchestrator uses these plans to drive Phase 2.

---

## Phase 2 — Build

### Step 9 — Foundation Engineer (`09`)

Monorepo layout, package management, lint/format, shared primitives (error envelope, ID generation, clock abstraction for testable poll cycles), environment contracts, database and gateway package foundations, local compose runtime (services + database + fake providers), bootstrap scripts. **Exit check:** a fresh clone reaches a running local environment via documented commands.

### Step 10 — Contract & Client Guardian (`10`)

Authors the six OpenAPI contracts from the design skeletons, using glossary terms verbatim (states are `placed|accepted|delivered|cancelled` — nothing else, anywhere). Generates typed clients for backend-to-backend and frontend use; seeds MSW handlers from the same contracts. **From this point, every API change in the run routes back through this agent — no exceptions.**

### Step 11 — Data & Migration Engineer (`11`)

Schemas + migrations with rollback notes. Project-specific invariants made structural where possible: the ledger table is **append-only** (no UPDATE/DELETE paths exposed; enforced at the database layer, not just the application layer); non-negative balance enforced transactionally; one-vote-per-resident-per-poll as a uniqueness constraint; order rows carry the price snapshot. Seed data: a demo registry, a sample menu, deterministic test residents.

### Step 12 — Integration Engineer (`12`)

Three fakes behind production-shaped interfaces: a payment fake with deterministic success/failure/abandon scenarios (driving Journey B and its failure path), an SMS fake that records OTP sends for tests, and the registry importer that parses the admins' actual spreadsheet format. Error mapping and retry/timeout policy defined per provider. Real Stripe and SMS adapters are stubbed for a later task — fake-first per packet §7.

### Step 13 — Security review #1 (`15`)

Checkpoint before domain implementation: OTP flow design (rate limiting on request/verify, code expiry, lockout), token lifecycle, the role/permission matrix compiled from packet §8, and integration egress (only the phone number goes to the SMS provider; nothing user-identifying goes to the payment provider beyond what Stripe requires). Findings feed directly into the next step's constraints.

### Step 14 — Backend Domain Implementer (`13`)

Service order follows the dependency graph:

```text
shared backend utilities
→ identity        (registry sync, OTP, sessions, roles, audit)
→ menu            (draft/publish, version history, price source of truth)
→ credit-ledger   (append-only movements, balance, top-up via payment interface)
→ notification    (dispatch, list, read state)
→ poll            (cycles, one-vote constraint, results, close)
→ ordering        (placement with snapshot + ledger deduction, queue transitions,
                   cancellation with automatic refund, notification events)
```

Ordering comes last because it consumes menu, ledger, and notification. Each service lands with service-level tests. Any needed contract or schema adjustment triggers `↺ 10` or `↺ 11` — never an inline edit.

### Step 15 — Frontend Feature Builder (`14`)

Starts as soon as contracts are stable (mock-backed; does not wait for all services):

```text
shared frontend foundation   (i18n es-MX, theme, a11y baseline, auth token flow)
→ resident shell             (login, navigation, session handling)
→ operator shell
→ resident screens           (menu, ordering incl. insufficient-credits state,
                              wallet, top-up result, polls, notifications)
→ operator screens           (queue oldest-first, menu editor, poll admin)
→ admin screens              (registry import, roles, transactions, audit)
→ page composition + route-state completion
```

All API access via generated clients; MSW kept contract-aligned; every user-facing string in i18n from the first commit.

---

## Phase 3 — Hardening

### Step 16 — Observability Engineer (`16`)

Structured logs with correlation IDs across the order → ledger → notification chain (the chain operators will actually debug), health checks per service, metrics on the ordering window (§11 says that is the only peak that matters), and redaction rules: phone numbers and ballot content never appear in logs, per packet §9.

### Step 17 — Validation & Test Engineer (`17`)

Runs the validation ladder in order:

1. **Stub conformance** — every bundle task has a real implementation behind it.
2. **Invariants** — the 9 business rules as executable tests (balance never negative under concurrent orders; ledger rejects mutation; double-vote rejected; price snapshot survives menu republish; refund-on-cancel is atomic).
3. **Contract tests** — services and MSW both conform to the OpenAPI truth.
4. **Frontend integration** — route states from the UX inventory, including A′.
5. **E2E** — journeys A, A′, B (success/fail/abandon), C (including not-in-registry rejection), D (including cancel-with-refund), E.
6. **Conformance sweep** — orphan and coverage check across the bundle.
7. **Acceptance gate** — the 8 examples from packet §13, executed literally.

Failures route to the owning implementer via the Orchestrator; the ladder restarts from the failed rung after fixes.

### Step 18 — Code Reviewer (`18`)

Full-diff review. Blocking findings `↺` to the owning implementer; security smells route to `15`, boundary smells to `08`. Re-review after fixes.

### Step 19 — Security review #2 (`15`)

Final pass over the implemented system: permission matrix enforcement spot-checks (operator genuinely cannot read balances; admin genuinely cannot see ballot content), secret handling, CORS, rate limits, audit-log coverage of sensitive admin actions. Findings by severity; high findings block release.

---

## Phase 4 — Delivery

### Step 20 — CI/CD & Deployment Engineer (`19`), pipeline pass

Pipelines: lint → typecheck → unit → contract validation → integration → E2E (against fakes) → image build → dependency and image scan → publish. Deployment configuration for staging and production with rollback path; migration job wired before app rollout; staging deploy executed and smoke-checked.

### Step 21 — Documentation & Runbook Writer (`20`)

Developer setup, local-run guide, API notes, operator runbook (kitchen tablet workflow, what to do when a payment webhook fails, how to run a registry import), deployment and rollback notes, release notes, known limitations (e.g., credit expiration deferred to LATER per packet §4).

### Step 22 — Release readiness (`19`, second pass) and `[H]` GATE 3

The CI/CD agent assembles the release evidence: bundle conformance passed, contracts aligned, migrations validated with rollback, security findings resolved or formally accepted, observability on critical flows, full ladder green, acceptance gate green, staging verified, rollback documented, runbook updated, limitations documented. The approver reviews the evidence and authorizes production release; the CI/CD agent executes it.

### Step 23 — Orchestrator close-out (`01`)

Final delivery summary: what shipped, accepted risks, deferred LATER items, and the open-question archive — the seed material for the next run's packet.

---

## Loop-Back Rules Used in This Run

| Finding | Detected by | Routed to |
|---|---|---|
| Requirement ambiguity or contradiction | 02, or anyone later | Human via Orchestrator (blocking) |
| Architecture violation in design | 08 | 04 |
| Architecture violation in code | 08 / 18 | 13 or 14 |
| Bundle gap | 06 | 05 |
| Needed API change during build | 13 / 14 | 10 |
| Needed schema change during build | 13 | 11 |
| Security finding | 15 | Owning implementer (12 / 13 / 14) |
| Failing invariant / E2E / acceptance | 17 | Owning implementer |
| Review blocker | 18 | Owning implementer |
| Anything untraceable to packet or design | Anyone | Human via Orchestrator (blocking) |

## Parallelization Notes

Safe to run concurrently once contracts are stable: frontend (mock-backed) alongside backend services; integration fakes alongside data work; documentation drafting alongside hardening (finalized only after behavior stabilizes). Never parallelize: anything across an unresolved gate, two agents editing the same boundary, or implementation against an unapproved contract change.
