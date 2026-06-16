# Proposal: File-Per-Agent Advisory Pipeline

**Status:** Draft for review (supersedes the in-memory draft)
**Author:** generated for `contact@veglez.com`
**Date:** 2026-06-16
**Scope:** A second, lightweight way to run the roster for **advisory/review** work on an
existing codebase. An orchestrator routes read-only agents and carries each handoff as a
**file on disk** — one output file per agent — so the next logical agent reads its
predecessor's file instead of the orchestrator holding everything in context. The existing
file-based delivery run (`run-delivery`, `runs/<run-id>/`) is untouched.

---

## 1. Why not in-memory

The first draft proposed carrying handoffs in the orchestrator's context window. That is
the wrong default for two reasons:

1. **It forces the orchestrator to hold every token.** Each agent's output stays resident
   in the conversation for the rest of the run. A chain of even a few analysts blows the
   context budget the protocol's §5 was written to protect — and it does so *unavoidably*,
   because the conversation **is** the storage.
2. **Subagent returns are not clean across harnesses.** The in-memory design assumed the
   Task tool returns *only* the agent's final answer. Some harnesses do; **many leak the
   subagent's entire working context back into the main conversation**, tainting the
   orchestrator with reasoning, tool output, and intermediate chatter the orchestrator
   never needed. The orchestrator's context degrades with every dispatch.

**Files fix both.** If an agent writes its conclusion to a file and the orchestrator only
ever passes *file paths* to the next agent, then:

- the orchestrator carries **paths, not payloads** — its context stays small and stable
  regardless of how many agents run or how verbose each one is;
- whatever a harness leaks back from a subagent is irrelevant, because the **file** is the
  source of truth, not the return value;
- the run is **durable and inspectable** — you can open `agents-run/.../security-engineer-output.md`
  and read exactly what that agent concluded.

The handoff medium becomes the filesystem. The orchestrator's job shrinks to routing and
path-passing.

---

## 2. The model

```
agents-run/
└── orchestrator-<query-id>/          ← one folder per orchestrated run
    ├── requirements-analyst-output.md
    ├── architecture-guardian-output.md
    ├── security-engineer-output.md
    └── code-reviewer-output.md
```

- `<query-id>` is a short slug derived from the user's request (e.g.
  `orchestrator-auth-review-0616`) so a folder is self-describing and runs don't collide.
- **One output file per agent**, named `<agent-name>-output.md`.
- The folder is created by the orchestrator at the start of a run and is the **only** place
  this pipeline writes.

### Dispatch contract

The orchestrator is the **single caller of agents.** No agent invokes another. For each
step the orchestrator injects two things into the agent's prompt:

1. **Input paths** — the output file(s) of the predecessor agent(s) this agent must read.
2. **Output path** — the exact file this agent must write its findings to
   (`agents-run/orchestrator-<query-id>/<agent-name>-output.md`).

The agent reads its inputs from disk, does its analysis, writes its findings to the
specified output path, and returns a one-line "done, wrote `<path>`" confirmation. The
orchestrator never depends on the *content* of that return — only that the file now exists.

```
orchestrator                                    agent (Task subagent)
   │  prompt: "read <prev>-output.md;            │  reads input file(s) from disk
   │           write your findings to  ─────────▶│  analyzes
   │           <this-agent>-output.md"           │  writes <this-agent>-output.md
   │  return: "done: wrote <path>"  ◀────────────│  returns one-line confirmation
   │  (context cost ≈ one path, not the payload)
   │  next step: passes <this-agent>-output.md
   │             as input to the next agent
```

---

## 3. Orchestrated vs. direct invocation

This is the key distinction that keeps the design simple:

| Mode | Who calls | Writes a file? | Why |
|---|---|---|---|
| **Orchestrated** | The orchestrator dispatches a chain | **Yes** — each agent writes its `*-output.md` | Files are the handoff medium *between* agents; the next agent needs to read the last one. |
| **Direct** | The user invokes one agent themselves | **No** — the agent just answers | There is no "next agent" to hand off to, so there is nothing to persist. The deliverable is the answer in the user's session. |

So the file-writing behavior is **not** baked into the agents as an always-on rule. It is
**triggered by the orchestrator's prompt.** When the orchestrator dispatches an agent, it
tells it where to read and where to write. When a user invokes the same agent directly,
no output path is supplied, and the agent behaves exactly as it does today — it answers in
the conversation and writes nothing.

This means **the agent definitions need no hard fork.** The same agent supports both modes;
the difference is entirely in whether an output-path instruction is present in its prompt.

---

## 4. Scope — advisory/review agents only

Unchanged from the prior discussion, and it fits this model naturally. In scope are the
read-only / review-mode agents whose output is *findings*, not product code:

- **Read-only reviewers:** `06 bundle-intake-validator`, `08 architecture-guardian`,
  `18 code-reviewer`, `22 infrastructure-guardian`, plus `07 product-planner`.
- **Analyst:** `02 requirements-analyst` (analysis mode, fed the subject repo/description
  rather than a frozen packet).
- **Review-mode cross-cutting:** `15 security-engineer`, `26 privacy-compliance-officer`,
  `27 accessibility-auditor` — **review mode only**, never `mode: edit`.

The implementer agents stay out of scope: their artifacts are the product itself, which is
a different machinery (`run-delivery` / `runs/`). The one nuance worth noting: most of
these advisory agents *already* have `Edit`/`Write` in their tool posture for their
edit-mode duties. In this pipeline they use that write capability for exactly one thing —
writing their own `*-output.md` to the run folder — and nothing else. The orchestrator's
prompt makes that boundary explicit.

---

## 5. How this differs from `runs/` (the existing delivery machinery)

This is deliberately **not** a second copy of the full handoff protocol. Differences:

| | `runs/<run-id>/` (delivery) | `agents-run/orchestrator-<id>/` (advisory) |
|---|---|---|
| Purpose | Build & ship software | Analyze & review existing code |
| Files | packet, requirements, bundle, handoffs, gates, state | one `*-output.md` per agent |
| Handoff format | full §2 YAML payload + body sections | a findings document (lighter; see §6) |
| State | `state.md` digest + append-only handoffs | the set of output files; no separate state file |
| Gates | human sign-off recorded in `gates/` | one interactive acceptance checkpoint, no file |
| Canonical promotion | yes (to `docs/`) | none — findings stay in the run folder |
| Replay | full, from disk | partial — re-read any agent's output file |

The separate top-level folder (`agents-run/` vs `runs/`) keeps the two from being confused
and lets a project `.gitignore` the advisory runs if they're throwaway, while keeping
delivery `runs/` in the repo.

---

## 6. Output file format

Each `*-output.md` is a self-contained findings document so the next agent (or a human) can
consume it cold. Proposed minimal structure, reusing the handoff protocol's vocabulary:

```markdown
---
agent: security-engineer
run: orchestrator-auth-review-0616
inputs: [architecture-guardian-output.md]      # files this agent read
status: complete                                # complete | blocked
---

## Summary
<2–4 sentence headline of what this agent found>

## Findings
- <finding, with a citation to a file:line or to an input finding's id>

## Risks
- [id] <risk, severity, why it matters>          # carried forward, never silently dropped

## Open questions
- <anything the next agent or the human must resolve>

## Recommended next
<which agent should run next and why — advisory only; orchestrator decides>
```

`inputs` lists the predecessor files (traceability). Findings cite their source — either a
`file:line` in the subject repo or the id of an upstream finding — preserving the protocol's
*decisions-cite-sources* rule. Risks accumulate down the chain; an agent may add or
re-assess but not silently delete an upstream risk.

---

## 7. Gates

One interactive acceptance checkpoint at the end, via `AskUserQuestion`: the orchestrator
presents the synthesized findings (assembled from the output files, not from its own
memory of them) and asks the user to accept. No gate file. Modeled on the `spike` case's
findings/decision gate — terminate on acceptance, no canonical promotion.

---

## 8. Proposed deliverables (if approved)

1. **An orchestrator driver** — `commands/run-advisory.md` (working name), sibling to
   `run-delivery.md`, that:
   - derives `<query-id>` and creates `agents-run/orchestrator-<query-id>/`;
   - selects the advisory agents and order (from the user's list, a mini-playbook, or
     inference);
   - for each step, dispatches one agent via `Task` with **input path(s) + output path** in
     the prompt;
   - keeps only paths and a short progress note in context — never the payloads;
   - ends with one `AskUserQuestion` acceptance checkpoint and a synthesized summary.
2. **A one-page "advisory output file" convention** — §6, either an appendix to the handoff
   protocol or a sibling doc.
3. **(Optional) advisory mini-playbooks** — common chains (e.g. brownfield review:
   requirements-analyst → architecture-guardian → security-engineer → code-reviewer).

The agent files need **no hard changes** for v1 — the read-input/write-output instruction
is supplied by the orchestrator at dispatch time (§3), and direct invocation is unaffected.

---

## 9. Open questions for the reviewer

1. **`<query-id>` generation** — orchestrator-derived slug, a timestamp, or user-supplied?
   And should `agents-run/` be git-ignored by default (throwaway) or committed?
2. **Re-running the same agent in one run** — if an agent must run twice (e.g. a re-review
   after another agent's findings), `<agent-name>-output.md` collides. Add a sequence
   prefix (`02-security-engineer-output.md`), or allow overwrite, or disallow re-runs in
   v1?
3. **Subject input** — does the orchestrator point agents at the real target repo (their
   read-only tools read actual files), or only at a pasted description? Reading real files
   is far more useful and is the natural fit for these read-only agents.
4. **Driver scope** — Claude Code `commands/` only for v1, or author it as a portable
   roster concept first (so Copilot/Cursor get it via the converter)?
5. **Write-boundary enforcement** — is the orchestrator's prompt instruction ("write only
   your one output file") enough, or do we want a harder guard so an advisory agent can't
   accidentally write into the subject repo?
