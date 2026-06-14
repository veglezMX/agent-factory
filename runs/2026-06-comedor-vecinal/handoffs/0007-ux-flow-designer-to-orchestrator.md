---
handoff: 0007
run: 2026-06-comedor-vecinal
from: 03-ux-flow-designer
to: 01-delivery-orchestrator
task: 02-design/ux-inventory
status: complete
gate_impact: gate-2
inputs:
  - runs/2026-06-comedor-vecinal/handoffs/0006-orchestrator-to-ux-flow-designer.md
  - runs/2026-06-comedor-vecinal/01-requirements/requirements.md
  - runs/2026-06-comedor-vecinal/01-requirements/glossary.md
  - runs/2026-06-comedor-vecinal/00-packet/stakeholder-input-packet.md
  - runs/2026-06-comedor-vecinal/00-packet/amendment-001.md
  - runs/2026-06-comedor-vecinal/state.md
outputs:
  - runs/2026-06-comedor-vecinal/02-design/ux-inventory.md
decisions:
  - "Operator/admin shells hold role-specific screens only; staff use the resident shell for resident capabilities — keeps the shared tablet free of personal data (packet §8, §9, §12)"
  - "Insufficient-credits is a first-class state of R-05 order confirmation with exact shortfall and top-up routing, never an error toast (J-A′, AC-02)"
  - "External payment page excluded from the inventory; return handled by R-10 top-up result with success and failed/abandoned states (FR-14, J-B, AC-03)"
  - "Deliver-by-pickup-code (O-03) and cancel (O-04) are distinct confirmation routes off the queue, not inline row actions (FR-09, FR-10, FR-15)"
  - "One availability screen (O-06) covers week-menu AND daily dishes per the confirmed interpretation (FR-06, A-§F)"
  - "Kitchen closed modeled as a first-class additional state on R-03/R-04/R-05 and as a remaining-queue state on O-02 — closing never auto-cancels (FR-12, INV-16, A-§A.16)"
  - "Poll voting screen carries rejected-second-vote and poll-closed-mid-screen as named states (FR-18, J-E, INV-06)"
  - "A-06 removal confirmation shows remaining balance and states the automatic removal refund to original card(s) before executing (FR-24, A-§A.15, INV-15)"
  - "Registry import screen states the adds/updates-only invariant and always reports 0 removed (FR-02, INV-17, A-§A.17)"
  - "Login reset is its own confirmation route off the resident record for audit clarity (FR-03, FR-23)"
  - "Top-up amount control enforces 50–2,000 bounds inline with an out-of-bounds state (FR-14, INV-19)"
risks:
  - {id: R-004, severity: med, text: "Removal-refund payout outcome presentation unspecified: A-06 confirms initiation, but the packet does not define what an admin sees if the provider payout is delayed/fails after initiation, nor whether the removal stands — UX cannot finalize A-06 success/error semantics until 04/12 resolve this (FR-24, A-§A.15; linked to R-003)"}
  - {id: R-005, severity: low, text: "Shared-tablet session policy undefined: per-person login (FR-01) on one shared device (packet §12) with no specified sign-out/shift behavior — O-01 session duration semantics open (ux-inventory OI-1)"}
open_questions: []
next_recommended: 04-solution-designer
---

## Context summary

Gate 1 approved scope (handoff 0006); this task turns the 3 roles, 5 journeys
(+J-A′ failure path), 24 FRs, and 19 invariants into a complete interface
inventory ahead of Gate 2. Inputs were the frozen packet, amendment-001, the
requirements document, the glossary (ubiquitous language, no synonyms), and
state.md (open risk R-003 on Mercado Pago partial-refund coverage, FR-24).
Constraints honored: three shells on three device contexts (packet §12),
60+/large-text/high-contrast baseline (packet §10), es-MX with externalized
strings, route-level states for every screen, insufficient-credits as a
first-class state of order confirmation, glossary terms verbatim, no time
estimates, no technology choices ("Django-admin-style" recorded only as the
FR-20 UI expectation). Requirements with no clean screen/state expression were
listed as open issues, not guessed.

## What was done

Wrote `02-design/ux-inventory.md`:

- **Three shells** defined with device posture: Resident (Android mobile
  browser, 60+ baseline), Operator (shared kitchen tablet; glare/gloves),
  Admin (desktop; Django-admin-style CRUD expectation, FR-20).
- **35 screens**: 13 resident (R-01…R-13), 10 operator (O-01…O-10), 12 admin
  (A-01…A-12). Every screen has purpose, FR-nn/packet-§ citations, and the
  five route states (loading/empty/error/unauthorized/success) plus named
  journey states: insufficient credits (R-05), kitchen closed (R-03/R-04/R-05,
  O-02), dish no longer available (R-04/R-05), failed/abandoned top-up (R-10),
  rejected-second-vote and poll-closed-mid-screen (R-11), remaining-queue-
  after-close (O-02), draft/published sub-modes (O-07/O-08), removal-refund
  confirmation (A-06), 0-removed import summary (A-05).
- **Navigation maps** per shell (indented trees).
- **Journey traces** J-A, J-A′, J-B, J-C, J-D, J-E mapped to screen sequences.
- **Accessibility & i18n notes**: es-MX only, all strings externalized,
  large-text/high-contrast as default, glossary 1:1 into UI copy, tablet
  glare/glove handling, no personal data on the shared tablet.
- **4 open issues** (OI-1…OI-4) for items not expressible as screens/states.

## What was NOT done and why

- No wireframes, components, visual design, or copy decks — out of this
  task's scope (inventory only); palette/logo flagged as OI-4 (packet §10).
- No API contracts, data shapes, or technology selection — boundary of this
  agent; 04-solution-designer owns those.
- No screen for "resolve disputes" (packet §2) — no FR backs a dedicated
  surface; assumed served by A-08 + history views, flagged as OI-3 rather
  than invented.
- No SMS-notification or order-modification surfaces — out of scope per
  A-§E and packet §15 scope default.

## Boundary touches

- "Django-admin-style" appears exactly once as the recorded FR-20 UI
  expectation, explicitly marked as not a technology selection.
- Mercado Pago is named only as the confirmed FR-14/FR-24 provider (A-§C);
  the external payment page is excluded from the inventory.
- Accessibility requirements restated as non-overridable baseline (packet
  §10) — no requirement was weakened or extended.

## Verification performed

- Coverage check: all 24 FRs appear in at least one screen citation except
  none — FR-01…FR-24 each cited (FR-15/FR-16/FR-17 via R-07/O-04/R-13).
- All five route states present on every screen entry; J-A′, J-E special
  states present as named first-class states.
- Glossary audit: placed/accepted/delivered/cancelled, week menu, daily dish,
  no longer available, pickup code, kitchen hours, removal refund, audit
  trail used verbatim; no banned synonyms; "menu" never used bare.
- No time estimates; no framework names in the inventory.

## Notes for the receiver

- R-004 must reach 04/12 with R-003: A-06's success/error semantics for the
  payout leg are intentionally provisional.
- OI-1 (shared-tablet session) and OI-3 (disputes surface) are cheap
  stakeholder confirmations — candidates for batching per packet §16.
- OI-4 (palette/logo) needs an owner before any visual design work.
- The inventory is the screen-level contract for Gate 2; 04-solution-designer
  can map routes/data needs directly from screen IDs (R-nn/O-nn/A-nn).
