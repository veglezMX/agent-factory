---
case: dependency-upgrade
name: Dependency Upgrade / Security Patch
trigger: Third-party dependency or framework upgrade, or a CVE/security advisory requiring a patch
entry_criteria:
  - prior run closed; canonical docs/ baseline in force (handoff-protocol §6.1, §6.3)
  - the upgrade target is named with from/to versions, or the CVE/advisory id is cited
  - no new scope: the change is the version bump and whatever the bump forces, nothing else
agents: [01,09,10,11,13,14,15,17,18,19,20,21,22]
skills: []
gates: [release]
baseline: consumes
closure: >
  Gate 3 (release) approved, versions pinned/locked, full regression suite green; for a
  CVE-driven run, Security Engineer (15) has confirmed the vulnerability is actually
  remediated (not merely version-bumped) and signed off; every risk ID terminal, zero
  open questions (handoff-protocol §6.1)
---

# Playbook — Dependency Upgrade / Security Patch

**Purpose:** Carry an externally driven version change — a dependency or framework upgrade, or a CVE/security-advisory patch — through to a released, regression-clean state. The work is defined entirely by the bump and what the bump forces; it adds **no new behavior**. This is the narrowest build-bearing case: it consumes the canonical baseline, runs no discovery or design, and exists to prove that the system still behaves identically (or, for a CVE, is genuinely fixed) after the version moves.

**Legend:**

- `[H]` — human gate: the run blocks until the approver acts.
- `↺` — loop-back: findings return work to an earlier agent (full table in `../agent-handoff-protocol.md` §4).
- All ordering reflects dependency, never duration. No stage carries a time estimate.

---

## When to use / when NOT

Use dependency-upgrade when the trigger is **external** and carries **no new scope**: a library, runtime, or framework moves to a new version, or a CVE/advisory demands a patch. The intended end state is the same product on newer versions, with the full regression suite still green.

Do **not** use dependency-upgrade when:

- The upgrade is a **vehicle for a feature** — you actually want new behavior that the new version enables → run **greenfield** (its increment variant; `baseline: consumes`). Scope means discovery, UX, design, and gates 1–2, none of which this case runs.
- The upgrade **surfaced a defect** in shipped behavior (the bump exposed a latent bug, or the new version regressed something) → that is a separate **`defect`** run (planned), with its own reproducible report. Do not fold a behavior fix into the bump; pinning the version and fixing the bug are two different changes with two different proofs.
- There is no canonical `docs/` baseline because the product was built elsewhere → `brownfield-onboard` (planned) first, to establish the baseline this case diffs against.

The discriminator: **dependency-upgrade keeps behavior constant and changes versions; defect changes behavior and keeps versions; greenfield/increment adds behavior.** If two of those are true at once, split the run.

See `README.md` for the case picker.

---

## Entry criteria

Before issuing handoff `0001`, the Orchestrator verifies:

- The **prior run is closed** and canonical artifacts are in force (protocol §6.1, §6.3); the first handoff cites that closure evidence, exactly as an increment does.
- The trigger is named precisely: the dependency/framework with **from → to versions**, or the **CVE/advisory id** with its affected component. A vague "update our deps" is not an entry condition — it is a question routed to the human.
- The change is confirmed **scope-free**: no new role, journey, feature, or business rule rides along. Any new scope detected at intake re-routes to greenfield/increment, not this case.
- The **regression suite** that defines "behavior unchanged" exists and is the baseline of record (it is the canonical product's test ladder; this case does not author new acceptance scope).

---

## Run at a glance

```text
[Human invokes 01-delivery-orchestrator with the upgrade target or CVE id + closure citation]

PHASE 0 — DISCOVERY & DESIGN
  (none — externally driven, no new scope; canonical docs/ baseline consumed as-is)

PHASE 1 — PLANNING
  (none — no bundle to compile; the "bundle" is the pinned version delta)

PHASE 2 — BUILD  (the bump and only what the bump forces)
  09-foundation-engineer (~)       lockfile/manifest bump, pin versions, tooling alignment
  10-contract-client-guardian (~)  regenerate clients IF a generated dependency's API shifted   ↺ self on drift
  11-data-migration-engineer (~)   migration only IF the upgrade forces a storage/driver change
  13-backend-domain-implementer(~) minimal call-site fixes for removed/changed APIs (no new logic)
  14-frontend-feature-builder (~)  minimal call-site fixes for removed/changed APIs (no new UI)
  21-infrastructure-platform (~)   base image / runtime / platform pin IF the upgrade is infra-level

PHASE 3 — HARDENING  (prove behavior is unchanged; for a CVE, prove it is fixed)
  17-validation-test-engineer      run the FULL regression ladder against pinned versions   ↺ owning implementer on red
  18-code-reviewer                 review the bump diff: scope-free, no logic riders        ↺ 13/14 on blockers
  22-infrastructure-guardian (~)   review infra/base-image pin IF 21 ran                    ↺ 21 on findings
  15-security-engineer             MANDATORY for CVE: verify vuln actually remediated       ↺ owning implementer on findings
                                   (advisory upgrade: confirm no new exposure introduced)

PHASE 4 — DELIVERY
  20-documentation-runbook-writer(~) update version notes / dependency manifest in docs & runbook
  19-cicd-deployment-engineer      pipeline re-run (incl. dependency/image scan), staging deploy
  19-cicd-deployment-engineer      release execution readiness (regression green + 15 sign-off bundled)
  [H] GATE 3: release approval   — CVE runs: 15 sign-off is a BINDING gate condition (§3.4 variant)
  01-delivery-orchestrator         delivery summary; promote updated version/dependency facts to docs/ (§6.3)
```

---

## Phase-by-phase

Each step names what the agent receives and produces *in this case*. Agent scope is defined once in the roster; this is not restated here. Every Phase-2 agent below is **conditional (`~`)**: it runs only if the bump actually forces work in its boundary. The Orchestrator scopes the run from the upgrade delta and invokes only the agents the delta touches.

### Phase 0 — Discovery & Design

None. The trigger is external and scope-free, so there is nothing to discover, design, or gate at scope/design. The canonical requirements, glossary, and architecture are **consumed unchanged** — they are the definition of the behavior this run must preserve, not something this run revises.

### Phase 1 — Planning

None. There is no Stakeholder Input Packet, no bundle to compile, and no slices to plan. The unit of work is the **version delta** itself (the from→to change plus its forced call-site and lockfile edits). `05`/`06`/`07` do not run.

### Phase 2 — Build

The Orchestrator boots (`01`), creates the run workspace (protocol §1), registers the single release gate, and routes the upgrade delta to the first build agent the delta touches.

1. **Foundation Engineer (`09`).** Receives the upgrade target. Performs the actual bump in the manifest and lockfile, **pins/locks** every changed and transitively changed version so the resolved tree is reproducible, and aligns lint/format/tooling if the bump moves a tool version. **Exit check:** a fresh clone resolves to the pinned tree and the local runtime still starts via the documented commands. **Invariant:** versions are pinned, not floated.
2. **Contract & Client Guardian (`10`).** Runs **only if** a dependency that backs generated clients shifted its API surface (e.g. a codegen library or a contract toolchain version moved). Regenerates the typed clients from the unchanged contracts and re-aligns mocks. **It does not change the contracts themselves** — the contract is product truth and stays constant; only the generated output may move with the tool. **↺** Re-runs on generation drift until clients and mocks match the contract.
3. **Data & Migration Engineer (`11`).** Runs **only if** the upgrade forces a persistence-layer change (a database driver, ORM, or engine version that requires a migration or a schema-compatibility shim). Authors the forced migration with rollback notes; never weakens an invariant to satisfy the new version. No new schema scope.
4. **Backend Domain Implementer (`13`).** Runs **only if** the new version removed or changed an API the services call. Makes the **minimal** call-site adaptations to keep existing behavior identical — renamed imports, changed signatures, deprecated-call replacements. **No new logic, no refactors of convenience.** Any contract or schema need routes to `10`/`11`, never an inline edit.
5. **Frontend Feature Builder (`14`).** Runs **only if** the bump changed a frontend dependency's API. Makes the **minimal** call-site adaptations to preserve existing screens and route states; consumes only regenerated clients; never adds UI or alters behavior.
6. **Infrastructure & Platform Engineer (`21`).** Runs **only if** the upgrade is infrastructure-level — a base image, language runtime, or platform component pin. Updates the pinned image/runtime and provisioning manifests so the deployed environment matches the new version, with rollback to the prior pin documented.

### Phase 3 — Hardening

7. **Validation & Test Engineer (`17`).** The center of gravity of this case. Runs the **full existing regression ladder** (invariants, contract tests, integration, E2E, conformance, and the acceptance sweep that defines shipped behavior) against the pinned versions. The bar is **green-to-green**: behavior identical before and after the bump. Any red is a finding routed to the owning implementer; the ladder restarts from the failed rung. This case adds no new test scope — it re-proves the existing one.
8. **Code Reviewer (`18`).** Reviews the bump diff for the one thing this case must guarantee: that it is **scope-free**. Flags any logic rider, opportunistic refactor, or behavior change that snuck in alongside the version move; confirms versions are pinned, not floated. **↺** Blocking findings to `13`/`14`; if the diff smells architectural it routes to the Architecture Guardian per protocol §4 (that reviewer is not a standing member of this case but remains reachable as a router target).
9. **Infrastructure Guardian (`22`).** Runs **only if** `21` ran. Reviews the base-image/runtime/platform pin for posture: no broadened surface, no weakened isolation, rollback pin intact. **↺** Findings to `21`.
10. **Security Engineer (`15`).** Always runs, and is **mandatory and load-bearing for a CVE-driven run**: it verifies the vulnerability is **actually remediated** — the patched code path is reachable, the fix is present in the resolved (not merely requested) version, no vulnerable transitive copy survives in the lockfile — **not just that a version string changed**. For a non-CVE advisory upgrade, it confirms the bump introduced no new exposure (new permissions, new egress, new secret surface from the dependency). High findings route to the owning implementer (`13`/`14`/`21`) and block release. For CVE runs, its sign-off is a binding Gate 3 condition (below).

### Phase 4 — Delivery

11. **Documentation & Runbook Writer (`20`).** Runs **if** the upgrade changes anything an operator or developer must know: the dependency manifest in `docs/`, supported-version notes, the runbook's environment/runtime versions, and a release note stating what moved (component, from→to, CVE id if any). Strictly from what changed — no invented procedure.
12. **CI/CD pipeline pass (`19`).** Re-runs the delivery pipeline against the pinned tree — including the **dependency and image scan**, which for a CVE run is corroborating evidence that the advisory no longer fires — builds the image, and deploys to staging with a smoke check.
13. **Release readiness (`19`, second pass) + `[H]` GATE 3.** The CI/CD agent assembles release evidence: versions pinned/locked, full regression ladder green, dependency/image scan clean, staging verified, rollback to the prior pin documented, and — **for a CVE run — the Security Engineer's remediation sign-off attached**. The approver authorizes; CI/CD executes.
    - **`[H]` GATE 3 — Release.** Standard release gate (protocol §3.1). **Variant for CVE-driven runs:** `15`'s remediation sign-off is a **binding gate condition** — the gate cannot be approved without it (relies on a handoff-protocol §3.4 case-specific-gate definition the orchestrator maintains). A behavior-only advisory upgrade uses the standard release gate as-is. Where the patch must ship before the gate can convene (active exploit), this case borrows the **emergency/retroactive release gate** (act-first, approve-after; protocol §3.4) — the same as the `incident` case — and `15` plus the regression ladder become the retroactive evidence the approver signs against.
14. **Orchestrator close-out (`01`).** Delivery summary; promotes the **updated version/dependency facts** into canonical `docs/` (protocol §6.3) so the next run diffs against the new pinned baseline. No requirements, glossary, or architecture change — those were consumed unchanged.

---

## Loop-backs used

This case exercises a strict subset of the protocol's escalation table (§4): only the failure paths that a scope-free version move can produce. No scope, design, or bundle loop-backs exist here, because none of those phases run.

| Finding | Detected by | Routed to |
|---|---|---|
| Regression failure after the bump | 17 | Owning implementer (09 / 13 / 14 / 11 / 21) |
| Security finding / vulnerability not actually remediated | 15 | Owning implementer (13 / 14 / 21) |
| Client/mock generation drift from a moved codegen tool | 10 | 10 (self, re-generate) |
| Scope rider or opportunistic logic change in the diff | 18 | 13 / 14 |
| Infra/base-image pin regresses posture | 22 | 21 |
| Bump turns out to require new scope | 18 / any agent | Human via Orchestrator → re-route to greenfield increment (blocking) |
| Bump surfaced a behavior defect (not version-caused parity loss) | 17 / 18 | Human via Orchestrator → split off a `defect` run (blocking) |
| Anything untraceable to the named upgrade target or CVE | Anyone | Human via Orchestrator (blocking) |

Full semantics: `../agent-handoff-protocol.md` §4.

---

## Closure criteria

A dependency-upgrade run is closed when (protocol §6.1): Gate 3 (release) is `approved` and signed (or the run is formally cancelled per §6.4); **every changed version is pinned/locked** and the resolved tree is reproducible; the **full regression suite is green** (behavior unchanged); for a **CVE-driven run**, the Security Engineer (`15`) has confirmed the vulnerability is **actually remediated** — not merely version-bumped — and that sign-off is attached to the gate record; every risk ID is terminal (resolved or formally accepted by the approver's name); zero unanswered open questions remain in the final `state.md`. At closure the Orchestrator promotes the updated version/dependency facts into canonical `docs/` (§6.3); the requirements, glossary, and architecture baselines are unchanged.

## Worked example

none yet
