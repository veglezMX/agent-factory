# Stack Decision Record — Comedor Vecinal

**Run:** 2026-06-comedor-vecinal
**Producer:** 04-solution-designer (handoff 0008 → 0009)
**Context:** Gate 1 recorded a stakeholder stack **preference** (not mandate): lean Python/Django, with admin-panel affinity to FR-20 (`gates/gate-1-scope.md`). This record adopts or pushes back on each element with packet-traceable rationale. No time estimates. Cost figures are monthly estimates in MXN at an assumed exchange rate of **1 USD ≈ 18.5 MXN** (assumption to re-verify at Gate 2); the binding ceiling is **2,500 MXN/month for hosting + SMS, payment fees excluded** (packet §14, A-§D).

---

## SDR-01 — Backend language & framework: **Django (Python) — ADOPTED**

The Gate 1 preference is adopted on its merits, not deference. Django fits this packet unusually well: (1) the entire correctness posture (packet §11) hangs on ACID transactions over one relational database, and Django's ORM with `transaction.atomic`, row locking (`select_for_update`), database-level constraints, and first-class migrations maps directly onto the ledger mechanics of `architecture.md` §5.1–5.2 (INV-01, INV-02, INV-03); (2) one boring, batteries-included framework matches the 3-person committee ops reality (packet §2, §16) and the cost ceiling (packet §14) — sessions, auth scaffolding, i18n (gettext, packet §10), and admin tooling come without extra services; (3) the modular-monolith decomposition maps one-to-one onto Django apps with an import-linter contract enforcing the dependency edges of `architecture.md` §4. Each module of `architecture.md` §2 is one Django app owning its models — the single-writer table groups fall out of the app structure.

## SDR-02 — django.contrib.admin for FR-20: **ASSESSED AND REJECTED for the production Admin shell** (push-back on this half of the lean)

Honest assessment, as Gate 1 requires. FR-20's recorded UI expectation is "Django-admin-style CRUD" (A-§B) — that is a **pattern** expectation (list/filter/detail/confirm, per ux-inventory §4), not a technology selection. Using `django.contrib.admin` itself as the production admin shell is rejected for three packet-traceable reasons:

1. **It creates edit surfaces the packet forbids.** Default model registration yields update/delete forms; packet §8 says admins can **never** edit or delete credit history, and INV-02/INV-18 demand append-only ledger and audit trail. Locking contrib.admin down to safety is ongoing negative work — every new model is writable until someone forbids it. The database-layer enforcement of `architecture.md` §5.1 would catch violations, but the design should not ship a UI whose default posture violates the permission matrix.
2. **It bypasses the domain services.** Resident removal must trigger the removal refund (FR-24) and audit entries must commit atomically with their actions (INV-18); contrib.admin saves models directly, skipping the application-layer orchestration that carries these invariants. The dominant admin screens are custom flows anyway: A-05 import preview (INV-17), A-06 removal-refund confirmation (FR-24), A-11 audit view.
3. **It breaks the run's frontend rule.** The three shells consume generated API clients against one OpenAPI contract (handoff 0008; `architecture.md` §7); contrib.admin is server-rendered outside that contract, so the permission matrix (packet §8) would be enforced in two places instead of one.

**Disposition:** the Admin shell is the third generated-client SPA, styled to the Django-admin-style list/filter/detail/confirm patterns the stakeholder expects (A-§B). `django.contrib.admin` may exist in non-production environments as a read-only break-glass/debug tool, disabled in production. This is the packet-traceable push-back on the "admin panel affinity" half of the preference; the Django half stands (SDR-01).

## SDR-03 — API layer: **Django REST Framework + drf-spectacular (OpenAPI 3.1)**

One versioned JSON API, contract-first artifacts: drf-spectacular emits the OpenAPI document that generates the three shells' TypeScript clients and the contract-aligned mock server (`architecture.md` §7). DRF is chosen over lighter alternatives (django-ninja) for maturity and committee-supportability (packet §2, §16) — the most-documented choice is the cheapest to operate. Module boundaries (`architecture.md` §4) are enforced with import-linter in CI; serializers live with their owning module's app.

## SDR-04 — Frontend approach: **hybrid-light — three small SPA bundles, not server-rendered pages, not a heavy SPA framework build**

Considered: (a) Django server-rendered templates — lightest payloads, but incompatible with the binding generated-clients/mock topology (handoff 0008) and poor fit for the operator queue's live-refresh interaction (FR-09, J-D); (b) full SPA framework with SSR — overkill for an authenticated app with 35 screens and adds an extra runtime to operate (packet §14, §2); (c) **chosen:** three small per-shell SPA bundles (Vite workspace; a lean component approach such as Preact/Vue — final library choice delegated to 14-frontend-feature-builder within these budgets) sharing the generated client and design tokens. Binding constraints regardless of library: resident shell initial payload budget **≤ 200 KB gzipped**, large-text/high-contrast defaults, and no gesture-only interactions — packet §10 (60+ residents, mid-range Android), §12 (mobile browser, no store apps), ux-inventory §7 baseline. Operator and admin shells are separate bundles so the resident shell never pays for them.

## SDR-05 — Database: **PostgreSQL — ADOPTED**

PostgreSQL is justified directly by the invariants: `CHECK` constraints enforce INV-01 (balance never below zero) and INV-19 (top-up bounds) in the database; `UNIQUE (poll_id, resident_id)` enforces INV-06 at the constraint level; role grants (INSERT/SELECT only) plus triggers enforce append-only credit movements and audit trail **at the database layer** (INV-02, INV-18 — `architecture.md` §5.1, §5.7); `SELECT … FOR UPDATE` row locking gives the synchronous, transactional ledger writes the reliability posture demands (packet §11). Mature dump/restore tooling (`pg_dump`, WAL archiving) serves the indefinite financial-record retention (packet §9). No other store is needed: notifications, sessions, and read models all fit one Postgres at this scale (packet §11), keeping cost and ops inside §14/§2.

## SDR-06 — Hosting: **single VPS + managed PostgreSQL (DigitalOcean proposed), card-payable**

Proposal — DigitalOcean (card payment per packet §14; no committee provider preference recorded):

| Item | Spec | USD/mo | ≈ MXN/mo |
|---|---|---|---|
| App droplet (Django + shells static assets, Docker Compose, Caddy/TLS) | 2 vCPU / 4 GB | 24 | 444 |
| Managed PostgreSQL (daily backups, point-in-time recovery) | 1 GB / 1 vCPU | 15 | 278 |
| Object storage for logical backups (Spaces) | 250 GB cap | 5 | 93 |
| Domain + TLS | Let's Encrypt free; domain amortized | ~1 | ~20 |
| **Hosting subtotal** | | **~45** | **~835** |

Rationale: one instance comfortably serves the §11 peak (~200 users in an hour); managed PostgreSQL buys automated backups and point-in-time recovery without committee DBA work (packet §2) — the one place not to economize given correctness-over-availability (§11). A PaaS (Render/Railway) is an acceptable alternative at similar cost if the committee prefers even less server tending; the VPS is proposed for cost predictability under the fixed ceiling (A-§D). Hosting region: nearest US region (no MX region on the proposed provider); latency is irrelevant at this interaction model.

**Backup strategy (one line, as required):** managed-Postgres daily automated backups + PITR, plus a weekly `pg_dump` shipped to object storage with **no deletion lifecycle** — the credit and order history is the financial record and is retained indefinitely (packet §9) — with a periodic documented restore drill.

## SDR-07 — SMS provider: **Twilio proposed; local aggregator as cost fallback**

SMS is login codes **only** (FR-01; A-§E — no order alerts; order-status notifications are in-app, FR-16). Twilio is proposed: reliable Mexico delivery, card-payable, sandbox/test credentials that suit the fake-first posture (packet §7), and only the phone number + code text is ever sent to it (packet §9). Order of magnitude per outbound SMS to Mexico: **≈ USD 0.05–0.09 ⇒ ≈ 0.9–1.7 MXN** including potential carrier surcharges (verify current rate card at integration time — R-007).

Volume model at ~400 residents: sessions are deliberately long-lived on residents' own phones (`architecture.md` §6) precisely so OTP sends are rare — enrollment, new device, expiry renewal, admin login reset (FR-03). Steady-state estimate **≈ 300–800 SMS/month ⇒ ≈ 270–1,360 MXN/month**; launch month carries a one-time enrollment spike (~400+ extra sends). If realized unit cost lands at the top of the range, a Mexico-local aggregator (e.g., SMS Masivos-class, typically well under 0.5 MXN/SMS) is the named fallback behind the same SMS port (`integration-inventory.md` §2) — a provider swap, not a redesign.

## SDR-08 — Combined cost vs the ceiling: **fits, with stated headroom**

| Scenario | Hosting | SMS | Total | vs 2,500 MXN ceiling (A-§D) |
|---|---|---|---|---|
| Expected steady state | ~835 | ~270–700 | **~1,100–1,550** | ~950–1,400 headroom |
| Worst modeled (high SMS unit cost + high volume) | ~835 | ~1,360 | **~2,200** | ~300 headroom — thin |
| Launch month (enrollment spike) | ~835 | up to ~2,000 | may brush the ceiling once | flagged to approver |

The design protects the ceiling structurally (long-lived resident sessions, per-phone OTP rate limits, in-app-only notifications per A-§E). The thin worst-case headroom and FX/rate-card sensitivity are recorded as **R-007** rather than silently absorbed. Payment-provider fees are excluded from the ceiling by A-§D and are not modeled here.

## SDR-09 — i18n: **externalized strings everywhere; es-MX sole launch locale**

Backend: Django gettext with es-MX as the default locale; API responses carry stable message keys plus parameters wherever shells render them, so copy lives in shell catalogs. Shells: one message-catalog layer (es-MX at launch), zero hardcoded user-facing strings — CI lints for literals. Glossary terms map 1:1 into copy keys (one Spanish label per term, no synonyms — glossary rules; ux-inventory §7). This satisfies packet §10: English later is a new catalog, not rework.

## SDR-10 — Decision summary

| # | Decision | Verdict | Primary citations |
|---|---|---|---|
| SDR-01 | Django backend | Adopt (preference confirmed on merits) | §11, §2, §14, INV-01..03, gate-1 |
| SDR-02 | django.contrib.admin as Admin shell | **Push back** — patterns yes, technology no | §8, INV-02, INV-18, FR-24, A-§B |
| SDR-03 | DRF + OpenAPI, generated clients | Adopt | handoff 0008, §8, §2 |
| SDR-04 | Three light SPA bundles, ≤200 KB resident budget | Adopt | §10, §12, handoff 0008 |
| SDR-05 | PostgreSQL | Adopt | INV-01/02/06/18/19, §9, §11 |
| SDR-06 | VPS + managed Postgres (DigitalOcean), ~835 MXN | Propose | §14, A-§D, §11, §9 |
| SDR-07 | Twilio SMS, local-aggregator fallback | Propose | FR-01, A-§E, §9, §7, §14 |
| SDR-08 | Combined ≈1,100–2,200 MXN vs 2,500 ceiling | Fits; thin worst case flagged (R-007) | §14, A-§D |
| SDR-09 | gettext + shell catalogs, es-MX | Adopt | §10, glossary |
