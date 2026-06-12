# Domain Glossary — Comedor Vecinal (Ubiquitous Language)

**Run:** 2026-06-comedor-vecinal · **Producer:** 02-requirements-analyst · **Source:** packet §17 + terms used normatively elsewhere in the packet.

These words mean exactly one thing everywhere — requirements, contracts, schemas, code, tests, UI copy (translated, but 1:1). **No synonyms.** An artifact using a synonym ("voucher" for credit, "special" for daily dish, "closed" for cancelled) is non-conformant.

## From packet §17 (stakeholder-confirmed verbatim)

| Term | Definition |
|---|---|
| **Credit** | The internal prepaid unit; 1 credit = 1 MXN at top-up time. |
| **Registry** | The admin-maintained list of community members; sole source of who may log in. |
| **Cycle** | The period between polls; begins when operators open a poll; no fixed cadence. One poll per cycle; polls choose daily dishes. *(amended by amendment-001 §G)* |
| **Placed / Accepted / Delivered / Cancelled** | The only four order states. |
| **Published** | A menu visible to residents; the opposite of **Draft**. |
| **Week menu** | The standing list of dishes orderable on any day the kitchen is open; edited rarely, by operators. |
| **Daily dish** | A dish published for one specific date, orderable only that day while the kitchen is open. |
| **No longer available** | A per-day flag on a dish; blocks new orders immediately, triggers cancel + automatic refund of unfulfillable placed orders. |
| **Pickup code** | A short code attached to each order; the operator confirms it to mark the order delivered. |
| **Kitchen hours** | The admin-set weekly schedule, plus an operator switch to close early or open late on any given day. |

## Promoted from packet body (used normatively; definitions trace to cited sections)

| Term | Definition | Trace |
|---|---|---|
| **Top-up** | A credit movement adding credits via online card payment. | §3 J-B, §6 |
| **Refund** | A credit movement returning credits (never money) after a cancellation. | §5.4, §5.5, §5.15 |
| **Credit movement** | One append-only record: who, amount, direction, reason (top-up / order / refund), linked order or payment. | §6 |
| **Resident / Kitchen Operator / Administrator** | The only three roles. | §2 |
| **Registry import** | Admin upload of the community Excel sheet; the app syncs residents from it. | §7, §14 |
| **Kitchen open / closed** | The state controlled by schedule + operator override; ordering possible only while open. Closing never cancels existing orders. | §5.10, A-§A.16 |
| **Removal refund** | The automatic payout of a removed resident's remaining balance to the card(s) of their original top-ups; the single exception to credits-never-become-money. | A-§A.15, A-§G |
| **Audit trail** | The append-only record of sensitive administrator actions: role changes, resident add/remove, login resets, registry imports. | A-§A.18, A-§G |

## Banned ambiguities

- "Menu" alone is ambiguous — always **week menu** or **daily dishes**.
- "Available" alone is ambiguous — a dish is orderable, or flagged **no longer available**.
- "Refund to the resident" never means money out — see **Refund**.
