# Using the roster for review: orchestrator mode vs. single-agent run

The roster's advisory/review agents (the read-only reviewers and review-mode specialists)
can be used two ways. Pick by how many agents the job needs and whether their findings must
feed each other.

> **This is the advisory path** — analyzing and reviewing existing code. It is separate from
> a full **delivery run** (`run-delivery` / `runs/`), which builds and ships software. See
> [`proposals/advisory-pipeline.md`](proposals/advisory-pipeline.md) for the design and the
> locked decisions behind this document.

---

## At a glance

| | **Single-agent run** | **Orchestrator mode** |
|---|---|---|
| What it is | You invoke one advisory agent directly | The orchestrator dispatches a chain of advisory agents |
| When to use | One question, one specialist | A review that needs several specialists, each building on the last |
| Who calls the agent | You | The orchestrator (the **only** caller) |
| Files written | **None** — the agent answers in your session | One `*-output.md` per agent under `agents-run/orchestrator-<query-id>/` |
| Where the answer lives | Your conversation | The output files (+ a final synthesized summary) |
| Context cost | One agent's output, once | Flat — the orchestrator carries **file paths, not payloads** |
| Durability | Ephemeral (lives in the chat) | On disk for the run; `agents-run/` is git-ignored by default |
| Hand-off between agents | n/a | Each agent reads its predecessor's output file |

Rule of thumb: **one specialist → single-agent run. A chain that hands off → orchestrator mode.**

---

## Single-agent run

Use this when you want exactly one specialist's read on something and there is no "next
agent" to hand the result to. The agent reads what it needs, answers in your conversation,
and **writes no file** — there is nothing to persist because nothing downstream consumes it.

**How:**

- **Claude Code:** invoke the agent directly, e.g. ask for the `security-engineer` (or
  `code-reviewer`, `architecture-guardian`, …) and point it at the code in question.
- **Other harnesses:** invoke the agent by its native name per
  [PORTABILITY.md](../PORTABILITY.md).

**You get:** the agent's findings in the session. Copy them where you like; nothing lands in
`agents-run/`.

**Good for:**

- "Does this auth change leak anything?" → `security-engineer`
- "Review this diff for maintainability." → `code-reviewer`
- "Does this violate our layering?" → `architecture-guardian`
- "Is this IaC least-privilege?" → `infrastructure-guardian`

If you find yourself running a second agent on the *output* of the first, stop — that is
orchestrator mode, and it will manage the hand-off for you.

---

## Orchestrator mode

Use this when a review needs several specialists **and each one should build on the previous
one's findings** — e.g. an architecture read informs the security read, which informs the
final code review. The orchestrator is the only thing that calls agents; it carries the
hand-off between them as files so its own context stays small no matter how long the chain.

**How (Claude Code, v1):** start the advisory driver (`run-advisory`) and describe the
review you want, optionally naming the agents and order. The orchestrator then:

1. Derives a `<query-id>` from your request (you may override it) and creates
   `agents-run/orchestrator-<query-id>/`.
2. For each step, dispatches one agent with two things in its prompt: the **input file
   path(s)** to read (the previous agents' outputs) and the **output file path** for its
   findings (`<agent-name>-output.md`).
3. The agent reads the real target code (read-only) plus its input files and produces its
   findings. Write-capable review agents write their own output file; the strictly
   read-only reviewers (which have no write tool, by design) return their findings and the
   orchestrator writes the file for them. Either way the findings land in the file.
4. The orchestrator passes that file's path to the next agent, and so on.
5. At the end it presents the synthesized findings and asks you to **accept** (one
   interactive checkpoint — no gate file).

**What lands on disk:**

```
agents-run/
└── orchestrator-auth-review-0616/
    ├── requirements-analyst-output.md
    ├── architecture-guardian-output.md
    ├── security-engineer-output.md
    └── code-reviewer-output.md
```

Each `*-output.md` is a self-contained findings document (summary, findings with
`file:line` citations, risks, open questions, recommended next agent). You can open any of
them directly — they are the source of truth, not the orchestrator's memory of them.

**Good for:**

- A brownfield review chain: `requirements-analyst → architecture-guardian →
  security-engineer → code-reviewer`.
- Any review where a later specialist needs an earlier one's conclusions in writing.

---

## Things to know

- **`agents-run/` is git-ignored by default.** Advisory runs are throwaway. To keep one,
  commit its folder deliberately.
- **Re-running an agent in the same run** doesn't overwrite: the first run is
  `<agent-name>-output.md`, a re-run is `<agent-name>-output-2.md` (then `-3`, …). The
  orchestrator feeds the latest one downstream.
- **The subject repo is read-only.** Advisory agents read real files but write only their
  one output file in `agents-run/`. They never modify the code under review.
- **Agents need no special setup for either mode.** The same agent works directly or under
  the orchestrator; the only difference is whether the orchestrator handed it an output
  path. Invoke it yourself → no file. Let the orchestrator dispatch it → it writes its file.
- **This is not a delivery run.** If the goal is to *build* something (write code, run a
  full greenfield/defect/refactor case), use `run-delivery` and the `runs/` machinery
  instead — see the [README](../README.md) and
  [agent-handoff-protocol.md](agent-handoff-protocol.md).
