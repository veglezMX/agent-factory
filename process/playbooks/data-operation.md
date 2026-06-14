---
case: data-operation
name: Data Operation
trigger: One-off data-job request — backfill, bulk correction, large data migration, or ETL
entry_criteria:
  - the job is a one-off data change, not a feature or a defect (see When to use / when NOT)
  - canonical schema and data invariants exist to operate against and re-verify (docs/ baseline) — or the run records why none apply
  - the affected data scope, source of truth, and expected end state are stated up front
  - no other run is open (handoff-protocol §6.1)
agents: [01,11,15,16,17,18,19,26]
skills: []
gates: [data-operation]
baseline: consumes
closure: >
  Pre-execution data-operation gate approved (plan + rollback), apply executed and logged,
  data invariants re-verified green by 17, every risk ID terminal, zero open questions
  (handoff-protocol §6.1; gate variant per §3.4)
---

# Playbook — Data Operation

**Purpose:** Execute a one-off data job — a backfill, a bulk correction, a large data migration, or an ETL pass — **safely, reversibly, and verifiably**. The work changes data, never behavior: no new schema feature, no defect fix, no shipped logic. The whole point of this case is that a destructive or large-scale data change is approved on paper and rehearsed as a dry run **before** a single row is touched, and that the data's invariants are proven intact **after**.

**Legend:**

- `[H]` — human gate: the run blocks until the approver acts.
- `↺` — loop-back: findings return work to an earlier agent (full table in `../agent-handoff-protocol.md` §4).
- All ordering reflects dependency, never duration. No stage carries a time estimate.

---

## When to use / when NOT

Use data-operation when the request is to **change data in place** as a one-off — correct bad values in bulk, populate a new column from existing data, move/transform records between stores, or run an ETL pass — and the underlying schema and application behavior stay the same.

Do **not** use data-operation when:

- The job needs a **schema or feature change** (a new column the app reads, a new table, a behavior that consumes the data) → run **greenfield** as an **increment** (consumes the canonical baseline); the data move, if still needed, follows as a data-operation against the new schema.
- A **bug corrupted the data** and you want it fixed → run **`defect`** first to fix the cause so corruption stops recurring, **then** run data-operation to clean up the already-corrupted rows. Cleaning up without fixing the cause re-corrupts on the next write.
- The change is recurring/owned production behavior (a scheduled job that ships) → that is a **feature**, built greenfield/increment, not a one-off operation.

See `README.md` for the case picker.

---

## Entry criteria

Before issuing handoff `0001`, the Orchestrator verifies:

- The request is genuinely a **one-off data job**, not a feature or a defect (apply the test in *When to use / when NOT*; if it fails, redirect to the right case before opening this run).
- A **canonical baseline** exists to operate against — schema, persistence invariants, retention rules (`baseline: consumes`, promoted at a prior run's Gate 3, protocol §6.3) — so the operation can be expressed as a diff against known truth and the same invariants can be re-verified afterward. If the data store has **no** canonical baseline, the run records that explicitly and `baseline` degrades to `none` for this run (the operation then carries its own stated invariants).
- The **affected scope** (which records/tables/streams), the **source of truth**, and the **expected end state** are stated in the trigger; an under-specified scope is a blocking question to the human, never a guess (protocol §4).
- No other run is open (protocol §6.1).

---

## Run at a glance

```text
[Human invokes 01-delivery-orchestrator with the data-job request + affected scope]

PHASE A — PLAN (no data is touched in this phase)
  11-data-migration-engineer       request → operation plan: target scope, transformation,
                                   idempotency/restartability, blast radius, expected end state
  11-data-migration-engineer       written ROLLBACK plan: pre-image capture / reverse op / restore point
  11-data-migration-engineer       DRY RUN on a copy or in a no-commit transaction → diff & row-count report
  26-privacy-compliance-officer    (~) PII / retention / lawful-basis review of the touched data   ↺ → human via 01
  15-security-engineer             (~) access-path & secret review for the operation's credentials

  [H] DATA-OPERATION GATE  (pre-execution; relies on handoff-protocol §3.4)
      human approves the OPERATION plan AND the ROLLBACK plan together,
      with the dry-run evidence attached, BEFORE any apply.
      Destructive operations require explicit human approval (mirrors the
      Data & Migration Engineer roster rule).

PHASE B — EXECUTE
  16-observability-engineer        (~) operation logging / progress + redaction wired before apply
  11-data-migration-engineer       APPLY the approved operation (idempotent, restartable);
                                   every action logged to an auditable record         ↺ rollback on failure

PHASE C — VERIFY  (post-execution verification)
  17-validation-test-engineer      re-run data invariants + acceptance checks against the new state
                                   row counts / reconciliation vs expected end state   ↺ 11 on any violation
  18-code-reviewer                 (~) review the operation script + rollback artifact for auditability
  19-cicd-deployment-engineer      (~) if the operation ran as a deploy/migration job, confirm it is
                                   recorded, repeatable, and its rollback path is wired

  01-delivery-orchestrator         close-out: operation record + verification evidence archived;
                                   no canonical-doc promotion (data changed, not schema/architecture)
```

---

## Phase-by-phase

Each step names what the agent receives and produces *in this case*. Agent scope is defined once in the roster; this is not restated here.

### Phase A — Plan (no data is touched)

1. **Orchestrator boot (`01`).** Human invokes the Orchestrator with the data-job request and the affected scope. It creates the run workspace (protocol §1), registers the single **data-operation** gate, and routes the request to the Data & Migration Engineer. From here the human talks to the Orchestrator; specialists are reached through it.
2. **Operation plan (`11`).** Receives the request, the affected scope, and the canonical schema/invariants. Produces the **operation plan**: exact target set (queryable predicate, not prose), the transformation to apply, idempotency and restartability properties (safe to re-run after a partial failure), blast radius (rows/tables/streams touched and any downstream readers), and the expected end state expressed as checkable assertions. Each decision cites the packet/baseline section it derives from (e.g. retention rule §9, tracked information §6).
3. **Rollback plan (`11`).** Receives the operation plan. Produces a **written rollback plan** before any apply is contemplated: pre-image capture (snapshot the rows/keys that will change), a reverse operation or a restore point, and the exact condition under which rollback is triggered. This mirrors the roster rule that `11` never ships a destructive migration without rollback and explicit human approval — here that rule is the gate.
4. **Dry run (`11`).** Receives both plans. Executes the operation against a **copy** of the data or inside a **no-commit transaction**, producing a diff and row-count report: how many rows would change, sample before/after, and confirmation that the actual effect matches the expected end state. The dry run is the evidence the gate approver reads.
5. **Privacy & compliance review (`26`, conditional).** Engaged when the touched data is or may be personal data, or when the operation affects retention, deletion, or lawful basis. Reviews whether the operation is permitted for this data (§9 privacy/compliance/retention). A concern routes to the human via the Orchestrator — `26` does not silently clear or block; it raises the question for the named approver.
6. **Security review (`15`, conditional).** Engaged when the operation needs elevated or production credentials, or touches a sensitive store. Reviews the access path, secret handling, and minimum-privilege of the operation's credentials. Findings become constraints on the apply step.

   - **`[H]` DATA-OPERATION GATE — Pre-execution.** The approver named in the packet (§16) reviews the **operation plan and the rollback plan together**, with the dry-run diff attached, and signs before any apply. This is a **case-specific gate** (act-after-approve for a destructive-data risk): its intent — approve the plan *and* its reversal as a pair, pre-execution — relies on a handoff-protocol §3.4 case-specific-gate definition (the orchestrator adds that section). A destructive operation that reaches apply without this signed approval is a containment violation (protocol §4).

### Phase B — Execute

7. **Operation logging (`16`, conditional).** Engaged for any non-trivial or production operation. Wires progress logging and an auditable action record **before** apply begins, with redaction rules from the packet's privacy section so the log itself does not leak the data it is moving. Adds no business behavior.
8. **Apply (`11`).** Receives the **gate-approved** plan. Executes the operation idempotently and restartably, writing every action to the auditable record (what changed, when, by which run/handoff). On failure it stops and triggers the rollback plan from step 3 rather than improvising — **↺** rollback, then re-plan if needed. `complete` requires the run log and reconciliation counts as verification evidence (protocol §2.3).

### Phase C — Verify (post-execution verification)

9. **Invariant & acceptance re-verification (`17`).** Receives the post-apply state and the expected end state from the plan. Re-runs the **data invariants** (the same business rules as executable checks the baseline defines — append-only, uniqueness, non-negative, retention) plus reconciliation: row counts and sampled values against the expected end state. Any invariant violation or count mismatch is a finding routed **↺ 11** to re-mediate or to roll back; verification restarts after the fix. This rung is what makes the operation *verifiable*, not just *done*.
10. **Operation review (`18`, conditional).** Engaged when the operation ran as a committed script or migration. Reviews the operation script and the rollback artifact for correctness and **auditability** — that a human could replay why each row changed from the record alone. Blocking findings route to `11`.
11. **Delivery-job confirmation (`19`, conditional).** Engaged only when the operation was executed as a deployment/migration job through the pipeline. Confirms the job is recorded, repeatable, and that its rollback path is wired the same way a release rollback is. Does not deploy application changes — there are none in this case.
12. **Orchestrator close-out (`01`).** Confirms the verification evidence and the auditable operation record are archived in the run. **No canonical-doc promotion** (protocol §6.3) happens here: this case changed *data*, not requirements, glossary, architecture, or contracts, so the baseline it consumed is unchanged. Any risk raised during the run must be terminal before close (protocol §6.1).

---

## Loop-backs used

| Finding | Detected by | Routed to |
|---|---|---|
| Affected scope / end state under-specified or untraceable | 11, or anyone | Human via Orchestrator (blocking; protocol §4) |
| Dry-run diff does not match the expected end state | 11 | Re-plan within 11 before the gate |
| PII / retention / lawful-basis concern on touched data | 26 | Human via Orchestrator (blocking) |
| Operation needs broader access than minimum-privilege allows | 15 | Human via Orchestrator (gate condition on 11) |
| Apply fails mid-operation | 11 | Rollback plan (11), then re-plan |
| Data invariant violated or counts don't reconcile post-run | 17 | 11 |
| Operation script / rollback artifact not auditable | 18 | 11 |
| Anything untraceable to baseline or approved plan | Anyone | Human via Orchestrator (blocking) |

Full semantics: `../agent-handoff-protocol.md` §4.

---

## Closure criteria

A data-operation run is closed when (protocol §6.1, gate variant §3.4): the **pre-execution data-operation gate** is signed `approved` with the operation plan, the rollback plan, and the dry-run evidence on record (or the run is formally cancelled per §6.4 before any apply); the apply executed and is captured in the auditable operation record; **`17` re-verified the data invariants and reconciliation green** against the expected end state; every risk ID is terminal (resolved or formally accepted by the gate approver's name); zero unanswered open questions remain in the final `state.md`. The Orchestrator does **not** promote canonical artifacts at close — the consumed baseline (schema, invariants) is unchanged by a data-only operation.

## Worked example

none yet.
