"""The case × agent matrix in process/playbooks/README.md agrees with every playbook.

A cell marked `x` or `~` holds if and only if that agent id is in that playbook's
`agents:` list. This is the defect class that reached 0.2.0, and the one a hand-run
script in a skill later stopped catching without anyone noticing.
"""

from conftest import matrix, playbooks, roster_rows

CELLS = {"x", "~", "–"}


def test_matrix_parses_every_roster_row():
    m = matrix()
    assert m.rows, "parsed zero matrix rows — the parser or the table is broken"
    assert sorted(m.rows) == [r.id for r in roster_rows()]
    for aid, row in m.rows.items():
        assert int(row["__ncells__"]) == len(m.columns), f"row {aid} has the wrong cell count"


def test_one_column_per_playbook_and_legend_maps_it():
    m = matrix()
    cases = {p.case for p in playbooks()}
    assert set(m.abbrev_to_case) == set(m.columns), "legend and header columns differ"
    assert set(m.abbrev_to_case.values()) == cases


def test_cells_use_the_legend_symbols():
    for aid, row in matrix().rows.items():
        for col in matrix().columns:
            assert row[col] in CELLS, f"{aid}×{col}: {row[col]!r}"


def test_cells_agree_with_playbook_agents_lists():
    m = matrix()
    by_case = {p.case: p for p in playbooks()}
    bad = []
    for col in m.columns:
        pb = by_case[m.abbrev_to_case[col]]
        for aid, row in m.rows.items():
            if (row[col] in {"x", "~"}) != (aid in pb.agent_ids):
                bad.append(
                    f"{aid}×{pb.case}: matrix={row[col]!r}, in agents: {aid in pb.agent_ids}"
                )
    assert not bad, "\n".join(bad)
