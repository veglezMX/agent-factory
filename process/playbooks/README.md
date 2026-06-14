# Playbooks — Case Index

The roster (`../agent-roster.md`) and handoff protocol (`../agent-handoff-protocol.md`) are the shared spine: the complete set of agents and the rules by which work moves between them. A **playbook** is the per-**case** execution recipe — which agents and skills a class of work uses, in what order, with which gates and loop-backs. Not every case runs every agent.

Authoring contract: `playbook-schema.md`. Adding a case is a drop-in — one new `<case>.md` conforming to the schema, plus a column in the matrix below. The roster and protocol do not change to add a case.

---

## Cases

| Case | Status | Trigger | Gates | Baseline |
|---|---|---|---|---|
| [`greenfield`](greenfield.md) | **live** | Stakeholder Input Packet | scope · design · release | produces |
| `increment` (variant of greenfield) | **live** | Delta packet on a closed run | scope · design · release | consumes |
| [`brownfield-onboard`](brownfield-onboard.md) | **live** | Existing foreign codebase + thin packet | scope · design · release (baseline-approval) | produces |
| [`defect`](defect.md) | **live** | Reproducible defect report against shipped behavior | release | consumes |
| [`incident`](incident.md) | **live** | Active production incident (degradation/outage) | release (emergency/retroactive) | consumes |
| [`refactor`](refactor.md) | **live** | Internal restructuring with no behavior change | design · behavior-parity · release | consumes |
| [`dependency-upgrade`](dependency-upgrade.md) | **live** | Dependency/framework upgrade or CVE advisory | release (+ security sign-off on CVE) | consumes |
| [`spike`](spike.md) | **live** | Open feasibility/design question (pre-scoping) | findings | none |
| [`deprecation`](deprecation.md) | **live** | Decision to remove a feature, journey, or capability | scope · release | consumes |
| [`data-operation`](data-operation.md) | **live** | One-off data job: backfill, correction, migration, ETL | data-operation (pre-execution) | consumes / none |

Gate variants beyond the standard `scope · design · release` (emergency/retroactive, behavior-parity, data-operation, findings, baseline-approval) are defined in `../agent-handoff-protocol.md` §3.4.

---

## Pick a case

```text
Need to answer a question before the work can even be scoped?  ───►  spike

Is there a product yet?
├─ No  ─────────────────────────────────────────────────────────►  greenfield
└─ Yes
   ├─ Built elsewhere (no canonical baseline)?
   │   └─ First touch  ─────────────────────────────────────────►  brownfield-onboard, then increment
   └─ Built by this pipeline (canonical docs/ exist)?
       ├─ Production is on fire right now  ─────────────────────►  incident
       ├─ Adding a feature / module / journey  ─────────────────►  greenfield · increment variant
       ├─ Removing a feature / journey / capability  ───────────►  deprecation
       ├─ Fixing reproducible broken behavior  ────────────────►  defect
       ├─ Restructuring with no behavior change  ──────────────►  refactor
       ├─ Bumping a dependency / patching a CVE  ───────────────►  dependency-upgrade
       └─ Running a one-off data job (backfill/migration/ETL)  ─►  data-operation
```

A defect, a foreign codebase, an outage, or a data backfill should not be forced through full greenfield — that is the whole reason cases exist.

---

## Case × agent matrix

`x` = the case uses the agent · `–` = not used · `~` = conditional (opt-in per run).
Every column is authoritative — each is taken from the agent set its playbook actually runs. Column abbreviations: `gf` greenfield · `bf` brownfield-onboard · `df` defect · `in` incident · `rf` refactor · `du` dependency-upgrade · `sp` spike · `dp` deprecation · `do` data-operation. (The `increment` variant inherits the `greenfield` column.)

| # | Agent | gf | bf | df | in | rf | du | sp | dp | do |
|---|---|:--:|:--:|:--:|:--:|:--:|:--:|:--:|:--:|:--:|
| 01 | Delivery Orchestrator | x | x | x | x | x | x | x | x | x |
| 02 | Requirements Analyst | x | x | – | – | – | – | ~ | ~ | – |
| 03 | UX Flow Designer | x | ~ | ~ | – | – | – | – | – | – |
| 04 | Solution Designer | x | x | – | – | ~ | – | ~ | ~ | – |
| 05 | Bundle Compiler | x | x | – | – | – | – | – | – | – |
| 06 | Bundle Intake Validator | x | x | – | – | – | – | – | – | – |
| 07 | Product Planner | x | x | ~ | – | x | – | ~ | – | – |
| 08 | Architecture Guardian | x | x | ~ | – | x | – | ~ | x | – |
| 09 | Foundation Engineer | x | – | – | – | – | ~ | – | – | – |
| 10 | Contract & Client Guardian | x | x | ~ | – | ~ | ~ | – | x | – |
| 11 | Data & Migration Engineer | x | x | ~ | ~ | ~ | ~ | – | x | x |
| 12 | Integration Engineer | x | ~ | – | ~ | – | – | – | – | – |
| 13 | Backend Domain Implementer | x | x | x | ~ | ~ | ~ | ~ | x | – |
| 14 | Frontend Feature Builder | x | x | ~ | ~ | ~ | ~ | ~ | ~ | – |
| 15 | Security Engineer | x | x | ~ | ~ | – | x | – | ~ | ~ |
| 16 | Observability Engineer | x | ~ | – | ~ | – | – | – | – | ~ |
| 17 | Validation & Test Engineer | x | x | x | x | x | x | – | x | x |
| 18 | Code Reviewer | x | x | x | x | x | x | – | x | ~ |
| 19 | CI/CD & Deployment Engineer | x | x | x | x | x | x | – | x | ~ |
| 20 | Documentation & Runbook Writer | x | x | ~ | x | ~ | ~ | – | x | – |
| 21 | Infrastructure & Platform Engineer | x | ~ | – | – | ~ | ~ | ~ | – | – |
| 22 | Infrastructure Guardian | x | ~ | – | ~ | ~ | ~ | – | ~ | – |
| 23 | Performance & Load Engineer | x | – | – | ~ | ~ | – | ~ | – | – |
| 24 | Visual & Design-System Designer | x | – | – | – | – | – | – | – | – |
| 25 | AI & Prompt Engineer | ~ | – | ~ | – | – | – | ~ | – | – |
| 26 | Privacy & Compliance Officer | ~ | ~ | – | – | – | – | – | ~ | ~ |
| 27 | Accessibility Auditor | x | ~ | ~ | – | – | – | – | ~ | – |
| 28 | Product Analytics & Instrumentation Engineer | x | ~ | – | – | – | – | ~ | ~ | – |

Reading the columns: cases drop the discovery/design front-half (`02`–`08`) when there is no new scope to design (`defect`, `incident`, `dependency-upgrade`, `data-operation`); `brownfield-onboard` drops `09` because the foundation already exists; `spike` runs almost nothing to `x` because its only committed deliverable is a decision; `data-operation` collapses to the `11`+`17` core behind a pre-execution gate. The conditional (`~`) marks fire on what a given run actually touches — e.g. `10` only when an API moves, `26` only on regulated/PII data.

---

## Worked examples

Project-specific walkthroughs live in `../examples/`. They show one case applied to one product and link the real run workspace under `../../runs/`.

| Example | Case | Product |
|---|---|---|
| [`comedor-greenfield.md`](../examples/comedor-greenfield.md) | greenfield | Comedor Vecinal (community canteen) |
