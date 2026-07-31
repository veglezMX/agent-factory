---
description: Summarise where an agents-factory delivery run stands — phase, last handoff, gate status, open risks and questions, and the next playbook step. Read-only.
argument-hint: <run-id>   e.g. 2026-06-comedor-vecinal
allowed-tools: Read, Grep, Glob, Bash
---

Report the current state of delivery run **$1** by reading its workspace. This command is
strictly **read-only**: do not write, edit, or create any file, and do not dispatch any agent.
It answers "where does this run stand and what is next", nothing more.

Follow the `resuming-a-run` skill. The workspace is the truth — do not use chat history or
recollection as a source, and where `state.md` disagrees with the handoff files, the handoffs
win (they are append-only; `state.md` is a hand-maintained digest that can lag).

If `runs/$1/` does not exist, list the run directories that do and stop.

## What to read

1. `runs/$1/state.md` — the digest. Treat as a claim to verify.
2. `runs/$1/handoffs/` — the highest-numbered file in full; earlier ones only as needed to find
   the boundary between finished and unfinished work.
3. `runs/$1/gates/` — every record's `decision`, `approver`, and `conditions`.
4. `runs/$1/00-packet/` — the case and the approver named in §16.
5. `process/playbooks/<case>.md` — locate the current position in **Run at a glance**.
6. The run's artifact directories, to confirm that steps reported as done actually produced
   their canonical outputs.

## What to report

Lead with the answer, then the evidence.

1. **Status line** — case, phase, and one of: *awaiting gate N*, *in progress at step X*,
   *blocked on <blocker>*, or *closed*.
2. **Next step** — the next playbook step and the agent it belongs to. If a conditional step is
   next, say whether its condition holds. If the run is at a gate, say that no step proceeds
   until the record is signed, and point at the `conducting-a-gate` skill.
3. **Last handoff** — number, `from` → `to`, `status`, and what it produced.
4. **Gates** — each record with its decision and approver; name any gate the playbook expects
   at this point that has no record.
5. **Open risks** — every non-terminal risk ID with severity and current text.
6. **Open questions** — every unanswered one; these are human-blocked by definition.
7. **Discrepancies** — anything that does not reconcile. Report these explicitly rather than
   smoothing them over:
   - `status: complete` with no verification commands and results
   - `status: blocked` with neither an open question nor a `next_recommended`
   - a step reported done whose canonical artifact is missing
   - a risk ID that appears in no later handoff
   - a rejected gate with no follow-up handoff
   - `state.md` contradicting the handoff sequence
8. **Closure check** — if the run looks finished, evaluate all four §6.1 criteria explicitly and
   state whether a new run may open.

Be concise and factual. Cite paths, not summaries. If something cannot be determined from the
workspace, say so and name the artifact that should have contained it — a gap in the record is
a finding, not something to fill in by inference.
