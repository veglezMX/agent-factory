"""process/agent-roster.md is the registry; .github/agents/ must match it exactly."""

from conftest import CANONICAL_TOOL_ORDER, POSTURES, agents, roster_rows, roster_slug_by_id


def test_roster_and_agent_files_are_a_bijection():
    ids = [r.id for r in roster_rows()]
    assert len(ids) == len(set(ids)), "duplicate roster id"
    assert ids == [f"{i:02d}" for i in range(1, len(ids) + 1)], "roster ids must be 01..NN"
    mapped = roster_slug_by_id()
    assert sorted(mapped) == ids, (
        "every roster id needs exactly one agent file stating 'agent NN' in its Role, "
        f"and vice versa; roster={ids} files={sorted(mapped)}"
    )
    assert len(agents()) == len(ids)


def test_every_agent_states_a_unique_roster_number():
    seen: dict[str, str] = {}
    for a in agents():
        import re

        m = re.search(r"\bagent (\d\d)\b", a.body)
        assert m, f"{a.slug}: Role must state 'agent NN in the delivery roster'"
        assert m.group(1) not in seen, f"{a.slug} and {seen.get(m.group(1))} share an id"
        seen[m.group(1)] = a.slug


def test_roster_posture_is_a_legend_token():
    for r in roster_rows():
        assert r.posture in POSTURES, f"{r.id} {r.name}: posture {r.posture!r} not in legend"


def test_roster_posture_matches_tools_frontmatter():
    by_slug = {a.slug: a for a in agents()}
    for rid, slug in roster_slug_by_id().items():
        row = next(r for r in roster_rows() if r.id == rid)
        assert row.posture == by_slug[slug].posture, (
            f"{rid} {slug}: roster says {row.posture}, tools {by_slug[slug].tools} "
            f"derive {by_slug[slug].posture}"
        )


def test_tool_ids_are_known_and_in_canonical_order():
    for a in agents():
        unknown = [t for t in a.tools if t not in CANONICAL_TOOL_ORDER]
        assert not unknown, f"{a.slug}: unknown tool ids {unknown}"
        assert a.tools == sorted(a.tools, key=CANONICAL_TOOL_ORDER.index), (
            f"{a.slug}: tools not in canonical order {CANONICAL_TOOL_ORDER}"
        )


def test_only_orchestrator_and_code_reviewer_carry_agent_tool():
    holders = {
        rid
        for rid, slug in roster_slug_by_id().items()
        if "agent" in next(a for a in agents() if a.slug == slug).tools
    }
    assert holders == {"01", "18"}


def test_may_call_is_none_except_01_and_18():
    for r in roster_rows():
        if r.id in {"01", "18"}:
            continue
        assert r.may_call == "None", f"{r.id} {r.name}: May call must be None"


def test_code_reviewer_is_the_only_specialist_caller():
    """18 may route to exactly 15 and 08; no other agent may be listed as a caller."""
    names = {r.id: r.name for r in roster_rows()}
    allowed = {"Orchestrator", "Human", "Delivery Orchestrator"}
    for r in roster_rows():
        callers = {c.strip() for c in r.called_by.split(",")}
        others = {c for c in callers if c not in allowed and not c.startswith("any ")}
        if r.id in {"15", "08"}:
            assert others <= {names["18"]}, f"{r.id}: unexpected callers {others}"
        else:
            assert not others, (
                f"{r.id} {r.name}: only the Orchestrator or a human may call it, got {others}"
            )
