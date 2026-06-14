---
handoff: 0009
run: 2026-06-comedor-vecinal
from: 04-solution-designer
to: 01-delivery-orchestrator
task: 02-design/architecture-stack-integrations
status: complete
gate_impact: gate-2
inputs:
  - runs/2026-06-comedor-vecinal/handoffs/0008-orchestrator-to-solution-designer.md
  - runs/2026-06-comedor-vecinal/01-requirements/requirements.md
  - runs/2026-06-comedor-vecinal/01-requirements/glossary.md
  - runs/2026-06-comedor-vecinal/02-design/ux-inventory.md
  - runs/2026-06-comedor-vecinal/00-packet/stakeholder-input-packet.md
  - runs/2026-06-comedor-vecinal/00-packet/amendment-001.md
  - runs/2026-06-comedor-vecinal/gates/gate-1-scope.md
  - runs/2026-06-comedor-vecinal/state.md
outputs:
  - runs/2026-06-comedor-vecinal/02-design/architecture.md
  - runs/2026-06-comedor-vecinal/02-design/stack-decision-record.md
  - runs/2026-06-comedor-vecinal/02-design/integration-inventory.md
decisions:
  - "Modular monolith over one PostgreSQL, 8 modules with CI-enforced boundaries — single ACID transaction is the correctness tool §11 demands; service split rejected on cost §14/A-§D and 3-person ops §2"
  - "credit-ledger is the ONLY writer of credit movements (INV-02); append-only enforced at the database layer (grants + trigger); ordering charges/refunds through the ledger's in-process API inside one transaction (§11)"
  - "Nothing depends on ordering; the no-longer-available cascade (FR-06/INV-12) and kitchen-close queue resolution (INV-16) are application-layer orchestrations in single transactions"
  - "Price snapshot on order lines at placement (INV-03); pickup code confirmed server-side in the delivered transition (INV-14); UNIQUE(poll_id,resident_id) + unjoinable ballot table (INV-06, A-§F)"
  - "Django ADOPTED on merits (§11 transactions, §2/§14 ops); django.contrib.admin REJECTED for the production Admin shell — default edit surfaces conflict with §8/INV-02/INV-18 and FR-24 orchestration; Admin shell is the third generated-client SPA styled to Django-admin patterns (A-§B)"
  - "PostgreSQL justified by invariants (CHECK for INV-01/INV-19, UNIQUE for INV-06, grants+triggers for INV-02/INV-18, row locks for §11); DRF + OpenAPI with generated TS clients and contract-aligned mocks per handoff 0008"
  - "Hosting: VPS + managed Postgres (DigitalOcean, card-payable §14) ≈ 835 MXN/mo; SMS: Twilio (login codes only, A-§E) ≈ 270–1,360 MXN/mo; combined ≈ 1,100–2,200 MXN vs 2,500 ceiling (A-§D) — fits, thin worst case flagged as R-007"
  - "R-004 payout-leg allocation decided: newest-first, partial-refund per payment, per-leg idempotency, movement recorded on provider confirmation; removal stands regardless of payout outcome (§9 access-loss is packet-stated); residual-shortfall policy NOT invented — left open"
  - "R-005 resolved by proposal: long-lived operator-shell device session + per-operator PIN (enrolled via one FR-01 login each), PIN re-entry on destructive actions, per-action operator attribution; keeps INV-07 and SMS cost flat (§14)"
risks:
  - "R-003 (open, med, unchanged): Mercado Pago partial-refund coverage across multiple historical top-ups — sandbox validation plan specified in integration-inventory.md §1; gates FR-24 mechanism"
  - "R-004 (updated, med, partially resolved): allocation + failure/retry semantics now designed (architecture.md §5.6); OPEN remainder = policy for residual balance when refundable card amounts < remaining balance — stakeholder question to batch per §16; mitigation: A-06 shows refundable/residual split pre-confirm, residual stays visible on the frozen account"
  - "R-005 (updated, low, proposed-closed): shared-tablet design in architecture.md §6 pending 08-architecture-guardian review; no packet conflict found"
  - "R-006 (new, med): registry Excel parser can only be pinned by a sample of the admins' actual sheet (§14); request to stakeholder (batch per §16); fake-first fixtures keep work unblocked, but real-format parsing must not be implemented against a guess (§16)"
  - "R-007 (new, low): SMS unit-cost and FX variability vs the 2,500 MXN ceiling — worst modeled case ≈ 2,200 MXN leaves ~300 headroom; mitigations structural (long-lived sessions, per-phone rate limits, named local-aggregator fallback behind SmsPort)"
open_questions: []
next_recommended: 08-architecture-guardian
---

## Context summary

Gate 1 approved with a stack preference (lean Python/Django — justify or push
back). Binding constraints: 2,500 MXN/month ceiling for hosting + SMS (§14,
A-§D); three browser shells (§12) for ~400 residents with ~200 inside the peak
hour (§11); correctness over availability, always (§11); Mercado Pago confirmed
for top-ups in and removal refunds out (A-§C, FR-24); SMS for login codes only
(A-§E); registry Excel import that never removes anyone (INV-17); fake-first
integrations (§7). Handoff 0008 assigned R-004 (payout-leg semantics) and
R-005 (shared-tablet session) to this design, mandated explicit module
boundaries and data ownership reviewable by 08, and set the frontend rule:
three shells, generated API clients only, contract-aligned mocks.

## What was done

- **architecture.md** — modular monolith decision argued from the constraints;
  8 modules (identity-registry, menu, kitchen-hours, ordering, credit-ledger,
  polls, notifications, audit) with a data-ownership map (single writer per
  table group), dependency directions ("nothing depends on ordering";
  credit-ledger sole writer of credit movements), and the invariant-bearing
  mechanics: DB-layer append-only ledger and audit trail, price snapshot,
  one-vote uniqueness with participation/ballot separation, kitchen-hours
  model, pickup-code model, removal-refund flow, transactional synchronous
  ledger writes. R-004 and R-005 addressed in §5.6 and §6. Frontend topology
  per handoff 0008 in §7.
- **stack-decision-record.md** — SDR-01..10: Django adopted with rationale;
  contrib.admin honestly assessed and pushed back for production use;
  PostgreSQL justified via invariants; hybrid-light frontend (three small SPA
  bundles, 200 KB resident budget); hosting + SMS proposals with MXN estimates
  vs the ceiling; backup line (indefinite retention, §9); i18n approach (§10).
- **integration-inventory.md** — Mercado Pago, SMS, Excel import: per
  integration the interface boundary (port + owning module), deterministic
  fake behavior (success/failure/abandon per J-B; recorded sends; fixture
  workbooks), error mapping, retry/timeout posture, and data minimization
  (phone numbers only to the SMS provider, §9).

## What was NOT done and why

- No code, schemas-as-DDL, or API contract files — out of this agent's remit;
  contracts belong to the contract/client guardian and implementers downstream.
- The residual-shortfall policy for the removal refund (R-004 remainder) was
  **not** decided — it is a stakeholder policy choice (§16), not a design
  mechanic; mitigation specified instead.
- The frontend component library was not fixed — SDR-04 sets binding budgets
  and constraints and delegates the library pick to 14-frontend-feature-builder.
- No exact provider rate-card figures asserted — orders of magnitude with a
  stated FX assumption; verification flagged (R-007, R-003).

## Boundary touches

Wrote only under `02-design/` plus this handoff. Did not touch `state.md`
(orchestrator-owned), the packet, requirements, or gates.

## Verification performed

- Cross-checked every INV-01..19 has an explicit design mechanism
  (architecture.md §5 + SDR-05); every FR-01..24 is owned by exactly one
  module (architecture.md §2).
- Checked glossary-verbatim usage in all three documents (credit movement,
  removal refund, pickup code, kitchen hours, no longer available, week menu,
  daily dish, audit trail, registry import, the four order states).
- Confirmed no time estimates appear in any of the three documents.
- Cost arithmetic re-checked against the 2,500 MXN ceiling (SDR-08): expected
  ≈1,100–1,550; worst modeled ≈2,200.

## Notes for the receiver

- Recommend routing to **08-architecture-guardian** next (design self-approval
  is forbidden). Review focus suggestions: the newest-first payout allocation
  (architecture.md §5.6 — explicitly overridable), the R-005 device-session +
  PIN proposal (§6), and the contrib.admin push-back (SDR-02), since it
  diverges from half of the Gate 1 preference with cited rationale.
- Two stakeholder items are ready to batch per §16: (a) residual-shortfall
  policy for the removal refund (R-004 remainder); (b) a sample of the
  registry Excel sheet (R-006). Both are cheap asks and unblock 12/13.
- R-003 sandbox validation (Mercado Pago partial refunds) should be scheduled
  with the integration engineer before the FR-24 mechanism is treated as
  Gate-2-final.
