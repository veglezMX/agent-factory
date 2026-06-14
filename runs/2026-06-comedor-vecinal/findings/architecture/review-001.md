# Architecture Review 001 — Comedor Vecinal

**Run:** 2026-06-comedor-vecinal
**Reviewer:** 08-architecture-guardian (handoff 0010 → 0011)
**Scope reviewed:** `02-design/architecture.md`, `02-design/stack-decision-record.md`, `02-design/integration-inventory.md`, `02-design/ux-inventory.md` against `01-requirements/requirements.md` (FR-01..24, INV-01..19), packet §§2, 7–14, 16, amendment-001, and handoff 0009.
**Method:** checklist review per handoff 0010. Read-only; no design text was modified.

---

## 1. Checklist verdicts

| # | Checklist item | Verdict |
|---|---|---|
| 1 | Boundary completeness (FR/INV ownership) | **CONCERN** (F-01) — all FRs and INVs covered; four FRs deliberately split across two modules |
| 2 | Dependency directions | **PASS** |
| 3 | Data ownership / single writer / DB-layer append-only | **PASS** |
| 4 | Vote anonymity structure (A-§F) | **CONCERN** (F-02) — structural intent right, one correlation channel unaddressed |
| 5 | Fake/adapter symmetry, deterministic scenarios, data minimization | **PASS** |
| 6 | Frontend isolation | **PASS** |
| 7 | Consistency posture (§11, money paths) | **PASS** |
| 8 | Constraint conformance (packet §14, FR-24 routing, INV-18) | **PASS** (one note, F-05) |
| 9 | Risk handling (R-004, R-005) | **PASS with conditions** (F-03, F-04) |

### Item 1 detail — FR/INV coverage audit

Every FR-01..24 and every INV-01..19 has at least one named owner with a mechanism. No orphans. Dual listings (all explicitly annotated as halves in architecture.md §2, none accidental):

- **FR-06** — menu owns the flag; the cancel/notify/refund cascade is an application-layer orchestration over ordering (architecture.md §4). The cascade half has no single module owner — it is owned by the app-layer use case.
- **FR-12** — kitchen-hours (gate authority, `is_kitchen_open`) + ordering (gate enforcement inside the placement transaction).
- **FR-24** — identity-registry (removal orchestration) + credit-ledger (payout legs, movements).
- **INV-05, INV-10, INV-11, INV-16** — analogous deliberate splits, each with an unambiguous enforcement point.

### Item 2 detail — dependency graph

Edges (architecture.md §4): ordering → {menu, kitchen-hours, credit-ledger, notifications}; identity-registry → {credit-ledger, audit, SmsPort}; credit-ledger → PaymentsPort. menu, kitchen-hours, polls, notifications, audit have zero outbound module edges. Graph is acyclic. **Nothing depends on ordering** holds, including the FR-06/INV-12 cascade and INV-16 close (both app-layer orchestrations; menu and kitchen-hours never import ordering). **Credit-ledger depends only on its payments port** — verified: no edge from credit-ledger to ordering, menu, or polls; callers pass opaque references (§4). Edges are CI-enforced via import-linter (SDR-03).

### Item 3 detail — data ownership

§3 table: exactly one writing module per table group. `credit_movement` writer is credit-ledger only; ordering, identity-registry, and the payments adapter all go through the ledger's internal API. Append-only is enforced **at the database layer**: app role granted INSERT+SELECT only plus a BEFORE UPDATE/DELETE trigger (§5.1) — two independent layers, not application convention. Same mechanism for `audit_entry` (§5.7). Ordering snapshots dish name + unit price onto `order_line` at placement and never joins back to live menu prices (§5.2 step 3) — INV-03 satisfied without menu-data ownership. `credit_account` balance is a ledger-maintained projection with `CHECK (balance >= 0)` (INV-01) and a nightly re-derivation check.

### Item 7 detail — consistency posture

Ledger writes are synchronous and transactional, no queue, no fire-and-forget (§5.1). Order placement = one transaction including the charge (§5.2); cancellations + refunds one transaction; removal step 1 (mark removed + freeze + audit + persist payout legs) one transaction (§5.6). Removal-refund **movements recorded only on provider confirmation** — this is provider-asynchrony done correctly (movements reflect money that actually moved, packet §11), not an eventual-consistency shortcut. Top-up crediting is server-verified and idempotent per provider payment id (§8; integration-inventory §1). No money path relies on eventual consistency.

### Item 8 detail — constraint conformance

Cost math re-checked: 835 (hosting) + 270–1,360 (SMS) = 1,105–2,195 MXN ≈ SDR-08's 1,100–2,200, under the 2,500 ceiling (A-§D); DigitalOcean is card-payable (packet §14). Launch-month spike "may brush the ceiling once" is disclosed to the approver, not hidden. FR-24's payout leg is routed exclusively through credit-ledger → PaymentsPort.`refund_payment` (integration-inventory §1); identity-registry only initiates via the ledger API — no second money path exists. INV-18 write path: same-transaction audit insert + DB-layer append-only (§5.7) — an action committing without its audit entry is structurally impossible.

---

## 2. Findings

| ID | Severity | Finding | Cites |
|---|---|---|---|
| F-01 | non-blocking | **Split FR ownership needs a designated primary owner for downstream traceability.** FR-06, FR-12, FR-24 (and split-half invariants INV-05/10/11/16) are deliberately co-owned with annotated halves. The design is internally consistent and every enforcement point is unambiguous, but downstream agents (test ownership, contract ownership) need a single accountable module per FR. Condition C-1. | architecture.md §2, §4; checklist item 1 |
| F-02 | non-blocking | **Vote-anonymity claim is structurally sound at the schema level but overstated for raw SQL access.** `poll_ballot` has no resident column, no FK, no shared surrogate (§5.4) — good. However, participation and ballot are inserted **in one transaction**, so in PostgreSQL both rows share the `xmin` transaction id; sequential surrogate keys or a `created_at` column would add further correlation channels. An administrator with raw SQL access (explicitly inside the §9 threat model: "anonymous to everyone, including administrators") could link recent ballots to participants. The separation IS structural (satisfies A-§F as a schema property), but the sentence "the schema cannot answer 'how did X vote' even with raw SQL access" is not fully true as designed. Condition C-4; risk R-008. | architecture.md §5.4; A-§F; packet §9; INV-06 |
| F-03 | non-blocking | **R-005 proposal (device session + per-operator PIN) is sound and packet-consistent, but lacks PIN brute-force controls.** INV-07 preserved (every operator SMS-verified once against the registry); accountability per action; PIN re-entry on destructive actions; no resident data in the operator shell; SMS cost flat. Missing: PIN attempt throttling/lockout and audit of failed PIN attempts on the shared device. Accepted as the R-005 resolution **with** condition C-5. New risk R-009. | architecture.md §6; FR-01, INV-07; packet §8, §9, §12, §14 |
| F-04 | non-blocking | **R-004 handled correctly — no stakeholder decision invented.** Newest-first partial-refund allocation is a deterministic, ledger-traceable mechanic implementing A-§A.15, argued from provider refund windows; the designer invited overrule — **this review accepts newest-first as designed**, conditional on R-003 sandbox validation (the window/partial-refund facts are provider claims, not yet verified). The residual-shortfall policy is properly left open and batched per packet §16, with a usable mitigation (pre-confirm refundable/residual split in A-06). Conditions C-2, C-3. | architecture.md §5.6; integration-inventory §1; A-§A.15; packet §16 |
| F-05 | note | **Webhook intake is an inbound path into credit-ledger not drawn as an edge.** §4 shows credit-ledger → PaymentsPort (outbound); provider webhooks arrive inbound and perform "the same idempotent ledger call as return-polling" (integration-inventory §1). Single-writer discipline is preserved (the adapter goes through the ledger's internal API and never writes rows). Cosmetic: the module-boundary doc should name the webhook endpoint as part of credit-ledger's adapter surface so the import-linter contract covers it. | architecture.md §4, §8; integration-inventory §1 |
| F-06 | note | **kitchen-hours as an eighth module is a justified deviation from the seven-module suggestion.** FR-19's dual-role ownership (admin schedule vs operator override) lands in one module with two write paths, keeping packet §8's role separation clean and giving ordering a single `is_kitchen_open` authority. No action. | architecture.md §2, §5.5; FR-19; packet §8 |
| F-07 | note | **SDR-02 push-back (contrib.admin rejected for production) is correct and required.** Default edit surfaces would contradict packet §8 / INV-02 / INV-18, bypass FR-24 orchestration, and break the generated-clients rule. The pattern-vs-technology reading of A-§B is faithful. No action. | stack-decision-record SDR-02; packet §8; INV-02, INV-18 |
| F-08 | note | **R-006 gating language endorsed.** FR-02's real-format parser must not be implemented against a guessed layout (packet §16); fake-first fixtures keep everything else unblocked. Carried as condition C-3. | integration-inventory §3; packet §14, §16 |

**Blocking findings: 0.**

---

## 3. New risks

| ID | Sev | Risk | Mitigation path |
|---|---|---|---|
| R-008 | low | Recent ballots correlatable to participants by a raw-SQL administrator via shared transaction id (`xmin`), sequential keys, or timestamps on `poll_ballot` — weakens the §9/A-§F anonymity claim for the window before rows are frozen/rewritten | Condition C-4: non-sequential ballot keys, no timestamp column, periodic `VACUUM FREEZE` (or equivalent rewrite) on `poll_ballot`, and narrow the written claim in architecture.md §5.4 accordingly |
| R-009 | low | Per-operator PIN on the enrolled shared tablet is brute-forceable absent attempt limits; a guessed PIN forges per-action accountability (packet §8) | Condition C-5: PIN attempt throttling + lockout + audited failures; security-engineer review of PIN policy |

---

## 4. Overall verdict

**CLEAN-WITH-CONDITIONS** — no boundary violations, no dependency-direction breaks, no data-ownership violations, no requirement-coverage gaps, no packet contradictions. Gate 2 may proceed provided the following conditions are recorded:

- **C-1** (F-01): publish a primary-owner designation for FR-06, FR-12, FR-24 (one line each) in the design or trace matrix before test/contract ownership is assigned downstream.
- **C-2** (F-04, R-003): Mercado Pago sandbox validation of multi-payment partial refunds and refund windows completes before the FR-24 mechanism is treated as Gate-2-final (already specified in integration-inventory §1; elevated here to a gate condition).
- **C-3** (R-004 remainder, R-006): the two stakeholder asks — residual-shortfall policy and a sample registry Excel sheet — are batched per packet §16; FR-02 real-format parsing and A-06 residual policy do not get implemented past the designed mitigations until answered.
- **C-4** (F-02, R-008): polls implementation must specify the anonymity mechanics (non-sequential ballot keys, no ballot timestamps, transaction-artifact mitigation) and architecture.md §5.4's raw-SQL claim is corrected or the mechanism made true.
- **C-5** (F-03, R-009): R-005 PIN scheme gains attempt throttling/lockout with audited failures; flag for security-engineer review.

None of these requires looping back to 04-solution-designer; all are recordable as gate conditions and downstream work items.
