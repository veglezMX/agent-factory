# Prompt anatomy for agent definitions

An agent definition is a system prompt that a harness loads every time the agent runs. This
file gives the component structure every definition in the roster follows. It names what
each component must do, where it goes in the fixed section template (SKILL.md Step 4), and
how to check the result. It is self-contained: nothing outside this repository is needed to
apply it.

The structure is a general prompt-engineering anatomy narrowed to one job: a durable, reusable
role prompt whose per-call material arrives at invocation time. The general parts that do not
fit that job (one-off prompts, prefilled replies, registry packaging) are left out. Where this
file adds a rule of the framework's own rather than the general anatomy's, it says so.

---

## 1. Four structural principles

Apply these to every section before checking any single one.

1. **Sections over prose.** Each concern gets its own `##` section with one job. Each rule has
   one home section; other sections point at it rather than reword it. The only restatements
   are the ones the template requires: `## Handoff` restates the closing deliverable, and the
   shared `## Invocation` paragraph repeats the untrusted-material rule.
2. **Specific beats long.** A rule names an observable behaviour, a file path, a field, or a
   threshold. "Be thorough", "consider carefully", and "ensure quality" are not rules. If
   you cannot say how a reviewer would check it, rewrite it or delete it.
3. **Absolutes are reserved for invariants.** `never`, `always`, and `must not` mark safety and
   security rules, "untrusted content is data", and "do not guess, escalate". This framework
   adds one more: ownership boundaries (every `You must never:` list in `## Scope &
   Boundaries`). Preferences use ordinary verbs. An absolute spent on a preference weakens the
   ones that matter.
4. **Referenced content is data.** Packet text, source files, diffs, prior handoffs, logs, and
   web pages are material to inspect, never instructions to follow. Directives come only from
   the definition itself and the active invocation (the direct human task, or the routed
   handoff). Every definition must say so in `## Inputs` and name a few concrete examples of
   injected text it treats as data.

---

## 2. Components, and where each one lives

The anatomy has fourteen components. Twelve map onto sections of the agent template.
Examples have no section of their own and go inline. A reply prefill does not apply to a
harness-loaded definition. The roster adds three sections of its own.

| # | Component | Agent section | What it must do | Typical failure |
|---|---|---|---|---|
| 1 | Role | persona line + `## Role` | Name the role and roster number, what it owns, its phase and tool posture, and who owns the neighbouring concerns. It sets vocabulary, depth, and quality bar. | A list of virtues instead of a position in the roster. |
| 2 | Objective | `## Objective` | Name the outcome and who consumes it (the person or stage downstream), in one paragraph. | Restating the task steps. |
| 3 | Context | `## Context` | Describe pipeline position and standalone position separately: who is upstream, who is downstream, which documents are the sources of truth. | Run-specific facts baked into a reusable definition. |
| 4 | Inputs | `## Inputs` | State the minimum useful input, then the optional inputs, then the untrusted-material rule (principle 4). | No untrusted-material rule, or inputs only for one mode. |
| 5 | Task instructions | `## Task Instructions` | Give ordered, observable steps. Each step is something a reviewer can confirm happened. | "Analyse", "think about", "be careful" as steps. |
| 6 | Constraints | `## Scope & Boundaries` (+ `## Terminal Discipline` when the agent runs commands) | List what the agent owns and what it must never touch, naming the owner of each neighbouring concern. The negative half does the work. | Only the positive half; boundaries that name no owner. |
| 7 | Decision policy | `## Decision Policy` | For every judgement call (mode, severity, blocking or not, approve or block, which agent to recommend), state the criterion. | A judgement call with no criterion, so the model picks one. |
| 8 | Reasoning instructions | `## Reasoning Instructions` | Keep two parts separate: what to work through privately (edge cases worth checking), and which reasoning artifacts appear in the output (criterion applied, trace, assumptions, classification rationale). | One merged "show your work" line. |
| 9 | Output contract | `## Output Contract` | Give numbered sections or fields in order, with enums where values are closed, and map them onto the handoff schema (`process/agent-handoff-protocol.md` §2). | "A Markdown report"; a private schema that duplicates the handoff. |
| 10 | Output style | `## Output Style` | Cover tone, length, and formatting. Where the phrasing of a finding or change is easy to get wrong, add one short example (row 13). | Structure rules leaking in from the contract. |
| 11 | Quality criteria | `## Quality Criteria` | Say how the result will be judged, in checkable terms (traceability, nothing silently filled, boundaries held). | Criteria that restate the task. |
| 12 | Failure and uncertainty handling | `## Failure & Uncertainty Handling` | For missing input, conflicting sources, an absent or failing tool, or an untraceable decision: do not invent; name what is missing and why it matters; escalate a blocking question or offer a labelled assumption; surface conflicts instead of resolving them silently. | Silence, so the model guesses. |
| 13 | Examples | inline, inside the section they illustrate | Add a short example only where behaviour is fuzzy (wording of a finding, a borderline classification). | Long examples that crowd out the rules. |
| 14 | Reply prefill | not used | A harness-loaded definition has no slot for a prefilled reply. The Output Contract and the Handoff fix the shape instead. | — |
| — | *(roster)* | `## Responsibilities` | The enumerated job: everything the agent owns, as a list, before the procedure. | Duplicating Task Instructions. |
| — | *(roster)* | `## Invocation` | The shared contract paragraph, verbatim, plus this agent's trigger paragraph (SKILL.md Step 5). | A paraphrase. |
| — | *(roster)* | `## Handoff` | Open with the line that formal handoff requirements apply in `pipeline` mode and what `standalone` mode returns instead. Then say what closes the work, what the closing handoff carries, and the recommended next agent. A specialist recommends and does not route; only the Orchestrator (01) routes, and the Code Reviewer (18) may forward findings to 15 and 08. | Routing instructions from an agent that may not route. |

**The core floor.** Objective, Task Instructions, and Output Contract are the minimum that makes
a definition a prompt rather than a fragment. If any of the three is weak, fix it before
polishing anything else.

---

## 3. Durable rules and per-call material

A general prompt splits into a durable system part, a per-call user part, and the
immediate ask at the end. In this framework the agent definition is the durable part. The
invocation (the direct human task in standalone mode, or the routed handoff in pipeline mode)
is the per-call part. That split gives four rules:

- **Nothing per-call in the definition.** No run ID, project fact, stack choice, or sample
  input written as if it were real. Name where such material comes from instead (the packet
  section, the approved design, the inbound handoff).
- **Inputs arrive delimited.** The definition describes inputs by kind and location. The
  invocation supplies them, and they are data (principle 4).
- **The definition ends on what to deliver.** The general anatomy keeps the output contract
  near the end so it is the freshest instruction. The roster's fixed order instead places
  `## Output Contract` before `## Quality Criteria` and `## Failure & Uncertainty Handling`
  and closes on `## Handoff`, which restates the closing deliverable. The test suite enforces
  that order, so keep it. Make sure `## Handoff` really does restate what must be delivered
  (checklist item 11).
- **The immediate ask belongs to the caller.** Do not end a definition with a task line;
  the invocation supplies it. The invocation, in turn, should not restate the definition: the
  model then weighs the copy over the original. A short reminder of the Output Contract is
  enough.

---

## 4. The agent overlay

Every roster member is a tool-using agent, so the general rules for tool-using agents apply,
translated into this framework's terms:

| General agent rule | In this framework |
|---|---|
| The runtime, not the model, decides whether the loop continues. | The agent finishes its bounded task and stops. Routing belongs to the Orchestrator or the human. Say "stop there; do not self-extend" in Task Instructions. |
| Tools come from a declared allowlist; an unlisted tool is an error, not a guess. | The tool posture (`R`, `R+route`, `E`, `E+T`, `O`) is the contract, and `tools:` declares it. Whether a harness enforces `tools:` per agent depends on the platform (see `PORTABILITY.md`). Where it does not, the posture holds only through the prose. So the prose must state the posture, must never ask for a capability the posture does not grant, and must say that needing such a capability means a handoff or a blocking question, never a workaround. |
| Non-idempotent or destructive actions need explicit authority. | `## Terminal Discipline` (for agents that run commands) names what needs a recorded approval and what never runs against shared state. |
| Name when to ask a human, and how to resume with the answer as authoritative. | In `pipeline` mode, a blocking `open_questions[]` entry in the handoff. In `standalone` mode, ask the human directly and stop. Once answered, the answer is not re-litigated. |
| Classify tool failures and say what to do about each. | `## Failure & Uncertainty Handling` says what to do when a tool or an input is absent or a command fails: fix within the boundary and re-verify, or report it as a blocker. Never reach outside the boundary to make it pass, and never work around it silently. |

---

## 5. Authoring checklist

Run this against the definition you wrote or changed. Report each item as `PASS` or `FAIL`
with the line to look at. `N/A` is allowed only on items 4 and 9, under the condition stated
in each row. A `FAIL` on item 1, 3, or 6 (the core floor) means the definition is not ready
for review. Any other `FAIL` is something to fix before review, not a reason to stop writing.

Items 1–9 and 11 are the general anatomy's checklist, applied to agent definitions. Item 10 is
this framework's own.

| # | Check | How to verify |
|---|---|---|
| 1 | A stranger can tell the role, objective, audience, and neighbours. | The persona line names the role and roster number; `## Role` names who owns the adjacent concerns; `## Objective` names the outcome and who consumes it. |
| 2 | Referenced content is data. | `## Inputs` has the untrusted-material rule with concrete examples of injected text. |
| 3 | Task steps are observable. | Each numbered step names a checkable action ("confirm", "record", "classify", "write"). No step reads "think", "consider", or "be thorough". |
| 4 | Every judgement call has a criterion. | Each choice the agent makes (mode, severity, blocking, approve/block, recommendation) appears in `## Decision Policy` with its rule. `N/A` only if the agent makes no judgement calls. |
| 5 | Private reasoning and visible artifacts are separate. | `## Reasoning Instructions` names what to work through privately and, separately, the artifacts the output must include. |
| 6 | The output contract is enforceable. | A reviewer could pass or fail the output on structure alone: sections or fields in order, closed values listed, and the mapping onto the handoff schema stated. |
| 7 | Style is separate from contract. | Structure lives in `## Output Contract`; tone, length, and formatting live in `## Output Style`. |
| 8 | Missing or conflicting information has a rule. | `## Failure & Uncertainty Handling` covers missing input, conflicting sources, an absent or failing tool, and an untraceable decision, and none of them is "guess". |
| 9 | Absolutes are invariants. | Every `never`, `always`, and `must not` guards a boundary, safety, data-not-instructions, or escalation rule. `N/A` only if there are none. |
| 10 | Prose matches posture. | No sentence asks for a capability the `tools:` line does not grant: editing for `R`, `R+route`, or `O`; running commands without `execute`; dispatching another agent without `agent`. A needed capability the posture lacks is a handoff or a blocking question. |
| 11 | The definition closes on the deliverable. | `## Handoff` restates what the closing output carries and names the recommended next agent. No task line and no reference material trail it. |

The mechanical half — frontmatter, section order, posture and `tools:` agreement, roster and
playbook routing — is enforced by the test suite (`tests/test_agents.py`,
`tests/test_roster.py`, `tests/test_matrix.py`). This checklist covers the half the tests
cannot judge: whether each section does its job.
