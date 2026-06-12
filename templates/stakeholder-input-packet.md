# Stakeholder Input Packet

**Purpose:** This document is the single trigger artifact for the development agent pipeline. It is written entirely in non-technical language by the project stakeholder. The Requirements Analyst agent (`00a`) consumes it first; every downstream agent traces its inputs back to a section of this packet.

**Rules for the stakeholder:**

- Write in plain language. No technical terms are required anywhere.
- "I don't know" is a valid answer — mark it `OPEN`. The Requirements Analyst will turn open items into clarification questions.
- Anything not listed in §4 (Feature Inventory) or explicitly excluded in §15 (Out of Scope) is treated as out of scope by default.
- Every section below shows the **template prompt** followed by a **worked example** (a residential community canteen app) so you can see the expected level of detail.

---

## 1. Project Identity

> **Template:** Project name (working title is fine). One paragraph: what is this, and why does it need to exist? What happens today without it?

**Example:**

**Name:** Comedor Vecinal

**Vision:** A private app for our residential community's canteen. Today, residents order lunch by sending WhatsApp messages to the kitchen staff, pay in cash, and the staff tracks credit balances in a paper notebook. Orders get lost, balances are disputed, and nobody knows what's on the menu until they ask. This app lets residents see the daily menu, order with prepaid credits, top up those credits online, and vote on upcoming menu options — while giving the kitchen staff a clear queue of orders and a trustworthy record of every credit movement.

---

## 2. Users & Roles

> **Template:** List every kind of person who will touch the system. For each: who are they, roughly how many exist, and one sentence on what they need from the app. Do not describe permissions yet (that is §8).

**Example:**

| Role | Who they are | Approx. count | What they need |
|---|---|---|---|
| Resident | Adults living in the community, registered in the community registry | ~400 | See menu, place orders, manage credits, vote in polls |
| Kitchen Operator | Staff who cook and hand out food | 4 | See incoming orders, mark them accepted/delivered, publish menus |
| Administrator | Community committee members | 3 | Manage residents and staff, see all transactions, resolve disputes, reset access |

---

## 3. User Journeys

> **Template:** Narrate the 3–7 most important walkthroughs as short stories: "Maria opens the app, then…". Cover the happy path and at least one thing-goes-wrong path per journey. These stories are the backbone of everything the agents build.

**Example:**

**Journey A — Ordering lunch (resident, happy path):**
Maria opens the app on her phone around mid-morning. She sees today's published menu with prices in credits. She picks "pollo con mole" and one agua fresca, confirms, and the app shows her order as "placed" and her credit balance reduced. Later she gets a notification that the kitchen accepted her order, and another when it's marked delivered.

**Journey A' — Ordering with insufficient credits:**
Maria tries to order but her balance is too low. The app tells her exactly how many credits she is short and offers to take her to the top-up screen. Her order is not placed and nothing is deducted.

**Journey B — Topping up credits:**
Maria taps "add credits," chooses an amount, and is sent to an online payment page. After paying with her card, she returns to the app and sees her new balance and a receipt in her transaction history. If the payment fails or she abandons it, her balance is unchanged and the attempt shows as failed in her history.

**Journey C — First-time access:**
A new resident, Jorge, was added to the community registry by an administrator. He opens the app, enters his phone number, receives a code by SMS, types it in, and is inside. People whose phone numbers are not in the registry cannot get in at all.

**Journey D — Kitchen operations:**
At opening time, the operator sees a list of placed orders, newest at the bottom, oldest first. She accepts orders as the kitchen starts them and marks them delivered when residents pick them up. If the kitchen runs out of a dish, she cancels remaining orders for it; affected residents are notified and their credits are automatically returned.

**Journey E — Menu voting:**
Once per cycle, residents see a poll with candidate dishes for the upcoming menu. Each resident votes once. When the poll closes, everyone can see the results, and the winning dishes inform the next published menu.

---

## 4. Feature Inventory & Priorities

> **Template:** List features as short verb phrases. Tag each: `MUST` (launch is meaningless without it), `SHOULD` (wanted at launch, can slip), `LATER` (explicitly deferred). Do not include time estimates — only priority.

**Example:**

| Feature | Priority |
|---|---|
| Phone-number login with SMS code | MUST |
| View today's published menu | MUST |
| Place an order paid with credits | MUST |
| See my orders and their status | MUST |
| Credit balance and transaction history | MUST |
| Online card top-up | MUST |
| Kitchen order queue (accept / deliver / cancel) | MUST |
| Automatic refund on kitchen cancellation | MUST |
| Notifications for order status changes | MUST |
| Admin: manage residents and staff roles | MUST |
| Menu drafting and publishing by operators | MUST |
| Menu polls with one-vote-per-resident | SHOULD |
| Mark-all-read for notifications | SHOULD |
| Admin view of all credit transactions | SHOULD |
| Credit expiration after long inactivity | LATER |
| Scheduled/recurring orders | LATER |
| Dietary preference filters | LATER |

---

## 5. Business Rules (Plain Language)

> **Template:** State the rules that must never be broken, as plain sentences. Think: money, fairness, limits, irreversibility. These become the system's invariants and its automated safety tests.

**Example:**

1. A resident's credit balance can never go below zero.
2. Every credit movement (top-up, order payment, refund) is permanent history — records are never edited or deleted, only added.
3. An order is charged at the menu price that was visible when the resident placed it, even if the menu changes afterward.
4. Residents can cancel their own order only while it is still "placed" (not yet accepted); cancellation returns the full amount.
5. When the kitchen cancels an order, the refund is automatic and immediate.
6. Each resident gets exactly one vote per poll; votes cannot be changed after the poll closes.
7. Only people present in the community registry can ever log in.
8. Only administrators can change who is staff or admin.
9. A published menu is visible to all residents at the same moment; drafts are invisible to residents.

---

## 6. Information the Business Tracks

> **Template:** List the "things" the business keeps records about and what it needs to remember about each. Plain nouns only — this seeds the data design.

**Example:**

- **Resident:** name, phone number, unit/address within the community, active or removed
- **Menu:** date it applies to, list of dishes with name/description/price in credits, whether it is draft or published, history of past menus
- **Order:** who placed it, which dishes, total in credits, current status (placed → accepted → delivered, or cancelled), timestamps of each step
- **Credit movement:** who, how much, direction (in/out), reason (top-up, order, refund), link to the related order or payment
- **Poll:** question, dish options, open/closed, who voted (but votes are anonymous in results), final tallies
- **Notification:** recipient, message, read/unread

---

## 7. External Services & Real-World Touchpoints

> **Template:** Anything that leaves the app: payments, SMS, email, third-party systems. For each: is a simulated/sandbox version acceptable for early testing? Do you already have an account/provider preference?

**Example:**

| Touchpoint | Purpose | Provider preference | Fake/sandbox OK initially? |
|---|---|---|---|
| Card payments | Credit top-ups | We have a Stripe account (`OPEN`: confirm) | Yes |
| SMS | Login codes, optional order alerts | None — recommend one available in Mexico | Yes |
| Community registry | Source of truth for who is a resident | Currently an Excel sheet maintained by admins; app should import/sync from an uploaded file | Yes |

---

## 8. Permissions (Plain Language)

> **Template:** For each role from §2, complete: "Can…" and "Can never…". The agents convert this into the enforced permission matrix.

**Example:**

**Resident — can:** see published menus, order for themselves, see only their own orders/balance/history, top up their own credits, vote once per poll, manage their notifications.
**Resident — can never:** see other residents' data, see draft menus, change order status beyond cancelling their own placed order, touch polls administration.

**Kitchen Operator — can:** everything a resident can, plus: see all orders for the day, accept/deliver/cancel any order, draft and publish menus, open and close polls.
**Operator — can never:** see or modify credit balances beyond refunds triggered by cancellation, manage residents or roles.

**Administrator — can:** everything an operator can, plus: add/remove residents, grant/revoke operator and admin roles, view all credit transactions, trigger a login reset for a resident, view an audit trail of sensitive actions.
**Administrator — can never:** edit or delete credit history, vote on behalf of residents, see how an individual voted.

---

## 9. Privacy, Compliance & Data Retention

> **Template:** What data is sensitive? What must be hidden from whom? Any legal/regulatory expectations? How long is data kept?

**Example:**

- Phone numbers are the most sensitive data; visible only to administrators, never to other residents or operators, and never sent to any external service except the SMS provider.
- Individual votes are anonymous to everyone, including administrators.
- Credit and order history is retained indefinitely (it is the financial record).
- Removed residents lose access immediately, but their historical transactions remain.
- We operate in Mexico; assume Mexican consumer data norms apply. `OPEN`: confirm whether any formal LFPDPPP review is needed.

---

## 10. Languages, Branding & Accessibility

> **Template:** Languages at launch, tone, any brand assets, accessibility expectations.

**Example:**

- Spanish (Mexico) at launch; structure everything so English can be added later without rework.
- Tone: warm and neighborly, not corporate.
- Brand: community logo will be provided; colors flexible — propose a palette.
- Must be comfortably usable by residents aged 60+ on mid-range Android phones: large text, high contrast, simple navigation.

---

## 11. Scale & Reliability Expectations (Plain Words)

> **Template:** How many people, how often, what is the cost of downtime — in everyday terms, not numbers you'd have to invent.

**Example:**

- ~400 residents; realistic peak is the late-morning ordering window when perhaps half of them open the app within the same hour.
- If the app is down during the ordering window, the kitchen falls back to WhatsApp — painful but survivable. Outside that window, downtime is a minor annoyance.
- Credit balances being **wrong** is far worse than the app being **down**. Correctness over availability, always.

---

## 12. Devices & Channels

> **Template:** Where will each role use the app?

**Example:**

- Residents: their own phones, almost entirely Android, via the mobile browser (no app-store install at launch).
- Operators: a shared tablet in the kitchen, also via browser.
- Administrators: laptops via browser.

---

## 13. Acceptance Examples ("We'll know it works when…")

> **Template:** 5–10 concrete checkable statements. These become the release gate's acceptance criteria.

**Example:**

1. A resident from the registry can go from never-having-used-the-app to a delivered order using only their phone, with no human help.
2. A resident with 0 credits cannot place any order, and is guided to top up.
3. After a successful card payment, the new balance appears without the resident needing to refresh or contact anyone.
4. When the kitchen cancels an order, the resident's refund and notification both happen without any manual step.
5. Two administrators independently reviewing the transaction history of any resident arrive at the same balance the app shows.
6. A poll with 100 voters shows exactly 100 votes, and no resident manages to vote twice.
7. Someone with a phone number not in the registry cannot get past the login screen.
8. An operator can publish tomorrow's menu from the tablet in under a minute of interaction.

---

## 14. Constraints & Preferences

> **Template:** Hosting preferences, monthly cost ceilings for external services, existing accounts, anything the builders must respect.

**Example:**

- Monthly running cost (hosting + SMS + payment fees excluded) should stay modest — this is community-funded. `OPEN`: confirm ceiling.
- No preference on hosting provider; prefer something the committee can pay by card.
- The community registry Excel sheet format must keep working — admins will not change their spreadsheet habits.

---

## 15. Out of Scope (Explicit)

> **Template:** Things someone might assume are included but are not.

**Example:**

- No cash handling or cash reconciliation inside the app.
- No delivery to units — pickup at the canteen only.
- No nutrition information, calorie counts, or allergen legal compliance at launch.
- No iOS/Android store apps at launch.
- No chat between residents and kitchen.

---

## 16. Decision-Maker & Approval Process

> **Template:** Who answers the Requirements Analyst's open questions? Who approves scope, design, and release? How quickly can they respond?

**Example:**

- **Single point of contact:** Valentin (committee tech lead) answers all clarification questions and is the approver for the scope gate, the design gate, and the release gate.
- Open questions should be batched, not sent one at a time.
- Anything marked `OPEN` in this packet blocks implementation of the affected feature until answered — building on a guess is never acceptable.

---

## 17. Glossary

> **Template:** Domain words that must mean exactly one thing everywhere in the system.

**Example:**

- **Credit:** the internal prepaid unit; 1 credit = 1 MXN at top-up time.
- **Registry:** the admin-maintained list of community members; sole source of who may log in.
- **Cycle:** the menu planning period; one poll per cycle.
- **Placed / Accepted / Delivered / Cancelled:** the only four order states.
- **Published:** a menu visible to residents; the opposite of **Draft**.

---

# Appendix: Input → Agent Traceability

Every pipeline agent must find its raw material in this packet. If an agent has no source section, the packet is incomplete; if a section has no consumer, it is decoration.

| Packet section | Primary consuming agents |
|---|---|
| §1 Project Identity | Requirements Analyst, Product Planner, Documentation Writer |
| §2 Users & Roles | Requirements Analyst, Solution Designer, Security Engineer |
| §3 User Journeys | Product Planner, Solution Designer, Frontend Feature Builder, Validation & Test Engineer (E2E) |
| §4 Feature Inventory | Product Planner (scope), Bundle Compiler (task decomposition), Delivery Orchestrator (sequencing) |
| §5 Business Rules | Backend Domain Implementer, Data & Migration Engineer (invariants), Validation & Test Engineer (invariant tests) |
| §6 Information Tracked | Solution Designer, Data & Migration Engineer, Contract & Client Guardian |
| §7 External Touchpoints | Integration Engineer (fakes + adapters), Security Engineer (data egress), Solution Designer |
| §8 Permissions | Security Engineer (permission matrix), Backend Domain Implementer (enforcement), Contract & Client Guardian |
| §9 Privacy & Retention | Security Engineer, Observability Engineer (log redaction), Data & Migration Engineer (retention) |
| §10 Language & Accessibility | Frontend Feature Builder (i18n, a11y), Documentation Writer |
| §11 Scale & Reliability | Solution Designer, Observability Engineer, CI/CD & Deployment Engineer |
| §12 Devices & Channels | Frontend Feature Builder, Validation & Test Engineer (test targets) |
| §13 Acceptance Examples | Validation & Test Engineer (acceptance gate), Code Reviewer, Delivery Orchestrator (release gate) |
| §14 Constraints | Solution Designer (stack/hosting), CI/CD & Deployment Engineer |
| §15 Out of Scope | Product Planner, Bundle Intake Validator (orphan detection), all implementers |
| §16 Decision Process | Delivery Orchestrator (human gates), Requirements Analyst (question routing) |
| §17 Glossary | Requirements Analyst, all agents (ubiquitous language) |
