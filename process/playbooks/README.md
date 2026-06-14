# Playbooks — Case Index

The roster (`../agent-roster.md`) and handoff protocol (`../agent-handoff-protocol.md`) are the shared spine: the complete set of agents and the rules by which work moves between them. A **playbook** is the per-**case** execution recipe — which agents and skills a class of work uses, in what order, with which gates and loop-backs. Not every case runs every agent.

Authoring contract: `playbook-schema.md`. Adding a case is a drop-in — one new `<case>.md` conforming to the schema, plus a column in the matrix below. The roster and protocol do not change to add a case.

---

## Cases

| Case | Status | Trigger | Gates | Baseline |
|---|---|---|---|---|
| [`greenfield`](greenfield.md) | **live** | Stakeholder Input Packet | scope · design · release | produces |
| `increment` (variant of greenfield) | **live** | Delta packet on a closed run | scope · design · release | consumes |
| `brownfield-onboard` | planned | Existing foreign codebase + thin packet | TBD | produces |
| `defect` | planned | Reproducible defect report | TBD (lighter) | none |

**Planned** cases are slots, not yet authored. Their rows below are provisional sketches to show intent; they are finalized when the playbook is written.

---

## Pick a case

```text
Is there a product yet?
├─ No  ──────────────────────────────────────────────►  greenfield
└─ Yes
   ├─ Built by this pipeline (canonical docs/ exist)?
   │   ├─ Adding a feature / module / journey  ───────►  greenfield · increment variant
   │   └─ Fixing shipped behavior              ───────►  defect (planned)
   └─ Built elsewhere (no canonical baseline)?
       └─ First touch  ──────────────────────────────►  brownfield-onboard (planned)
                                                          then increment for the actual change
```

A defect or a foreign codebase should not be forced through full greenfield — that is the whole reason cases exist.

---

## Case × agent matrix

`x` = the case uses the agent · `–` = not used · `~` = conditional (opt-in per run).
The `greenfield` column is authoritative. `brownfield-onboard` and `defect` columns are **provisional** until those playbooks are authored.

| # | Agent | greenfield | brownfield-onboard | defect |
|---|---|:---:|:---:|:---:|
| 01 | Delivery Orchestrator | x | x | x |
| 02 | Requirements Analyst | x | x | – |
| 03 | UX Flow Designer | x | – | ~ |
| 04 | Solution Designer | x | x | – |
| 05 | Bundle Compiler | x | x | – |
| 06 | Bundle Intake Validator | x | x | – |
| 07 | Product Planner | x | x | ~ |
| 08 | Architecture Guardian | x | x | ~ |
| 09 | Foundation Engineer | x | – | – |
| 10 | Contract & Client Guardian | x | x | ~ |
| 11 | Data & Migration Engineer | x | x | ~ |
| 12 | Integration Engineer | x | ~ | – |
| 13 | Backend Domain Implementer | x | x | x |
| 14 | Frontend Feature Builder | x | x | ~ |
| 15 | Security Engineer | x | x | ~ |
| 16 | Observability Engineer | x | ~ | – |
| 17 | Validation & Test Engineer | x | x | x |
| 18 | Code Reviewer | x | x | x |
| 19 | CI/CD & Deployment Engineer | x | x | x |
| 20 | Documentation & Runbook Writer | x | x | ~ |

The rationale behind the planned columns — why brownfield drops `09` (foundation already exists) and defect drops the discovery/design front-half (no new scope to design) — is documented when each playbook is authored.

---

## Worked examples

Project-specific walkthroughs live in `../examples/`. They show one case applied to one product and link the real run workspace under `../../runs/`.

| Example | Case | Product |
|---|---|---|
| [`comedor-greenfield.md`](../examples/comedor-greenfield.md) | greenfield | Comedor Vecinal (community canteen) |
