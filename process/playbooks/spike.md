---
case: spike
name: Spike / Research
trigger: Open feasibility or design question that must be answered before a real run can be scoped
entry_criteria:
  - one named question with a stated decision it unblocks, scope-boxed (the question, not the build)
  - no real run open for the area under study (this is a pre-scoping probe, not in-flight work)
agents: [01,02,04,07,08,13,14,21,23,25,29]
skills: []
gates: [findings]
baseline: none
closure: >
  Findings gate accepted: the decision/findings record answers the question, every probe
  artifact is labelled throwaway, and a recommended follow-on case with a seeded packet
  is on record (handoff-protocol §6.1 variant — no release, no canonical promotion)
---

# Playbook — Spike / Research

**Purpose:** Answer one open feasibility or design question that blocks scoping a real run. The deliverable is a **decision/findings record**, optionally backed by a **throwaway** prototype that exists only to inform the decision. A spike deliberately breaks the build-to-release assumption: nothing it produces ships, and it ends by recommending the follow-on case (usually a greenfield increment or a refactor) and seeding that case's packet.

**Legend:**

- `[H]` — human gate: the run blocks until the approver acts.
- `↺` — loop-back: findings return work to an earlier agent (full table in `../agent-handoff-protocol.md` §4).
- All ordering reflects dependency, never duration. No stage carries a time estimate. A spike is **scope-boxed** (bounded by the question), never time-boxed.

---

## When to use / when NOT

Use a spike when a feasibility or design question must be answered **before** a real run can be scoped — "can provider X meet this SLA," "does this data model survive the access pattern," "is this AI capability good enough to depend on" — and the honest answer is *we do not know yet*.

Do **not** use a spike when:

- The answer is already known and you are building → `greenfield` for a new product, or its **increment** variant for a feature on a closed run. A spike whose question is already settled is wasted ceremony.
- The behavior is known but the structure must change → `refactor` (behavior-parity, no new scope).
- An incident is live and you must act first → `incident` (emergency/retroactive release gate).
- You need to reconstruct a foreign codebase's baseline before changing it → `brownfield-onboard`.

The discriminator: a spike's exit is a **decision**, never shipped behavior. If the intended exit is running production code, you are in the wrong case — pick the case that has a release gate.

See `README.md` for the case picker.

---

## Entry criteria

Before issuing handoff `0001`, the Orchestrator verifies:

- **One question, scope-boxed.** The probe names a single feasibility/design question and the downstream decision it unblocks (e.g. "which integration approach to put in the next increment's packet"). The question is the boundary; expanding it mid-run is a new spike, not a bigger one.
- **No real run open** for the area under study. A spike is a pre-scoping probe; it must not race an in-flight build for the same scope (concurrency rule, protocol §4).
- **No baseline dependency.** `baseline: none` — a spike neither diffs against nor promotes canonical `docs/`. If the question needs the canonical baseline as *input*, the baseline is read-only reference, never an output.

---

## Run at a glance

```text
[Human invokes 01-delivery-orchestrator with the open question]

PHASE 0 — FRAME THE QUESTION
  02-requirements-analyst (~)   question → sharpened question + success criteria + assumptions
                                (what answer would satisfy the decision; what is out of probe scope)

PHASE 1 — PROBE DESIGN
  04-solution-designer (~)      question + criteria → probe approach(es) + what each would prove
  08-architecture-guardian (~)  sanity-check probe approach is decisive & contained   ↺ 04 if a probe proves nothing
  07-product-planner (~)        probe ordering: cheapest decisive probe first

PHASE 2 — PROBE (throwaway only; pick the agents the question needs)
  13-backend-domain-implementer (~)  throwaway service/logic spike
  29-ui-layout-designer (~)           throwaway layout/data-presentation probe
  14-frontend-feature-builder (~)    throwaway rendered interaction/code-feasibility spike
  21-infra-platform-engineer (~)     throwaway provisioning/runtime spike
  23-performance-load-engineer (~)   load/latency/capacity measurement
  25-ai-prompt-engineer (~)          model/prompt feasibility & quality probe
  ── every artifact stamped THROWAWAY: never merged to main, never promoted ──
  ↺ question cannot be answered without a human decision → 01 → human (blocking)

PHASE 3 — DECIDE
  02-requirements-analyst (~)   probe results → findings & recommendation:
                                answer · confidence · recommended follow-on case · SEEDED PACKET
  [H] GATE F: findings/decision accepted   (NO release gate — §3.4 case-specific gate)

  01-delivery-orchestrator      close-out: discard/quarantine throwaway code, hand the
                                seeded packet to the recommended case (no canonical promotion)
```

---

## Phase-by-phase

Each step names what the agent receives and produces *in this case*. Agent scope is defined once in the roster; this is not restated here. Every agent here is conditional (`~`): a spike calls only the subset its question needs — a pure-feasibility data question may never reach `14`, a pure-UI question may never reach `21`.

### Phase 0 — Frame the question

1. **Orchestrator boot (`01`).** Human invokes the Orchestrator with the open question. It creates the run workspace (protocol §1), registers the single findings gate (no scope/design/release gates), and routes the question to the Requirements Analyst. From here the human talks to the Orchestrator; specialists are reached through it.
2. **Requirements Analyst — frame (`02`).** Receives the raw question. Produces the **sharpened question**, explicit **success criteria** (what observed result would let the human decide), and the **assumptions/out-of-probe-scope** list. This is not a requirements document for a product — it is the spec for what the probe must prove. Ambiguity in the question becomes a batched open question, never a guess.

### Phase 1 — Probe design

3. **Solution Designer — probe approach (`04`).** Receives the sharpened question and success criteria. Produces one or more **probe approaches**, each stating what it would prove and what it would *not*, plus the explicit decision that "throwaway is acceptable here" — probes optimize for a decisive answer, not for production quality. Names which specialists (`13/14/21/23/25/29`) each approach needs.
4. **Architecture Guardian — probe sanity (`08`).** Reviews each probe approach for two things only: is it **decisive** (a clean result actually answers the question) and is it **contained** (it cannot leak into or depend on real product surfaces). **↺** A probe that would prove nothing, or that cannot be kept throwaway, returns to `04`. This is not a design gate — there is no architecture to approve, only a probe to validate.
5. **Product Planner — probe ordering (`07`).** Receives the validated probe approaches. Produces the **probe order**: cheapest decisive probe first, so the question can close as soon as evidence is sufficient without running every probe. Ordering is dependency/decisiveness only — no time estimates.

### Phase 2 — Probe (throwaway only)

The Orchestrator calls only the probe agents the question requires. **Every artifact any of these agents produces is stamped THROWAWAY: it is never merged to `main`, never promoted to canonical, and exists solely as evidence for the findings record.** This is the case's key invariant.

6. **Backend Domain Implementer — throwaway service (`13`).** When the question is about backend feasibility (an algorithm, a data access pattern, a domain rule's tractability). Produces a disposable service or script that exercises the uncertain path and records observed behavior. No contracts, no migrations promoted, no service-boundary commitments — those belong to the follow-on case.
7. **UI Layout Designer — throwaway layout (`29`).** When the uncertainty is page composition, information hierarchy, responsive layout, or whether selected endpoint data can support a useful interface. Produces a disposable data-to-UI map, layout/prototype, and observed design findings without changing contracts or inventing fields.
8. **Frontend Feature Builder — throwaway rendered UI (`14`).** When the question requires code/rendering feasibility beyond a layout decision. Produces a disposable screen/interaction stub. Not wired to real contracts and never promoted.
9. **Infrastructure & Platform Engineer — throwaway provisioning (`21`).** When the question is about runtime, provisioning, or platform feasibility. Produces a disposable environment/manifest, then tears it down.
10. **Performance & Load Engineer — measurement (`23`).** When the question is quantitative. Produces the measurement harness and recorded numbers against the success criteria.
11. **AI & Prompt Engineer — model/prompt probe (`25`).** When the question is about an AI/model capability. Produces a disposable evaluation against representative inputs and reports quality/confidence.
   - **↺** At any point, if the question cannot be answered without a human decision (a business trade-off, a risk acceptance, a "which matters more" call), the owning agent sets `status: blocked`, records the decision needed in `open_questions`, and routes to `01 → human`. Probes never invent the business answer.

### Phase 3 — Decide

12. **Requirements Analyst — findings & recommendation (`02`).** Receives the probe evidence. Produces the **decision/findings record**: the answer to the question, the **confidence** in it, the evidence trail (pointing at the throwaway artifacts), the **recommended follow-on case** (usually `greenfield` increment or `refactor`), and a **seeded packet** for that case — the scope, constraints, and risks the spike surfaced, expressed in the next case's input shape. The findings record explicitly states that all probe code is throwaway.
    - **`[H]` GATE F — Findings/Decision.** The approver accepts (or rejects) the findings. There is **no release gate** — nothing ships. This gate's intent — a human accepts a decision record rather than authorizing a deployment — relies on a handoff-protocol §3.4 case-specific-gate definition (the orchestrator will add that section). A `rejected` findings gate routes back: if the question was wrong, to `02` (re-frame); if the probe was inconclusive, to `04` (re-probe).
13. **Orchestrator close-out (`01`).** On an accepted findings gate, the Orchestrator closes the run: it **discards or quarantines** the throwaway artifacts (they never reach `main` or canonical `docs/`), records the closure with **no canonical promotion** (`baseline: none`), and hands the seeded packet to the recommended follow-on case as that case's trigger. The spike's job is done the moment the next case has what it needs to be scoped.

---

## Loop-backs used

| Finding | Detected by | Routed to |
|---|---|---|
| Question is ambiguous or unanswerable as posed | 02, or anyone later | Human via Orchestrator (blocking) |
| Probe approach proves nothing / cannot stay throwaway | 08 | 04 |
| Probe needs a business/risk decision only a human can make | 13 / 14 / 21 / 23 / 25 | Human via Orchestrator (blocking) |
| Findings rejected — wrong question | F gate | 02 (re-frame) |
| Findings rejected — inconclusive evidence | F gate | 04 (re-probe) |
| Anything untraceable to the framed question | Anyone | Human via Orchestrator (blocking) |

Full semantics: `../agent-handoff-protocol.md` §4. The findings/decision gate is a case-specific variant per §3.4.

---

## Closure criteria

A spike run is closed when (handoff-protocol §6.1, variant): the **findings gate is accepted** and signed by the approver named for this probe (or the spike is formally cancelled per §6.4 when the question is abandoned); the **decision/findings record answers the framed question** with a stated confidence; **every probe artifact is labelled throwaway** and confirmed not merged to `main` or promoted to canonical; a **recommended follow-on case with a seeded packet** is on record; every risk ID is terminal and zero open questions remain in the final `state.md`. Because `baseline: none`, the Orchestrator performs **no canonical promotion** at close — the spike's output is a decision and a seed, not shipped artifacts.

## Worked example

none yet
