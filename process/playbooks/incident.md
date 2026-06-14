---
case: incident
name: Incident Response / Hotfix
trigger: Active production incident (service degradation or outage)
entry_criteria:
  - a production incident is OPEN and observed (alert, report, or detected degradation)
  - the affected product was built by this pipeline; canonical docs/ exist to consume
  - emergency authority named in packet §16 is reachable to authorize and to sign retroactively
agents: [01,11,12,13,14,15,16,17,18,19,20,22,23]
skills: []
gates: [release]
baseline: consumes
closure: >
  Service restored and verified; emergency release gate signed RETROACTIVELY by the §16
  approver; full ladder green post-restore; review (18) clean; post-incident report (20)
  recommends a follow-on defect or refactor run for the durable fix; every risk ID terminal,
  zero open questions (handoff-protocol §6.1, with the §3.4 emergency/retroactive gate variant)
---

# Playbook — Incident Response / Hotfix

**Purpose:** Restore a degraded or down production service as fast as safely possible — by fix-forward or rollback — and then complete the normally-upstream rigor **retroactively**. This case inverts gate ordering: mitigation deploys under documented emergency authority *before* formal approval, and the release gate is signed *after* the fact. The inversion is the only thing that changes. **No step is dropped:** regression tests, code review, observability confirmation, and the post-incident writeup all happen — they happen *after* restore instead of before. Every emergency action is logged so the retroactive gate has real evidence to sign against.

**Legend:**

- `[H]` — human gate: the run blocks until the approver acts. In this case the approver acts in two beats — emergency authorization *before* mitigation, retroactive signature *after* restore.
- `↺` — loop-back: findings return work to an earlier agent (full table in `../agent-handoff-protocol.md` §4).
- All ordering reflects dependency, never duration. No stage carries a time estimate. "Fast" here is a sequencing constraint (mitigate first), not a clock.

---

## When to use / when NOT

Use incident when a **production** service is **actively** degraded or down and restoring it cannot wait for the normal discovery → design → build → gate sequence.

Do **not** use incident when:

- The bug is reproducible but **not urgent** — production is stable, users are not actively harmed → run a **`defect`** (the lighter, normally-ordered lane). Urgency, not reproducibility, is what puts work in this case.
- There is **no product in production yet** → the work belongs in `greenfield`; there is nothing to restore.
- The fix is a deliberate, scoped change to shipped behavior with no live emergency → `greenfield` increment variant.
- The durable, root-cause remediation is itself substantial → this case ships the *mitigation*; it then **hands off** the lasting fix to a follow-on `defect` (root cause) or `refactor` (structural cause) run, recorded by `20` in the post-incident report. Incident is not where you re-architect.

See `README.md` for the case picker.

---

## Entry criteria

Before issuing handoff `0001`, the Orchestrator verifies:

- A production incident is **open and observed** — there is a concrete signal (alert, report, or detected degradation), not a hypothesis.
- The product was built by this pipeline and has a **canonical baseline** under `docs/` to consume (`baseline: consumes`); the mitigation is diffed against shipped truth, not invented from zero.
- The **emergency approver** named in packet §16 is reachable — both to grant the act-first authorization and to sign the gate retroactively (relies on a `../agent-handoff-protocol.md` §3.4 case-specific gate definition for the emergency/retroactive release gate).
- A run workspace is opened (protocol §1). Because §6.1 forbids two open runs, an in-flight non-incident run is **paused** and recorded in `state.md`; the incident takes precedence and is closed before the paused run resumes.

---

## Run at a glance

```text
[Human/alert invokes 01-delivery-orchestrator: production is degraded/down]

PHASE A — STABILIZE (mitigate first; gate ordering inverted)
  01-delivery-orchestrator         opens incident run, consumes canonical docs/, logs the timeline
  16-observability-engineer        triage: scope blast radius, locate failing signal       [~]
  [H] EMERGENCY AUTHORIZATION      §16 approver grants act-first authority (logged, not yet signed)
  Decision: fix-forward or rollback?
   ├─ ROLLBACK ─► 19-cicd-deployment-engineer   revert to last-good release; verify restore
   └─ FIX-FORWARD ─► owning implementer (13/14) + 11/12/15 [~]   minimal mitigation patch
                     19-cicd-deployment-engineer  deploy mitigation under emergency authority
  16-observability-engineer        CONFIRM restore: signal back to healthy

PHASE B — RETROACTIVE RIGOR (nothing dropped, only re-ordered)
  17-validation-test-engineer      regression + the missing test that would have caught this
                                                                          ↺ 13/14 on failure
  18-code-reviewer                 post-hoc review of the emergency diff   ↺ 13/14 on blocker
  15-security-engineer             post-hoc check if mitigation touched sensitive surface  [~]
  22-infrastructure-guardian       post-hoc check if mitigation touched infra/deploy path  [~]
  23-performance-load-engineer     confirm mitigation didn't trade outage for degradation  [~]

PHASE C — CLOSE THE LOOP
  20-documentation-runbook-writer  POST-INCIDENT REPORT (mandatory, never skipped):
                                   timeline, root cause, every emergency action logged,
                                   + RECOMMENDS a follow-on defect/refactor run for durable fix
  [H] GATE: RELEASE (emergency/retroactive) — §16 approver signs AFTER restore, against the log
  01-delivery-orchestrator         close-out; promote any canonical doc deltas (§6.3);
                                   register the recommended follow-on run; resume paused run
```

---

## Phase-by-phase

Each step names what the agent receives and produces *in this case*. Agent scope is defined once in the roster; it is not restated here.

### Phase A — Stabilize (mitigate first)

1. **Orchestrator boot (`01`).** Invoked by a human or an alert with the incident signal. Opens the incident run workspace (protocol §1), pauses any in-flight run per the entry criteria, and starts an **emergency timeline** in `state.md` — every action from here is timestamped and logged, because the retroactive gate will be signed against this log. Consumes the canonical `docs/` baseline so every later step diffs against shipped truth. Routes triage to `16`.
2. **Observability triage (`16`).** Receives the incident signal and the canonical observability map. Produces the blast-radius scope and the failing-signal location — which service, which dependency, since when — using existing logs, metrics, traces, and health checks. Conditional only in that some incidents arrive already triaged; when they do, `16`'s product is a one-line confirmation, not a re-investigation. Recommends fix-forward vs rollback to `01`.
   - **`[H]` EMERGENCY AUTHORIZATION.** The §16 approver grants **act-first authority** to deploy a mitigation before formal approval. This is *logged*, not the gate signature — the gate itself is signed retroactively in Phase C. This authorization is what makes the inverted ordering legitimate rather than a bypass.
3. **Mitigation path decision (routed by `01`).** Two mutually exclusive routes, chosen on which restores faster and safer:
   - **Rollback (`19`).** Receives the last-good release identity from the canonical release record. Reverts the deployment (and, only if forced and explicitly authorized, a migration — destructive data operations still require the human approval the roster mandates for `11`). Produces the restored deployment.
   - **Fix-forward (owning implementer `13` / `14`, with `11` / `12` / `15` conditional).** Receives the failing-signal scope. Produces the **minimal** mitigation patch — the smallest change that restores service, not the durable fix. `11` is pulled in only if the mitigation touches data; `12` only if it touches an integration; `15` only if it touches auth, secrets, or permissions. The implementer records the patch as an emergency decision line citing the incident, not a normal bundle task.
4. **Deploy mitigation (`19`).** Receives the rollback or the mitigation patch. Deploys under the emergency authority from step 2, logging the deploy action and artifact in the timeline. Produces the running, mitigated production state.
5. **Restore confirmation (`16`).** Receives the post-deploy system. Produces the explicit signal that the failing metric is back to healthy. **Until `16` confirms restore, the incident is not stabilized** and the run does not advance to Phase B.

### Phase B — Retroactive rigor (nothing dropped, only re-ordered)

6. **Validation & Test Engineer (`17`).** Receives the emergency diff (or rollback delta) and the incident description. Produces the regression run *plus* the **specific test that would have caught this incident** — the coverage gap is closed here, not deferred. **↺** Any failure routes to the owning implementer (`13` / `14`); the ladder restarts from the failed rung. A green run here is the evidence the retroactive gate needs.
7. **Code Reviewer (`18`).** Receives the emergency diff. Produces a post-hoc review — the review that would normally precede deploy now happens after it, with the same blocking authority. **↺** Blocking findings route to the owning implementer (`13` / `14`); security smells route to `15`, infra smells to `22`. A blocker found here does **not** un-restore service, but it **must** be resolved before the gate signs — that is what keeps "act first" from becoming "skip forever."
8. **Security Engineer (`15`, conditional).** Engaged when the mitigation touched a sensitive surface (auth, secrets, permissions, provider egress). Produces a post-hoc security finding set; high findings block the retroactive gate.
9. **Infrastructure Guardian (`22`, conditional).** Engaged when the mitigation or rollback touched the deploy path, runtime, or infra config. Produces a post-hoc infra-boundary finding set; violations block the gate.
10. **Performance & Load Engineer (`23`, conditional).** Engaged when restore was speed-driven and may have traded an outage for silent degradation. Produces a confirmation that the mitigated system meets the canonical performance posture, or a finding that it does not.

### Phase C — Close the loop

11. **Documentation & Runbook Writer (`20`).** Receives the full timeline, the emergency diff, the test/review/specialist outputs, and the restore confirmation. Produces the **post-incident report** — mandatory and **never skipped**: incident timeline, root-cause analysis, every emergency action logged for audit, what restored service, and a **named recommendation for a follow-on `defect` or `refactor` run** to carry the durable fix that this case deliberately did not attempt. Updates the operator runbook so the next occurrence is faster.
    - **`[H]` GATE — Release (emergency/retroactive variant).** The §16 approver signs `gates/gate-release.md` **after** restore, reviewing the assembled evidence: the emergency-authorization log, the deploy timeline, the green post-restore ladder (`17`), the clean post-hoc review (`18`), any conditional specialist findings resolved or accepted, the restore confirmation (`16`), and the post-incident report (`20`). This gate relies on a `../agent-handoff-protocol.md` §3.4 case-specific gate definition (emergency/retroactive release). A `rejected` retroactive gate does not un-deploy the mitigation — it routes the open blockers back through the loop-backs until they are resolved, and is re-presented; it cannot be left unsigned.
12. **Orchestrator close-out (`01`).** Produces the final incident summary; promotes any canonical-doc deltas the mitigation introduced (§6.3); **registers the follow-on run** recommended by `20` as backlog in `state.md` (§6.6 — never folded into this run); and resumes the run paused at entry. The incident run is closed only when its closure criteria below hold.

---

## Loop-backs used

This case exercises a subset of the protocol's escalation table (`../agent-handoff-protocol.md` §4). Note that all loop-backs here fire in **Phase B**, *after* restore — they correct the emergency diff, they do not block mitigation.

| Finding | Detected by | Routed to |
|---|---|---|
| Regression failure on the emergency diff | 17 | Owning implementer (13 / 14) |
| Post-hoc review blocker on the emergency diff | 18 | Owning implementer (13 / 14) |
| Security finding on the mitigation | 15 | Owning implementer (13 / 14 / 12) |
| Infra-boundary violation in the deploy/rollback path | 22 | 19, or owning implementer |
| Performance regression introduced by the mitigation | 23 | Owning implementer (13 / 14) |
| Mitigation untraceable to the incident or canonical baseline | Anyone | Human via Orchestrator (blocking) |

Full semantics: `../agent-handoff-protocol.md` §4. The emergency/retroactive gate ordering relies on the §3.4 case-specific gate definition.

---

## Closure criteria

An incident run is closed when (protocol §6.1, with the §3.4 emergency/retroactive gate variant):

- **Service is restored and confirmed** by `16` — the failing signal is healthy.
- **The emergency release gate is signed retroactively** by the §16 approver against the logged evidence (or the run is formally cancelled per §6.4, which here would mean the mitigation was itself rolled back).
- **No rigor was dropped:** the post-restore ladder (`17`) is green, the post-hoc review (`18`) is clean, and any conditional specialist findings (`15` / `22` / `23`) are resolved or formally accepted by name.
- **The post-incident report (`20`) exists** and names a follow-on `defect` or `refactor` run for the durable fix; that follow-on is registered in `state.md` (§6.6), not silently absorbed.
- **Every risk ID is terminal** and **zero open questions** remain in the final `state.md`. The Orchestrator promotes any canonical-doc deltas (§6.3) and resumes the run paused at entry.

## Worked example

none yet
