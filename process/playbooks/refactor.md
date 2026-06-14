---
case: refactor
name: Refactor / Tech-Debt
trigger: Internal restructuring request with no intended behavior change
entry_criteria:
  - prior run closed, canonical docs/ baseline in force (handoff-protocol §6.1, §6.3)
  - restructuring request names the structure to change and asserts zero behavior change
  - the behavior to be preserved is reachable by existing or addable characterization tests
agents: [01,04,07,08,10,11,13,14,17,18,19,20,21,22,23]
skills: []
gates: [design, behavior-parity, release]
baseline: consumes
closure: >
  Release gate approved, behavior-parity gate green (characterization tests captured
  pre-change stay green post-change), zero new features, every risk ID terminal, zero
  open questions; canonical architecture updated only if the restructure moved a
  boundary (handoff-protocol §6.1, §6.3)
---

# Playbook — Refactor / Tech-Debt

**Purpose:** Change internal structure — extract a service, split a module, upgrade an internal pattern — while *proving* externally observable behavior is unchanged. The restructure may move an architectural boundary, in which case the canonical architecture is updated at closure. This case never adds, removes, or alters behavior; that property is what every gate in it exists to defend.

**Legend:**

- `[H]` — human gate: the run blocks until the approver acts.
- `↺` — loop-back: findings return work to an earlier agent (full table in `../agent-handoff-protocol.md` §4).
- All ordering reflects dependency, never duration. No stage carries a time estimate.

---

## When to use / when NOT

Use refactor when a product built by this pipeline carries internal debt and the request is purely structural: the same inputs must produce the same outputs, the same contracts must stand, the same screens must render the same states. The win is maintainability, not capability.

Do **not** use refactor when:

- The change **adds or alters externally observable behavior** — a new field, a changed rule, a different response, a new screen state → run an **increment** (the greenfield variant; `baseline: consumes`). The moment a "refactor" wants to change what a user or caller sees, it is a feature, not a refactor.
- The change **fixes a bug** in shipped behavior → `defect` (planned). A defect *intends* to change behavior (the wrong behavior becomes right); a refactor *forbids* it.
- The product was **not** built by this pipeline and has no canonical baseline to preserve behavior against → `brownfield-onboard` (planned) first to reconstruct the baseline, then refactor against it.
- There is **no product yet** → `greenfield`.

The dividing line is the key invariant: if behavior parity cannot be the acceptance contract, this is the wrong case. See `README.md` for the case picker.

---

## Entry criteria

Before issuing handoff `0001`, the Orchestrator verifies:

- The prior run is **closed** (protocol §6.1): Gate 3 approved or formally cancelled, every risk ID terminal, zero open questions. The first handoff cites that closure evidence.
- The canonical `docs/` baseline (architecture, contracts, requirements, glossary) is in force (§6.3) — it is the truth the refactor must not violate.
- `00-packet/` holds a **delta packet** (§6.2) naming the `baseline_run` and the canonical artifacts, scoped to the structural change only and asserting **no intended behavior change**.
- The behavior to be preserved is reachable by characterization tests — existing acceptance/E2E/contract suites, plus any added to pin currently-untested behavior before the change.

---

## Run at a glance

```text
[Human invokes 01-delivery-orchestrator with the restructuring delta packet]

PHASE 0 — DESIGN (restructure approach only; no new behavior)
  07-product-planner               delta packet → restructure plan (slices, out-of-scope = all behavior)
  04-solution-designer (~)         target boundary/topology change vs canonical architecture
  08-architecture-guardian         restructure-approach review                ↺ 04 on violations
  [H] GATE A: design approval (08 approves the restructure approach)

PHASE 1 — PARITY BASELINE (capture behavior BEFORE the change)
  17-validation-test-engineer      characterization tests over current behavior → ALL GREEN (pre)
  [H] GATE B: behavior-parity baseline accepted (§3.4 case-specific gate)

PHASE 2 — RESTRUCTURE (move structure, never behavior)
  10-contract-client-guardian (~)  contracts UNCHANGED; re-point clients only if files move
  11-data-migration-engineer  (~)  structure-only migration (rename/split), invariants preserved
  13-backend-domain-implementer(~) extract/split/move services behind unchanged interfaces  ↺ self on parity fail
  14-frontend-feature-builder (~)  re-home components/modules, rendered output unchanged       ↺ self on parity fail
  21-infrastructure-platform-eng(~) provisioning/topology moves if a service was extracted
  (08 re-called on any boundary move during restructure)                       ↺ 13/14 on boundary violation

PHASE 3 — HARDENING (prove parity, not new coverage)
  17-validation-test-engineer      re-run the SAME characterization suite → MUST STAY GREEN (post)
  23-performance-load-engineer(~)  perf parity check if the restructure touched a hot path
  18-code-reviewer                 diff review: structural-only, zero behavior drift            ↺ 13/14 on blockers
  22-infrastructure-guardian  (~)  reviews any provisioning/topology change from 21
  [H] GATE B (close): behavior-parity proven (pre==post green; §3.4)          ↺ 17→implementer on any red

PHASE 4 — DELIVERY
  19-cicd-deployment-engineer      pipelines run the parity suite; staging deploy + smoke
  20-documentation-runbook-writer(~) update docs ONLY where structure moved
  19-cicd-deployment-engineer      release execution readiness
  [H] GATE C: release approval
  01-delivery-orchestrator         close-out; update canonical architecture iff a boundary moved (§6.3)
```

---

## Phase-by-phase

Each step names what the agent receives and produces *in this case*. Agent scope is defined once in the roster; this is not restated here. Build-phase agents marked `~` are conditional: a refactor calls only those whose territory the restructure actually touches (a service extraction calls `13`/`21`; a frontend module split calls `14`; a pure backend pattern upgrade calls neither `14` nor `21`).

### Phase 0 — Design

1. **Orchestrator boot (`01`).** Human invokes the Orchestrator with the restructuring delta packet. It verifies prior-run closure (§6.1), creates the run workspace (§1), registers the gates, and routes the packet to the Product Planner. From here the human talks to the Orchestrator; specialists are reached through it.
2. **Product Planner (`07`).** Receives the delta packet and the canonical baseline. Produces the restructure plan in vertical slices, with the **out-of-scope section explicitly listing all behavior** as immutable — every plan asserts zero new capability. Affected artifacts name the files/modules/services that move; testing strategy points at the characterization suite that will hold the line.
3. **Solution Designer (`04`, conditional).** Called only when the restructure moves an architectural boundary (service extraction, module split that changes ownership). Receives the canonical architecture and the restructure plan. Produces the *delta* to the boundary/topology map — what moves where — with rationale traceable to the packet. Skipped for an in-place pattern upgrade that keeps every boundary intact.
4. **Architecture Guardian review (`08`).** Reviews the restructure **approach** (not greenfield architecture): does the proposed move keep dependency directions legal, preserve data ownership, avoid creating a cycle, keep fake/adapter symmetry? **↺** Violations return to `04` (or to `07` if the plan itself is unsound); re-review until clean.
   - **`[H]` GATE A — Design.** Standard `design` gate (protocol §3.1). Approver confirms the restructure approach is sound and bounded. No implementation starts first.

### Phase 1 — Parity baseline

5. **Validation & Test Engineer — capture (`17`).** Receives the restructure plan and the canonical acceptance examples/journeys/contracts. **Before any code moves**, produces or confirms a **characterization test suite** that pins current externally observable behavior — invariants, contract tests, route-state and E2E behavior, the packet's acceptance examples executed literally. Any currently-untested behavior in the blast radius gets a new pinning test now. The whole suite is run against the *unchanged* code and recorded **all green (pre)** — this snapshot is the parity contract.
   - **`[H]` GATE B (baseline) — Behavior-parity.** Case-specific gate; intent: accept the captured pre-change green suite as the binding definition of "unchanged behavior." This gate relies on a handoff-protocol **§3.4 case-specific-gate** definition (the orchestrator adds that section). Without an accepted pre-change baseline, the restructure has nothing to prove against and must not begin.

### Phase 2 — Restructure

6. **Contract & Client Guardian (`10`, conditional).** Contracts are **frozen** — a refactor that changes a contract is a feature and is out of case. Called only to re-point or re-generate clients when contract *files relocate* with a service extraction; the contract content is byte-for-byte preserved and contract tests stay green. Any pressure to alter a contract escalates to the human via `01` as out-of-scope.
7. **Data & Migration Engineer (`11`, conditional).** Called only for structure-only persistence moves (table/column rename, schema split) where every data invariant from §5/§6 is preserved. Migrations carry rollback notes; no destructive migration without explicit human approval. Behavior of reads/writes is unchanged — the characterization suite proves it.
8. **Backend Domain Implementer (`13`, conditional).** Executes the extraction/split/move: relocates service code behind **unchanged interfaces**, in dependency order. Each moved unit re-runs its characterization tests locally. A contract or schema change is never made inline — it routes `↺ 10` / `↺ 11` and, because content must not change, surfaces as an out-of-scope flag. **↺** Any parity failure returns to this implementer.
9. **Frontend Feature Builder (`14`, conditional).** Re-homes components/modules/state so rendered output and route states are identical. All API access stays through generated clients; i18n strings and auth flow are preserved verbatim. Snapshot/integration characterization tests confirm pixels-and-states parity. **↺** Parity failure returns here.
10. **Infrastructure & Platform Engineer (`21`, conditional).** Called only when a service was actually extracted and needs its own provisioning/topology slot (a new deployable unit, queue, or runtime). Provisioning mirrors the new boundary from `04`; no capacity or behavior change beyond hosting the moved code.
    - During restructure, `08` is re-called on any boundary move; **↺** boundary violations in code return to `13`/`14`.

### Phase 3 — Hardening

11. **Validation & Test Engineer — prove (`17`).** Re-runs the **same characterization suite** captured in Phase 1 against the restructured code. The pass criterion is binary: **post-change green must equal pre-change green**, test-for-test. A single new red — or a quietly weakened assertion — fails parity and routes to the owning implementer; the suite is never edited to make the diff pass.
12. **Performance & Load Engineer (`23`, conditional).** Called only if the restructure touched a hot path (a service crossing a process boundary it did not before, a new network hop). Confirms latency/throughput **parity** against the canonical baseline — a refactor must not silently regress performance. Findings route to `13`/`21`.
13. **Code Reviewer (`18`).** Full-diff review with one extra lens: the diff must be **structurally explainable with zero behavior drift** — no opportunistic logic tweaks riding along, no "while I was here" changes. Blocking findings `↺` to the owning implementer; boundary smells route to `08`. Re-review after fixes.
14. **Infrastructure Guardian (`22`, conditional).** Called only when `21` ran. Reviews the provisioning/topology change for least-privilege, network boundary correctness, and that no capability was added with the move. Findings route to `21`.
    - **`[H]` GATE B (close) — Behavior-parity.** The same §3.4 case-specific gate closes here: approver confirms the post-change suite is green and identical to the accepted pre-change baseline, no assertion weakened, no characterization test deleted. **↺** Any red routes `17 → owning implementer` and the gate stays shut.

### Phase 4 — Delivery

15. **CI/CD pipeline pass (`19`).** Ensures the pipeline runs the characterization suite as a release-blocking stage, builds images for any relocated/extracted deployable, wires structure-only migrations before rollout with rollback, and smoke-checks a staging deploy that the restructure did not break startup or wiring.
16. **Documentation & Runbook Writer (`20`, conditional).** Updates docs **only where structure moved** — module map, service inventory, local-run commands for a newly extracted service, deployment/rollback notes for new topology. Behavioral docs (API usage, user-facing guides) are untouched because behavior is untouched. Skipped if the restructure left every documented surface in place.
17. **Release readiness (`19`, second pass) + `[H]` GATE C — Release.** Standard `release` gate (protocol §3.1). The CI/CD agent assembles release evidence: parity suite green (pre==post), contracts unchanged, structure-only migrations validated with rollback, perf parity (if checked), infra review clean (if `21`/`22` ran), staging verified, rollback documented. Approver authorizes; CI/CD executes.
18. **Orchestrator close-out (`01`).** Final delivery summary. Promotes canonical artifacts (§6.3) **only where structure changed**: if a boundary moved, the **canonical architecture is updated** to the new topology (this is the one canonical doc a refactor may rewrite); requirements, glossary, and contract *content* are unchanged and re-promoted as-is. Archives the parity evidence so the next run inherits the new baseline.

---

## Loop-backs used

| Finding | Detected by | Routed to |
|---|---|---|
| Restructure approach violates architecture (design) | 08 | 04 (or 07 if the plan is unsound) |
| Boundary violation introduced during restructure (code) | 08 / 18 | 13 or 14 |
| Behavior-parity failure (post suite ≠ pre suite green) | 17 | Owning implementer (13 / 14 / 11) |
| Performance regression on a touched hot path | 23 | 13 / 21 |
| Provisioning / topology defect or scope creep | 22 | 21 |
| Review blocker (incl. behavior drift riding along) | 18 | Owning implementer |
| Pressure to change a contract / add behavior | 10, or anyone | Human via Orchestrator (out-of-scope; blocking) |
| Anything untraceable to packet or canonical baseline | Anyone | Human via Orchestrator (blocking) |

Full semantics: `../agent-handoff-protocol.md` §4. The behavior-parity gate's intent is defined in `../agent-handoff-protocol.md` §3.4 (case-specific gate).

---

## Closure criteria

A refactor run is closed when (protocol §6.1): the `release` gate is `approved` and signed (or the run is formally cancelled per §6.4); the **behavior-parity gate is green** — the post-change characterization suite equals the accepted pre-change baseline, test-for-test, with no assertion weakened or test deleted; **zero new features** were introduced; every risk ID is terminal (resolved or formally accepted by the gate approver's name); every gate condition is closed; zero unanswered open questions remain in the final `state.md`. At closure the Orchestrator updates canonical artifacts (§6.3) — and updates the **canonical architecture** only if the restructure moved a boundary.

## Worked example

none yet
