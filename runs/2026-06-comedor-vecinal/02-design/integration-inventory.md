# Integration Inventory — Comedor Vecinal

**Run:** 2026-06-comedor-vecinal
**Producer:** 04-solution-designer (handoff 0008 → 0009)
**Posture:** all three integrations are **fake-first** (packet §7): every external touchpoint sits behind a port (interface) owned by exactly one module (`architecture.md` §4), with a deterministic fake as the default implementation in development and tests. Real adapters are sandbox-first and swapped in by configuration only. No time estimates. Glossary terms verbatim.

---

## 1. Mercado Pago — card payments (top-ups in, removal refunds out)

**Confirmed provider** (A-§C; FR-14, FR-24). Two money directions, one port.

### Interface boundary

- **Port:** `PaymentsPort`, owned by **credit-ledger** — the only module that touches it (`architecture.md` §4). Operations: `create_topup_checkout(attempt_id, amount_credits) → checkout_url`, `get_payment_status(provider_payment_id)`, `refund_payment(provider_payment_id, amount, idempotency_key)` for removal refund payout legs.
- **Top-up flow (J-B, R-09/R-10):** resident picks an amount (50–2,000 credits, INV-19, enforced again by ledger CHECK); the port creates a hosted-checkout session (Checkout Pro-style redirect — matches ux-inventory's "external payment page, not part of this inventory") with an opaque `external_reference` = our `payment_attempt` id; resident pays on the provider page and returns to R-10.
- **Confirmation is server-verified, never redirect-trusted:** R-10 asks our server; our server queries payment status from the provider (and independently receives webhooks). Crediting is **idempotent per provider payment id** — exactly one top-up credit movement per approved payment, whichever of return-poll or webhook arrives first (AC-03; packet §11).
- **Webhook handling:** endpoint validates the notification's authenticity per provider mechanism, then **re-fetches the payment status from the provider API** before acting (never trusts webhook payload contents); unknown/duplicate notifications are acknowledged and dropped. Webhook processing performs the same idempotent ledger call as return-polling.
- **Removal refund (FR-24, INV-15):** identity-registry orchestrates removal; credit-ledger computes payout legs **newest-first, partial-refund per payment** (`architecture.md` §5.6) and submits each via `refund_payment` with a per-leg idempotency key. A leg's credit movement is recorded only on provider confirmation.

### Fake behavior (deterministic, per J-B)

The fake implements the full port plus a fake "payment page" route. Scenario selection is deterministic by amount suffix (documented for testers): e.g., amounts ending **.00 → success**, **specific marker amount → failure**, **specific marker amount → abandon** (user returns without paying). The fake emits the same webhook calls the real provider would, so success/failure/abandon each exercise the identical code path: success → approved status + webhook; failure → rejected status, balance unchanged, attempt visible as **failed** in R-08 history; abandon → attempt stays pending then expires, balance unchanged (J-B). Refund legs in the fake: configurable per-leg outcomes (confirmed / rejected / delayed) to drive A-06 and the R-004 mitigation states, including the partial-refund and refund-window-exceeded cases (R-003 rehearsal).

### Error mapping

| Provider condition | System behavior |
|---|---|
| Payment rejected / expired | `payment_attempt` → failed; **no credit movement; balance unchanged** (J-B); R-10 failed/abandoned state |
| Checkout abandoned | attempt pending → expired by timeout sweep; balance unchanged; visible as failed in history (J-B) |
| Webhook for unknown payment | acknowledged, logged, no state change |
| Duplicate notification / double return | idempotency key absorbs it — one movement maximum |
| Refund leg rejected (window exceeded, etc.) | `payout_attempt` → failed, visible to admins; no movement recorded; residual handling per R-004 mitigation (`architecture.md` §5.6) |
| Provider API down during checkout creation | R-09 error state: "could not start the payment", balance unchanged |

### Retry / timeout posture

Checkout creation: short timeout, no automatic retry (resident retries from R-09; nothing was deducted). Status verification: short timeout, bounded retries with backoff (R-10 shows "confirmando tu pago…" meanwhile; the attempt resolves via webhook regardless). Refund legs: retried with the **same idempotency key** on timeout/5xx; never retried on a definitive rejection. Webhooks: provider-side redelivery is the retry mechanism; our endpoint is idempotent and fast-acks.

### Data minimization (packet §9)

Sent to the provider: amount, currency (MXN), opaque `external_reference`, back URLs. **Never the phone number** (§9: phone numbers go to no external service except the SMS provider). The registry stores no email (packet §6); if the provider's checkout mandates a payer field, an opaque per-resident alias is used — never real personal data. Provider credentials are server-side only; sandbox credentials first (A-§C).

### Risk notes

- **R-003 (open, med):** partial-refund coverage across multiple historical top-ups — multiple partial refunds against one payment, refund windows by payment age/method, minimum refund amounts — **must be validated in the provider sandbox before Gate 2 sign-off of FR-24's mechanism**. The newest-first allocation (`architecture.md` §5.6) is designed to be robust to window limits but the limits themselves are provider facts to verify, not assume.
- **R-004 (open remainder):** residual balance when refundable card amounts < remaining balance — stakeholder policy question, batched per packet §16; mitigation in `architecture.md` §5.6.

---

## 2. SMS provider — login codes only

Proposed provider: **Twilio**, local-aggregator fallback (SDR-07). Scope is exactly FR-01 login codes: **no order alerts** (A-§E) — order-status notifications are in-app only (FR-16).

### Interface boundary

- **Port:** `SmsPort`, owned by **identity-registry** — the only module that may call it (`architecture.md` §4). Single operation: `send_login_code(phone_e164, code)`. No other message type exists in the codebase; adding one would be a contract change reviewable against A-§E.
- Codes: 6-digit, single-use, short expiry, generated and stored (hashed) by identity-registry; the port only transports.
- **Rate limiting lives on our side** (per-phone and global): protects cost (packet §14, R-007) and blunts enumeration — combined with J-C's neutral error wording, send failures and not-in-registry produce the same resident-visible message, leaking nothing about registry membership (INV-07, packet §9).

### Fake behavior

The fake **records every send** (recipient, code, timestamp) in a test-visible outbox instead of transmitting — tests and local development read the code from the outbox to complete login (J-C end-to-end without a real SMS). Deterministic failure injection by phone-number marker (e.g., a reserved test suffix → provider-error) to exercise the error path.

### Error mapping

| Condition | System behavior |
|---|---|
| Provider rejects / times out | One bounded retry; then R-01/O-01/A-01 show the neutral "could not send a code right now, try again" — same wording regardless of cause (J-C; no registry leak) |
| Number not in registry | **No send is attempted at all** (INV-07); identical neutral UI message (J-C) |
| Rate limit hit | Neutral "try again later" message; logged for cost monitoring (R-007) |

### Retry / timeout posture

Short timeout, exactly one automatic retry, then surface the neutral error. No queuing/backlog of codes (a late login code is worthless and a cost); the resident simply requests again.

### Data minimization (packet §9)

The SMS provider receives **the phone number and the code text — nothing else**: no name, no unit/address, no role, no usage metadata. This is the single permitted phone-number egress (§9). Provider dashboards/logs are configured to minimal retention where the provider allows.

---

## 3. Registry Excel import — admins' existing sheet

The community registry Excel sheet format **must keep working unchanged** — admins will not change their spreadsheet habits (packet §14). Import is FR-02; surfaced as A-05.

### Interface boundary

- **Port:** `RegistrySheetParser`, owned by **identity-registry**. Input: the uploaded workbook file; output: a normalized row set (name, phone number, unit/address — the resident fields of packet §6) plus per-row diagnostics. Parsing is pure (no writes); the **apply** step is a separate identity-registry use case behind A-05's preview→confirm flow.
- **Adds/updates only, never removes** (INV-17, A-§A.17): the apply step matches rows to residents by normalized phone number (E.164, +52 default region); unmatched sheet rows → add; matched rows → update of name/unit fields; **residents absent from the sheet are untouched** — removal exists only as the explicit A-06 flow. The A-05 result always reads "N added, M updated, 0 removed — always".
- Every import (who, when, file identity/hash, counts) writes an **audit trail** entry in the same transaction as the apply (FR-23, INV-18).
- Roles are never touched by import (INV-08 — only admins change roles, and only via A-07).

### Fake behavior

Not an external service — the "integration" is the file format itself. Fixture workbooks stand in for the real sheet: a golden fixture matching the assumed layout, plus malformed variants (missing columns, duplicate phone numbers in-sheet, unparseable phone values, empty sheet, wrong file type) driving each A-05 state deterministically (loading/empty/error/success per ux-inventory).

### Error mapping

| Condition | System behavior |
|---|---|
| Unreadable file / wrong format | A-05 error state; **registry unchanged**; plain-language message |
| Row-level problems (bad phone, missing name) | Listed per-row in the preview; admin may apply the valid rows; invalid rows are skipped and reported — never half-applied silently |
| Duplicate phone within the sheet | Flagged in preview; those rows excluded from apply until resolved in the sheet |
| Apply fails mid-way | Single transaction — full rollback, registry unchanged (packet §11 posture) |

### Retry / timeout posture

Synchronous parse with a file-size cap (a ~400-resident sheet is tiny); no retries — the admin re-uploads. Apply is one transaction; idempotent re-apply of the same sheet is naturally a no-op set of updates.

### Data minimization

The sheet never leaves the server; it is parsed and discarded — only the audit entry's file hash and the resulting resident records persist (packet §9: phone numbers admin-only). No third party is involved in this integration.

### Risk note

- **R-006 (new, med):** the parser can only be pinned by a **sample of the admins' actual sheet** (packet §14 fixes the format but the run has no copy). Until a sample is provided (request batched to the stakeholder per packet §16), the golden fixture encodes an assumed layout and the parser's column mapping is isolated in one place so the real sample changes mapping code only. Blocking note: per packet §16, FR-02's real-format parsing should not be *implemented against a guess* — the fake-first fixtures keep everything else unblocked.
