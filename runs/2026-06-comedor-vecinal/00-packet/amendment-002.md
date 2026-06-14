# Packet Amendment 002 — Comedor Vecinal

**Run:** 2026-06-comedor-vecinal
**Date:** 2026-06-11
**Source:** Stakeholder (Valentin, packet §16) decision at Gate 2 (R-004 residual-shortfall question, batched per condition C-3).
**Status:** Stakeholder-confirmed (Gate 2 record). Supersedes nothing; refines amendment-001 §A rule 15.

---

## A. §5 rule 15 — removal refund, residual-shortfall clause added

**15 (refined).** Credits never convert back to money inside the app, with exactly one exception: when an administrator removes a resident who has a positive balance, the card-refundable part of the balance is automatically refunded to the card(s) of their original top-ups through the payment provider. Any residual that cannot be refunded to a card is paid by the committee **outside the app**; the administrator sees the refundable/residual split before confirming the removal, and the residual is recorded as a payout movement so the balance reaches exactly zero. Both movements are permanent history (rule 2).

## B. Derived clarifications

- The admin removal flow (UX screen A-06) must present the refundable/residual split as a confirmation step before any movement is written.
- The residual payout movement records that money was handed over outside the app; the app enforces the record, not the payment.
- Bootstrap note (operational, not scope): initial administrator account seeded for Valentin; residents manageable via the admin panel until the registry Excel sample arrives. FR-02 (import) remains MUST and blocks on R-006.
