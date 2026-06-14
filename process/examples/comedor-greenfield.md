# Worked Example — Greenfield applied to Comedor Vecinal

**What this is:** The [`greenfield`](../playbooks/greenfield.md) recipe run against one concrete product — **Comedor Vecinal**, a private community-canteen app (daily menu, prepaid credits, online top-up, menu polls, kitchen order queue). It shows what each agent receives and produces *for this specific project*, where the recipe's abstract steps become concrete artifacts.

**How to read it:** the playbook is the case logic; this is the instance. For agent scope see `../agent-roster.md`; for handoff/gate mechanics see `../agent-handoff-protocol.md`; for the abstract step order see the playbook.

**Real artifacts:** the live run workspace is `../../runs/2026-06-comedor-vecinal/` — frozen packet, requirements, design docs, gate records, and sequential handoffs. That run is live through Phase 0 (design, Gate 2). The narrative below covers all phases to show the full shape of a greenfield run.

---

## Phase 0 — Discovery & Design

### `02` Requirements Analyst

**Produces for this project:**

- Requirements document: 3 roles, 5 journeys (A, A′, B, C, D, E), 11 MUST features, the 9 plain-language business rules restated as candidate invariants.
- Glossary promoted to ubiquitous language: credit, registry, cycle, the four order states, published/draft.
- Batched open questions even though the packet is "complete." Example findings: *Journey D says cancellation refunds automatically, §8 says operators can never modify balances — confirm the refund is system-initiated, not operator-initiated. §6 says votes are anonymous but tracks "who voted" — confirm participation is recorded separately from ballot content.*

**`[H]` GATE 1 — Scope:** approver answers the questions and signs the requirements. (`../../runs/2026-06-comedor-vecinal/gates/gate-1-scope.md`)

### `03` UX Flow Designer

- **Resident shell** (mobile, Android-first, large text): Login (phone → OTP), Today's Menu, Order Confirmation, My Orders, Wallet (balance + history + top-up), Top-up Result, Polls, Poll Results, Notifications.
- **Operator shell** (shared tablet): Order Queue (oldest-first per Journey D), Menu Editor (draft/publish), Poll Admin.
- **Admin area** (desktop): Resident Registry (import/sync), Roles, All Transactions, Audit View.
- Route-state inventory per screen; the insufficient-credits path of Journey A′ specified as a first-class state of Order Confirmation, not an error toast.

### `04` Solution Designer

- **Service decomposition (6):** identity, menu, credit-ledger, notification, poll, ordering — with a data-ownership map (ordering stores a *price snapshot* at placement per rule 3; credit-ledger is the only writer of credit movements; ordering *coordinates* deduction through the ledger's API, never writes ledger rows).
- **Dependency directions:** ordering → menu (read), ordering → credit-ledger (command), ordering → notification (event); poll → identity (eligibility read); nothing depends on ordering.
- **Consistency decision:** synchronous, transactional ledger writes — from §11's "wrong balances are worse than downtime."
- **Integration inventory (3):** payment (Stripe; fake first), SMS (proposal; fake first), registry importer (file-based, matching the admins' spreadsheet).
- **Frontend topology:** two shells + admin area, shared foundation, generated clients only, MSW mocks contract-aligned.
- Stack decision record with packet-traceable rationale.

### `08` Architecture Guardian → **`[H]` GATE 2 — Design**

Reviews boundary completeness, dependency directions, no service owning another's data, fake/adapter symmetry, frontend isolation. **↺** Violations return to `04`; re-review until clean (`../../runs/2026-06-comedor-vecinal/findings/architecture/review-001.md`). Cost-relevant choices (hosting, SMS provider) surface at the gate.

### `05` Bundle Compiler → `06` Bundle Intake Validator

Bundle: 6 OpenAPI contracts; schemas for residents, menus, orders, ledger, polls, notifications; foundation, shared, 3 integrations, 6 services, 2 shells + admin, security, observability; validation (invariant suite from the 9 rules; E2E from journeys A–E; acceptance gate from §13's 8 examples); containerization, CI/CD, deployment, documentation, release — plus the dependency graph. The Validator checks every journey reaches an E2E task, every rule an invariant, every screen a frontend task; **↺** blocking gaps to `05`.

## Phase 1 — Planning

### `07` Product Planner

Per vertical slice, ordered by business value: (1) access — registry import + OTP login; (2) menu — draft/publish/view; (3) credits — ledger + top-up with fake payment; (4) ordering — place/accept/deliver/cancel with refund; (5) notifications; (6) polls.

## Phase 2 — Build

- **`09` Foundation:** monorepo, package management, lint/format, shared primitives (error envelope, ID generation, clock abstraction for testable poll cycles), env contracts, db/gateway foundations, local compose runtime (services + db + fakes). Exit: fresh clone → running local env.
- **`10` Contract & Client Guardian:** the six OpenAPI contracts using glossary terms verbatim (states are `placed|accepted|delivered|cancelled` — nothing else, anywhere); typed clients; MSW handlers from the same contracts.
- **`11` Data & Migration:** ledger table **append-only** (no UPDATE/DELETE paths, enforced at the database layer); non-negative balance transactionally; one-vote-per-resident-per-poll as a uniqueness constraint; order rows carry the price snapshot. Seeds: demo registry, sample menu, deterministic test residents.
- **`12` Integration:** payment fake (deterministic success/failure/abandon for Journey B), SMS fake (records OTP sends for tests), registry importer (parses the admins' actual spreadsheet). Real Stripe/SMS adapters stubbed (fake-first per §7).
- **`15` Security review #1:** OTP flow (rate limiting on request/verify, code expiry, lockout), token lifecycle, the role/permission matrix from §8, integration egress (only the phone number to SMS; nothing user-identifying to payment beyond Stripe's needs).
- **`13` Backend Domain:** shared → identity → menu → credit-ledger → notification → poll → ordering. Ordering last because it consumes menu, ledger, and notification. Contract/schema changes trigger `↺ 10` / `↺ 11`.
- **`14` Frontend:** shared foundation (i18n es-MX, theme, a11y, auth token flow) → resident shell → operator shell → resident screens (incl. insufficient-credits state) → operator screens (queue oldest-first, menu editor, poll admin) → admin screens → composition. Every string in i18n from the first commit.

## Phase 3 — Hardening

- **`16` Observability:** correlation IDs across order → ledger → notification (the chain operators debug); health checks per service; metrics on the ordering window (the only peak per §11); redaction — phone numbers and ballot content never logged (§9).
- **`17` Validation & Test ladder:** stub conformance → invariants (balance never negative under concurrent orders; ledger rejects mutation; double-vote rejected; price snapshot survives menu republish; refund-on-cancel atomic) → contract tests → frontend integration (incl. A′) → E2E (A, A′, B success/fail/abandon, C incl. not-in-registry rejection, D incl. cancel-with-refund, E) → conformance sweep → acceptance gate (the 8 examples from §13, executed literally).
- **`18` Code Reviewer:** full-diff; blockers `↺` to the owning implementer; security smells to `15`, boundary smells to `08`.
- **`15` Security review #2:** permission-matrix spot-checks (operator genuinely cannot read balances; admin genuinely cannot see ballot content), secret handling, CORS, rate limits, audit-log coverage. High findings block release.

## Phase 4 — Delivery

- **`19` CI/CD pipeline pass:** lint → typecheck → unit → contract validation → integration → E2E (against fakes) → image build → dependency/image scan → publish; staging + production config with rollback; migration job before app rollout; staging smoke-checked.
- **`20` Documentation:** developer setup, local-run guide, API notes, operator runbook (kitchen tablet workflow, what to do when a payment webhook fails, how to run a registry import), deployment/rollback notes, release notes, known limitations (e.g. credit expiration deferred to LATER per §4).
- **`19` Release readiness + `[H]` GATE 3:** release evidence assembled; approver authorizes; CI/CD executes.
- **`01` Close-out:** delivery summary; promotes requirements, glossary, architecture, contracts to canonical `docs/` for the next increment; archives the open-question seed.
