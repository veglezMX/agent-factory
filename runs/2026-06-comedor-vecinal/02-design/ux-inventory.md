# UX Interface Inventory — Comedor Vecinal

**Run:** 2026-06-comedor-vecinal
**Producer:** 03-ux-flow-designer (handoff 0006 → 0007)
**Sources:** `01-requirements/requirements.md`, `01-requirements/glossary.md`, `00-packet/stakeholder-input-packet.md`, `00-packet/amendment-001.md`, `state.md`
**Status:** Ready for 04-solution-designer (Gate 2 input)

This document names every screen, its purpose, the requirements it serves, and its
route-level states. It contains **no component implementations, no API contracts,
no technology choices**. "Django-admin-style" appears only as the recorded UI
expectation for FR-20 (A-§B). All terms follow the glossary verbatim.

---

## 1. The three shells

| Shell | Role(s) | Device & context (packet §12) | Design posture |
|---|---|---|---|
| **Resident shell** | Resident (~400) | Own mid-range Android phone, mobile browser, no store app | Large text, high contrast, simple linear navigation; comfortably usable by residents aged 60+ (packet §10) |
| **Operator shell** | Kitchen Operator (4) | One shared tablet in the kitchen, browser | Glanceable at arm's length; very large touch targets; tolerant of glare, wet/gloved hands; minimal typing |
| **Admin shell** | Administrator (3) | Laptop, desktop browser | Dense tabular CRUD; Django-admin-style expectation recorded for FR-20 (A-§B) — list/filter/detail/confirm patterns |

**Shell membership decision (packet §8):** operators and administrators can do
everything a resident can, but the operator and admin shells contain **only
role-specific screens**. Staff exercising resident capabilities (ordering,
top-up, voting, own notifications) do so through the resident shell on their own
phone. This keeps the shared kitchen tablet free of personal data (packet §9)
and keeps each shell's navigation small.

**Shared state vocabulary.** Every route in every shell defines these five states;
per-screen entries below say what each means concretely and add journey-specific
states where required:

- **loading** — content not yet available; layout placeholder, no dead screen.
- **empty** — the route loaded but has nothing to show; always a worded, friendly explanation, never a blank area.
- **error** — the route could not load or an action failed; plain-language message + retry; never raw technical text.
- **unauthorized** — the session's role may not see this route (packet §8 matrix); the shell explains and routes to its home (or to login if no session).
- **success** — the route's normal, populated state, or the completed state of an action route.

---

## 2. Screen inventory — Resident shell

### R-01 Login — phone number
- **Purpose:** entry point; resident enters their phone number to request an SMS code. Registry is the sole gate.
- **Serves:** FR-01, J-C, INV-07; packet §5.7.
- **States:**
  - loading — submitting the number.
  - empty — n/a (form is the initial state).
  - error — number not in registry: **no entry at all** (J-C); same neutral message regardless of reason, no hint whether the number exists (packet §9).
  - unauthorized — n/a (public route).
  - success — advances to R-02.

### R-02 Login — SMS code
- **Purpose:** resident types the code received by SMS; on confirmation, session starts.
- **Serves:** FR-01, J-C; packet §4, §5.7.
- **States:**
  - loading — verifying the code.
  - empty — n/a.
  - error — wrong/expired code; offer re-send; no registry information leaked.
  - unauthorized — n/a (public route).
  - success — session established; lands on R-03.

### R-03 Today — week menu + daily dishes
- **Purpose:** the home screen. Shows the standing **week menu** and today's published **daily dishes** as two clearly separated sections, every dish with its price in credits. Current credit balance always visible. Drafts never appear (INV-09).
- **Serves:** FR-04, FR-12; packet §4, §17, J-A; glossary "week menu", "daily dish", "published".
- **States:**
  - loading — menu placeholders.
  - empty — no daily dishes published today: daily-dishes section says so plainly; week menu still shown. Both empty only if no week menu is published.
  - error — menus could not load; retry.
  - unauthorized — no session → R-01.
  - success — both sections populated; dishes flagged **no longer available** are visibly disabled, never hidden silently (FR-06).
  - **kitchen closed** (additional, first-class) — banner with today's **kitchen hours**; menus remain readable, ordering controls disabled (FR-12, INV-10, glossary "kitchen open / closed").

### R-04 Order placement
- **Purpose:** build an order: multiple dishes, multiple portions, multiple meals; quantity steppers; running total in credits against own balance. No per-resident cap (INV-13).
- **Serves:** FR-07, FR-12; packet §4, §5.13, §8.
- **States:**
  - loading — prices/availability check.
  - empty — nothing selected yet; prompt to pick from R-03.
  - error — placement attempt failed for a non-balance reason; retry, nothing deducted.
  - unauthorized — no session → R-01.
  - success — order summary ready, advances to R-05.
  - **dish no longer available** (additional) — a selected dish was flagged while composing: that line is blocked immediately with a clear per-dish message; rest of the order remains (FR-06, INV-12).
  - **kitchen closed** (additional) — kitchen closed while composing: placement blocked, order kept on screen, banner explains (FR-12, INV-16).

### R-05 Order confirmation
- **Purpose:** the commit point. Shows the exact dishes, quantities, prices as visible at placement (INV-03), total, balance after. Confirming places the order.
- **Serves:** FR-07, FR-08, FR-10; J-A, J-A′; packet §5.1, §5.3.
- **States:**
  - loading — placing the order.
  - empty — n/a (reached only with a composed order).
  - error — placement failed (not balance-related); nothing deducted; retry.
  - unauthorized — no session → R-01.
  - success — order is **placed**; balance reduced; **pickup code** displayed immediately and prominently (J-A, glossary "pickup code").
  - **insufficient credits** (additional, FIRST-CLASS — not an error toast) — full-screen state: exact shortfall in credits ("te faltan N créditos"), primary action goes to R-09 top-up, order kept intact for return; **nothing is deducted and no order is placed** (J-A′, INV-01, AC-02).
  - **kitchen closed** / **dish no longer available** (additional) — same semantics as R-04 if the change lands at the moment of confirmation (FR-12, FR-06).

### R-06 My orders
- **Purpose:** list of the resident's own orders, newest first, each with status chip — **placed / accepted / delivered / cancelled** only (glossary) — and its **pickup code** visible from the list for active orders.
- **Serves:** FR-08, FR-10; packet §4, §8 (own data only).
- **States:**
  - loading — list placeholder.
  - empty — "no orders yet" with link to R-03.
  - error — could not load; retry.
  - unauthorized — no session → R-01.
  - success — list with statuses and pickup codes.

### R-07 Order detail
- **Purpose:** one order: dishes, quantities, total, status timeline with timestamps, large shareable **pickup code** (packet §8: show or share). Self-cancel button **only while placed** — confirm dialog states the full credit refund (INV-04).
- **Serves:** FR-08, FR-10, FR-15; packet §5.4, §6.
- **States:**
  - loading / empty (order id not found → friendly not-found) / error / unauthorized (another resident's order — own data only, packet §8) / success.
  - **cancelled by kitchen** (additional presentation of success) — shows the automatic refund line and the reason wording from J-D ("refund in place, sorry for the inconvenience, the dish is no longer available") when applicable (FR-06, FR-15, INV-05).

### R-08 Wallet — balance & history
- **Purpose:** current credit balance plus the full, append-only transaction history: every credit movement (top-up / order / refund) with direction, amount, and linked order or payment (packet §6). Failed top-up attempts appear as failed (J-B). Entry point to R-09.
- **Serves:** FR-13; packet §4, §6; INV-02; glossary "credit movement", "top-up", "refund".
- **States:**
  - loading / empty ("no movements yet", balance 0 shown) / error / unauthorized / success.

### R-09 Top-up — amount
- **Purpose:** choose a top-up amount. Enforces **50–2,000 credits per transaction** in the control itself (preset amounts + bounded custom field, bounds stated on screen). 1 credit = 1 MXN at top-up time (glossary "credit"). Hands off to the payment provider's page (Mercado Pago, FR-14) — that external page is **not** part of this inventory.
- **Serves:** FR-14, INV-19; packet §4, §7, A-§A.19, A-§C; J-B.
- **States:**
  - loading — initiating handoff to the payment page.
  - empty — n/a (presets always shown).
  - error — could not start the payment; balance unchanged.
  - unauthorized — no session → R-01.
  - success — redirected to the payment page.
  - **out-of-bounds** (additional, inline) — amount below 50 or above 2,000 is rejected at input with the bounds spelled out (INV-19).

### R-10 Top-up result
- **Purpose:** the return route after the payment page. Confirms the outcome and shows the new balance **without the resident needing to refresh or contact anyone** (AC-03).
- **Serves:** FR-14; J-B; AC-03.
- **States:**
  - loading — verifying the payment outcome ("confirmando tu pago…").
  - empty — n/a.
  - error — outcome could not be confirmed yet; balance shown is the last known one; the attempt will appear in R-08 history either way.
  - unauthorized — no session → R-01.
  - success — new balance + receipt entry; link to R-08 and back to R-03.
  - **failed / abandoned** (additional, first-class) — payment failed or was abandoned: **balance unchanged**, attempt visible as failed in history (J-B); retry path to R-09.

### R-11 Poll — voting
- **Purpose:** the open poll for the current cycle: question and candidate daily dishes; exactly one vote per resident per poll (INV-06). Votes are anonymous to everyone (packet §9, A-§F).
- **Serves:** FR-18; J-E; packet §4, §5.6.
- **States:**
  - loading — poll fetch.
  - empty — no open poll this cycle: friendly message, link to latest results (R-12).
  - error — vote could not be recorded; **never counted twice**; retry.
  - unauthorized — no session → R-01.
  - success — vote recorded confirmation, then to R-12 (results visible after close → "thanks, results when the poll closes").
  - **already voted / second vote rejected** (additional, per J-E) — clear message that the vote was rejected and is never counted (INV-06); shows that participation is recorded, never the ballot content (A-§F).
  - **poll closed mid-screen** (additional, per J-E) — if the poll closes while this screen is open: "poll closed" message and automatic routing to R-12 results.

### R-12 Poll — results
- **Purpose:** final tallies of a closed poll; visible to everyone after close (FR-18). Winning dishes inform upcoming daily dishes (J-E) — informational note only.
- **Serves:** FR-18; J-E; packet §5.6, §6.
- **States:**
  - loading / empty (no closed polls yet) / error / unauthorized / success (tallies; no individual votes anywhere — packet §9).

### R-13 Notifications
- **Purpose:** in-app notifications for order status changes (in-app only at launch — SMS is solely for login codes, A-§B, A-§E). Read/unread distinction and **mark-all-read**.
- **Serves:** FR-16, FR-17; packet §4, §6, A-§E.
- **States:**
  - loading / empty ("you're all caught up") / error / unauthorized / success (list; mark-all-read control enabled only when something is unread).

**Resident shell total: 13 screens.**

---

## 3. Screen inventory — Operator shell

### O-01 Login (shared tablet)
- **Purpose:** same phone + SMS-code mechanism as FR-01; registry is the sole gate; only sessions with the Kitchen Operator (or Administrator) role enter this shell (packet §8).
- **Serves:** FR-01, INV-07; packet §8, §12.
- **States:** loading / empty n/a / error (not in registry or wrong code — neutral message, J-C) / unauthorized (resident-only session: explained, pointed to the resident shell) / success → O-02.

### O-02 Order queue
- **Purpose:** the working list of orders for the day, **oldest first** (FR-09, J-D). Each row: dishes + quantities, status (**placed / accepted / delivered / cancelled**), elapsed time. Row actions: accept (placed → accepted), deliver (→ O-03), cancel (→ O-04). Tablet-glanceable: one row readable from arm's length.
- **Serves:** FR-09, FR-08; packet §4, §8, J-D.
- **States:**
  - loading / empty ("no orders yet today") / error / unauthorized (no operator role) / success.
  - **kitchen closed, queue remaining** (additional) — after closing, new orders are blocked but **nothing is auto-cancelled**; the queue stays active until the operator resolves every remaining order (deliver, or cancel with refund) (FR-12, INV-16, A-§A.16).

### O-03 Deliver order — pickup code confirmation
- **Purpose:** confirm an order's **pickup code** to mark it delivered; large keypad entry sized for gloves; an order is delivered **only** on code confirmation (INV-14, AC-10).
- **Serves:** FR-10; packet §5.14, J-A, J-D.
- **States:** loading (verifying code) / empty n/a / error (wrong code: order stays in its current state, clear retry) / unauthorized / success (order is **delivered**; returns to O-02).

### O-04 Cancel order — confirmation
- **Purpose:** explicit confirmation before a kitchen cancellation; states plainly that the refund is **automatic and immediate** and the resident is notified — the operator never moves credits manually (FR-15, A-§F).
- **Serves:** FR-09, FR-15, FR-16; packet §5.5, J-D; INV-05.
- **States:** loading / empty n/a / error (cancellation failed; order unchanged) / unauthorized / success (order is **cancelled**; refund + notification confirmed on screen as automatic).

### O-05 Per-dish demand count (today)
- **Purpose:** per-dish ordered-portions count for the day — what to cook, at a glance; biggest numbers on the shell (FR-11). Feeds from the same per-dish sales data as the admin history (packet §6).
- **Serves:** FR-11; packet §4, §6, J-D.
- **States:** loading / empty (no portions ordered yet today) / error / unauthorized / success.

### O-06 Dish availability — mark "no longer available"
- **Purpose:** the day's orderable dishes — **week menu AND daily dishes alike** (A-§F) — each with a clearly-labeled **no longer available** toggle. Confirming states the consequences before applying: new orders blocked immediately; unfulfillable placed orders cancelled + notified + auto-refunded (FR-06, INV-12, AC-09).
- **Serves:** FR-06; packet §4, §5.12, A-§F; glossary "no longer available".
- **States:**
  - loading / empty (kitchen has nothing published today) / error (flag not applied; nothing changed) / unauthorized / success (flag applied; screen reports how many placed orders were auto-cancelled + refunded — system-initiated, FR-15).

### O-07 Week menu editor (draft → publish)
- **Purpose:** edit the standing **week menu** (name/description/price in credits, packet §6) as a **draft**, then publish. Drafts are invisible to residents; a published change is visible to all simultaneously (INV-09, A-§F).
- **Serves:** FR-05; packet §4, §8, A-§F; glossary "week menu", "published".
- **States:** loading / empty (no week menu yet: start one) / error (draft preserved) / unauthorized / success — with two sub-modes of success: **draft** (clearly badged "borrador — invisible a residentes") and **published**. Publish is an explicit confirmation step.

### O-08 Daily dishes editor (draft → publish)
- **Purpose:** draft and publish **daily dishes** for a specific date; orderable only that day while the kitchen is open (INV-11). Same draft → publish flow as O-07 (A-§F). Must be publishable from the tablet in under a minute of interaction (AC-08) — minimal required fields, duplicate-from-poll-winners affordance is informational only (J-E "winners inform daily dishes").
- **Serves:** FR-05; packet §4, §6, J-D; glossary "daily dish", "published".
- **States:** loading / empty (no dishes drafted for the chosen date) / error (draft preserved) / unauthorized / success (draft badge vs published, as O-07).

### O-09 Kitchen open/close
- **Purpose:** the operator's same-day override switch over the admin-set weekly schedule (glossary "kitchen hours"). Shows current state (**kitchen open / closed**) and today's scheduled hours. Closing warns: new orders blocked immediately, existing orders stay valid and **must each be resolved** — closing never cancels anything by itself (INV-16, A-§A.16).
- **Serves:** FR-12, FR-19; packet §4, §5.10, §5.11, J-D.
- **States:** loading / empty n/a (always has a state) / error (switch not applied; previous state stands) / unauthorized / success — plus the post-close reminder of remaining queue count linking to O-02.

### O-10 Poll admin
- **Purpose:** open and close menu polls (ad-hoc — opening a poll begins a cycle, no fixed cadence, glossary "cycle"): set the question and candidate daily dishes, open, close, see tallies after close. Participation (who voted) is visible; ballot content never is, to anyone (A-§F, packet §9).
- **Serves:** FR-18; packet §4, §5.6, §8, A-§F.
- **States:** loading / empty (no poll this cycle: create one) / error / unauthorized / success — with sub-modes: **open** (live participation count only, no tallies) and **closed** (final tallies, same as R-12).

**Operator shell total: 10 screens.**

---

## 4. Screen inventory — Admin shell

The recorded UI expectation for this shell is Django-admin-style CRUD (FR-20,
A-§B): list with search/filter → detail form → explicit confirm for destructive
actions. That expectation is recorded here verbatim; it is not a technology
selection (04-solution-designer decides implementation).

### A-01 Login (desktop)
- **Purpose:** same FR-01 mechanism; only Administrator sessions enter this shell (packet §8).
- **Serves:** FR-01, INV-07; packet §8, §12.
- **States:** loading / empty n/a / error (neutral, J-C) / unauthorized (non-admin session: explained) / success → A-02.

### A-02 Admin home
- **Purpose:** index of the admin shell's sections (residents, roles, transactions, sales history, schedule, audit trail, import) — the Django-admin-style landing list (FR-20).
- **Serves:** FR-20; packet §8.
- **States:** loading / empty n/a / error / unauthorized / success.

### A-03 Resident registry — list
- **Purpose:** searchable, filterable list of the registry: name, phone number (admin-only data, packet §9), unit/address, active or removed (packet §6). Entry to A-04 (add/edit), A-06 (removal), A-12 (login reset).
- **Serves:** FR-20; packet §2, §6, §8.
- **States:** loading / empty (registry empty: prompt to add or import) / error / unauthorized / success.

### A-04 Resident — add / edit
- **Purpose:** create or update one resident record (name, phone number, unit/address). Adding writes to the **audit trail** (FR-23).
- **Serves:** FR-20, FR-23; packet §6, A-§A.18.
- **States:** loading / empty (new blank form) / error (validation, e.g., duplicate phone; record unchanged) / unauthorized / success (saved; audit trail entry confirmed).

### A-05 Registry import (Excel)
- **Purpose:** upload the community Excel sheet in its existing, unchanged format (packet §14). Preview of adds/updates before applying. **Import only adds or updates residents — it never removes anyone** (INV-17, A-§A.17); the screen states this invariant explicitly. Every import is recorded in the **audit trail** (FR-23).
- **Serves:** FR-02, FR-20, FR-23; packet §7, §14, A-§A.17.
- **States:**
  - loading — parsing/applying.
  - empty — sheet parsed but contains no usable rows: shown as such, nothing applied.
  - error — unreadable sheet or failed apply; registry unchanged; row-level issues listed plainly.
  - unauthorized / success — applied summary: N added, M updated, **0 removed — always**.

### A-06 Resident removal — removal-refund confirmation
- **Purpose:** the explicit removal flow (removal is never implicit — INV-17). The confirmation screen is the heart of FR-24: it shows the resident's **remaining balance** and states that this balance will be **automatically refunded to the card(s) of their original top-ups** (the **removal refund** — the single exception to credits-never-become-money, INV-15), recorded as a credit movement. It also states: access lost immediately, historical transactions remain (packet §9). Removal writes to the **audit trail** (FR-23).
- **Serves:** FR-20, FR-24, FR-23; A-§A.15, A-§A.17, A-§B; glossary "removal refund".
- **States:**
  - loading — fetching the balance to display, then executing.
  - empty — n/a (always reached for a specific resident).
  - error — removal not applied; resident and balance unchanged.
  - unauthorized / success — resident removed; for positive balance: removal refund initiation confirmed and the credit movement reference shown; for zero balance: removal confirmed with "no removal refund needed".
  - **Note:** the on-screen presentation of an asynchronous payout outcome (provider-side delay or failure after initiation) is **not specified by the packet** — raised as an open issue below (ties to risk R-003).

### A-07 Roles management
- **Purpose:** grant or revoke Kitchen Operator and Administrator roles — only administrators change roles (INV-08). Every change writes to the **audit trail** (FR-23).
- **Serves:** FR-20, FR-23; packet §5.8, §8, A-§A.18.
- **States:** loading / empty (no staff yet beyond defaults) / error (no change applied) / unauthorized / success (change applied; audit trail entry confirmed).

### A-08 All credit transactions
- **Purpose:** read-only view of every **credit movement** in the system (who, amount, direction, reason, linked order or payment — packet §6), filterable by resident/date/reason. Append-only and never editable from anywhere (INV-02; admins can never edit or delete credit history, packet §8). This is the dispute-resolution surface (packet §2, AC-05).
- **Serves:** FR-22; packet §4, §6, §8, A-§B.
- **States:** loading / empty (no movements yet) / error / unauthorized / success.

### A-09 Per-dish sales history
- **Purpose:** portions ordered per dish per day, across days — informs raw-material purchasing decisions made outside the app (FR-21, packet §15: no inventory management here).
- **Serves:** FR-21; packet §4, §6.
- **States:** loading / empty (no sales in the selected range) / error / unauthorized / success.

### A-10 Kitchen weekly schedule
- **Purpose:** set the admin-owned weekly schedule half of **kitchen hours** (the operator same-day override lives in O-09 and is never editable here — packet §8: operators can never set the weekly schedule, and the inverse separation is kept clean).
- **Serves:** FR-19; packet §4, §5.10, §6; glossary "kitchen hours".
- **States:** loading / empty (no schedule yet: must be set before the kitchen can open by schedule) / error (schedule unchanged) / unauthorized / success.

### A-11 Audit trail
- **Purpose:** read-only, append-only view of the **audit trail**: role changes, resident add/remove, login resets, registry imports (the four sensitive action classes — A-§A.18), filterable by actor/action/date.
- **Serves:** FR-23; packet §8, A-§A.18, A-§B; glossary "audit trail".
- **States:** loading / empty (no sensitive actions recorded yet) / error / unauthorized / success.

### A-12 Login reset — confirmation
- **Purpose:** trigger a login reset for one resident (reached from A-03/A-04); explicit confirm stating the effect (resident must sign in again with a fresh SMS code). Writes to the **audit trail** (FR-23).
- **Serves:** FR-03, FR-23; packet §8, A-§A.18.
- **States:** loading / empty n/a / error (no reset performed) / unauthorized / success (reset done; audit trail entry confirmed).

**Admin shell total: 12 screens. Inventory total: 35 screens.**

---

## 5. Navigation maps

### Resident shell (bottom navigation, four anchors + login)

```
R-01 Login — phone number
└── R-02 Login — SMS code
    └── (session) →

Hoy (home)                          ← nav anchor 1
├── R-03 Today — week menu + daily dishes
│   └── R-04 Order placement
│       └── R-05 Order confirmation
│           ├── (success) → R-07 Order detail (pickup code)
│           └── (insufficient credits) → R-09 Top-up — amount
Mis pedidos                         ← nav anchor 2
├── R-06 My orders
│   └── R-07 Order detail (pickup code, self-cancel while placed)
Créditos                            ← nav anchor 3
├── R-08 Wallet — balance & history
│   └── R-09 Top-up — amount
│       └── (external payment page — out of inventory)
│           └── R-10 Top-up result → back to R-08 / R-03
Más                                 ← nav anchor 4
├── R-11 Poll — voting
│   └── R-12 Poll — results
└── R-13 Notifications  (also reachable from a persistent bell with unread count)
```

### Operator shell (persistent left/top rail on tablet)

```
O-01 Login (shared tablet)
└── (operator session) →

Pedidos
├── O-02 Order queue (oldest first)
│   ├── O-03 Deliver order — pickup code confirmation
│   └── O-04 Cancel order — confirmation
Cocina hoy
├── O-05 Per-dish demand count (today)
├── O-06 Dish availability — mark "no longer available"
└── O-09 Kitchen open/close          ← state also shown permanently in the rail
Menús
├── O-07 Week menu editor (draft → publish)
└── O-08 Daily dishes editor (draft → publish)
Encuestas
└── O-10 Poll admin
```

### Admin shell (Django-admin-style section index, FR-20)

```
A-01 Login (desktop)
└── (admin session) →

A-02 Admin home (section index)
├── Residentes
│   ├── A-03 Resident registry — list
│   │   ├── A-04 Resident — add / edit
│   │   ├── A-06 Resident removal — removal-refund confirmation
│   │   └── A-12 Login reset — confirmation
│   └── A-05 Registry import (Excel)
├── Roles
│   └── A-07 Roles management
├── Créditos
│   └── A-08 All credit transactions
├── Ventas
│   └── A-09 Per-dish sales history
├── Cocina
│   └── A-10 Kitchen weekly schedule
└── Auditoría
    └── A-11 Audit trail
```

---

## 6. Journey → screen traces

| Journey | Screen sequence |
|---|---|
| **J-A** Resident orders (happy path) | R-03 (week menu + today's daily dishes, kitchen open) → R-04 (quantities) → R-05 **success** (placed; balance reduced; **pickup code** shown) → R-13 notification on accept (FR-16) → R-07 (pickup code presented at the canteen) → operator O-03 confirms code → order **delivered**, visible in R-06/R-07 |
| **J-A′** Insufficient credits | R-03 → R-04 → R-05 **insufficient-credits state** (exact shortfall; nothing deducted, no order placed) → R-09 top-up → external payment page → R-10 success → return to R-05 with the order intact → place |
| **J-B** Card top-up | R-08 → R-09 (amount, 50–2,000 bounds) → external payment page → R-10 **success** (new balance, no refresh needed — AC-03) → receipt in R-08 history. Failure/abandon: R-10 **failed/abandoned state** — balance unchanged, attempt visible as failed in R-08 |
| **J-C** First-time access | R-01 (phone number) → SMS code received → R-02 → R-03. Failure: number not in registry → R-01 **error state**, no entry at all |
| **J-D** Kitchen operations | O-09 (open per schedule or override) → O-02 (queue, oldest first) + O-05 (per-dish count) → accept on O-02 → O-03 (deliver by pickup code). Dish runs out: O-06 mark **no longer available** → new orders blocked immediately (R-03/R-04/R-05 reflect it), unfulfillable placed orders **cancelled** + auto-refunded + residents notified (R-13, R-07 cancelled-by-kitchen presentation) |
| **J-E** Menu voting | R-11 (one vote) → success → R-12 after close. Second vote attempt: R-11 **rejected-second-vote state** (clear message, never counted). Poll closes mid-screen: R-11 **poll-closed state** → R-12 results. Operator side: O-10 open → (cycle runs) → O-10 close → tallies visible; winners inform O-08 daily dishes |

---

## 7. Accessibility & i18n notes

**Language (packet §10, NFR i18n):**
- es-MX is the only launch locale. Every user-facing string in all three shells is externalized from day one — zero hardcoded copy — so English can be added later without rework.
- Glossary terms map 1:1 into UI copy (translated but one term per concept): e.g., **placed/accepted/delivered/cancelled** each get exactly one Spanish label used everywhere — list chips, detail timelines, notifications, operator queue. No synonyms in copy, per glossary rules.
- Tone: warm and neighborly, not corporate (packet §10). Error and empty states are worded, never technical.

**Resident shell baseline (packet §10 — non-negotiable, not overridable by later agents):**
- Large text and high contrast are the **default**, not an opt-in setting; layouts must hold at enlarged system font sizes on mid-range Android browsers without truncation.
- Simple, shallow navigation: four anchors, no gestures-only interactions, no horizontal carousels for critical content.
- Touch targets sized generously; one primary action per screen; the pickup code and the credit balance are the two largest pieces of text in their screens.
- The insufficient-credits state (R-05) and the kitchen-closed banner (R-03) use words + iconography, never color alone.

**Operator shell — kitchen tablet conditions:**
- Glare: highest-contrast theme of the three shells; no thin type; status conveyed by shape + label, not hue alone.
- Gloves / wet hands: oversized tap targets throughout; O-03 pickup-code entry uses a large on-screen keypad; destructive actions (O-04 cancel, O-06 no-longer-available, O-09 close) are two-step confirms sized so a mis-tap cannot complete them.
- Shared device: no resident-personal data surfaces in this shell (packet §9 — phone numbers never visible to operators).

**Admin shell:**
- Desktop density is acceptable (3 trained users), but the same contrast baseline and externalized strings apply; destructive confirmations (A-06 removal) restate consequences in full sentences, not icon-only buttons.

---

## 8. Open issues for the orchestrator

Items that cannot be expressed as a screen or state without inventing requirements.
No screens were created for these.

| # | Issue | Trace |
|---|---|---|
| OI-1 | **Shared-tablet session policy.** Packet §12 names a shared kitchen tablet and FR-01 defines per-person login, but nothing specifies operator identity handling across shifts on one device (stay signed in? sign out between operators? does it matter for accountability?). O-01 is specified, but its session-duration behavior is not. | packet §12, FR-01, §8 |
| OI-2 | **Removal-refund payout outcome presentation.** FR-24/A-§A.15 define the automatic payout; A-06 shows the balance and confirms initiation. The packet does not say what an administrator should see if the provider-side payout is delayed or fails after initiation (and whether the removal itself stands). Linked to open risk R-003 (state.md). | FR-24, A-§A.15, state.md R-003 |
| OI-3 | **Admin "resolve disputes" has no dedicated FR.** Packet §2 lists it as an administrator need; A-08 (all credit transactions, FR-22) + R-08 history are assumed to be the dispute surface (consistent with AC-05). Confirm no dedicated dispute screen is in scope. | packet §2, FR-22, AC-05 |
| OI-4 | **Brand palette and logo.** Packet §10: logo to be provided, palette to be proposed. Not a screen; needs a downstream owner (visual design, alongside 04). | packet §10 |
