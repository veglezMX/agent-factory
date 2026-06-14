# Interview Guide — Question Bank & Gap Probes

Companion to SKILL.md. Questions are phrased for a non-technical stakeholder; adapt wording to their domain, keep the plain-language register. Never read this list out wholesale — pick the highest-priority unanswered items, ≤4 per round.

## §1 Project Identity

- "In one or two sentences: what is this, and what goes wrong today without it?"
- "Does the project have a name, even a working one?"
- Probe: if the answer describes a feature ("an app to book appointments"), ask for the pain ("what happens today when someone books?").

## §2 Users & Roles

- "Who will touch this system? Everyone — staff, customers, admins, even occasional users."
- For each role: "Who are they? Roughly how many? What's the one thing they need from this?"
- Probe: "Who fixes things when they go wrong — disputes, mistakes, locked-out users?" (surfaces the admin role stakeholders forget).
- Probe: "Is there an owner/manager view?" (the stakeholder themselves is often an unlisted role).

## §3 User Journeys

- "Walk me through the most important moment of use as a short story: '<Name> opens the app, then…'"
- For every journey: "And when it goes wrong? They have no money / no signal / it's sold out / they're not registered — what should happen?"
- Probe: "How does a brand-new user get in the very first time?" (first-access journey is almost always missing).
- Target: 3–7 journeys, each with at least one failure path.

## §4 Feature Inventory & Priorities

- Read back the features extracted from journeys: "If launch lacked this, is launch pointless (MUST), painful (SHOULD), or fine (LATER)?"
- Probe: "What's the smallest version you'd actually put in front of people?"
- Never accept or record time estimates — redirect to priority.

## §5 Business Rules

- "What must NEVER happen, even if everything else fails?" (money lost, double booking, data leaked)
- "What is permanent? What can never be edited or undone once it happens?"
- Money/irreversibility drill — for every charge, refund, penalty, deletion: "Exactly how much? Measured from which moment, by whose clock? Who, if anyone, can make an exception?"
- Boundary drill: "At exactly 24 hours — charged or not?" (force the boundary to one side).
- Each answer must reduce to one testable sentence; read it back until it does.

## §6 Information the Business Tracks

- "What things do you keep records about today — on paper, spreadsheets, anywhere?"
- Per thing: "What do you need to remember about each one?"
- Probe: "What do you need to look up a year later?" (surfaces history/audit needs).

## §7 External Services & Real-World Touchpoints

- "What has to leave the app — messages, payments, emails, other systems you already use?"
- Per touchpoint: "Do you already have a provider or account? Is a simulated version OK while we build?"
- Probe: "What do you use today for this?" (existing Excel/WhatsApp/calendar workflows are integration requirements in disguise).

## §8 Permissions

- Per §2 role: "Complete these two sentences: '<Role> can…' and '<Role> can NEVER…'"
- Probe: "Can <role A> see <role B>'s data?" for every sensitive pair (notes, money, personal data).
- Probe: "Who can change who has which role?"

## §9 Privacy, Compliance & Data Retention

- "What's the most sensitive piece of information here? Who must never see it?"
- "Any laws or regulations you know apply?" (GDPR, health data, financial records — if they name one, ask what they think it requires, mark legal interpretation `OPEN` for the analyst)
- "How long do records need to be kept? Can people ask for their data to be deleted, and is that even allowed for your records?"

## §10 Languages, Branding & Accessibility

- "What language(s) at launch? More later?"
- "Any users who'd struggle — older people, small phones, poor eyesight?"
- "Logo, colors, tone — exists, or should we propose?"

## §11 Scale & Reliability

- "How many people, and when's the busy moment?" (everyday words, not numbers they'd invent)
- "If it's down for an hour at the worst time — what happens?"
- "Which is worse: the app down, or the data wrong?" (sets correctness-vs-availability)

## §12 Devices & Channels

- Per role: "Where are they when they use it — own phone, shared computer, tablet at a counter?"

## §13 Acceptance Examples

- "Complete: 'We'll know it works when…' — give me 5 to 10, each something a person could check."
- Convert vague ones: "users are happy" → "a first-time user gets from nothing to <core outcome> with no human help."
- Include at least one example per money/irreversibility rule; cover the MUST features, grouping several into one end-to-end example where needed to stay within the 5–10 cap.

## §14 Constraints & Preferences

- "Monthly cost ceiling for running this? Hosting preferences? Existing accounts we must reuse?"
- "Any deadline?" → write the absolute date and ask: "hard deadline or aspiration?"

## §15 Out of Scope

- "What might someone assume is included that is NOT?" (apps stores, cash handling, chat, reports…)
- Read the final list back — unlisted features are excluded by default, so this list protects the stakeholder.

## §16 Decision-Maker & Approval

- "Who answers questions while we build — one name? How fast can they usually reply?"
- "Who says yes to scope, design, and release?"

## §17 Glossary

- Built throughout: every domain word the stakeholder used with a specific meaning ("cycle", "credit", "registry") → "When you say <word>, what exactly counts as one?"

## Contradiction & Hedge Sweep (before read-back)

- Pairs that commonly conflict: "cancel anytime" vs. cancellation fees; "delete my data" vs. permanent records; "everyone can see X" vs. privacy of X.
- Every "maybe / I think / probably / we might": "Earlier you said '<quote>' — decide now, or shall I record it as an open question?"
