---
handoff: 0008
run: 2026-06-comedor-vecinal
from: 01-delivery-orchestrator
to: 04-solution-designer
task: 02-design/architecture-stack-integrations
status: complete
gate_impact: gate-2
inputs:
  - runs/2026-06-comedor-vecinal/01-requirements/requirements.md
  - runs/2026-06-comedor-vecinal/01-requirements/glossary.md
  - runs/2026-06-comedor-vecinal/02-design/ux-inventory.md
  - runs/2026-06-comedor-vecinal/00-packet/stakeholder-input-packet.md
  - runs/2026-06-comedor-vecinal/00-packet/amendment-001.md
  - runs/2026-06-comedor-vecinal/gates/gate-1-scope.md
  - runs/2026-06-comedor-vecinal/handoffs/0007-ux-flow-designer-to-orchestrator.md
outputs: []
decisions:
  - "UX inventory accepted (35 screens, all 24 FRs covered); OI-3 dispute-resolution mapping to the all-transactions view accepted as sufficient for launch (packet §2 admin needs)"
  - "OI-4 (palette/logo) deferred to 14-frontend-feature-builder per packet §10 ('propose a palette')"
  - "OI-1/R-005 (shared-tablet session) and OI-2/R-004 (payout-leg semantics) assigned to 04 to address in design"
risks: []
open_questions: []
next_recommended: 04-solution-designer
---

## Context summary

Gate 1 approved with a stakeholder stack preference: lean Python/Django
(preference, not mandate — justify or push back). Constraints that bind the
design: 2,500 MXN/month ceiling (hosting + SMS; payment fees excluded),
browser-only three shells, ~400 residents with ~half active within one hour
at peak, correctness over availability (packet §11 — wrong balances worse
than downtime), Mercado Pago confirmed for top-ups in AND removal refunds
out (R-003), SMS provider for Mexico to be proposed, Excel registry import,
fake-first integrations (packet §7), notifications in-app only.

## What was done

Routing; open-issue triage from handoff 0007.

## What was NOT done and why

n/a

## Boundary touches

None.

## Verification performed

n/a (routing handoff)

## Notes for the receiver

Decompose to serve THIS packet's constraints — do not mimic the playbook's
six-service sketch if a modular monolith with explicit module boundaries and
single-writer data ownership serves the cost ceiling and ops reality better;
either way, boundaries and data ownership must be explicit and reviewable by
08. Address R-004 (payout-leg) and R-005 (tablet session) in the design.
End by writing handoff 0009 (04 → 01).
