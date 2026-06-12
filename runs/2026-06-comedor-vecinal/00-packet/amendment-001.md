# Packet Amendment 001 — Comedor Vecinal

**Run:** 2026-06-comedor-vecinal
**Date:** 2026-06-11
**Source:** Stakeholder (Valentin, packet §16) answers to `01-requirements/open-questions.md` OQ-01…OQ-14, via handoff 0003.
**Status:** Stakeholder-confirmed verbatim (read-back 2026-06-11). The frozen packet under `00-packet/stakeholder-input-packet.md` is never edited; this amendment supersedes it where stated. Affected gate: Gate 1.

---

## A. §5 Business Rules — rule 15 amended, rules 16–19 added

**15 (amended).** Credits never convert back to money, with exactly one exception: when an administrator removes a resident who has a positive balance, the remaining balance is automatically refunded to the card(s) of their original top-ups through the payment provider, and the payout is recorded as a credit movement. *(OQ-05)*

**16 (new).** Closing the kitchen blocks new orders immediately; orders already placed or accepted stay valid, and the operator must resolve every one of them (deliver, or cancel with refund) — closing never cancels anything by itself. *(OQ-07)*

**17 (new).** Removing a resident is always an explicit administrator action; a registry import only adds or updates residents, never removes anyone. *(OQ-06)*

**18 (new).** Every sensitive administrator action — role changes, resident add/remove, login resets, registry imports — is recorded in the audit trail. *(OQ-04)*

**19 (new).** A top-up is between 50 and 2,000 credits per transaction. *(OQ-14)*

## B. §4 Feature Inventory — priority changes and additions

| Feature | Change | Source |
|---|---|---|
| Menu polls with one-vote-per-resident | SHOULD → **MUST** | OQ-03 |
| Admin view of all credit transactions | SHOULD → **MUST** | OQ-03 |
| Audit trail of sensitive admin actions (role changes, resident add/remove, login resets, registry imports) | **Added, MUST** | OQ-04 |
| Removal refund: automatic payout of remaining balance to original card(s) on resident removal | **Added, MUST** | OQ-05 |
| Notifications for order status changes | Clarified: **in-app only at launch** | OQ-13 |
| Admin: manage residents and staff roles | Clarified: delivered as an admin panel (Django-admin-style CRUD) for residents and roles | OQ-06 |

## C. §7 External Touchpoints — payment provider resolved

Card payments provider: **Mercado Pago** (confirmed; replaces the `OPEN` Stripe entry). Used for card top-ups in and removal refunds out. Sandbox first, unchanged.

## D. §14 Constraints — cost ceiling resolved

Monthly running cost ceiling (hosting + SMS; payment fees excluded): **2,500 MXN/month**. *(OQ-02)*

## E. §15 Out of Scope — two exclusions amended/added

- *(amended)* No cash-out or refund-to-card, **with exactly one exception:** the automatic removal refund of §5 rule 15.
- *(added)* No SMS order alerts at launch — order-status notifications are in-app only; SMS is used solely for login codes.

## F. Confirmed interpretations (reconciliations, not new scope)

- Every refund and payout is system-initiated by an event (cancellation, removal); operators and admins never manually move credits. *(OQ-08)*
- Poll participation (who voted) is stored separately from ballot content (what they chose); only participation is ever visible, to anyone. *(OQ-09)*
- Week-menu edits follow draft → publish, same as daily dishes; published changes appear to everyone at once. *(OQ-10)*
- The "no longer available" flag applies to week-menu dishes and daily dishes alike. *(OQ-11)*
- A cycle is ad-hoc: the period between polls; it begins when operators open a poll. No configured cadence. *(OQ-12)*

## G. §17 Glossary — affected entries

- **Cycle (amended):** the period between polls; begins when operators open a poll; no fixed cadence. Polls choose daily dishes.
- **Removal refund (new):** the automatic payout of a removed resident's remaining balance to the card(s) of their original top-ups; the single exception to credits-never-become-money.
- **Audit trail (new):** the append-only record of sensitive administrator actions: role changes, resident add/remove, login resets, registry imports.
