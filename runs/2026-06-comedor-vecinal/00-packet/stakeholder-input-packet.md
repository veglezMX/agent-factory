# Stakeholder Input Packet — Comedor Vecinal

**Status:** Complete, stakeholder-confirmed. Frozen copy for run `2026-06-comedor-vecinal`.
**Stakeholder:** Valentin (committee tech lead). Interview conducted and all normative sections (§5, §8, §13, §15, §17 additions) explicitly confirmed on 2026-06-11.
**Open items:** two, both marked `OPEN` after the stakeholder was asked (§7 payment provider, §14 cost ceiling). Per §16, each blocks implementation of its affected feature until answered.

---

## 1. Project Identity

**Name:** Comedor Vecinal

**Vision:** A private app for our residential community's canteen. Today, residents order lunch by sending WhatsApp messages to the kitchen staff, pay in cash, and the staff tracks credit balances in a paper notebook. Orders get lost, balances are disputed, and nobody knows what's on the menu until they ask. This app lets residents see the standing week menu and each day's daily dishes, order with prepaid credits, top up those credits online, and vote on upcoming daily dishes — while giving the kitchen staff a clear queue of orders, a per-dish count of what to cook, and a trustworthy record of every credit movement.

---

## 2. Users & Roles

| Role | Who they are | Approx. count | What they need |
|---|---|---|---|
| Resident | Adults living in the community, registered in the community registry | ~400 | See menus, place orders, manage credits, vote in polls |
| Kitchen Operator | Staff who cook and hand out food | 4 | See incoming orders and per-dish counts, mark orders accepted/delivered, publish daily dishes, manage dish availability and kitchen open/close |
| Administrator | Community committee members | 3 | Manage residents and staff, see all transactions and per-dish sales history, set kitchen schedule, resolve disputes, reset access |

---

## 3. User Journeys

**Journey A — Ordering lunch (resident, happy path):**
Maria opens the app on her phone mid-morning, while the kitchen is open. She sees the standing week menu plus today's published daily dishes, all with prices in credits. She picks "pollo con mole" (today's daily dish) and one agua fresca, confirms, and the app shows her order as "placed," her credit balance reduced, and the order's pickup code. She gets a notification when the kitchen accepts her order. At the canteen she shows her pickup code; the operator confirms it and the order is marked delivered.

**Journey A′ — Ordering with insufficient credits:**
Maria tries to order but her balance is too low. The app tells her exactly how many credits she is short and offers to take her to the top-up screen. Her order is not placed and nothing is deducted.

**Journey B — Topping up credits:**
Maria taps "add credits," chooses an amount, and is sent to an online payment page. After paying with her card, she returns to the app and sees her new balance and a receipt in her transaction history. If the payment fails or she abandons it, her balance is unchanged and the attempt shows as failed in her history.

**Journey C — First-time access:**
A new resident, Jorge, was added to the community registry by an administrator. He opens the app, enters his phone number, receives a code by SMS, types it in, and is inside. People whose phone numbers are not in the registry cannot get in at all.

**Journey D — Kitchen operations:**
The kitchen opens per the admin-set schedule (or the operator opens it from the tablet). The operator sees the list of placed orders, oldest first, and the per-dish count of portions ordered so far today. She accepts orders as the kitchen starts them and marks them delivered when residents present their pickup codes. If the kitchen runs out of a dish, she marks it "no longer available": new orders for it are blocked immediately, remaining orders the kitchen cannot fulfil are cancelled, and affected residents are notified — refund in place, sorry for the inconvenience, the dish is no longer available — with their credits automatically returned.

**Journey E — Menu voting:**
Once per cycle, residents see a poll with candidate daily dishes for the upcoming cycle. Each resident votes once. If a resident tries to vote a second time, the attempt is rejected with a clear message and is never counted. If the poll closes while a resident has the voting screen open, the app shows "poll closed" and takes them to the results. When the poll closes, everyone can see the results, and the winning dishes inform the upcoming daily dishes.

---

## 4. Feature Inventory & Priorities

| Feature | Priority |
|---|---|
| Phone-number login with SMS code | MUST |
| View standing week menu and today's daily dishes | MUST |
| Place an order paid with credits (multiple portions and meals allowed) | MUST |
| See my orders, their status, and pickup codes | MUST |
| Credit balance and transaction history | MUST |
| Online card top-up | MUST |
| Kitchen order queue (accept / deliver against pickup code / cancel) | MUST |
| Automatic refund on kitchen cancellation | MUST |
| Mark dish "no longer available" (block new orders, auto-cancel + refund unfulfillable ones) | MUST |
| Kitchen open/close switch (operator) + weekly schedule (admin) | MUST |
| Per-dish ordered-portions count for the day (operator) | MUST |
| Per-dish sales history view (admin, informs raw-material purchasing) | MUST |
| Notifications for order status changes | MUST |
| Admin: manage residents and staff roles | MUST |
| Daily-dish drafting and publishing; week-menu editing (operators) | MUST |
| Menu polls with one-vote-per-resident | SHOULD |
| Mark-all-read for notifications | SHOULD |
| Admin view of all credit transactions | SHOULD |
| Credit expiration after long inactivity | LATER |
| Scheduled/recurring orders | LATER |
| Dietary preference filters | LATER |

---

## 5. Business Rules (Plain Language)

1. A resident's credit balance can never go below zero.
2. Every credit movement (top-up, order payment, refund) is permanent history — records are never edited or deleted, only added.
3. An order is charged at the menu price that was visible when the resident placed it, even if prices change afterward.
4. Residents can cancel their own order only while it is still "placed" (not yet accepted); cancellation returns the full amount in credits.
5. When the kitchen cancels an order, the refund is automatic and immediate.
6. Each resident gets exactly one vote per poll; a second vote attempt is rejected with a clear message and is never counted.
7. Only people present in the community registry can ever log in.
8. Only administrators can change who is staff or admin.
9. A published menu change (week menu or daily dishes) is visible to all residents at the same moment; drafts are invisible to residents.
10. Orders can be placed only while the kitchen is open; the kitchen is open per the admin-set weekly schedule unless an operator closes it early or opens it late that day.
11. A daily dish can be ordered only on its own day; week-menu dishes can be ordered on any day the kitchen is open.
12. When an operator marks a dish "no longer available," new orders for that dish are blocked immediately, and any placed orders the kitchen cannot fulfil are cancelled with automatic refund and a notification to the resident.
13. There is no per-resident quantity limit: a resident may order multiple portions and multiple meals, limited only by their credit balance and dish availability.
14. An order is marked delivered only when the operator confirms its pickup code.
15. Credits never convert back to money: every refund returns credits, never a card or cash payment.

---

## 6. Information the Business Tracks

- **Resident:** name, phone number, unit/address within the community, active or removed
- **Week menu:** the standing list of dishes with name/description/price in credits, edit history
- **Daily dishes:** date they apply to, list of dishes with name/description/price in credits, draft or published, history of past days
- **Dish availability:** per dish per day, available or "no longer available"
- **Order:** who placed it, which dishes and quantities, total in credits, current status (placed → accepted → delivered, or cancelled), pickup code, timestamps of each step
- **Credit movement:** who, how much, direction (in/out), reason (top-up, order, refund), link to the related order or payment
- **Poll:** question, dish options, open/closed, who voted (but votes are anonymous in results), final tallies
- **Notification:** recipient, message, read/unread
- **Kitchen hours:** admin-set weekly schedule plus per-day operator open/close overrides
- **Per-dish sales:** portions ordered per dish per day (feeds the operator daily count and the admin sales history)

---

## 7. External Services & Real-World Touchpoints

| Touchpoint | Purpose | Provider preference | Fake/sandbox OK initially? |
|---|---|---|---|
| Card payments | Credit top-ups | `OPEN` — Stripe account believed available; stakeholder asked 2026-06-11, could not yet confirm | Yes |
| SMS | Login codes, optional order alerts | None — recommend one available in Mexico | Yes |
| Community registry | Source of truth for who is a resident | Currently an Excel sheet maintained by admins; app should import/sync from an uploaded file | Yes |

---

## 8. Permissions (Plain Language)

**Resident — can:** see the published week menu and daily dishes; place orders of any size, for themselves or informally for others, always paid from their own balance; see only their own orders, balance, and history; top up their own credits; vote once per poll; manage their notifications; show or share an order's pickup code.
**Resident — can never:** see other residents' data, see draft menus, change order status beyond cancelling their own placed order, touch poll administration, recover credits as money.

**Kitchen Operator — can:** everything a resident can, plus: see all orders for the day; accept, deliver (against pickup code), or cancel any order; mark a dish "no longer available"; open or close the kitchen for the day; edit the standing week menu; draft and publish daily dishes; open and close polls; see the per-dish ordered-portions count for the day.
**Operator — can never:** see or modify credit balances beyond refunds triggered by cancellation, manage residents or roles, set the kitchen weekly schedule.

**Administrator — can:** everything an operator can, plus: add or remove residents; grant or revoke operator and admin roles; view all credit transactions; view the per-dish sales history across days; set the kitchen weekly schedule; trigger a login reset for a resident; view an audit trail of sensitive actions.
**Administrator — can never:** edit or delete credit history, vote on behalf of residents, see how an individual voted, convert credits to money.

---

## 9. Privacy, Compliance & Data Retention

- Phone numbers are the most sensitive data; visible only to administrators, never to other residents or operators, and never sent to any external service except the SMS provider.
- Individual votes are anonymous to everyone, including administrators.
- Credit and order history is retained indefinitely (it is the financial record).
- Removed residents lose access immediately, but their historical transactions remain.
- We operate in Mexico; Mexican consumer data norms apply. No formal LFPDPPP review is required for launch (confirmed by stakeholder 2026-06-11).

---

## 10. Languages, Branding & Accessibility

- Spanish (Mexico) at launch; structure everything so English can be added later without rework.
- Tone: warm and neighborly, not corporate.
- Brand: community logo will be provided; colors flexible — propose a palette.
- Must be comfortably usable by residents aged 60+ on mid-range Android phones: large text, high contrast, simple navigation.

---

## 11. Scale & Reliability Expectations (Plain Words)

- ~400 residents; realistic peak is the late-morning ordering window when perhaps half of them open the app within the same hour.
- If the app is down during the ordering window, the kitchen falls back to WhatsApp — painful but survivable. Outside that window, downtime is a minor annoyance.
- Credit balances being **wrong** is far worse than the app being **down**. Correctness over availability, always.

---

## 12. Devices & Channels

- Residents: their own phones, almost entirely Android, via the mobile browser (no app-store install at launch).
- Operators: a shared tablet in the kitchen, also via browser.
- Administrators: laptops via browser.

---

## 13. Acceptance Examples ("We'll know it works when…")

1. A resident from the registry can go from never-having-used-the-app to a delivered order using only their phone, with no human help.
2. A resident with 0 credits cannot place any order, and is guided to top up.
3. After a successful card payment, the new balance appears without the resident needing to refresh or contact anyone.
4. When the kitchen cancels an order, the resident's refund and notification both happen without any manual step.
5. Two administrators independently reviewing the transaction history of any resident arrive at the same balance the app shows.
6. A poll with 100 voters shows exactly 100 votes, and no resident manages to vote twice.
7. Someone with a phone number not in the registry cannot get past the login screen.
8. An operator can publish tomorrow's daily dishes from the tablet in under a minute of interaction.
9. Marking a dish "no longer available" blocks new orders for it instantly, and every affected placed order is refunded and its resident notified without any manual step.
10. Outside kitchen hours no order can be placed, and an order can be marked delivered only with its correct pickup code.

---

## 14. Constraints & Preferences

- Monthly running cost (hosting + SMS; payment fees excluded) should stay modest — this is community-funded. `OPEN`: ceiling number — stakeholder asked 2026-06-11, could not yet commit.
- No preference on hosting provider; prefer something the committee can pay by card.
- The community registry Excel sheet format must keep working — admins will not change their spreadsheet habits.

---

## 15. Out of Scope (Explicit)

- No cash handling or cash reconciliation inside the app.
- No cash-out or refund-to-card: credits are spend-only; every refund returns credits, never money.
- No formal household accounts or ordering links — ordering for others is informal and always paid from the orderer's own credits.
- No delivery to units — pickup at the canteen only, against the order's pickup code.
- No nutrition information, calorie counts, or allergen legal compliance at launch.
- No iOS/Android store apps at launch.
- No chat between residents and kitchen.
- No raw-material or inventory management — the sales view informs purchasing decisions, but purchasing happens outside the app.

---

## 16. Decision-Maker & Approval Process

- **Single point of contact:** Valentin (committee tech lead) answers all clarification questions and is the approver for the scope gate, the design gate, and the release gate.
- Open questions should be batched, not sent one at a time.
- Anything marked `OPEN` in this packet blocks implementation of the affected feature until answered — building on a guess is never acceptable.

---

## 17. Glossary

- **Credit:** the internal prepaid unit; 1 credit = 1 MXN at top-up time.
- **Registry:** the admin-maintained list of community members; sole source of who may log in.
- **Cycle:** the menu planning period; one poll per cycle. Polls choose daily dishes.
- **Placed / Accepted / Delivered / Cancelled:** the only four order states.
- **Published:** a menu visible to residents; the opposite of **Draft**.
- **Week menu:** the standing list of dishes orderable on any day the kitchen is open; edited rarely, by operators.
- **Daily dish:** a dish published for one specific date, orderable only that day while the kitchen is open.
- **No longer available:** a per-day flag on a dish; blocks new orders immediately, triggers cancel + automatic refund of unfulfillable placed orders.
- **Pickup code:** a short code attached to each order; the operator confirms it to mark the order delivered.
- **Kitchen hours:** the admin-set weekly schedule, plus an operator switch to close early or open late on any given day.

---

# Appendix: Input → Agent Traceability

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
