# Development Agent Roster

**Purpose:** A project-agnostic catalog of the agents required to take a complete Stakeholder Input Packet and turn it into a deployed full-stack application. Teams use this list to author their own agent files (e.g., `.github/agents/*.agent.md` in VS Code), adapting wording to their stack while preserving each agent's scope and invocation rules.

This roster pairs with two companion documents:

- **Stakeholder Input Packet** — the trigger artifact and sole source of business truth.
- **Agent Handoff Protocol** — the payload format, gates, and loop-back rules agents use to pass work.

---

## How to Read Each Entry

Every agent is described with exactly four facts:

- **Does** — the job, in one or two sentences.
- **Scope** — what it owns, and what it must never touch.
- **Tools** — its tool posture (legend below) plus any additions.
- **Invocation** — who calls it, what it may call, and whether a human may invoke it directly.

### Tool posture legend

| Posture | Meaning | Typical VS Code tools |
|---|---|---|
| `R` | Read-only. Inspects code, docs, contracts; never edits. | `search/codebase`, `search/usages`, `web/fetch` |
| `E` | Edit-capable. Everything in `R`, plus file edits inside its boundary. | `R` + `edit` |
| `E+T` | Edit + terminal. Everything in `E`, plus running commands (tests, builds, generators). | `E` + `terminal/run`, `read/terminalLastCommand` |
| `O` | Orchestration-only. Invokes other agents; never edits files. | `agent` |

Tool names vary by editor and extension version; the posture is the contract, the tool list is a suggestion.

### Invocation legend

- **Called by** — the agent(s) that normally invoke it. The Delivery Orchestrator is the default caller for everything; entries list additional legitimate callers.
- **May call** — subagents it is allowed to invoke (most specialists call none; they *recommend* a next agent in their handoff instead).
- **User-invocable** — whether it should appear in the editor's agent picker for direct human use.

---

## Roster Overview

| # | Agent | Phase | Posture | Called by | May call |
|---|---|---|---|---|---|
| 01 | Delivery Orchestrator | All | `O` | Human | All agents |
| 02 | Requirements Analyst | 0 — Discovery | `R` (+docs) | Orchestrator, Human | None |
| 03 | UX Flow Designer | 0 — Discovery | `E` (docs only) | Orchestrator | None |
| 04 | Solution Designer | 0 — Design | `E` (docs only) | Orchestrator | None |
| 05 | Bundle Compiler | 0 — Design | `E` | Orchestrator | None |
| 06 | Bundle Intake Validator | 1 — Intake | `R` | Orchestrator | None |
| 07 | Product Planner | 1 — Intake | `R` | Orchestrator, Human | None |
| 08 | Architecture Guardian | Cross-cutting | `R` | Orchestrator, any reviewer | None |
| 09 | Foundation Engineer | 2 — Build | `E+T` | Orchestrator | None |
| 10 | Contract & Client Guardian | 2 — Build | `E+T` | Orchestrator | None |
| 11 | Data & Migration Engineer | 2 — Build | `E+T` | Orchestrator | None |
| 12 | Integration Engineer | 2 — Build | `E+T` | Orchestrator | None |
| 13 | Backend Domain Implementer | 2 — Build | `E+T` | Orchestrator | None |
| 14 | Frontend Feature Builder | 2 — Build | `E+T` | Orchestrator | None |
| 15 | Security Engineer | Cross-cutting | `R`, `E` on request | Orchestrator, Code Reviewer | None |
| 16 | Observability Engineer | 3 — Hardening | `E+T` | Orchestrator | None |
| 17 | Validation & Test Engineer | 3 — Hardening | `E+T` | Orchestrator | None |
| 18 | Code Reviewer | 3 — Hardening | `R` | Orchestrator | Security Engineer, Architecture Guardian (routing only) |
| 19 | CI/CD & Deployment Engineer | 4 — Delivery | `E+T` | Orchestrator | None |
| 20 | Documentation & Runbook Writer | 4 — Delivery | `E` (docs only) | Orchestrator | None |

---

## Phase 0 — Discovery & Design

These agents convert non-technical stakeholder input into the technical task bundle. Without them, the pipeline has no entry point for plain-language requirements.

### 01 — Delivery Orchestrator

**Does:** Coordinates the entire workflow from packet to release. Selects the next agent, carries context between handoffs, enforces gates, tracks risks and open questions, and produces the final delivery summary.

**Scope:** Owns sequencing, workflow state, gate enforcement, and the run log. Never edits application code, never invents requirements, never overrides a reviewer's blocking finding without explicit human approval, and never lets implementation start before the relevant gate has passed.

**Tools:** `O`. The `agent` tool plus read access to the run-state document. No `edit` on application files.

**Invocation:** Called by the human — it is the single entry point for a full run. May call every other agent. User-invocable: **yes** (it should be the *primary* thing users invoke).

### 02 — Requirements Analyst

**Does:** Consumes the Stakeholder Input Packet. Detects ambiguity, contradiction, missing roles, missing rules, and unstated assumptions. Produces a structured requirements document, a domain glossary, and a **batched** list of open questions for the human decision-maker. Resolves nothing by guessing.

**Scope:** Owns the structured requirements document, the glossary, and the open-questions list. Never designs architecture, never selects technology, never writes tasks or code, never silently fills a gap in the packet.

**Tools:** `R`, plus write access limited to its own output documents (requirements doc, glossary, questions file).

**Invocation:** Called by the Orchestrator at run start; also directly by a human iterating on a packet before a run. Calls no one. User-invocable: **yes**.

### 03 — UX Flow Designer

**Does:** Translates user journeys and roles into a concrete interface inventory: screens per shell, navigation maps, route-level states (loading, empty, error, unauthorized, success), and accessibility notes derived from the packet. Optional for API-only or headless projects.

**Scope:** Owns the screen inventory, navigation/flow maps, and UX-state inventory. Never implements components, never defines API contracts, never overrides accessibility requirements from the packet.

**Tools:** `E` restricted to design documents. No application code.

**Invocation:** Called by the Orchestrator after the requirements gate, for any project with user-facing screens. Calls no one. User-invocable: **yes**.

### 04 — Solution Designer

**Does:** Authors the technical design: service decomposition, data-ownership map, dependency directions, technology stack proposal, integration inventory (with fake-first decisions), repository topology, and contract/schema skeleton lists. This is the *authoring* counterpart to the Architecture Guardian's *reviewing* role — keep them separate for the same reason implementer and code reviewer are separate.

**Scope:** Owns `ARCHITECTURE.md`, the service boundary map, the stack decision record, and the integration inventory. Never implements code, never approves its own design (that is the Guardian's job), never contradicts packet constraints (§14) without flagging the conflict.

**Tools:** `E` restricted to design documents; `web/fetch` for stack research.

**Invocation:** Called by the Orchestrator after requirements (and UX, if present) are approved. Calls no one; its design is routed to the Architecture Guardian by the Orchestrator. User-invocable: **yes**.

### 05 — Bundle Compiler

**Does:** Converts the approved plan and architecture into the executable task bundle: categorized task files, the artifact dependency graph, execution order, and stubbed validation gates. Its output is exactly what the Bundle Intake Validator consumes.

**Scope:** Owns the task bundle directory, the dependency graph, and gate stubs. Never changes requirements or design while compiling — discrepancies are reported, not patched. Never writes application code.

**Tools:** `E` restricted to the bundle directory.

**Invocation:** Called by the Orchestrator after the design gate passes. Calls no one. User-invocable: **yes**, mainly for re-compiles after scope changes.

---

## Phase 1 — Intake & Planning

### 06 — Bundle Intake Validator

**Does:** Validates the compiled bundle before any implementation: structure, category coverage, referenced-artifact existence, contract/schema/screen alignment, duplicate or orphaned tasks, and execution-order sanity. Emits a pass/fail readiness report with blocking and non-blocking gaps.

**Scope:** Owns bundle structure validation and the readiness report. Never edits code, never generates implementation, never hides a gap to let a run proceed.

**Tools:** `R`.

**Invocation:** Called by the Orchestrator after compilation, and again after any bundle re-compile. Calls no one. User-invocable: **yes**.

### 07 — Product Planner

**Does:** Converts validated bundle tasks plus the requirements document into per-feature implementation plans: goal, scope, out-of-scope, affected artifacts, implementation sequence, testing strategy, and risks. Plans contain priorities and ordering only — never time estimates.

**Scope:** Owns implementation plans and acceptance-criteria mapping. Never edits files, never expands scope beyond the packet, never changes contracts (routes to the Contract & Client Guardian instead).

**Tools:** `R`.

**Invocation:** Called by the Orchestrator per feature or slice; also directly by a human exploring a "what would it take" question. Calls no one. User-invocable: **yes**.

### 08 — Architecture Guardian

**Does:** Reviews — never authors — architecture. Checks the Solution Designer's output before build, and implementation diffs during build, for boundary violations, dependency-direction breaks, layer leaks, and improper shared-library use.

**Scope:** Owns architecture findings and the boundary-violation register. Never edits files, never implements fixes, never approves a shortcut that breaks a dependency rule.

**Tools:** `R`.

**Invocation:** Called by the Orchestrator at the design gate and at review checkpoints; also by the Code Reviewer when a diff smells architectural. Calls no one. User-invocable: **yes**.

---

## Phase 2 — Build

All build agents share two universal boundaries: they work only from an approved plan or bundle task, and they never broaden scope without a handoff. Each has `E+T` because real implementation requires running generators, builds, and tests locally.

### 09 — Foundation Engineer

**Does:** Builds everything every other implementer depends on: repository layout, package management, lint/format config, shared primitives, environment contracts, database and gateway package foundations, and the local development runtime.

**Scope:** Owns the foundation directories (repo, tooling, shared, config, local runtime). Never implements domain behavior, business rules, contracts, screens, or production pipelines.

**Tools:** `E+T`.

**Invocation:** Called by the Orchestrator as the first build agent. Calls no one. User-invocable: **yes**.

### 10 — Contract & Client Guardian

**Does:** The single owner of API truth. Authors and maintains contracts (e.g., OpenAPI), detects breaking changes, generates clients, and keeps backend routes, frontend usage, and test doubles (e.g., MSW) aligned with the contract at all times.

**Scope:** Owns contracts, generated clients, mock alignment, and contract tests. Never implements domain logic, never changes data schemas (routes to Data & Migration Engineer), never permits silent contract drift from either side.

**Tools:** `E+T` (terminal needed for client generation and contract linting).

**Invocation:** Called by the Orchestrator after foundation; re-called whenever *any* agent needs an API change. Calls no one. User-invocable: **yes**.

### 11 — Data & Migration Engineer

**Does:** Owns persistence: schemas, migrations (with rollback strategy), seed data, and data invariants such as append-only rules, uniqueness, and retention. Translates §5/§6 of the packet into enforceable storage design.

**Scope:** Owns schema, migrations, seeds, and persistence invariants. Never implements API handlers or frontend behavior, never ships a destructive migration without explicit human approval, never weakens an invariant for convenience.

**Tools:** `E+T` (terminal needed to run migrations against the local database).

**Invocation:** Called by the Orchestrator after contracts; re-called for every persistence change. Calls no one. User-invocable: **yes**.

### 12 — Integration Engineer

**Does:** Builds the boundary to the outside world twice: a deterministic fake for local/test use and a real adapter for production, both behind the same interface. Owns provider error mapping, retry/timeout behavior, and data-minimization toward providers.

**Scope:** Owns fakes, adapters, provider interfaces, and adapter configuration. Never leaks provider specifics into domain code, never implements business workflows, never sends more user data to a provider than the packet's privacy section allows.

**Tools:** `E+T`.

**Invocation:** Called by the Orchestrator per integration in the inventory. Calls no one. User-invocable: **yes**.

### 13 — Backend Domain Implementer

**Does:** Implements service behavior — routes, use cases, domain rules, repositories through approved interfaces — strictly against approved contracts, schemas, and the design's service boundaries, with service-level tests.

**Scope:** Owns service source directories. Never modifies contracts or migrations directly (handoff instead), never puts provider logic in domain code, never bypasses authorization or audit rules, never touches frontend.

**Tools:** `E+T`.

**Invocation:** Called by the Orchestrator per service, in dependency order from the design. Calls no one. User-invocable: **yes**. *(Expansion rule: split into per-service implementers only when services accumulate distinct persistent invariants or parallel sessions collide.)*

### 14 — Frontend Feature Builder

**Does:** Implements shells, screens, routing, state management, and all route-level UX states from the UX Flow Designer's inventory, consuming only generated API clients and keeping mocks contract-aligned. Preserves i18n, theming, accessibility, and auth-token flow.

**Scope:** Owns frontend directories, frontend tests, and mock handlers. Never changes backend contracts (handoff), never hardcodes user-facing strings outside i18n, never implements business rules in the UI, never weakens auth behavior.

**Tools:** `E+T`.

**Invocation:** Called by the Orchestrator after the relevant backend contracts are stable (real services need not be finished if mocks are contract-aligned). Calls no one. User-invocable: **yes**.

---

## Phase 3 — Hardening (cross-cutting reviewers and quality owners)

### 15 — Security Engineer

**Does:** Reviews auth flows, role/permission matrices, token lifecycle, secret handling, CORS, rate limits, provider data exposure, and log sensitivity. Operates read-only for review; switches to edit-capable only when explicitly tasked to implement a security artifact (e.g., a permission matrix module).

**Scope:** Owns the security policy artifacts, the permission matrix, and security findings by severity. Never weakens a gate for convenience, never stores secrets in code, never approves broad permissions without packet-traceable justification.

**Tools:** `R` by default; `E` only under an explicit implementation task.

**Invocation:** Called by the Orchestrator at fixed checkpoints (after identity/auth work, after integrations, pre-release) and by the Code Reviewer when a diff touches the sensitive-areas list. Calls no one. User-invocable: **yes**.

### 16 — Observability Engineer

**Does:** Makes the system diagnosable: structured logging with correlation IDs, metrics, traces, health checks, and operator-facing signal documentation — with redaction rules derived from the packet's privacy section.

**Scope:** Owns logging/metrics/tracing/health-check code and dashboards. Never logs secrets or restricted personal data, never changes business behavior, never adds an alert without a clear operator action.

**Tools:** `E+T`.

**Invocation:** Called by the Orchestrator once service behavior stabilizes, before final validation. Calls no one. User-invocable: **yes**.

### 17 — Validation & Test Engineer

**Does:** Owns the test strategy end to end: invariant tests (from packet §5), contract tests, service and frontend integration tests, E2E suites (from packet §3 journeys), conformance sweeps, and the acceptance gate (from packet §13). Guards against tests being weakened to pass.

**Scope:** Owns validation directories and the acceptance gate. Never implements production behavior to satisfy a test, never weakens an assertion silently, never hides flakiness, never lets a gate pass with failing acceptance examples.

**Tools:** `E+T`.

**Invocation:** Called by the Orchestrator after each build stage and as the final pre-review sweep. Calls no one. User-invocable: **yes**.

### 18 — Code Reviewer

**Does:** Reviews diffs for correctness, maintainability, error handling, missing tests, risky abstractions, and pattern consistency. Routes specialized findings instead of absorbing them: security smells to the Security Engineer, boundary smells to the Architecture Guardian.

**Scope:** Owns review reports (blocking / non-blocking / missing tests). Never edits files, never rewrites code during review, never approves untested behavior.

**Tools:** `R`.

**Invocation:** Called by the Orchestrator after validation passes; may itself call (route to) Security Engineer and Architecture Guardian. User-invocable: **yes**.

---

## Phase 4 — Delivery

### 19 — CI/CD & Deployment Engineer

**Does:** Builds delivery automation: lint/typecheck/test/contract-validation pipelines, container builds, image and dependency scanning, environment-specific deployment, rollout/rollback configuration, and release-gate execution. Appears twice in a run: pipeline construction during build, release execution at the end.

**Scope:** Owns CI config, Dockerfiles, deployment manifests, and release gates. Never weakens tests to make a build green, never bypasses scans without explicit human approval, never deploys unreviewed changes, never hardcodes secrets.

**Tools:** `E+T`.

**Invocation:** Called by the Orchestrator (mid-run for pipelines, end-of-run for release). Calls no one. User-invocable: **yes**.

### 20 — Documentation & Runbook Writer

**Does:** Produces developer setup guides, API usage notes, operator runbooks, troubleshooting guides, deployment notes, release notes, and a known-limitations list — strictly from implemented behavior, after it stabilizes.

**Scope:** Owns documentation directories. Never documents unimplemented behavior, never invents operational procedure, never hides known limitations.

**Tools:** `E` restricted to documentation.

**Invocation:** Called by the Orchestrator after code review and before the release gate. Calls no one. User-invocable: **yes**.

---

## Adoption Notes for Teams

1. **Minimum viable roster.** If you must start smaller, the irreducible core is: Orchestrator (01), Requirements Analyst (02), Solution Designer (04), Backend Implementer (13), Frontend Builder (14), Validation & Test Engineer (17), Code Reviewer (18). Every agent you omit becomes an implicit responsibility of one of these — make that assignment explicit in the absorbing agent's file rather than letting it happen silently.
2. **Author/reviewer pairs are non-negotiable.** Solution Designer ↔ Architecture Guardian and Implementers ↔ Code Reviewer must remain separate agents. An agent that reviews its own output is a rubber stamp.
3. **Specialists recommend, the Orchestrator routes.** No specialist invokes another specialist directly; each ends its handoff with a recommended next agent, and the Orchestrator decides. This keeps the call graph a star, not a web, and makes runs auditable.
4. **Terminal access is the privilege to watch.** `E+T` agents can run anything; constrain them in their agent files to project-local commands (tests, builds, generators, migrations against local databases) and forbid network-mutating or environment-mutating commands outside their boundary.
5. **The packet is upstream of everything.** When any agent cannot trace a decision back to a packet section or an approved design document, the correct move is a blocking question routed to the human — never a guess.
