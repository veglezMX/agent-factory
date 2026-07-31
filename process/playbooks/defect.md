---
case: defect
name: Defect Fix
trigger: Reproducible defect report against shipped behavior
entry_criteria:
  - prior run closed (Gate 3 approved or formally cancelled, zero open risks/questions — handoff-protocol §6.1)
  - the defect is reproducible (a known sequence of steps yields the wrong observed behavior)
  - canonical docs/ baseline exists to diff the expected behavior against (handoff-protocol §6.3)
agents: [01,03,07,08,10,11,13,14,15,17,18,19,20,25,27]
skills: []
gates: [release]
baseline: consumes
closure: >
  Release gate approved, the reproducing test is committed and green, the full regression
  suite is green, every risk ID terminal, zero open questions; no canonical doc changes
  unless the fix corrected a baseline that misdescribed correct behavior (protocol §6.1, §6.3)
---

# Playbook — Defect Fix

**Purpose:** Take a reproducible defect report against behavior this pipeline already shipped and carry it to a deployed fix — without designing new scope. This is a deliberately narrow lane: it consumes the canonical baseline rather than producing one, runs no scope or design gate, and is governed by a single invariant — **reproduce with a failing test first, then make the minimal change that turns it green, keeping the full regression suite green.** Anything that wants more than that is not a defect; it is an increment.

**Legend:**

- `[H]` — human gate: the run blocks until the approver acts.
- `↺` — loop-back: findings return work to an earlier agent (full table in `../agent-handoff-protocol.md` §4).
- All ordering reflects dependency, never duration. No stage carries a time estimate.

---

## When to use / when NOT

Use defect when shipped behavior is **wrong and reproducible**, the prior run is closed, and a canonical `docs/` baseline exists that says what the behavior should have been. The work is bounded by the report: one wrong behavior, one minimal fix.

Do **not** use defect when:

- The request adds a capability the product never had — a new role, journey, feature, or business rule → run **greenfield · increment variant** (`greenfield.md`). New scope needs scope and design gates; defect has neither.
- The fix would change documented, intended behavior rather than restore it → that is a scope change, not a defect → **increment** (it re-opens Gate 1 per protocol §3.3).
- Production is actively down or degrading and the fix must ship before approval → `incident` (planned), which runs an act-first / approve-after release gate. Defect is approve-then-act and assumes the system is still serving correctly enough to wait.
- The product was not built by this pipeline and has no canonical baseline to diff against → `brownfield-onboard` (planned) first to reconstruct the baseline, then defect or increment.

See `README.md` for the case picker.

---

## Entry criteria

Before issuing handoff `0001`, the Orchestrator verifies:

- **The prior run is closed** (protocol §6.1): its Gate 3 record is `approved` (or a cancellation record exists), every risk ID is terminal, and the final `state.md` shows zero open questions. The defect run's first handoff cites that closure evidence, exactly as an increment does.
- **The defect is reproducible.** `00-packet/` holds a defect report — observed vs. expected behavior, the exact reproduction steps, and the canonical artifact (`docs/requirements.md`, `docs/glossary.md`, or a contract) that establishes the expected behavior. A report no one can reproduce is not admissible; it returns to the reporter, not into the pipeline.
- **A canonical baseline exists** to diff against (protocol §6.3). Defect `consumes` it; it does not produce a new one.

Reproducibility is confirmed as an **informal reproduction sign-off** before any fix is written (see Phase 1). It is not a recorded gate — it gates nothing downstream by a signature — but no fix proceeds until the failing test exists and fails for the reported reason.

---

## Run at a glance

```text
[Human invokes 01-delivery-orchestrator with the defect report + closure citation]

PHASE 0 — TRIAGE  (no scope gate, no design gate)
  01-delivery-orchestrator         verifies closure + reproducibility; opens defect run
  17-validation-test-engineer      writes the FAILING test that reproduces the defect
                                   against the canonical expected behavior
  [reproduction sign-off]          informal: test fails for the reported reason         ↺ 01→human if not reproducible
  08-architecture-guardian (~)     locates the owning boundary; confirms blast radius    (skip if owner is obvious)

PHASE 1 — PLAN  (optional, only if the fix is non-trivial)
  07-product-planner (~)           minimal-change plan: root cause, owner, out-of-scope   (skip for a one-line fix)

PHASE 2 — FIX  (minimal change, single owner)
  13-backend-domain-implementer    minimal fix that turns the failing test green
   or 14-frontend-feature-builder (~)  (frontend defect)
  10-contract-client-guardian (~)  only if the root cause is a contract defect           13/14 ↺ 10
  11-data-migration-engineer (~)   only if the root cause is a schema/data defect         13 ↺ 11
  15-security-engineer (~)         only if the defect is a security defect or the fix
                                   touches the sensitive-areas list
  25-ai-prompt-engineer (~)        only if the root cause is in prompt/model behavior     25 ↺ 10

PHASE 3 — VERIFY  (the invariant)
  17-validation-test-engineer      reproducing test now GREEN; FULL regression suite green ↺ owning implementer on any red
  18-code-reviewer                 diff review: minimal, in-scope, no creep              ↺ 13/14 on blockers
  15-security-engineer (~)         re-check if the diff touched sensitive areas
  27-accessibility-auditor (~)     only if the defect IS an accessibility defect, or the
                                   fix changed rendered UI                               ↺ 14 on blockers

PHASE 4 — DELIVER
  19-cicd-deployment-engineer      pipeline runs full suite; staging deploy smoke-checked
  20-documentation-runbook-writer (~)  release notes / known-limitations update           (skip if no operator-visible change)
  19-cicd-deployment-engineer      release readiness evidence
  [H] GATE: release approval
  01-delivery-orchestrator         delivery summary; canonical promotion ONLY if a doc was wrong (§6.3)
```

---

## Phase-by-phase

Each step names what the agent receives and produces *in this case*. Agent scope is defined once in the roster; this is not restated here. Agents marked `~` are conditional — invoked only when the defect's nature pulls them in.

### Phase 0 — Triage

1. **Orchestrator boot (`01`).** Human invokes the Orchestrator with the defect report and the prior run's closure citation. It creates the defect run workspace (protocol §1), registers the single release gate, refuses to proceed if the prior run is not closed (§6.1), and routes the report to the Validation & Test Engineer to reproduce. From here the human talks to the Orchestrator; specialists are reached through it.
2. **Validation & Test Engineer — reproduce (`17`).** Receives the defect report and the canonical artifact stating the expected behavior. Produces **a failing test that encodes the defect**: it exercises the reported steps and asserts the *correct* behavior, so it fails for exactly the reported reason. This test is the contract for the rest of the run — the fix is "done" when this goes green and nothing else goes red.
   - **Reproduction sign-off (informal).** The Orchestrator confirms the test fails for the reported reason before any fix begins. **↺** If the defect cannot be reproduced, the run does not proceed — it returns to the reporter via the human (protocol §4, last row: untraceable to packet/design). This is a checkpoint, not a recorded gate; nothing is signed.
3. **Architecture Guardian — locate (`08`, conditional).** Receives the failing test and the canonical architecture. Produces the owning boundary and a blast-radius note: which service/component owns the defect and what the minimal fix may touch without crossing a boundary. **Skipped when the owning boundary is obvious** from the test and the report.

### Phase 1 — Plan

4. **Product Planner — minimal-change plan (`07`, conditional).** Receives the failing test and the boundary note. Produces a tightly scoped plan: root cause, the single owner, the minimal change, and an explicit **out-of-scope** list naming nearby things this run will *not* touch. **Skipped for a one-line or otherwise self-evident fix** — the plan exists to prevent scope creep, not to ceremony-wrap a trivial change.

### Phase 2 — Fix

5. **Owning implementer — minimal fix (`13`, or `14` for a frontend defect, conditional).** Receives the failing test, the boundary note, and (if present) the minimal-change plan. Produces the **smallest change that turns the failing test green**, plus any service-level test the fix newly warrants. The change stays inside the owning boundary. Refactoring, cleanup, and "while I'm here" improvements are out of scope — they belong to a separate increment, not a defect.
6. **Contract & Client Guardian (`10`, conditional).** Invoked **only when the root cause is a contract defect**. Backend or frontend never edits a contract inline; the change routes here, which re-aligns the contract, regenerates clients, and keeps mocks consistent. **↺** `13`/`14` route to `10` for any needed API change.
7. **Data & Migration Engineer (`11`, conditional).** Invoked **only when the root cause is a schema or data-invariant defect**. Owns the corrective migration (with rollback notes); a destructive migration still requires explicit human approval. **↺** `13` routes to `11` for any needed schema change.
8. **Security Engineer (`15`, conditional).** Invoked **only when the defect itself is a security defect, or the fix touches the sensitive-areas list**. Findings become constraints on the fix; high findings block the release gate.
9. **AI & Prompt Engineer (`25`, conditional).** Invoked **only when the root cause is in prompt or model-mediated behavior** — a wrong, drifted, or unsafe model output that the canonical baseline says should differ. Owns the corrective prompt/model change behind the same minimal-fix invariant; the reproducing test from `17` pins the expected output. Routes contract changes to `10` and never broadens scope beyond the reported behavior.

### Phase 3 — Verify

10. **Validation & Test Engineer — verify the invariant (`17`).** Confirms the reproducing test is now **green** and runs the **full regression suite**, which must also be green — the invariant of this case. A green reproducing test with any other test red is not a fix; it is a regression. **↺** Any red routes to the owning implementer; verification restarts after the fix.
11. **Code Reviewer (`18`).** Full-diff review with a defect-specific lens: the change is minimal, traces to the defect, and introduces **no scope creep**. Blocking findings **↺** to the owning implementer; security smells route to `15`, boundary smells to `08`. Re-review after fixes.
12. **Security re-check (`15`, conditional).** A final pass **only if the diff touched sensitive areas**. High findings block release.
13. **Accessibility Auditor (`27`, conditional).** Invoked **only when the defect itself is an accessibility defect** — the reported wrong behavior is a keyboard trap, an unannounced state, a contrast or reflow failure — **or when the fix changed rendered UI**. In the first case the reproducing test from `17` pins the expected accessible behavior and this agent confirms the fix restores it; in the second it checks the narrow question "did this diff regress focus order, announcement, or contrast on the touched surface?", not the screen's overall conformance. A broader audit of untouched UI is out of scope — that is an increment. **↺** Blocking findings return to `14`.

### Phase 4 — Deliver

14. **CI/CD pipeline pass (`19`).** Runs the pipeline including the **full suite and the new reproducing test**, builds and scans the image, and smoke-checks a staging deploy with the fix in place. Migration job (if `11` produced one) wired before app rollout, with rollback.
15. **Documentation & Runbook Writer (`20`, conditional).** Updates release notes and the known-limitations list to record the fix. **Skipped when the fix has no operator- or developer-visible change** beyond the corrected behavior itself.
16. **Release readiness (`19`, second pass) + `[H]` release gate.** The CI/CD agent assembles release evidence (reproducing test committed and green, full regression suite green, security findings resolved or accepted, staging verified, rollback documented). Approver authorizes; CI/CD executes. Gate semantics: handoff-protocol §3.1 (release).
17. **Orchestrator close-out (`01`).** Final delivery summary. Canonical `docs/` are promoted **only if the defect revealed a baseline that misdescribed correct behavior** — i.e. the doc, not just the code, was wrong (§6.3). A pure code fix that already matched the canonical baseline changes no docs; that is the normal case for `baseline: consumes`.

---

## Loop-backs used

| Finding | Detected by | Routed to |
|---|---|---|
| Defect not reproducible | 17, at reproduction | Human via Orchestrator (blocking; returns to reporter) |
| Owning boundary unclear / fix would cross a boundary | 08 | Human via Orchestrator, or scoped per the boundary note |
| Failing reproducing test still red after fix | 17 | Owning implementer (13 / 14) |
| Full regression suite red after fix (new regression) | 17 | Owning implementer (13 / 14) |
| Root cause is a contract defect | 13 / 14 | 10 |
| Root cause is a schema / data-invariant defect | 13 | 11 |
| Root cause is in prompt / model-mediated behavior | 13 / 17 | 25 |
| Security defect or fix touches sensitive areas | 15 / 18 | Owning implementer (13 / 14) |
| Accessibility defect, or the fix regressed a11y on the touched UI | 27 | 14 |
| Review blocker (creep, missing test, risky change) | 18 | Owning implementer (13 / 14) |
| Fix would change intended behavior, not restore it | Anyone | Human via Orchestrator (blocking → becomes an increment, not a defect) |
| Anything untraceable to the canonical baseline | Anyone | Human via Orchestrator (blocking) |

Full semantics: `../agent-handoff-protocol.md` §4.

---

## Closure criteria

A defect run is closed when (protocol §6.1): the release gate is `approved` and signed (or the run is formally cancelled per §6.4); the test that reproduces the defect is committed and green; the **full regression suite is green**; every risk ID is terminal (resolved or formally accepted by the gate approver's name); every gate condition is closed; zero unanswered open questions remain in the final `state.md`. Canonical artifacts are promoted (§6.3) **only** when the fix corrected a baseline doc that misdescribed correct behavior — a defect `consumes` the baseline and leaves it unchanged in the ordinary case.

## Worked example

none yet
