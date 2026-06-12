# Packet Interview State — Comedor Vecinal

**Working state only — never the packet.** Created 2026-06-11. Resume interrupted interviews from here.

**Intended packet destination (default, operator to confirm at save):** `runs/2026-06-comedor-vecinal/00-packet/stakeholder-input-packet.md`

**Stakeholder:** Valentin (committee tech lead, per §16 of template example; matches git user and session operator).

## Input sources

1. Template worked example in `stakeholder-input-packet.md` (Comedor Vecinal) — calibrates detail; content pending stakeholder confirmation that it is real project truth.
2. `comedor-vecinal-execution-playbook.md` — confirms project identity; its assumption line ("Stripe confirmed; SMS provider to be proposed; cost ceiling confirmed") is a playbook assumption, NOT a stakeholder confirmation. Treat the three `OPEN` items as still open until answered.

## Section map (pending Round 1 baseline confirmation)

| § | Section | Status | Notes |
|---|---|---|---|
| 1 | Project Identity | PARTIAL | Example text exists; needs confirmation as real content |
| 2 | Users & Roles | PARTIAL | Same |
| 3 | User Journeys | PARTIAL | Journey E has no thing-goes-wrong path (gate requires one per journey) |
| 4 | Feature Inventory | PARTIAL | Missing candidates: kitchen demand summary, per-dish stock limits, pickup verification |
| 5 | Business Rules | PARTIAL | Missing rules: order quantity limits, ordering window/cutoff, published-menu edit policy |
| 6 | Information Tracked | PARTIAL | Order quantities per dish unstated |
| 7 | External Touchpoints | PARTIAL | `OPEN`: Stripe confirmation |
| 8 | Permissions | PARTIAL | "Order for themselves" — ordering for others never asked |
| 9 | Privacy & Retention | PARTIAL | `OPEN`: LFPDPPP review |
| 10 | Language & Accessibility | PARTIAL | Example looks complete; confirm in baseline |
| 11 | Scale & Reliability | PARTIAL | Example looks complete; confirm in baseline |
| 12 | Devices & Channels | PARTIAL | Example looks complete; confirm in baseline |
| 13 | Acceptance Examples | PARTIAL | 8 examples; may need additions for new rules (stock, cutoff) |
| 14 | Constraints | PARTIAL | `OPEN`: cost ceiling |
| 15 | Out of Scope | PARTIAL | Credit cash-out / refund-to-card exclusion not explicit; multiple menus per day implicit only |
| 16 | Decision Process | PARTIAL | Valentin named; confirm in baseline |
| 17 | Glossary | PARTIAL | One-menu-per-date implication to confirm |

## Hedges / contradictions to resolve

- H1: §7 "We have a Stripe account (`OPEN`: confirm)" — playbook assumes confirmed; stakeholder has not said so in this interview.
- H2: §14 cost ceiling `OPEN`.
- H3: §9 LFPDPPP review `OPEN`.
- C1: Glossary implies one menu per date; §15 does not exclude breakfast/dinner explicitly.

## Question queue

**Round 1 (asked 2026-06-11):**
- Q1 Baseline: is template example real project content as-is?
- Q2 Order quantity limits (multiples of same dish, daily cap).
- Q3 Ordering window (open/close moments).
- Q4 Per-dish stock limits / sold-out behavior.

**Round 2 (pending):**
- Q5 Kitchen demand summary feature + priority.
- Q6 Pickup verification mechanism.
- Q7 Published-menu editing policy.
- Q8 Ordering for others (family/neighbor).

**Round 3 (pending):**
- Q9 Multiple menus per day → §15/§17.
- Q10 Credit cash-out exclusion → §15.
- Q11 Journey E failure path (double vote / poll closes mid-vote).
- Q12 The three `OPEN` items: Stripe, cost ceiling, LFPDPPP.

## Answers log

**Round 1 (2026-06-11):**

- A1 (baseline): **Yes, as-is.** Template example content = stakeholder's own statements. All PARTIAL sections promote to FILLED-pending-read-back; gaps below still open.
- A2 (order limits): Multiples of same dish OK. No fixed per-resident cap — "daily cap is limited to production; the app should flag when a dish is no longer available in the day."
- A3 (order window): **NEW STRUCTURE** — "There is a week menu that will never change, plus a set of Daily dishes available only during the day until the kitchen closes." Two menu types: fixed weekly menu + daily dishes. Ordering closes when kitchen closes.
- A4 (dish stock): Unlimited + kitchen cancels (existing example behavior; refund automatic).

**New items raised by Round 1:**

- C2 (tension A2 vs A4): A2 says app flags dish unavailable in-day; A4 says unlimited ordering with cancel-on-runout. Likely combined rule: operator manually flags dish unavailable → app blocks NEW orders; already-placed unfulfillable orders cancelled + refunded. CONFIRM in Round 2.
- N1: weekly menu mechanics — always orderable during kitchen hours? who maintains it? does draft/publish apply only to daily dishes? does the poll feed weekly menu or daily dishes?
- N2: "kitchen closes" — boundary moment needs definition (configurable kitchen hours acceptable).

**Round 2 (2026-06-11):**

- A5 (sold-out rule, resolves C2): CONFIRMED — operator marks dish "no longer available" → app blocks new orders for it. If placed orders exist that kitchen cannot fulfil, those are cancelled; resident notified ("refund is in place, sorry for the inconvenience, dish is no longer available") and refund automatic.
- A6 (menu types, resolves N1): **Standing + daily specials.** Week menu = fixed dish list always orderable any open day, edited rarely by operators. Daily dishes = extras published each day, orderable only that day until kitchen closes. Polls feed the daily dishes.
- A7 (demand summary): MUST. Per-dish ordered-portions count for the day, visible to operators. PLUS stated purpose/extension: track sales per dish so admins can decide raw-material purchase quantities → admin per-dish sales view. Priority of admin sales view: ask Round 4.
- A8 (pickup): **Pickup code.** Each order gets a short code; resident says/shows it; operator enters/taps it to mark delivered.

**Round 3 (2026-06-11):**

- A9 (order for others): **Anyone, own credits.** Resident may order any number of meals paid from their own balance; pickup by whoever has the code; no formal household linking.
- A10 (cash-out): exclude explicitly in §15 — credits are spend-only; refunds always return credits, never money.
- A11 (voting failure path): second vote attempt rejected with clear message; voting after close shows "poll closed" and routes to results; nothing double-counted.
- A12 (payment provider): **still `OPEN`** — stakeholder asked, could not confirm. Carry `OPEN` (legitimate per skill: question was put to stakeholder).

**Round 4 (2026-06-11):**

- A13 (cost ceiling): **still `OPEN`** — asked, no number yet. Carry `OPEN`.
- A14 (LFPDPPP): **no formal review** — follow Mexican consumer-data norms as written in §9; resolves H3.
- A15 (kitchen hours): **Both** — admin-set weekly schedule as default + operator switch to close early / open late on any day. Resolves N2.
- A16 (admin sales view): **MUST.**

All queue items answered. Hedges: H1 (Stripe) → legitimate `OPEN`; H2 (ceiling) → legitimate `OPEN`; H3 resolved; C1 resolved by week-menu + daily-dishes structure (A6); C2 resolved (A5).

**Phase 3 read-back (pending):** §5 (15 rules), §8 (3 roles incl. new abilities), §13 (10 examples), §15 (8 exclusions incl. cash-out, household links, inventory).
