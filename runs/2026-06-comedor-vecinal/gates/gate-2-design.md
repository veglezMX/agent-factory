# Gate 2 — Design

run: 2026-06-comedor-vecinal
decision: approved-with-conditions
approver: Valentin (packet §16)
date: 2026-06-11
evidence_reviewed:
  - runs/2026-06-comedor-vecinal/02-design/architecture.md
  - runs/2026-06-comedor-vecinal/02-design/stack-decision-record.md
  - runs/2026-06-comedor-vecinal/02-design/integration-inventory.md
  - runs/2026-06-comedor-vecinal/02-design/ux-inventory.md
  - runs/2026-06-comedor-vecinal/findings/architecture/review-001.md  (clean-with-conditions, 0 blocking)
conditions:
  - "C-1: designate single primary owner module for FR-06 / FR-12 / FR-24 before bundle compilation"
  - "C-2: Mercado Pago sandbox partial-refund validation before FR-24 implementation starts (R-003)"
  - "C-3a: RESOLVED AT GATE — residual-shortfall policy decided by approver (see notes; amendment-002)"
  - "C-3b: sample registry Excel still pending (R-006) — importer task blocks until provided"
  - "C-4: vote-anonymity DB mechanics fixed per review-001 (R-008)"
  - "C-5: operator PIN throttling/lockout added to shared-tablet scheme (R-009)"
notes: >
  Stack approved: Django/DRF modular monolith (8 modules), PostgreSQL,
  3 generated-client SPAs; django.contrib.admin pushback endorsed by approver.
  Hosting DigitalOcean VPS + managed Postgres ~835 MXN/mo; SMS Twilio
  ~270–1,360 MXN/mo; fits 2,500 MXN ceiling (R-007 watches headroom).
  Approver decisions at gate: (1) residual-shortfall on removal refund —
  committee pays outside the app; admin sees refundable/residual split before
  confirming; residual recorded as a payout movement that zeroes the balance
  (frozen as 00-packet/amendment-002.md). (2) Bootstrap: seed the approver
  (Valentin) as initial administrator; residents manageable via the admin
  panel (FR-20) until the Excel sample arrives — FR-02 import remains MUST,
  its build blocks on R-006.
