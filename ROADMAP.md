# Roadmap

Where agents-factory goes after `0.3.0`. This is a plan, not a promise: items move when a run
or a review shows they should. Versions follow [docs/RELEASING.md](docs/RELEASING.md). Work in
progress is tracked as GitHub issues on the matching milestone. Update this page in the same
pull request that finishes or reorders an item.

## Where it stands

`0.3.0` made the repository's **text** trustworthy. A test suite and CI gates now enforce the
roster, postures, section template, playbook matrix, manifests, links, and derived
directories. Releases follow a written, automated process.

What is not proven yet is that the framework **runs**. The only reference run
(`runs/2026-06-comedor-vecinal/`) stops at Gate 2, so Phases 1–4 and the agents that own them
have never run on a real packet. No test checks that an agent behaves as its definition says.
A review of the Phase 1–4 contracts found contradictions that a real run would hit within its
first few steps. That is the work ahead.

## Guiding direction

1. **Fix a contract before running it.** A run that hits a contradiction tests whoever
   improvised around it, not the framework.
2. **Deterministic checks before model-in-the-loop checks.** Validate what lands on disk
   (handoffs, gate records, generated tool grants) first. Use live evals for what only a
   model run can show.
3. **Test the way users run it.** Prove the framework from a tagged, installed copy in a
   separate project, not from inside this repository.
4. **One definition per rule.** Shared prose stays neutral; harness details live in the
   installer and `PORTABILITY.md`.
5. **Tier before freezing.** Decide which install targets 1.0 guarantees before SemVer starts
   covering every target, flag, and path.

---

## 0.3.x — trust fixes

- [x] **No external authoring dependency.** The prompt anatomy that agent definitions follow
  now ships with the `authoring-an-agent` skill (`prompt-anatomy.md`) instead of coming from
  a separate repository. *(Unreleased.)*
- [ ] **`agents-run/` is not git-ignored in user projects.** The advisory docs say it is, but
  only this repository's `.gitignore` ignores it. Check the ignore status when `/run-advisory`
  starts, and add a rule against copying secrets into advisory output verbatim.
- [ ] **`routing-a-step` emits a status the protocol does not allow** (`dispatched`). Use one
  of the protocol's status values.
- [ ] **`/new-agent` tells the author to bump the plugin version**, which AGENTS.md rule 4
  reserves for releases. Make it add a CHANGELOG entry only.
- [ ] **One gate script** that CI, `just check`, and the AGENTS.md fallback chain all call,
  and a review rule a single maintainer can meet.
- [ ] **Wrong read-only advice in shipped text.**
  - The installer and `PORTABILITY.md` tell Hermes users to run read-only work with
    `hermes --safe-mode`. That flag is a troubleshooting switch: it does not restrict file or
    terminal tools, and it turns off the shell hooks that could.
  - The Codex advice, `codex --sandbox read-only`, still lets a human approve writes in the
    interactive CLI. The hard stop is `codex exec --sandbox read-only` (headless) or adding
    `--ask-for-approval never` (interactive).
- [ ] **Stale claim that a subagent cannot start another.** Claude Code subagents can now start
  subagents of their own, up to three levels deep. `install.sh`, `PORTABILITY.md`, and
  `/run-delivery` still say otherwise. Correct the text now; whether the Orchestrator still has
  to be the main loop is a 0.5.0 question.
- [ ] **VS Code setup in `PORTABILITY.md` is out of date.** VS Code reads `~/.copilot/agents`
  and `~/.copilot/skills` natively, which `--target copilot` already writes. The
  `chat.agentFilesLocations` / `chat.agentSkillsLocations` settings it recommends are
  deprecated.

## 0.4.0 — prove it runs

Milestone issues: [#10](https://github.com/veglezMX/agent-factory/issues/10) (one greenfield
packet end to end) and [#11](https://github.com/veglezMX/agent-factory/issues/11)
(behavioural evals).

**Before #10 starts, in order:**

1. **Who writes what in a run workspace.** The Orchestrator is the only allowed writer of
   `state.md` but has no edit tool. Several read-only agents are told their findings are
   "written to" a findings path. Handoff numbers have two allocators. One protocol rule
   should name the single writer of each file, and a test should enforce it.
2. **One definition of a passed gate.** Define pending, signed, and passed on disk, and what
   a halt looks like. Decide how "plans approved before implementation" is recorded. Greenfield
   has no plan gate today.
3. **Paths and schemas for Phases 1–4.** Give every Phase 1–4 output exactly one path. Write
   a task-bundle schema, since the Bundle Compiler is told to stop when the format is
   unspecified, and nothing specifies it. List every value downstream agents defer to "the
   approved design" in the Solution Designer's output contract.
4. **A run validator** (`tools/check_run.py`). The handoff schema is called machine-checkable,
   but nothing checks it. CI runs the validator over `runs/`, with an allowlist for the
   reference run's known gaps.
5. **Version stamp.** Record which release produced an install, and which release a new run
   started on.
6. **Amend #10 with kickoff decisions.** Run it in a separate repository from a tagged
   install, with a deliberately small packet: a handful of requirements, one integration with
   its fake built first, numeric performance budgets, and a deploy target the approver
   controls.

**Before #10 reaches Phase 4:**

7. **A release step after Gate 3**, plus the Orchestrator's closure and promotion duties.
8. **The build loop.** Plans are written per vertical slice, while `/run-delivery` walks the
   build steps per layer. Define the per-slice loop and a Phase 2 exit criterion.

**Alongside #10, for #11:**

9. **Report injected instructions.** The contract says instructions planted in inputs never
   override the definition, but no output shape has a place to report one. Add an
   `injected_instructions` field.
10. **Static grant test.** For every agent on every target, fail when the generated tool grant
    is broader than the agent's posture. Document per target what is enforced, set by a
    session flag, or prose only.
11. **Eval harness.** Scenarios assert only on disk state, with one adapter script per harness.
    Prose-only-posture targets come first. Live evals become a pre-release step.
12. **Write down the 1.0 criteria** in `docs/RELEASING.md` (see below).

### Read-only enforcement

This repository is text, so it cannot enforce a posture itself. What it can do is emit, for
each target, the strongest gate that harness offers, and say plainly where only the prose
holds. There are three layers:

| Layer | What it is | Where it exists |
|---|---|---|
| **Per-agent prevention** | The harness never gives the agent a write or shell tool. | Claude Code (`tools:`), Copilot CLI and VS Code (`tools:`), Zoo/Roo (`groups`), and Gemini CLI (`tools:`, a new target). Cursor has `readonly: true` subagents in its runtime; this is unverified in the IDE, and the installer does not emit them yet. |
| **Per-session prevention** | The whole session is read-only, by flag, sandbox, or OS. | Codex (`codex exec --sandbox read-only`), Crush (`permissions deny`), Hermes (a container with the project mounted read-only), and on any harness a read-only mount or container. A separate git worktree is not enough: it is writable and shares refs and hooks with the main repository. |
| **Detection** | After every read-only step, check that nothing changed on disk. | Everywhere: an empty `git status --porcelain --ignored` (excluding paths the driver owns), plus a checksum of the run directory and of `.git` refs and hooks. `git diff` alone misses untracked files. This is the assertion the #11 eval makes. |

Hooks can add per-agent prevention only where the hook knows which agent is calling. Claude
Code's pre-tool hook receives the agent type. Codex's does too once agents ship as roles,
but its hooks run only after the user trusts them. Copilot CLI, Hermes, and Crush hooks do
not identify the agent, so there they are session-wide. On every target, the Orchestrator's
"never edits" and narrowings such as "read-only by default; edits on request" remain prose.

13. **Grant test, extended.** For every target, check the generated output of every `R` and
    `R+route` agent for any write-capable grant. Also validate the Copilot and VS Code tool
    ids against their alias table: unknown ids are dropped silently, so a typo removes a tool
    without an error.
14. **Claude Code guard hook**, shipped with the plugin and `--target claude`.
    - During a run, it denies file writes and shell for read-only agent types.
    - It denies dispatching anything that is not a roster agent, so a run cannot fall back
      to a general-purpose agent with every tool.
    - A stop hook runs the disk-state check.
    - The guard must fail closed: on any internal error it blocks.
15. **Per-target posture notes in `PORTABILITY.md`**, saying for each target which layer
    enforces each posture, and what stays prose.

## 0.5.0 — case-aware core, installs, and platforms

**Case-aware core.** The Orchestrator's gate order, run closure, and `/run-delivery`'s
default all assume greenfield.
- Record the case in the handoff schema and `state.md`.
- Give each playbook a terminal gate and a closure rule.
- Add a `closing-a-run` skill.
- Add a preemption rule for incident and spike runs (today, incident pauses another run while
  the protocol forbids opening one while another is unclosed).
- Add trigger templates and a thin packet for non-greenfield cases.

**Installs you can upgrade and remove.**
- Orphans persist in the manifest until they are removed.
- Add `--prune` and `--uninstall`.
- Project manifests record relative paths.
- Plugin installs find their own docs without a clone.
- This must land before any release renames or removes an agent, skill, or command.

**New platforms: Gemini CLI, Crush, and VS Code.** Start after the target registry and
support tiers exist, so each new target lands with a tier. Each target is its own pull
request.

- **VS Code.**
  - `--target copilot` already installs agents and skills where VS Code reads them, and
    VS Code enforces each agent's `tools:` list. So VS Code needs no new layout.
  - Add `vscode` as an alias of `copilot` with identical output.
  - Ship the four commands as skills with `disable-model-invocation: true`, so they appear
    as `/run-status` and the like. Prompt files are deprecated and not loaded by the newer
    harness. The command bodies are written for Claude Code and need a neutral rewrite or a
    per-target variant.
  - Optionally inject `agents: [security-engineer, architecture-guardian]` into the Code
    Reviewer at install time. This is documented only for the older local harness.
- **Gemini CLI.** The strongest new target: it enforces a per-agent `tools:` allowlist and
  can deny tools per subagent by policy.
  - Emit `.gemini/agents/<slug>.md` with a strict frontmatter (`name`, `description`,
    `tools`; drop `argument-hint`, which the schema rejects).
  - Always emit `tools:`. An omitted list inherits every tool.
  - Copy skills to `.gemini/skills/`. Convert commands to `.gemini/commands/*.toml`.
  - Write a user-level policy file that denies writes and shell to read-only agents, as a
    backstop against a settings override that widens `tools:`.
  - Subagents cannot call subagents, so the Orchestrator runs as the main session, started
    by a command.
  - A global install must add the docs directory to `context.includeDirectories`; the
    installer prints the setting rather than editing the user's settings.
  - Optionally package the same output as a Gemini extension.
- **Crush.** No per-agent definitions, so it follows the skill-based shape of Codex and
  Hermes.
  - Each agent ships as a user-invocable skill, the framework skills too.
  - `/run-status` ships as a command; the others depend on dispatching named agents, which
    Crush cannot do.
  - Posture is per session: an optional shell fragment, sourced from the user's `crushrc`,
    reads `AGENTS_FACTORY_POSTURE` and runs `permissions deny` for the matching tools. This
    makes `R` read-only and `E` shell-free for the whole session (built-in tools only; MCP
    tools need a hook).
  - Project-scope `.crush/` is git-ignored by Crush, so the installer must say so or add an
    exception.
- **All three:** a regression test per target in `tests/test_installer.py`, a column in the
  `PORTABILITY.md` tables, and a CHANGELOG entry. Harness tool names stay inside the installer
  and `PORTABILITY.md`.

**Re-examine the main-loop requirement.** Claude Code subagents can now start subagents. Decide
whether the Orchestrator can run as an agent on Claude Code, and whether the Code Reviewer keeps
its `agent` grant there, before 1.0 fixes the driver's shape.

**Driver hardening.** `/run-delivery` re-derives its position from disk at every step, so a
long run does not depend on one session's context.

## 1.0 — definition of done

- [ ] #10 closed from a tagged install: release evidence, a signed Gate 3, closure, and
  promotion. At least one phase is driven through `routing-a-step`.
- [ ] #11 closed: one scenario per property passes on every trial, and live evals run before
  every release.
- [ ] The run validator passes on every committed run (legacy runs only via the allowlist).
- [ ] No agent is told to do what its posture forbids, and the grant test covers every agent
  on every target.
- [ ] Every gate in every playbook resolves to a record filename and a closure check.
- [ ] Installs are versioned, upgradable, and removable.
- [ ] Every install target has a support tier; only tier-1 targets carry the SemVer guarantee.
- [ ] A deprecation policy: deprecate in a minor release with an installer warning, remove in
  a major one.
- [ ] One release after #10 ships with no breaking change to the handoff schema, gate format,
  run layout, or invocation contract, followed by `1.0.0-rc.1`.

## Later

- A security-incident case; decide on mobile, data/ML, and re-platform cases, or declare them
  out of scope.
- Move the advisory dispatch contract from a proposal into a normative document.
- A `writing-a-handoff` skill.
- A macOS (bash 3.2) CI job, and per-target release archives.
- A five-minute path at the top of the README, and a "run report" issue template.
- A slimmer plugin payload.

## Not doing

- **Replacing `install.sh` with an external packager.** Investigated and rejected in
  [the 0.3.0 design spec](docs/superpowers/specs/2026-08-29-versioning-gates-and-tests-design.md):
  it would drop targets, the commands, and the posture contract.
- **Skills as separately installable packages.** One distributable, one version.
- **New cases or agents before the core is case-aware.**
- **Evals that assert on tool-call transcripts.** Transcripts differ per harness; assert on
  what lands on disk.
- **Building #10 inside this repository, or continuing the reference run.**
