# Proposal: In-Memory Advisory Pipeline (no artifacts)

**Status:** Draft for review
**Author:** generated for `contact@veglez.com`
**Date:** 2026-06-16
**Scope:** A second way to run the roster — an orchestrator that routes advisory/review
agents and carries handoffs **in its own context** instead of writing files to
`runs/<run-id>/`. No run workspace, no handoff files, no gate records, no canonical
promotion. The existing file-based delivery run (`run-delivery`) is untouched.

---

## 1. Motivation

The framework today is built for **building software**: a 28-agent greenfield pipeline
that produces a deployed application, with every step durably recorded under
`runs/<run-id>/`. That durability is essential when implementers are writing code that
must survive across cold sessions and human gates.

But there is a second, lighter use case the roster already serves well and the current
machinery makes heavier than it needs to be:

> *"I have an existing codebase. I want a chain of specialists to analyze and review it
> and hand their conclusions to the next logical specialist — but I don't want a run
> workspace full of artifacts. Just give me the orchestrated analysis."*

For this use case the deliverable **is the conversation**: a sequence of findings, each
informed by the last. Nothing needs to persist to disk because nothing is being built.
Writing handoff files, `state.md`, and gate records adds ceremony without adding value,
and forces the user to clean up a `runs/` directory they never wanted.

This proposal adds an **in-memory advisory pipeline** for exactly that case.

---

## 2. What stays the same

The four guarantees of the handoff protocol (`agent-handoff-protocol.md`) split cleanly:

| Guarantee | File-dependent? | In this pipeline |
|---|---|---|
| **Traceability** — decisions cite their source | No | **Kept.** Citations travel inline in the handoff payload. |
| **Containment** — agents stay inside their boundary | No | **Kept.** Tool postures are unchanged; advisory agents are read-only by nature. |
| **Statelessness** — agent reconstructs from disk | **Yes** | **Inverted** (see §4). The orchestrator's context is the state. |
| **Auditability** — replay a run from files | **Yes** | **Dropped by design.** The audit trail is the session transcript only. |

Also unchanged:

- **The agent roster.** The same specialists, same scopes, same boundaries.
- **The orchestrator-as-main-loop pattern.** Only the main session can route between
  subagents (`README.md` Limitations), so the orchestrator is still the driver.
- **The handoff *schema*.** The §2 YAML-frontmatter-plus-body format is reused verbatim
  as the in-memory message format — see §5.
- **The routing knowledge.** Playbooks still describe which agents run and in what order.

---

## 3. Agent scope — advisory/review only

A "no-artifact" pipeline is, by definition, a pipeline of agents whose output is **text,
not files**. The implementer agents (`09 foundation` … `14 frontend`, `16`, `19`, `21`,
`23`, `25`, `28`) exist *to write code or config* — their artifacts are the product, so
"implementer without artifacts" is a contradiction. They are **out of scope** for this
pipeline.

In scope are the agents that already produce findings/reports rather than files:

| Posture | Agents | Change needed |
|---|---|---|
| **`R`** read-only reviewers | `06 bundle-intake-validator`, `07 product-planner`, `08 architecture-guardian`, `18 code-reviewer`, `22 infrastructure-guardian` | None to their behavior; they already report rather than write. |
| **`R`** analysts | `02 requirements-analyst` (analysis mode) | Runs from supplied context instead of a frozen packet file. |
| **Review-mode** cross-cutting | `15 security-engineer`, `26 privacy-compliance-officer`, `27 accessibility-auditor` — **review mode only** | Already default to read-only; `mode: edit` is explicitly excluded here. |

These agents need at most a small framing change (§6), not new behavior.

---

## 4. The core change: context is the transport

### Today (file-based)

```
orchestrator                          specialist
    │  writes handoffs/NNNN-…md  ─────────▶ reads handoffs/NNNN-…md
    │                                        reads inputs/* from disk
    │                                        reads state.md
    │  reads handoffs/NNNN-…md  ◀───────── writes handoffs/NNNN-…md
    │  writes state.md
```

### Proposed (in-memory)

```
orchestrator                          specialist (Task subagent)
    │  handoff payload IN the prompt ─────▶ reads the payload from its prompt
    │                                        (no disk reads — gets all context inline)
    │  payload as the Task return ◀──────── returns the handoff payload as its
    │  held in orchestrator context          final message
    │  digest folded into running state
```

The Task tool **already returns the subagent's final message to the orchestrator in
memory** — `run-delivery` relies on this (*"the agent… returns its closing handoff
content"*). The only real change is that the orchestrator (a) injects the inbound handoff
into the prompt instead of writing a file, and (b) keeps the return in context instead of
writing it to a file. The transport flips from *filesystem* to *context window*; the
payload format is identical.

**State lives in the orchestrator's context.** There is no `state.md`. The orchestrator
maintains a running digest in-context: current step, the chain of handoffs so far
(summarized), open risks by id, and open questions.

---

## 5. In-memory handoff payload

Reuse `agent-handoff-protocol.md` §2 with three redefinitions:

1. **`inputs` / `outputs` are inline, not paths.** Today they are file paths. Here, an
   agent's *output* **is** the handoff body it returns; its *inputs* are summarized in the
   inbound payload's context summary (plus any read-only file paths in the target repo it
   was pointed at — reading the subject codebase is allowed; writing the run workspace is
   not).
2. **`run` is optional / ephemeral.** No `runs/<run-id>/` exists. A short label may be
   carried for the orchestrator's own bookkeeping, but it references nothing on disk.
3. **`gate_impact` becomes an interactive pause, not a file.** See §7.

Everything else — `from`, `to`, `status`, `decisions`, `risks`, `open_questions`,
`next_recommended`, and the §2.2 body sections — is unchanged. The §2.3 hard rules still
apply (*no handoff no work*, *complete requires verification*, *blocked names the blocker*,
*decisions cite sources*, *risks are never deleted within the session*).

---

## 6. Agent framing change

The only edit to agents is to reinterpret two protocol lines for context-fed operation.
This is best done as a **mode note** the orchestrator includes in each dispatch, so the
agent files themselves need not fork:

- *"No handoff, no work"* still holds — but **"handoff" means the structured payload in my
  prompt**, not a file on disk. The agent refuses if its prompt contains no valid handoff.
- *"Reads only: inbound handoff, listed inputs, state.md"* becomes **"Reads only: the
  inbound handoff payload in my prompt, and any read-only paths it names in the subject
  repo."** No `state.md`, no run workspace.
- *"Ends by writing a handoff file"* becomes **"Ends by returning the handoff payload as my
  final message."**

Because the in-scope agents are all read-only, the *Containment* guarantee needs no
enforcement work — none of them can write artifacts in the first place.

---

## 7. Gates without files

Standard runs record a human decision in `gates/`. With no filesystem, a gate becomes an
**interactive checkpoint**: the orchestrator pauses, presents the assembled evidence via
`AskUserQuestion`, and holds the decision in context. For an advisory pipeline most cases
need at most one terminal "do you accept these findings?" checkpoint — closest to the
`spike` case's **findings/decision gate** (`agent-handoff-protocol.md` §3.4), which
already terminates on `decision: accepted` rather than a deployment and performs **no
canonical promotion**. That is the right model here: the pipeline ends in an accepted set
of findings, nothing is promoted to `docs/`.

---

## 8. The tradeoff to accept up front

The orchestrator becomes the **single stateful component and the context-window ceiling.**
The protocol's §5 *Context Budget* discipline existed precisely so a long run would not
drown in its own history — and it leaned on files (`state.md` as a digest, fresh sessions,
the 30-line summary) to do it. With no files, the orchestrator must carry that weight in
context, so this pipeline:

- **Has no durability.** If the session ends, the run is gone — there is no `state.md` to
  resume from. Acceptable because nothing was being built.
- **Cannot be replayed from disk.** The audit trail is the transcript only.
- **Has a length ceiling.** Every agent return the orchestrator keeps consumes context.
  Mitigation: the orchestrator must **distill each return into a compact digest before
  moving to the next agent** — even more aggressively than §5 requires — carrying forward
  decisions, open risks, and open questions, not full bodies.

These constraints make the in-memory pipeline a fit for **short advisory chains** (a
handful of agents), not for the full build roster. That aligns exactly with the intended
use case.

---

## 9. Proposed deliverables (if approved)

1. **A new orchestrator driver** — e.g. `commands/run-pipeline.md` (sibling to
   `run-delivery.md`) that:
   - takes a subject description / repo pointer and an optional ordered agent list;
   - selects advisory agents and an order (from a playbook or the user's list);
   - dispatches each via `Task`, injecting the inbound handoff in the prompt;
   - keeps a compact in-context digest; routes findings to the next logical agent;
   - ends with one `AskUserQuestion` acceptance checkpoint and a synthesized summary;
   - **writes nothing to disk.**
2. **A short in-memory handoff convention** — one page, either folded into the handoff
   protocol as an appendix or kept beside this proposal, codifying §5–§6.
3. **(Optional) an advisory mini-playbook** — "which advisory agents, in what order" for
   common chains (e.g. brownfield review: requirements-analyst → architecture-guardian →
   security-engineer → code-reviewer), mirroring the `playbooks/` schema.

No changes to existing agent files are strictly required for v1; the framing note (§6) is
carried by the orchestrator at dispatch time.

---

## 10. Open questions for the reviewer

1. **Driver naming/placement** — `run-pipeline`? `advise`? `review-chain`? And does it
   live in `commands/` (Claude Code) only for v1, or should it be authored as a roster
   concept first (portable across harnesses)?
2. **Agent order** — fixed mini-playbooks, or always user-supplied order, or orchestrator
   infers order from the request?
3. **Subject input** — does the pipeline read the target repo directly (advisory agents
   point their read-only tools at real files), or work only from a description the user
   pastes in? Reading real files is more useful but means the agents *do* touch the
   filesystem (read-only) even though they write nothing.
4. **Findings output** — pure in-chat, or allow an opt-in "write me one summary file at the
   end" escape hatch (which would technically be one artifact)?
