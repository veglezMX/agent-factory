# Standalone Agent Invocation — Cheat Sheet

Every specialist in this roster supports a bounded direct human call through `standalone`
mode; the Delivery Orchestrator is needed only for a governed `pipeline` run. The normative
rules live in [`agent-invocation-contract.md`](agent-invocation-contract.md).

The agents are capability-decoupled: no specialist must invoke another. In pipeline mode,
artifacts form a governed chain. In standalone mode, the direct task, target, and selected
references define the local scope; a full upstream artifact chain is optional.

## What a standalone call needs

1. **A bounded task** — the outcome you want from this specialist.
2. **A target** — a file, component, service, diff, endpoint set, artifact, or area.
3. **Capability-specific inputs, when material** — for example endpoint schemas for a UI
   layout task or a diff for review. The agent inspects available local context before asking.

No run ID, run workspace, handoff, gate, Orchestrator, or prior agent is required. Those are
pipeline concerns. Scope and safety boundaries remain identical in both modes.

### Minimal standalone prompt template

```
mode: standalone
task: <the bounded outcome>
target: <file, component, service, diff, artifact, or area>
inputs: [<optional paths, endpoints, schemas, screenshots, or constraints>]
apply: false  # set true only when you want in-scope edits
```

### UI layout example

```yaml
mode: standalone
operation: design                 # design | review | apply
task: Improve the information hierarchy and responsive layout without changing behavior.
target: src/pages/orders/OrdersPage.tsx
data_sources:
  - generatedClient.orders.listOrders
  - contracts/openapi/orders.yaml
inputs:
  - src/components/ui/
  - current desktop/mobile screenshots
apply: false                      # true is required before application code may be edited
```

The UI Layout Designer first maps visible elements to available endpoint/client fields. Missing
data is reported as a dependency; it is never fabricated or obtained by silently changing the API.

## Posture legend

| Mark | Meaning |
|------|---------|
| **E** | Edit-capable — writes its own artifacts / real repo code |
| **R** | Read-only — writes *findings only*, never edits your code |
| **O** | Orchestration-only — drives other agents |

---

## The chain (what feeds what)

```
packet → requirements → [ux] → [design-system] → [ui-layout] → architecture → bundle → build → hardening → delivery
```

Cross-cutting **reviewers (R)** sit outside the pipeline chain — point them at any diff or
artifact and they return findings. In standalone mode, every specialist works the same way:
give it a bounded target and only the references relevant to that task.

---

## Phase 0 — Discovery & Design

| Agent | Feed it | Produces | Posture |
|-------|---------|----------|---------|
| **requirements-analyst** | The Stakeholder Input Packet | `01-requirements/requirements.md`, `glossary.md`, `open-questions.md` | E |
| **ux-flow-designer** | Packet + `requirements.md` | `02-design/ux-inventory.md` | E — *optional; skips if API-only/headless* |
| **visual-design-system-designer** | Packet (branding/a11y) + `ux-inventory.md` | `02-design/design-system.md` | E — *optional; skips if no UI* |
| **ui-layout-designer** | A page/screen target + available endpoint/client data; UX/design-system inputs optional standalone | Responsive page layouts, data-to-UI mapping, state designs, visual acceptance baselines; optional presentational code changes | E+T — *`design`, `review`, or explicit `apply` operation* |
| **solution-designer** | `requirements.md` + UX/UI layout data needs when present | `02-design/architecture.md`, `stack-decision-record.md`, `integration-inventory.md` | E |

**Pipeline root = `requirements-analyst`.** Its only input is the packet. No packet yet?
Build one first with the **`creating-stakeholder-packet`** skill (template:
`templates/stakeholder-input-packet.md`). Standalone tasks do not need to start at this root.

## Phase 1 — Intake & Planning

| Agent | Feed it | Produces | Posture |
|-------|---------|----------|---------|
| **bundle-compiler** | Approved requirements + architecture/UX/UI layout artifacts | `03-bundle/` (task files, dep graph, gate stubs) | E |
| **bundle-intake-validator** | Compiled `03-bundle/` | Pass/fail readiness report | R |
| **product-planner** | Validated bundle tasks + `requirements.md` | Per-feature implementation plan | R |

## Phase 2 — Build  *(these can write real repo code; handoffs are pipeline-only)*

| Agent | Feed it | Produces | Posture |
|-------|---------|----------|---------|
| **foundation-engineer** | `architecture.md` + foundation bundle task | Repo layout, tooling, shared primitives, dev runtime | E — *first build agent* |
| **contract-client-guardian** | `architecture.md` + `integration-inventory.md` + approved UI data dependencies when present | API contracts + generated clients | E — *after foundation* |
| **backend-domain-implementer** | Approved contracts + schemas + bundle task | Backend routes/domain/repos + service tests | E |
| **data-migration-engineer** | Packet data sections + **stable** contracts | Schemas, migrations (+rollback), seed data | E — *after contracts* |
| **frontend-feature-builder** | Generated API client + `ux-inventory.md` + `design-system.md` + UI layout specs when available | Frontend screens/routing/state + all route states | E — *after backend contracts stable* |
| **integration-engineer** | One entry from `integration-inventory.md` | Deterministic fake + production adapter (one interface) | E — *once per integration* |
| **ai-prompt-engineer** | Packet AI-behavior spec | Prompts, eval harness, guardrails, RAG wiring | E — *conditional; per AI feature only* |

## Phase 3 — Hardening

| Agent | Feed it | Produces | Posture |
|-------|---------|----------|---------|
| **validation-test-engineer** | Built code + contracts | Invariant/contract/integration/E2E suites + acceptance gate | E |
| **observability-engineer** | Stabilized service behavior | Structured logging, metrics, traces, health checks | E |
| **product-analytics-engineer** | Stabilized product behavior + packet privacy § | Event taxonomy, KPI/funnel instrumentation (consent-gated) | E |
| **performance-load-engineer** | Packet scale expectations + critical journeys | Load/stress/soak/spike suites + perf budgets | E |
| **code-reviewer** | An implementation diff | `findings/review/` (routes to security/arch) | R |
| **security-engineer** | Diff touching auth/secrets/CORS/etc. | `findings/security/` | E |
| **accessibility-auditor** | Design-system a11y spec **or** implemented UI | `findings/accessibility/` | E |
| **ui-layout-designer** | Implemented page + approved UI layout/baseline | `findings/ui/` fidelity review; optional standalone presentational improvements | E+T |
| **architecture-guardian** | Solution-designer output **or** an impl diff | `findings/architecture/` | R |
| **infrastructure-guardian** | An IaC / deploy-manifest diff | `findings/infrastructure/` | R |
| **privacy-compliance-officer** | Data design/integrations + packet privacy § | `findings/compliance/` **or** a named policy artifact | E |

The five read-only agents (**code-reviewer, architecture-guardian, infrastructure-guardian,
bundle-intake-validator, product-planner**) touch nothing — safest to run solo on any target.

## Phase 4 — Delivery

| Agent | Feed it | Produces | Posture |
|-------|---------|----------|---------|
| **infrastructure-platform-engineer** | `architecture.md` + infra bundle task | IaC: network, data stores, secrets, DNS/TLS, IAM, compute | E — *plan-before-apply; never destructive to shared/prod without recorded approval* |
| **cicd-deployment-engineer** | Foundation + build output | CI pipelines, container builds, deploy + rollback config | E |
| **documentation-runbook-writer** | Implemented, stabilized behavior | Setup guides, runbooks, release notes, known-limitations | E |

## Orchestration

| Agent | Feed it | Produces | Posture |
|-------|---------|----------|---------|
| **delivery-orchestrator** | The Stakeholder Input Packet | Runs the whole chain; gates + `state.md` + delivery summary | O — *THE entry point; use for the full run instead of wiring agents by hand* |

---

## When to go solo vs. full run

- **Standalone** — improving one page layout, tuning a UX flow, reviewing a diff, drafting a
  policy, or performing another bounded specialist task. Supply the target and relevant inputs;
  no run ID or formal handoff is required.
- **Full run** — the whole chain, with each agent fed its upstream automatically. Use the
  **`run-delivery`** skill (main session becomes the Orchestrator) or invoke
  `delivery-orchestrator` with the packet.
