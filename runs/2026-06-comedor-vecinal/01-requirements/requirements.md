# Requirements Document — Comedor Vecinal

**Run:** 2026-06-comedor-vecinal
**Producer:** 02-requirements-analyst (dry-run, human-invoked; handoff 0001)
**Source:** `00-packet/stakeholder-input-packet.md` (frozen, stakeholder-confirmed 2026-06-11) + `00-packet/amendment-001.md` (confirmed 2026-06-11)
**Status:** Ready for Gate 1 (scope approval). All 14 open questions answered via amendment-001 (delta review: handoff 0004). Citations "A-§x" refer to amendment-001 sections.

Every requirement cites its packet section. Nothing here is invented; gaps are questions, not guesses.

---

## 1. Roles (packet §2)

| ID | Role | Count | Needs |
|---|---|---|---|
| ROLE-R | Resident | ~400 | See menus, order, manage credits, vote |
| ROLE-O | Kitchen Operator | 4 | Queue + per-dish counts, order transitions, menus, availability, kitchen open/close |
| ROLE-A | Administrator | 3 | Residents/staff management, transactions + sales history, schedule, disputes, access resets |

---

## 2. User Journeys (packet §3)

| ID | Journey | Failure path |
|---|---|---|
| J-A | Resident orders (week menu + daily dishes, pickup code) | J-A′ insufficient credits: exact shortfall shown, routed to top-up, nothing deducted |
| J-B | Card top-up | Payment fails/abandoned: balance unchanged, attempt visible as failed |
| J-C | First-time access via registry + SMS code | Number not in registry: no entry at all |
| J-D | Kitchen operations (schedule/open, queue oldest-first, per-dish count, deliver by code) | Dish runs out: marked "no longer available", new orders blocked, unfulfillable orders cancelled + notified + auto-refunded |
| J-E | Menu voting, one vote per cycle | Second vote rejected with clear message; poll closes mid-screen → "poll closed" + results |

---

## 3. Functional Requirements (packet §4, §5, §7, §8)

### Identity & Access

| ID | Requirement | Priority | Trace |
|---|---|---|---|
| FR-01 | Phone-number login with SMS code; registry is sole gate | MUST | §4, §5.7, J-C |
| FR-02 | Registry import/sync from admin-uploaded Excel; sheet format unchanged | MUST | §7, §14 |
| FR-03 | Admin triggers login reset for a resident | MUST | §8 (under "manage residents", §4) |

### Menus

| ID | Requirement | Priority | Trace |
|---|---|---|---|
| FR-04 | View standing week menu + today's published daily dishes, prices in credits | MUST | §4, §17 |
| FR-05 | Operators edit week menu via draft → publish, same flow as daily dishes | MUST | §4, §8, A-§F |
| FR-06 | Operator marks any dish (week menu or daily) "no longer available": new orders blocked immediately; unfulfillable placed orders cancelled + notified + auto-refunded | MUST | §4, §5.12, A-§F |

### Ordering

| ID | Requirement | Priority | Trace |
|---|---|---|---|
| FR-07 | Place order: multiple dishes, multiple portions, multiple meals; own credits only; no per-resident cap | MUST | §4, §5.13, §8 |
| FR-08 | Order states placed→accepted→delivered / cancelled; resident self-cancel only while placed, full credit refund | MUST | §5.4, §17 |
| FR-09 | Kitchen queue: oldest first; accept / deliver / cancel any order | MUST | §4, J-D |
| FR-10 | Pickup code per order; delivered only on operator code confirmation | MUST | §5.14, §17 |
| FR-11 | Per-dish ordered-portions count for the day, operator-visible | MUST | §4 |
| FR-12 | Ordering only while kitchen open; daily dishes only on their own day; closing blocks new orders, never auto-cancels — operator resolves the remaining queue (deliver or cancel-with-refund) | MUST | §5.10, §5.11, A-§A.16 |

### Credits

| ID | Requirement | Priority | Trace |
|---|---|---|---|
| FR-13 | Credit balance + full transaction history per resident | MUST | §4 |
| FR-14 | Online card top-up via **Mercado Pago**; 50–2,000 credits per transaction | MUST | §4, §7, A-§A.19, A-§C |
| FR-15 | Automatic, immediate refund on any kitchen cancellation; all refunds/payouts system-initiated by events — no manual credit movement by any role | MUST | §5.5, §5.12, A-§F |

### Notifications

| ID | Requirement | Priority | Trace |
|---|---|---|---|
| FR-16 | Notifications for order status changes, in-app only at launch (SMS solely for login codes) | MUST | §4, A-§B, A-§E |
| FR-17 | Mark-all-read | SHOULD | §4 |

### Polls

| ID | Requirement | Priority | Trace |
|---|---|---|---|
| FR-18 | Menu polls, one vote per resident per cycle (ad-hoc, operator-opened; no fixed cadence); results visible after close; winners inform daily dishes; participation stored separately from ballot content | MUST | §4, §5.6, J-E, A-§B, A-§F |

### Kitchen operations

| ID | Requirement | Priority | Trace |
|---|---|---|---|
| FR-19 | Admin-set weekly kitchen schedule + operator same-day open/close override | MUST | §4, §5.10, §17 |

### Administration

| ID | Requirement | Priority | Trace |
|---|---|---|---|
| FR-20 | Add/remove residents and grant/revoke roles via an admin panel (Django-admin-style CRUD); removal always explicit — registry import only adds/updates | MUST | §4, §5.8, A-§A.17, A-§B |
| FR-21 | Per-dish sales history across days (raw-material decisions) | MUST | §4 |
| FR-22 | View all credit transactions | MUST | §4, A-§B |
| FR-23 | Audit trail of sensitive admin actions: role changes, resident add/remove, login resets, registry imports | MUST | §8, A-§A.18, A-§B |
| FR-24 | Removal refund: on removing a resident with positive balance, automatically pay out the remaining balance to the card(s) of their original top-ups via Mercado Pago, recorded as a credit movement | MUST | A-§A.15, A-§B |

### Deferred (packet §4 LATER)

Credit expiration after inactivity; scheduled/recurring orders; dietary preference filters.

---

## 4. Candidate Invariants (packet §5, verbatim — seeds for invariant tests)

| ID | Invariant |
|---|---|
| INV-01 | Credit balance never below zero |
| INV-02 | Credit movements append-only; never edited or deleted |
| INV-03 | Order charged at price visible at placement |
| INV-04 | Resident self-cancel only while "placed"; full credit refund |
| INV-05 | Kitchen cancellation → automatic immediate refund |
| INV-06 | Exactly one vote per resident per poll; second attempt rejected, never counted |
| INV-07 | Registry-only login |
| INV-08 | Only admins change staff/admin roles |
| INV-09 | Published menu change visible to all simultaneously; drafts invisible to residents |
| INV-10 | Orders only while kitchen open (schedule + operator override) |
| INV-11 | Daily dish orderable only on its own day; week-menu dishes any open day |
| INV-12 | "No longer available" → new orders blocked immediately; unfulfillable placed orders cancelled + refunded + notified |
| INV-13 | No per-resident quantity limit beyond balance and availability |
| INV-14 | Delivered only on pickup-code confirmation |
| INV-15 | Credits never convert back to money, with exactly one exception: the automatic removal refund to original card(s), recorded as a credit movement (A-§A.15) |
| INV-16 | Closing the kitchen blocks new orders immediately and never auto-cancels; every remaining order is resolved by the operator (A-§A.16) |
| INV-17 | Resident removal is always explicit; registry import never removes anyone (A-§A.17) |
| INV-18 | Every sensitive admin action is recorded in the audit trail (A-§A.18) |
| INV-19 | A top-up is between 50 and 2,000 credits per transaction (A-§A.19) |

---

## 5. Permission Matrix Summary (packet §8 — enforced matrix authored by Security Engineer)

| Capability | R | O | A |
|---|---|---|---|
| See published menus / place orders / own data / top-up / vote / own notifications / share pickup code | ✓ | ✓ | ✓ |
| See all day orders; accept/deliver/cancel; mark unavailable; kitchen open-close; edit week menu; publish daily dishes; polls open-close; daily per-dish count | | ✓ | ✓ |
| Residents + roles; all transactions; sales history; weekly schedule; login reset; audit trail | | | ✓ |
| **Never:** others' data, draft menus (R) · balances beyond cancel-refunds, residents/roles, weekly schedule (O) · edit/delete credit history, vote for residents, see individual votes, manual credit movements — the removal refund is system-initiated (A) | | | |

---

## 6. Non-Functional Requirements

| Area | Requirement | Trace |
|---|---|---|
| Scale | ~400 residents; peak = late-morning window, ~half within one hour | §11 |
| Reliability | Correctness over availability, always; wrong balances worse than downtime | §11 |
| Accessibility | Usable by 60+ on mid-range Android: large text, high contrast, simple navigation | §10 |
| i18n | es-MX at launch; structured for English later without rework | §10 |
| Devices | Residents: Android mobile browser; operators: shared tablet browser; admins: laptop browser. No store apps | §12, §15 |
| Privacy | Phone numbers admin-only, never to providers except SMS; votes anonymous to everyone — participation stored separately from ballot content (A-§F); financial history retained indefinitely; removed residents lose access, history remains; no formal LFPDPPP review (confirmed 2026-06-11) | §9 |
| Cost | Ceiling **2,500 MXN/month** (hosting + SMS; payment fees excluded); hosting payable by card | §14, A-§D |

---

## 7. Integrations (packet §7 — all fake-first)

| Integration | Status |
|---|---|
| Card payments | **Mercado Pago** confirmed (A-§C): top-ups in, removal refunds out. Sandbox first |
| SMS (login codes only — no order alerts, A-§E) | No provider preference; proposal due at design; Mexico availability |
| Registry Excel import | Format fixed by admins' existing sheet (§14). Import adds/updates only, never removes (A-§A.17) |

---

## 8. Acceptance Criteria (packet §13, verbatim — the release gate)

AC-01…AC-10 as packet §13 items 1–10.
Former conflict resolved: FR-18 and FR-22 promoted to MUST (A-§B); AC-05 and AC-06 now depend only on MUST features.

---

## 9. Out of Scope (packet §15, verbatim)

Cash handling; cash-out/refund-to-card **except the automatic removal refund (A-§E)**; formal household accounts; delivery to units; nutrition/allergen compliance; store apps; resident-kitchen chat; raw-material/inventory management; **SMS order alerts at launch (A-§E)**.

**Scope default (packet rules):** anything absent from §4 and not excluded in §15 is out of scope. Notable defaults derived, not invented: no order modification after placement (cancel-and-reorder only); no operator-initiated manual credit adjustments; no resident-to-resident credit transfers.

---

## 10. Open Items Affecting Gate 1

None. All 14 questions answered and confirmed in `00-packet/amendment-001.md` (2026-06-11); answers logged in `open-questions.md`. Gate 1 is ready for the approver's signature.
