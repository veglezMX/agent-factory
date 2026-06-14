---
case: deprecation
name: Deprecation / Sunset
trigger: Explicit decision to remove a feature, journey, or capability
entry_criteria:
  - the prior run on the affected product is closed (handoff-protocol §6.1)
  - a removal decision exists, named and dated, traceable to the decision-maker (packet §16)
  - the canonical docs/ baseline exists to diff the removal against (baseline: consumes)
agents: [01,02,04,08,10,11,13,14,15,17,18,19,20,22,26]
skills: []
gates: [scope, release]
baseline: consumes
closure: >
  Release gate approved, every risk ID terminal, zero open questions; the retired scope removed
  from canonical requirements, glossary, architecture, and contracts in docs/ (protocol §6.1, §6.3)
---

# Playbook — Deprecation / Sunset

**Purpose:** Take an explicit decision to remove a feature, journey, or capability and carry it to a clean, safe removal. The work is not "build less" — it is *unbuild*: identify every dependent before anything is touched, deprecate contracts with versioning, offboard data per retention and legal rules, migrate consumers off, communicate the change, and delete the dead scope. The case consumes the canonical baseline and, at closure, removes the retired scope from it so the next increment never re-references something that no longer exists.

**Legend:**

- `[H]` — human gate: the run blocks until the approver acts.
- `↺` — loop-back: findings return work to an earlier agent (full table in `../agent-handoff-protocol.md` §4).
- All ordering reflects dependency, never duration. No stage carries a time estimate.

---

## When to use / when NOT

Use deprecation when an explicit decision exists to **remove** something that shipped — a feature, a user journey, a role, an integration, a contract surface, or a stored data category — and the goal is to make it gone without breaking what stays.

Do **not** use deprecation when:

- You are **changing** behavior, not removing it (rename, re-scope, replace-with-equivalent, tighten a rule) → run **greenfield · increment variant**. Replacing a feature with a successor is an increment that *adds* the successor, optionally followed by a deprecation run that removes the predecessor once consumers have moved.
- The product was not built by this pipeline and has no canonical baseline to diff the removal against → `brownfield-onboard` (planned) first to reconstruct the baseline, then deprecate.
- The trigger is broken shipped behavior to fix, not retire → `defect` (planned).
- There is no decision yet, only a proposal to *consider* removing something → that exploration belongs to `spike` (planned), whose findings/decision gate produces the removal decision this case requires as entry.

See `README.md` for the case picker.

---

## Entry criteria

Before issuing handoff `0001`, the Orchestrator verifies:

- The prior run on the affected product is **closed** (protocol §6.1): Gate 3 approved or formally cancelled, zero open risks, zero open questions. The deprecation's first handoff cites that closure evidence (protocol §6.1) exactly as an increment does.
- A **removal decision exists** — named target, named decision-maker (packet §16), dated. KEY INVARIANT: a removal that cannot be traced to an explicit decision is refused. There is no "clean this up while we're here."
- The **delta packet** under `00-packet/` names the `baseline_run` and the canonical artifacts in force (protocol §6.2), and states the retired scope as a removal, plus any retention or legal obligations the decision-maker already knows about (packet §9).

---

## Run at a glance

```text
[Human invokes 01-delivery-orchestrator with the removal decision delta packet]

PHASE 0 — SCOPE & BLAST RADIUS
  02-requirements-analyst          decision → exact removal set + glossary terms retired + questions
  08-architecture-guardian         dependent map: every component/contract/journey that touches the target
  10-contract-client-guardian      contract surfaces of the target + current consumers of each
  11-data-migration-engineer       data the target owns + retention/legal obligations (packet §9)
  26-privacy-compliance-officer    retention/legal sign-off on offboarding plan   (~ when PII/regulated)
  04-solution-designer             removal & versioned-deprecation plan + consumer-migration order
  08-architecture-guardian         plan review: no orphaned dependents, no severed live path  ↺ 04
  [H] GATE 1: scope  (exact removal set + blast radius + retention/legal obligations confirmed)

PHASE 2 — UNBUILD
  10-contract-client-guardian      deprecate contract surfaces with versioning; regenerate clients
  14-frontend-feature-builder      migrate UI consumers off; remove retired screens/flows   (~ if UI scope)
  13-backend-domain-implementer    migrate backend consumers off; remove retired services/routes
  11-data-migration-engineer       data offboarding/export + retention-compliant deletion migration
  15-security-engineer             revoke obsolete permissions/secrets/egress of the target   (~)
  22-infrastructure-guardian       confirm no platform/provisioning resource is orphaned by removal (~)

PHASE 3 — HARDENING
  17-validation-test-engineer      removed-behavior gone; survivors green; retention-deletion verified
  18-code-reviewer                 removal diff review: no dangling refs, no dead code left   ↺ 13/14

PHASE 4 — DELIVERY
  20-documentation-runbook-writer  remove retired docs; write deprecation/release notes + migration notice
  19-cicd-deployment-engineer      ship the removal; rollback plan for the deletion
  [H] GATE 2: release  (ships the removal)
  01-delivery-orchestrator         final summary + remove retired scope from canonical docs/ (§6.3)
```

---

## Phase-by-phase

Each step names what the agent receives and produces *in this case*. Agent scope is defined once in the roster; this is not restated here.

### Phase 0 — Scope & blast radius

1. **Orchestrator boot (`01`).** Human invokes the Orchestrator with the removal-decision delta packet. It creates the run workspace (protocol §1), confirms the prior run is closed (§6.1), registers the scope and release gates, and routes the decision to the Requirements Analyst. From here the human talks to the Orchestrator; specialists are reached through it.
2. **Requirements Analyst (`02`).** Receives the removal decision and the canonical requirements/glossary. Produces a **delta review** that states the exact removal set — which requirements, journeys (packet §3), roles (packet §2), and business rules (packet §5) cease to exist — the glossary terms being retired, and a **batched** list of open questions. A removal that contradicts shipped behavior depended on elsewhere becomes a question, never a silent override.
3. **Architecture Guardian — dependent map (`08`).** Receives the removal set and the canonical architecture. Produces the **blast radius**: every component, service boundary, and journey that depends on the target, named against existing components. KEY INVARIANT: all dependents are identified *before* anything is removed. A hidden dependent surfaced later is a loop-back, not a footnote.
4. **Contract & Client Guardian — surface & consumers (`10`).** Receives the removal set. Produces the inventory of contract surfaces the target exposes and the current consumers of each (frontend, backend, external), so the plan can sequence migration before deprecation.
5. **Data & Migration Engineer — data ownership & obligations (`11`).** Receives the removal set and packet §9 (privacy, compliance & data retention). Produces the inventory of data the target owns and the retention/legal obligations on it. KEY INVARIANT: **no silent deletion** — every stored category is classified as export-then-delete, retain-for-period, or anonymize, each traced to a §9 rule. Unresolved obligations become open questions.
6. **Privacy & Compliance Officer (`26`).** **Conditional** — engaged when the retired data is PII or regulated (packet §9). Receives `11`'s obligation inventory; produces legal/retention sign-off (or conditions) on the offboarding plan. A retention-vs-removal conflict it cannot resolve routes to the human via `01` (it does not adjudicate law on its own).
7. **Solution Designer (`04`).** Receives the removal set, the dependent map, the contract-consumer inventory, and the data obligations. Produces the **removal & deprecation plan**: which contract surfaces get a versioned-deprecation path versus a clean cut, the consumer-migration order (consumers move *before* the surface is withdrawn), the data-offboarding sequence, and the deletion order that leaves no dangling reference. Never contradicts a §9 obligation without flagging it.
8. **Architecture Guardian — plan review (`08`).** Reviews the removal plan for completeness: no dependent left orphaned, no live path severed mid-flight, deletion order respects dependency direction. **↺** Violations return to `04`; re-review until clean.
   - **`[H]` GATE 1 — Scope.** The approver (packet §16) confirms the **exact removal set**, the **blast radius**, and the **retention/legal obligations** before any unbuild begins. Cost-relevant and legal-relevant choices surface here against packet §9 and §14. Nothing downstream starts first.

### Phase 2 — Unbuild

9. **Contract & Client Guardian (`10`).** As the single owner of API truth, deprecates the target's contract surfaces with versioning per the plan — marks deprecated, or removes after consumers have migrated — and regenerates clients so drift cannot creep in. **Every contract change in this run routes through `10`; no inline edits.**
10. **Frontend Feature Builder (`14`).** **Conditional** — engaged when UI consumers exist. Migrates frontend consumers off the deprecated surface and removes the retired screens, flows, and route states. Any needed contract change triggers `↺ 10`, never an inline edit. Removes retired user-facing strings from i18n with the screens.
11. **Backend Domain Implementer (`13`).** Migrates backend consumers off the deprecated surface and removes the retired services, routes, and use cases in dependency order — consumers of the target first, the target last. Any contract or schema change triggers `↺ 10` / `↺ 11`, never an inline edit.
12. **Data & Migration Engineer (`11`).** Executes the offboarding: export migrations where §9 requires retention, then the retention-compliant deletion migration, each with a rollback note. KEY INVARIANT holds at execution: no destructive migration ships without explicit human approval (carried from Gate 1), and no category is dropped that §9 says must be retained.
13. **Security Engineer (`15`).** **Conditional** — engaged when the target carried permissions, secrets, or provider egress. Revokes the obsolete role/permission entries, rotates or removes orphaned secrets, and withdraws egress to providers the target alone used. Findings that block removal route to the owning implementer via `01`.
14. **Infrastructure Guardian (`22`).** **Conditional** — engaged when the target had dedicated platform or provisioned resources. Reviews that the removal leaves no orphaned infrastructure (queues, buckets, jobs, scheduled tasks) and no provisioning resource still pointing at deleted code. Read-only; findings route via `01`.

### Phase 3 — Hardening

15. **Validation & Test Engineer (`17`).** Verifies the removal three ways: (1) the retired behavior is gone — its tests are deleted, and the journeys/rules that referenced it are removed from the suites, not left red; (2) the survivors are green — the full ladder still passes for everything that stays, proving no dependent was severed; (3) the data offboarding is verified — retained categories are present and exported, deleted categories are absent, against §9. Failures route to the owning implementer; the relevant rung restarts.
16. **Code Reviewer (`18`).** Full removal-diff review: no dangling references to deleted symbols, no dead code or feature flags left behind, no orphaned config. **↺** Blocking findings return to the owning implementer; boundary smells route to `08`, security smells to `15`. Re-review after fixes.

### Phase 4 — Delivery

17. **Documentation & Runbook Writer (`20`).** Removes the retired feature's developer, API, and operator documentation; writes the **deprecation/release notes** and the consumer-facing migration notice. KEY INVARIANT: the deprecation is **communicated** — what was removed, from when, what consumers must do, and what data was retained or deleted — strictly from what was actually removed.
18. **CI/CD pipeline pass (`19`).** Ships the removal: pipelines re-run green without the retired paths, the deletion migration is wired before app rollout, and a rollback plan for the deletion is documented and staged (the case-specific care here is that a deletion's rollback may be a restore-from-export, not a code revert).
19. **Release readiness + `[H]` GATE 2 — Release.** The CI/CD agent assembles release evidence (consumers migrated, contracts deprecated/withdrawn cleanly, data offboarded per §9 with retention verified, security revocations done, survivors green, removal diff reviewed, rollback documented, deprecation notes published). The approver (packet §16) authorizes; CI/CD executes the removal.
20. **Orchestrator close-out (`01`).** Final delivery summary; **removes** the retired scope from canonical requirements, glossary, architecture, and contracts in `docs/` (protocol §6.3) so the next increment diffs against a baseline that no longer references the deleted capability. Archives the open-question seed for the next packet.

---

## Loop-backs used

| Finding | Detected by | Routed to |
|---|---|---|
| Removal contradicts shipped behavior depended on elsewhere | 02 | Human via Orchestrator (blocking) |
| Hidden dependent on the target found during planning | 08 | 04 (re-plan migration/deletion order) |
| Hidden dependent on the target found during unbuild | 08 / 18 | Owning implementer (13 / 14) |
| Removal plan severs a live path or orphans a dependent | 08 | 04 |
| Needed contract deprecation/withdrawal during build | 13 / 14 | 10 |
| Needed schema/offboarding change during build | 13 | 11 |
| Data-retention vs removal conflict | 11 / 26 | Human via Orchestrator (blocking) |
| Security revocation blocks safe removal | 15 | Owning implementer (13 / 14) via 01 |
| Orphaned infrastructure left by the removal | 22 | Owning implementer / 19 via 01 |
| Removed-behavior test still red or survivor test broken | 17 | Owning implementer |
| Dangling reference or dead code in removal diff | 18 | Owning implementer |
| Anything untraceable to the removal decision or plan | Anyone | Human via Orchestrator (blocking) |

The retention-vs-removal conflict relies on the §3.4 case-specific-gate note for the scope gate (legal/retention obligations are a confirmed scope-gate condition, not a downstream surprise). Full semantics: `../agent-handoff-protocol.md` §4.

---

## Closure criteria

A deprecation run is closed when (protocol §6.1): the **release** gate is `approved` and signed (or the run is formally cancelled per §6.4); every risk ID is terminal (resolved or formally accepted by the gate approver's name) — including any retention-vs-removal risk accepted by `26`/the approver; every gate condition is closed; zero unanswered open questions remain in the final `state.md`. At closure the Orchestrator removes the retired scope from canonical artifacts (§6.3): the deleted requirements, glossary terms, architecture components, and contract surfaces are excised from `docs/`, leaving a baseline that no longer references the sunset capability.

## Worked example

none yet
