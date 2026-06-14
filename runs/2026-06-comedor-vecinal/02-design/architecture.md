# Architecture — Comedor Vecinal

**Run:** 2026-06-comedor-vecinal
**Producer:** 04-solution-designer (handoff 0008 → 0009)
**Sources:** `01-requirements/requirements.md`, `01-requirements/glossary.md`, `02-design/ux-inventory.md`, `00-packet/stakeholder-input-packet.md` + `amendment-001.md`, `gates/gate-1-scope.md`, `state.md`
**Status:** Design document for review by 08-architecture-guardian (Gate 2 input). No code, no time estimates. All terms follow the glossary verbatim.

---

## 1. Shape decision: modular monolith

**Decision: one deployable backend process (a modular monolith) over one PostgreSQL database, with module boundaries enforced in code and in CI — not a service fleet.**

Rationale, derived from the packet constraints rather than from the playbook's six-service sketch (per handoff 0008 notes):

- **Cost ceiling 2,500 MXN/month** (packet §14, A-§D): one small VPS plus one managed database is the cheapest topology that still gives managed backups. Every additional service multiplies hosting, monitoring, and deployment surface against a fixed community budget.
- **Operations reality** (packet §2, §16): a 3-person committee, one tech-lead approver. There is no on-call team to operate service meshes, brokers, or distributed tracing. One process, one database, one log stream.
- **Scale** (packet §11): ~400 residents, realistic peak ≈ 200 people within one late-morning hour. This is tens of requests per second at worst — far inside a single small instance's capacity.
- **Correctness over availability, always** (packet §11): "wrong balances worse than downtime." The strongest correctness tool available is the single ACID transaction. In a monolith over one PostgreSQL database, placing an order — kitchen-open check, availability check, price snapshot, order row, credit movement, balance update — is **one database transaction** that either fully commits or fully aborts. A service split would force sagas/compensation for exactly the flows the packet declares most critical. The packet's reliability posture argues *against* distribution, decisively.

The monolith is **modular**: each domain below is a separately-packaged module (a Django app, per `stack-decision-record.md` SDR-01) with a narrow service API, its own tables, and import rules enforced by a linter contract in CI (SDR-03). Module extraction later is possible because boundaries and data ownership are explicit; it is not anticipated to be needed at this scale.

---

## 2. Module decomposition

Eight modules. Seven match the suggested domain list from handoff 0008; **kitchen-hours** is added as a distinct small module because FR-19 splits its ownership across two roles (admin weekly schedule vs operator same-day override, packet §8) and both menu and ordering must consult it without owning it.

| Module | Responsibility | Key requirements |
|---|---|---|
| **identity-registry** | Residents (name, phone number, unit/address, active or removed — packet §6); roles; registry import apply step; phone + SMS-code login; sessions; login reset; resident removal flow (orchestrates the removal refund via credit-ledger) | FR-01, FR-02, FR-03, FR-20, FR-24, INV-07, INV-08, INV-17 |
| **menu** | Week menu and daily dishes; draft → publish lifecycle; per-dish-per-day "no longer available" flag | FR-04, FR-05, FR-06 (flag half), INV-09, INV-11 (data half) |
| **kitchen-hours** | Admin-set weekly schedule + operator same-day open/close override; single authoritative `is_kitchen_open(now)` answer | FR-19, FR-12 (gate half), INV-10, INV-16 |
| **ordering** | Orders and order lines; the four order states **placed / accepted / delivered / cancelled** (glossary); pickup code issue and confirmation; oldest-first queue; per-dish ordered-portions count (FR-11) and per-dish sales history (FR-21) as read models over its own data | FR-07–FR-12, FR-21, INV-03, INV-04, INV-05, INV-12–INV-14, INV-16 |
| **credit-ledger** | Credit movements (append-only) and balances; **sole writer of all credit movements** (INV-02); top-up intake via the payments port; removal refund payout legs via the payments port | FR-13, FR-14, FR-15, FR-22, FR-24, INV-01, INV-02, INV-15, INV-19 |
| **polls** | Polls per cycle; one vote per resident per poll; participation stored separately from ballot content; tallies after close | FR-18, INV-06, A-§F, packet §9 |
| **notifications** | In-app notifications (recipient, message, read/unread — packet §6); mark-all-read. In-app only at launch (A-§E) | FR-16, FR-17 |
| **audit** | Append-only audit trail of the four sensitive admin action classes: role changes, resident add/remove, login resets, registry imports | FR-23, INV-18, A-§A.18 |

Above the modules sits a thin **application layer**: one orchestrator function per use case (e.g., "mark dish no longer available", "remove resident"). It may call any module's service API and opens the single transaction per use case. Modules never reach around it to call each other except along the allowed edges in §4.

---

## 3. Data-ownership map — single writer per table group

Every table group has exactly one writing module. All other modules read through the owner's service API (in-process) or hold opaque IDs. **Cross-module SQL writes are forbidden and CI-enforced.**

| Table group | Owner (sole writer) | Notes |
|---|---|---|
| `resident`, `role_assignment`, `login_session`, `otp_code`, `registry_import_batch`, `device_session`, `operator_pin` | identity-registry | Phone numbers live only here; admin-only visibility (packet §9) |
| `week_menu_dish`, `daily_dish`, `dish_publication`, `dish_availability_flag` | menu | Draft rows carry a state column; published/draft per glossary |
| `weekly_schedule`, `day_override` | kitchen-hours | Admin writes schedule (A-10); operator writes override (O-09); both inside this one module per FR-19 |
| `order`, `order_line`, `order_status_event`, `pickup_code` (column on `order`) | ordering | Status events give the timeline on R-07 |
| `credit_account`, `credit_movement`, `payment_attempt`, `payout_attempt` | **credit-ledger — the ONLY writer of credit movements (INV-02)** | Ordering, identity-registry, and the payments adapter all go through the ledger's internal API; **none of them ever writes a ledger row** |
| `poll`, `poll_option`, `poll_participation`, `poll_ballot` | polls | `poll_ballot` carries **no resident reference** — see §5.4 |
| `notification` | notifications | |
| `audit_entry` | audit | Append-only like the ledger — see §5.7 |

---

## 4. Dependency directions

Allowed module-to-module edges (behavioral calls; ID references are always allowed):

```
ordering  ──reads──▶ menu            (published dishes, prices, "no longer available")
ordering  ──reads──▶ kitchen-hours   (is_kitchen_open)
ordering  ──calls──▶ credit-ledger   (charge / refund, same transaction)
ordering  ──calls──▶ notifications   (order status change notices, FR-16)
identity-registry ──calls──▶ credit-ledger   (initiate removal refund, FR-24)
identity-registry ──calls──▶ audit           (sensitive actions, FR-23)
credit-ledger ──calls──▶ payments port (Mercado Pago adapter — see integration-inventory.md)
identity-registry ──calls──▶ SMS port  (login codes only, A-§E)
```

Hard rules:

- **Nothing depends on ordering.** The "mark no longer available" cascade (menu flag → cancel unfulfillable placed orders, FR-06/INV-12) is orchestrated by the application layer, which calls `menu` then `ordering` in **one transaction** — menu never imports ordering. Likewise kitchen close (INV-16): kitchen-hours records the override; the application layer surfaces the remaining queue via ordering's read API.
- **Credit-ledger depends only on its payments port.** It knows nothing of orders, residents' menus, or polls; callers pass opaque references (order id, resident id, payment id) which the ledger records on the credit movement (who, amount, direction, reason, linked order or payment — packet §6).
- **audit and notifications depend on nothing.** They are written to, never read from, by other modules.
- Edges are encoded as an import-linter contract; a violating import fails CI (boundary reviewability for 08-architecture-guardian).

---

## 5. Invariant-bearing mechanics

### 5.1 Credit-ledger: append-only at the database layer (INV-02), non-negative (INV-01), synchronous (§11)

- `credit_movement` is **append-only enforced in PostgreSQL itself**, not just in code: the application database role is granted `INSERT` and `SELECT` only (no `UPDATE`, no `DELETE`), and a `BEFORE UPDATE OR DELETE` trigger raises an exception as a second layer. No ORM path, admin tool, or bug can edit history (INV-02; packet §8: admins can never edit or delete credit history).
- `credit_account` holds the current balance as a maintained projection with a database `CHECK (balance >= 0)` (INV-01). Every ledger write runs as: `SELECT … FOR UPDATE` on the account row → insert `credit_movement` → update balance — all inside the caller's transaction. A nightly consistency job re-derives each balance from the sum of movements and alarms on any drift (supports AC-05: two administrators independently reviewing history arrive at the balance the app shows).
- **Ledger writes are synchronous and transactional** (packet §11: correctness over availability). There is no queue, no eventual consistency, no "fire and forget" for money. If the ledger write cannot commit, the whole use case aborts and the user sees an error with nothing deducted (J-A′ posture generalized).
- `CHECK` constraint on top-up movements enforces 50–2,000 credits per transaction (INV-19) in the database in addition to the R-09 control.

### 5.2 Order placement: one transaction, price snapshot (INV-03)

Placing an order (R-05 confirm) is a single transaction:

1. `is_kitchen_open(now)` (INV-10; FR-12) — reject outside kitchen hours.
2. Re-read each dish: published, not flagged **no longer available**, and for a daily dish, today is its own day (INV-11, INV-12).
3. **Snapshot** dish name and unit price in credits onto each `order_line`. The order is charged at the price visible at placement; later price edits never touch existing orders because order lines never join back to live menu prices (INV-03).
4. Insert `order` (state **placed**) + lines + pickup code.
5. Call credit-ledger: charge movement + balance update under the account row lock. Insufficient balance ⇒ the transaction aborts, **nothing is deducted and no order is placed**; the API returns the exact shortfall for R-05's insufficient-credits state (J-A′, INV-01, AC-02).

Cancellations are the mirror image: state transition + refund movement in one transaction — resident self-cancel only while **placed** with full credit refund (INV-04); kitchen cancellation always with automatic, immediate refund (INV-05, FR-15, AC-04). All refunds are system-initiated by the event; no endpoint exists for any role to move credits manually (A-§F).

### 5.3 Pickup-code model (INV-14)

A **pickup code** is a short human-readable code (6 characters, unambiguous alphabet — no 0/O/1/I) generated at placement, stored on the order, unique among that day's non-terminal orders (collision → regenerate). The **delivered** transition exists only as "confirm pickup code": the operator's O-03 submission carries the code; the server matches it against the order in the same transaction that sets **delivered** (INV-14, AC-10). A wrong code changes nothing (O-03 error state). Codes are not secrets-grade — they gate handout, not money — but are rate-limited per order to prevent guessing.

### 5.4 One vote per resident per poll (INV-06) with participation/ballot separation (A-§F)

Two tables, deliberately unjoinable:

- `poll_participation(poll_id, resident_id)` with a **database UNIQUE constraint** on `(poll_id, resident_id)` — the second vote attempt fails at the constraint and is rejected with a clear message, never counted (INV-06, J-E, AC-06).
- `poll_ballot(poll_id, option_id)` — **no resident column, no foreign key to participation, no shared surrogate that links them**, and no insertion-order correlation guarantee. Votes are anonymous to everyone, including administrators (packet §9): the schema cannot answer "how did X vote" even with raw SQL access.

Both inserts happen in one transaction: participation first (uniqueness gate), then ballot. Tallies are visible only after close (FR-18); while **open**, O-10 sees the participation count only.

### 5.5 Kitchen-hours model (FR-19, INV-10, INV-16)

- `weekly_schedule`: per-day-of-week open/close times, written only via the admin shell (A-10; packet §8 — operators can never set the weekly schedule).
- `day_override`: per-date operator switch (open late / close early), written only via the operator shell (O-09), recording which operator set it (see §6).
- `is_kitchen_open(now)` = override for today if present, else schedule. Evaluated **server-side inside the placement transaction** (INV-10) — UI staleness cannot create an out-of-hours order.
- Closing **blocks new orders immediately and never auto-cancels** (INV-16, A-§A.16): the close action writes only the override; every remaining order is resolved by the operator through O-02 (deliver, or cancel with automatic refund).

### 5.6 Removal-refund flow (FR-24, INV-15) — R-004 resolution

The **removal refund** is the single exception to credits-never-become-money (INV-15, A-§A.15). Design:

**Payout-leg allocation (decided here, design-level):** the resident's remaining balance is spread across their original top-up payments **newest-first, partial-refund per payment**, where each payment's refundable remainder = its original amount − refunds already issued against it. Newest-first is chosen because card refunds are constrained by provider-side refund windows that close with payment age; allocating against the newest payments first maximizes the portion of the balance that can actually reach a card. This is an allocation mechanic, not a stakeholder policy invention: the stakeholder decision (A-§A.15) is "refund the remaining balance to the card(s) of their original top-ups"; newest-first is the deterministic algorithm that best satisfies it. 08-architecture-guardian may overrule the ordering; the algorithm must remain deterministic and ledger-traceable either way.

**Execution sequence (A-06):**

1. Admin confirms removal. One transaction: resident marked removed (access lost immediately, packet §9; historical transactions remain), `credit_account` frozen (no further charges possible), audit entry written (FR-23), and payout legs computed and persisted as `payout_attempt` rows (one per source payment, with amount and idempotency key).
2. Each leg is submitted to the payments port (Mercado Pago refund call — see `integration-inventory.md`). **The credit movement for a leg is recorded by the ledger only when the provider confirms that leg** — credit movements reflect money events that actually happened (packet §11). A confirmed leg = one append-only movement, reason: removal refund, linked to the original payment (packet §6, A-§A.15).
3. Leg failures are retried with the same idempotency key; persistently failed legs stay visible as failed `payout_attempt`s in the admin shell. **The removal itself stands regardless of payout outcome** — removal is an explicit admin action and access loss is immediate per packet §9; the packet ties no reversal of removal to payout failure.

**Genuinely undecidable — kept open, not guessed (R-004 residual):** if the refundable card amounts are less than the remaining balance (top-ups older than the provider refund window, or provider-rejected legs), the packet does not say what happens to the residual. The design does **not** invent a write-off, a cash payout, or a blocking rule. Mitigation until the stakeholder decides: A-06 computes and displays the refundable vs residual split **before** the admin confirms; confirmed removals with a residual keep the residual visible on the frozen account (admins see it in A-08); the policy question goes to the stakeholder batched per packet §16. Recorded as the open remainder of R-004 in handoff 0009.

This also resolves ux-inventory OI-2: A-06 success = removal committed + legs initiated; the per-leg provider outcome is shown asynchronously on the resident's (frozen) account view, with failed legs flagged. R-003 (Mercado Pago partial-refund coverage across multiple historical top-ups) is the sandbox-validation gate for this whole mechanism — see `integration-inventory.md` §1.

### 5.7 Audit trail (FR-23, INV-18)

`audit_entry` records actor, action class (role change, resident add/remove, login reset, registry import — exactly the four classes of A-§A.18), target, timestamp, and a summary payload. Same database-layer append-only enforcement as the ledger (§5.1): app role has INSERT+SELECT only, trigger blocks UPDATE/DELETE. Writes happen **inside the same transaction** as the sensitive action — an action that commits without its audit entry is impossible (INV-18). A-11 is a read-only view.

---

## 6. R-005 — shared-tablet session policy (proposal)

Constraint set: per-person login via phone + SMS code (FR-01, INV-07); one shared kitchen tablet (packet §12); accountability for operator actions (packet §8 separates operator capabilities; §5.12/A-§F make cancellations and availability flags consequential); SMS cost pressure under the §14 ceiling discourages re-sending codes every shift; no resident-personal data on the shared device (packet §9, ux-inventory shell-membership decision).

**Proposal: long-lived device session + per-operator PIN.**

- **Device session:** the tablet is enrolled once by any Kitchen Operator or Administrator completing the normal FR-01 phone + SMS login on it (registry remains the sole gate, INV-07). This creates a long-lived `device_session` scoped to the operator shell only — it can never read resident-personal data (the operator shell contains none, per ux-inventory).
- **Operator identification:** each operator, on first use of the tablet, completes their own FR-01 login once and sets a short numeric PIN stored for that device (`operator_pin`, hashed). Thereafter, shift handover = pick your name on the lock screen + PIN. No SMS per shift.
- **Accountability:** every state-changing operator action (accept, deliver, cancel, mark **no longer available**, kitchen open/close override, draft/publish, poll open/close) is recorded with the identified operator. Destructive actions (O-04 cancel, O-06 flag, O-09 close) additionally require PIN re-entry at the confirm step, so a walked-away tablet cannot execute them under someone else's name.
- **Idle lock:** short inactivity timeout returns to the name+PIN lock screen without destroying the device session. Admins can revoke the device session or any operator's PIN via login reset (FR-03), which is audit-trailed (FR-23).

This keeps FR-01/INV-07 intact (every operator identity was SMS-verified against the registry at least once), keeps SMS spend flat, and gives per-action accountability on a shared device. Status: design proposal closing R-005 pending 08-architecture-guardian review; no packet conflict identified.

Resident sessions (own phones) are long-lived with renewal (order of 90 days) — chosen for 60+ usability (packet §10: simple navigation, no repeated hurdles) and to keep SMS volume inside the cost ceiling (packet §14; see `stack-decision-record.md` SDR-07). Admin sessions are short (hours, re-login daily) given their blast radius (packet §8).

---

## 7. Frontend topology

- **Three shells, three small single-page bundles** (Resident / Operator / Admin per ux-inventory §1), built from one frontend workspace with shared design tokens and a shared component base, split per shell so the resident bundle carries zero admin/operator code. Resident shell has a hard size budget for mid-range Android over mobile browser (packet §10, §12) — see SDR-04.
- **Generated API clients only.** One OpenAPI contract is the single source of truth; each shell consumes a generated TypeScript client. Hand-written fetch calls are forbidden (CI check). The permission matrix (packet §8) is enforced server-side per endpoint; shells only decide what to *show*.
- **Contract-aligned mocks.** Frontend development and shell-level tests run against a mock server generated from the same OpenAPI contract, loaded with deterministic fixtures covering each route's five states (loading/empty/error/unauthorized/success) plus the journey-specific states in ux-inventory (insufficient credits, kitchen closed, no longer available, failed/abandoned top-up, second-vote rejected, poll closed mid-screen). The integration fakes in `integration-inventory.md` feed these fixtures the same deterministic scenarios (packet §7: fake-first).
- **Notification delivery:** in-app only (A-§E). Short polling (resident shell bell + operator queue refresh) rather than websockets/SSE — four operators and ~200 peak residents polling at relaxed intervals is trivial load (packet §11), and every invariant is enforced server-side at write time, so UI staleness can never violate INV-10/INV-12; this trades a few seconds of freshness for ops simplicity (packet §14, §2).

---

## 8. Cross-cutting

- **AuthZ:** role checks per endpoint from one declarative permission table mirroring requirements §5 (packet §8). Operators and admins exercising resident capabilities use the resident shell with their own personal session (ux-inventory shell-membership decision); the device session of §6 never grants resident-data access.
- **Top-up correctness (AC-03):** R-10 confirms the outcome by asking *our* server, which verifies payment status with the provider server-side (never trusting the redirect alone); crediting is idempotent per provider payment id — exactly one top-up credit movement per approved payment regardless of webhook/return races. Details in `integration-inventory.md` §1.
- **Observability, minimal:** structured logs with phone numbers redacted everywhere (packet §9 — phone numbers never leave the system except to the SMS provider), the nightly ledger-consistency check (§5.1), uptime ping, and error alerting to the committee. No tracing stack (packet §14, §2).
- **i18n:** all user-facing strings externalized in shells and API alike from day one; es-MX sole launch locale, English addable without rework (packet §10; SDR-09).
- **Retention:** credit and order history retained indefinitely — it is the financial record (packet §9); removed residents lose access immediately, history remains. Backup posture in SDR-08.

---

## 9. Design-level open items

| # | Item | Disposition |
|---|---|---|
| 1 | R-004 residual: policy when refundable card amounts < remaining balance at removal | Open risk, mitigated (§5.6); stakeholder question batched per packet §16 — **not** decided here |
| 2 | R-005 shared-tablet proposal (§6) | Decision proposed; awaits 08-architecture-guardian review |
| 3 | Registry Excel sheet: exact column layout of the admins' existing sheet (packet §14) | New risk R-006 — a sample sheet is required to pin the import parser; fake-first fixtures until then (`integration-inventory.md` §3) |
