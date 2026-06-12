# Open Questions — Comedor Vecinal

**Run:** 2026-06-comedor-vecinal · **Producer:** 02-requirements-analyst · **For:** Valentin (packet §16, single decision-maker)
**Batched per packet §16.** Per packet rules, each blocking question blocks only its affected features; building on a guess is never acceptable.

> **STATUS: ALL ANSWERED — 2026-06-11.** Answers confirmed and frozen in `00-packet/amendment-001.md`; requirements.md and glossary.md updated (handoff 0004).
>
> | OQ | Answer |
> |---|---|
> | 01 | **Mercado Pago** confirmed as payment provider |
> | 02 | Ceiling **2,500 MXN/month** (hosting + SMS; payment fees excluded) |
> | 03 | Polls and admin all-transactions view both promoted to **MUST** |
> | 04 | Audit trail added as **MUST**: role changes, resident add/remove, login resets, registry imports |
> | 05 | Removal refund: remaining balance **auto-refunded to original card(s)** via payment provider, recorded as credit movement — sole exception to credits-never-become-money |
> | 06 | Removal always explicit (admin panel, Django-admin-style); import only adds/updates |
> | 07 | Closing kitchen blocks new orders; operator must resolve remaining queue; closing never auto-cancels |
> | 08 | Confirmed: all refunds/payouts system-initiated; no role manually moves credits |
> | 09 | Confirmed: participation stored separately from ballot content; only participation visible |
> | 10 | Week-menu edits: **draft → publish**, same as daily dishes |
> | 11 | "No longer available" applies to **both** week-menu and daily dishes |
> | 12 | Cycle is **ad-hoc, operator-opened**; no fixed cadence |
> | 13 | Notifications **in-app only** at launch; SMS solely for login codes |
> | 14 | Top-up bounds **50–2,000 credits** per transaction |

Original questions kept below for audit.

---

## Blocking (Gate 1 cannot pass unanswered)

### OQ-01 — Payment provider (carried from packet §7 `OPEN`)
Stripe account believed to exist; asked 2026-06-11, unconfirmed. **Blocks:** FR-14 (card top-up) real-adapter work; fake-first work may proceed.
*Options:* confirm Stripe / name another provider (e.g., Mercado Pago) / authorize fake-only launch path.

### OQ-02 — Monthly cost ceiling (carried from packet §14 `OPEN`)
No number committed. **Blocks:** Gate 2 cost-relevant choices (hosting, SMS provider).
*Options:* a hard MXN/month number / a soft target + approval at Gate 2 per choice.

### OQ-03 — SHOULD features inside the release gate (contradiction)
AC-05 (two admins reconcile any balance) requires FR-22 *admin view of all credit transactions* — tagged SHOULD. AC-06 (poll of 100 voters) requires FR-18 *polls* — tagged SHOULD. A SHOULD feature that slips fails the release gate, making these effectively MUST. **Blocks:** scope baseline.
*Options:* promote FR-18 + FR-22 to MUST / keep SHOULD and move AC-05, AC-06 out of the release gate into post-launch checks.

### OQ-04 — Audit trail granted but not scoped (contradiction)
§8 grants admins "view an audit trail of sensitive actions," but §4 does not list an audit-trail feature; by the packet's own default rule (not in §4 → out of scope), the grant has nothing to act on. **Blocks:** admin scope, security design.
*Options:* add to §4 as MUST / as SHOULD / strike from §8 for launch. If kept: which actions are "sensitive" — proposal: role changes, resident add/remove, login resets, registry imports.

### OQ-05 — Removed resident with positive balance (money gap)
§9: removed residents lose access, history remains. §15: credits never become money. A removed resident's positive balance is therefore stranded — packet states no rule. **Blocks:** FR-20 (remove resident), ledger rules.
*Options:* balance forfeits to community fund (recorded movement) / balance frozen, restored if re-added / removal blocked until balance is zero.

### OQ-06 — Registry re-import semantics (money + access)
When admins upload a new sheet, is a previously active resident who is absent from it removed automatically (access loss + OQ-05 consequences), or is removal always an explicit admin action with the import only adding/updating? **Blocks:** FR-02, FR-20.

### OQ-07 — Orders pending at kitchen close (money gap)
Kitchen closes (schedule or operator early close) with orders still placed or accepted. Packet states no rule. **Blocks:** FR-12, ordering close-out behavior.
*Options:* auto-cancel + refund + notify at close / remain valid for fulfilment until operator resolves each / operator forced to resolve queue before closing.

### OQ-08 — Refund initiation (rule/permission reconciliation)
§5.5/§5.12 make refunds automatic; §8 says operators can never modify balances "beyond refunds triggered by cancellation." Confirm: every refund is system-initiated by a cancellation event; no operator ever manually moves credits. (Expected: yes — confirmation closes it.)

---

## Clarifying (answer at Gate 1, or defer to design with approver's note)

### OQ-09 — Vote anonymity vs participation tracking
§6 tracks "who voted" while §9 makes votes anonymous to everyone. Confirm participation (who voted) is stored separately from ballot content (what they chose), and only participation is ever visible.

### OQ-10 — Week-menu edit flow
Daily dishes have draft→publish. Does a week-menu edit also pass through draft→publish, or apply immediately (still all-at-once per INV-09)?

### OQ-11 — "No longer available" on week-menu dishes
The flag is per dish per day. Confirm it applies to week-menu dishes as well as daily dishes.

### OQ-12 — Cycle cadence
"Cycle" has no defined length. Fixed cadence (e.g., weekly, configurable) or ad-hoc — a cycle simply begins when operators open a poll?

### OQ-13 — Notification channels
§7 mentions SMS for "optional order alerts"; §4's notifications MUST doesn't name a channel. In-app only at launch, or SMS alerts too (per-message cost — interacts with OQ-02)? If SMS: opt-in per resident?

### OQ-14 — Top-up bounds
Minimum/maximum top-up amount per transaction? (Anti-typo guard, e.g., 50–2,000 MXN, or no bounds.)

---

*Answer format suggestion: reply per ID ("OQ-03: promote both to MUST"). Answers become a packet amendment; the frozen packet is never edited.*
