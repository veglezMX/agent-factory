# Standalone Agent Invocation — Cheat Sheet

Every agent in this roster runs **solo from the agent picker**, not only under the
Delivery Orchestrator. Behavior is identical either way (see each agent's `## Invocation`).

The agents are **not coupled to each other** — no agent calls another (star topology; the
Orchestrator is the only hub). What couples them is **data**: each agent reads the artifact
the previous phase produced. Run one alone → you supply that upstream artifact yourself, or
the agent raises *blocking questions* naming the missing input. That is by design, not a crash.

## The two things every solo run needs

1. **A run-id** — a slug like `2026-07-my-thing` (`YYYY-MM-<slug>`). Tells the agent where to
   write. The workspace `runs/<run-id>/…` is created on first Write — a missing `runs/` folder
   is **never** a hard error, only a permission prompt.
2. **Its upstream input** — paste it inline, or point at the file. See the `Feed it` column.

Nothing else. No orchestrator, no other agents.

Every agent also emits a closing **handoff** at `runs/<run-id>/handoffs/NNNN-from-to.md`.

### Minimal solo prompt template

```
run-id: 2026-07-<slug>
<paste or reference the upstream artifact — e.g. the packet, requirements.md, a diff>
<your specific ask for this agent>
```

## Posture legend

| Mark | Meaning |
|------|---------|
| **E** | Edit-capable — writes its own artifacts / real repo code |
| **R** | Read-only — writes *findings only*, never edits your code |
| **O** | Orchestration-only — drives other agents |

---

## The chain (what feeds what)

```
packet → requirements → [ux] → [design-system] → architecture → bundle → build → hardening → delivery
```

Cross-cutting **reviewers (R)** sit outside the chain — point them at any diff or artifact and
they return findings. These are the most solo-friendly: no upstream chain required.

---

## Phase 0 — Discovery & Design

| Agent | Feed it | Produces | Posture |
|-------|---------|----------|---------|
| **requirements-analyst** | The Stakeholder Input Packet | `01-requirements/requirements.md`, `glossary.md`, `open-questions.md` | E |
| **ux-flow-designer** | Packet + `requirements.md` | `02-design/ux-inventory.md` | E — *optional; skips if API-only/headless* |
| **visual-design-system-designer** | Packet (branding/a11y) + `ux-inventory.md` | `02-design/design-system.md` | E — *optional; skips if no UI* |
| **solution-designer** | `requirements.md` (+ `ux-inventory.md` if present) | `02-design/architecture.md`, `stack-decision-record.md`, `integration-inventory.md` | E |

**Root of the chain = `requirements-analyst`.** Its only input is the packet. No packet yet?
Build one first with the **`creating-stakeholder-packet`** skill (template:
`templates/stakeholder-input-packet.md`). Everything downstream traces back to it.

## Phase 1 — Intake & Planning

| Agent | Feed it | Produces | Posture |
|-------|---------|----------|---------|
| **bundle-compiler** | Approved plan + `architecture.md` | `03-bundle/` (task files, dep graph, gate stubs) | E |
| **bundle-intake-validator** | Compiled `03-bundle/` | Pass/fail readiness report | R |
| **product-planner** | Validated bundle tasks + `requirements.md` | Per-feature implementation plan | R |

## Phase 2 — Build  *(these write real repo code + a handoff)*

| Agent | Feed it | Produces | Posture |
|-------|---------|----------|---------|
| **foundation-engineer** | `architecture.md` + foundation bundle task | Repo layout, tooling, shared primitives, dev runtime | E — *first build agent* |
| **contract-client-guardian** | `architecture.md` + `integration-inventory.md` | API contracts + generated clients | E — *after foundation* |
| **backend-domain-implementer** | Approved contracts + schemas + bundle task | Backend routes/domain/repos + service tests | E |
| **data-migration-engineer** | Packet data sections + **stable** contracts | Schemas, migrations (+rollback), seed data | E — *after contracts* |
| **frontend-feature-builder** | Generated API client + `ux-inventory.md` + `design-system.md` | Frontend screens/routing/state + all route states | E — *after backend contracts stable* |
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
| **architecture-guardian** | Solution-designer output **or** an impl diff | `findings/architecture/` | R |
| **infrastructure-guardian** | An IaC / deploy-manifest diff | `findings/infrastructure/` | R |
| **privacy-compliance-officer** | Data design/integrations + packet privacy § | `findings/compliance/` **or** a named policy artifact | E |

The 5 review-only agents (**code-reviewer, architecture-guardian, infrastructure-guardian,
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

- **Solo** — iterating on ONE phase (tune UX flows, re-review a diff, draft a data-retention
  policy). Feed the one upstream artifact; ignore the rest of the chain.
- **Full run** — the whole chain, with each agent fed its upstream automatically. Use the
  **`run-delivery`** skill (main session becomes the Orchestrator) or invoke
  `delivery-orchestrator` with the packet.
