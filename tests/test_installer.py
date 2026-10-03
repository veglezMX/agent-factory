"""scripts/install.sh: every target, run into temporary directories, output parsed for real.

Each test that names a bug number is a regression test for a defect found in the 0.2.0
installer (see CHANGELOG 0.3.0). They run against a scratch copy of the source tree
when they need to plant a malformed input, and never write to the repository.
"""

from __future__ import annotations

import os
import shutil
import subprocess
from pathlib import Path

import pytest
import yaml
from conftest import ROOT, agents, skills, split_frontmatter

SOURCES = [
    ".github/agents",
    ".github/skills",
    ".github/commands",
    "process",
    "templates",
    ".claude-plugin",
    "scripts",
    ".claude",
    ".cursor",
    "agents",
    "skills",
    "commands",
]


def run(
    args: list[str],
    home: Path,
    cwd: Path = ROOT,
    script: Path | None = None,
    env: dict[str, str] | None = None,
) -> subprocess.CompletedProcess[str]:
    e = {
        k: v
        for k, v in os.environ.items()
        if k
        not in {
            "CODEX_HOME",
            "HERMES_HOME",
            "COPILOT_HOME",
            "ROO_SETTINGS_DIR",
            "AGENTS_FACTORY_HOME",
            "CDPATH",
            "XDG_CONFIG_HOME",
        }
    }
    e.update({"HOME": str(home), "TMPDIR": str(home)})
    e.update(env or {})
    sh = script or (cwd / "scripts" / "install.sh")
    return subprocess.run(["bash", str(sh), *args], cwd=cwd, env=e, capture_output=True, text=True)


@pytest.fixture
def home(tmp_path: Path) -> Path:
    h = tmp_path / "home"
    h.mkdir()
    return h


@pytest.fixture
def project(tmp_path: Path) -> Path:
    p = tmp_path / "my project"  # a space in the path, on purpose
    p.mkdir()
    return p


@pytest.fixture
def src(tmp_path: Path) -> Path:
    """A scratch copy of the source tree that a test may mutate."""
    root = tmp_path / "src"
    for rel in SOURCES:
        shutil.copytree(ROOT / rel, root / rel)
    return root


def load_yaml(path: Path):
    return yaml.safe_load(path.read_text(encoding="utf-8"))


def frontmatter_of(path: Path) -> dict:
    meta, _ = split_frontmatter(path.read_text(encoding="utf-8"))
    return meta


# --------------------------------------------------------------------------- every target
GLOBAL_TARGETS = ["claude", "cursor", "copilot", "codex", "hermes", "agents"]


@pytest.mark.parametrize("target", GLOBAL_TARGETS)
def test_global_install_is_idempotent_and_installs_docs(target, home):
    r1 = run(["--target", target], home)
    assert r1.returncode == 0, r1.stderr
    assert (home / ".agents-factory" / "process" / "agent-invocation-contract.md").is_file()
    assert (home / ".agents-factory" / "templates" / "stakeholder-input-packet.md").is_file()
    r2 = run(["--target", target, "--check"], home)
    assert r2.returncode == 0, r2.stdout + r2.stderr
    assert "0 would change" in r2.stdout


@pytest.mark.parametrize("target", GLOBAL_TARGETS + ["roo"])
def test_project_install_into_path_with_spaces(target, home, project):
    r = run(["--target", target, "--scope", "project", "--path", str(project)], home)
    assert r.returncode == 0, r.stderr
    assert (project / ".agents-factory" / "process" / "agent-handoff-protocol.md").is_file()
    assert (
        run(
            ["--target", target, "--scope", "project", "--path", str(project), "--check"], home
        ).returncode
        == 0
    )


def test_generated_yaml_and_frontmatter_parse(home, project):
    for t in ["claude", "cursor", "codex", "hermes", "agents", "roo"]:
        assert (
            run(["--target", t, "--scope", "project", "--path", str(project)], home).returncode == 0
        )
    n = len(agents())
    for f in (project / ".claude" / "agents").glob("*.md"):
        assert set(frontmatter_of(f)) == {"name", "description", "tools"}
    for f in (project / ".cursor" / "rules").glob("*.mdc"):
        assert set(frontmatter_of(f)) == {"description", "alwaysApply"}
    for base in (".codex", ".hermes"):
        metas = [frontmatter_of(f) for f in (project / base / "skills").glob("*/SKILL.md")]
        assert len(metas) == n + len(skills())
    for f in (project / ".agents").glob("*.yaml"):
        mode = load_yaml(f)
        assert {"slug", "name", "roleDefinition", "groups", "customInstructions"} <= set(mode)
    modes = load_yaml(project / ".roomodes")["customModes"]
    assert len(modes) == n
    by_slug = {m["slug"]: m for m in modes}
    body = (ROOT / ".github/agents/code-reviewer.agent.md").read_text().split("\n## Role", 1)[1]
    assert body.strip()[:200] in by_slug["code-reviewer"]["customInstructions"]


# --------------------------------------------------------------------------- bug 1
def test_bug1_roo_dry_run_and_check_never_write(home, tmp_path):
    settings = tmp_path / "roo-settings"
    settings.mkdir()
    modes = settings / "custom_modes.yaml"
    modes.write_text("customModes:\n  - slug: my-mode\n    name: Mine\n")
    before = modes.read_bytes()
    env = {"ROO_SETTINGS_DIR": str(settings)}
    for flag in ("--dry-run", "--check"):
        run(["--target", "roo", flag], home, env=env)
        assert modes.read_bytes() == before, f"{flag} modified the user's modes file"


def test_bug1_roo_refuses_to_clobber_user_modes_without_force(home, tmp_path):
    settings = tmp_path / "roo-settings"
    settings.mkdir()
    modes = settings / "custom_modes.yaml"
    modes.write_text("customModes:\n  - slug: my-mode\n    name: Mine\n")
    env = {"ROO_SETTINGS_DIR": str(settings)}
    r = run(["--target", "roo"], home, env=env)
    assert "my-mode" in modes.read_text()
    assert "--force" in r.stderr
    r = run(["--target", "roo", "--force"], home, env=env)
    assert r.returncode == 0, r.stderr
    assert "my-mode" in (settings / "custom_modes.yaml.bak").read_text()
    assert len(load_yaml(modes)["customModes"]) == len(agents())


def test_bug1_roo_check_detects_stale_file(home, project):
    run(["--target", "roo", "--scope", "project", "--path", str(project)], home)
    f = project / ".roomodes"
    f.write_text(f.read_text().replace("Delivery Orchestrator", "Stale Orchestrator", 1))
    r = run(["--target", "roo", "--scope", "project", "--path", str(project), "--check"], home)
    assert r.returncode == 1
    assert "would update" in r.stdout


# --------------------------------------------------------------------------- bug 2
@pytest.mark.parametrize("field", ["argument-hint", "name"])
@pytest.mark.parametrize("target", ["codex", "hermes", "roo", "agents"])
def test_bug2_missing_optional_field_does_not_abort(field, target, src, home, project):
    a = src / ".github/agents/bundle-compiler.agent.md"
    lines = a.read_text().splitlines(keepends=True)
    a.write_text("".join(ln for ln in lines if not ln.startswith(f"{field}:")))
    r = run(["--target", target, "--scope", "project", "--path", str(project)], home, cwd=src)
    assert r.returncode == 0, r.stdout + r.stderr
    assert "Summary:" in r.stdout


# --------------------------------------------------------------------------- bug 3
def test_bug3_check_fails_on_warnings_raised_in_subshells(src, home):
    a = src / ".github/agents/bundle-compiler.agent.md"
    a.write_text(
        a.read_text().replace(
            'tools: ["read","search","edit"]', 'tools: ["read","search","edit","teleport"]'
        )
    )
    r = run(["--target", "repo", "--check"], home, cwd=src)
    assert r.returncode == 1
    assert "teleport" in r.stderr
    assert " 0 warnings" not in r.stdout


def test_bug3_check_reports_orphaned_skills_and_commands(src, home):
    shutil.rmtree(src / ".github/skills/resuming-a-run")
    (src / ".github/commands/run-status.md").unlink()
    r = run(["--target", "repo", "--check"], home, cwd=src)
    assert r.returncode == 1
    assert ".claude/skills/resuming-a-run" in r.stdout
    assert ".claude/commands/run-status.md" in r.stdout


# --------------------------------------------------------------------------- bug 4
def test_bug4_body_horizontal_rules_and_yaml_examples_survive(home, project):
    run(["--target", "cursor", "--scope", "project", "--path", str(project)], home)
    rule = (project / ".cursor/rules/skill-authoring-an-agent.mdc").read_text()
    src_body = (ROOT / ".github/skills/authoring-an-agent/SKILL.md").read_text()
    src_body = src_body.split("\n---\n", 1)[1]
    assert rule.count("\n---\n") >= src_body.count("\n---\n") + 1
    assert "```yaml\n---\nname: <slug>" in rule


# --------------------------------------------------------------------------- bug 5
@pytest.mark.parametrize(
    "tools",
    [
        "tools: ['read','search','edit','execute','todo']",
        "tools: [read, search, edit, execute, todo]",
        "tools:\n  - read\n  - search\n  - edit\n  - execute\n  - todo",
    ],
)
def test_bug5_tool_list_shapes(tools, src, home, project):
    a = src / ".github/agents/foundation-engineer.agent.md"
    a.write_text(a.read_text().replace('tools: ["read","search","edit","execute","todo"]', tools))
    for t in ("claude", "cursor", "roo"):
        r = run(["--target", t, "--scope", "project", "--path", str(project)], home, cwd=src)
        assert r.returncode == 0, r.stderr
    meta = frontmatter_of(project / ".claude/agents/foundation-engineer.md")
    assert meta["tools"] == "Read, Grep, Glob, Edit, Write, Bash, TodoWrite"
    assert "`E+T`" in (project / ".cursor/rules/foundation-engineer.mdc").read_text()
    modes = {m["slug"]: m for m in load_yaml(project / ".roomodes")["customModes"]}
    assert modes["foundation-engineer"]["groups"] == ["read", "edit", "command"]


def test_bug5_unparseable_tools_is_fatal(src, home, project):
    a = src / ".github/agents/foundation-engineer.agent.md"
    a.write_text(
        a.read_text().replace(
            'tools: ["read","search","edit","execute","todo"]', "tools: read search"
        )
    )
    r = run(["--target", "claude", "--scope", "project", "--path", str(project)], home, cwd=src)
    assert r.returncode != 0
    assert "cannot parse tools" in r.stderr


# --------------------------------------------------------------------------- bug 6
@pytest.mark.parametrize(
    "desc",
    [
        'description: "Handles C:\\\\temp paths and \\"quotes\\": safely."',
        "description: 'Single-quoted: it''s fine'",
        "description: >-\n  Folded description that\n  spans two lines.",
    ],
)
def test_bug6_descriptions_round_trip(desc, src, home, project):
    a = src / ".github/agents/bundle-compiler.agent.md"
    text = a.read_text()
    old = next(ln for ln in text.splitlines() if ln.startswith("description:"))
    a.write_text(text.replace(old, desc))
    expected = yaml.safe_load(desc)["description"]
    for t in ("cursor", "codex", "agents", "roo"):
        r = run(["--target", t, "--scope", "project", "--path", str(project)], home, cwd=src)
        assert r.returncode == 0, r.stderr
    assert frontmatter_of(project / ".cursor/rules/bundle-compiler.mdc")["description"] == expected
    assert (
        frontmatter_of(project / ".codex/skills/bundle-compiler/SKILL.md")["description"]
        == expected
    )
    assert load_yaml(project / ".agents/bundle-compiler.yaml")["whenToUse"] == expected
    modes = {m["slug"]: m for m in load_yaml(project / ".roomodes")["customModes"]}
    assert modes["bundle-compiler"]["whenToUse"] == expected


def test_bug6_indented_first_body_line_parses(src, home, project):
    a = src / ".github/agents/bundle-compiler.agent.md"
    meta_end = a.read_text().index("\n---\n", 4) + 5
    text = a.read_text()
    a.write_text(text[:meta_end] + "\n    indented code first\n" + text[meta_end:])
    for t in ("agents", "roo"):
        assert (
            run(
                ["--target", t, "--scope", "project", "--path", str(project)], home, cwd=src
            ).returncode
            == 0
        )
    assert load_yaml(project / ".agents/bundle-compiler.yaml")["customInstructions"].startswith(
        "    indented code first"
    )
    load_yaml(project / ".roomodes")


# --------------------------------------------------------------------------- bug 7
def test_bug7_crlf_sources_convert(src, home, project):
    a = src / ".github/agents/bundle-compiler.agent.md"
    a.write_bytes(a.read_bytes().replace(b"\n", b"\r\n"))
    r = run(["--target", "claude", "--scope", "project", "--path", str(project)], home, cwd=src)
    assert r.returncode == 0, r.stderr
    out = (project / ".claude/agents/bundle-compiler.md").read_text()
    assert "argument-hint" not in out
    assert (
        frontmatter_of(project / ".claude/agents/bundle-compiler.md")["tools"]
        == "Read, Grep, Glob, Edit, Write"
    )


# --------------------------------------------------------------------------- bug 8
def test_bug8_user_files_in_global_dirs_are_not_orphans(home):
    agents_dir = home / ".claude" / "agents"
    agents_dir.mkdir(parents=True)
    (agents_dir / "my-helper.md").write_text("---\nname: my-helper\n---\nmine\n")
    run(["--target", "claude"], home)
    r = run(["--target", "claude", "--check"], home)
    assert r.returncode == 0, r.stdout
    assert "my-helper" not in r.stdout


def test_bug8_name_differing_from_filename_is_not_an_orphan(src, home, project):
    a = src / ".github/agents/bundle-compiler.agent.md"
    a.write_text(a.read_text().replace("name: bundle-compiler", "name: task-bundler", 1))
    args = ["--target", "codex", "--scope", "project", "--path", str(project)]
    assert run(args, home, cwd=src).returncode == 0
    r = run([*args, "--check"], home, cwd=src)
    assert r.returncode == 0, r.stdout + r.stderr


def test_bug8_removed_agent_is_reported_from_manifest(src, home, project):
    args = ["--target", "codex", "--scope", "project", "--path", str(project)]
    assert run(args, home, cwd=src).returncode == 0
    (src / ".github/agents/bundle-compiler.agent.md").unlink()
    r = run([*args, "--check"], home, cwd=src)
    assert r.returncode == 1
    assert "bundle-compiler" in r.stdout and "ORPHAN" in r.stdout


# --------------------------------------------------------------------------- bug 9, 10
def test_bug9_exported_cdpath_is_harmless(home, project):
    # A relative script path is what makes `cd` consult CDPATH (and echo the directory).
    env = {**os.environ, "HOME": str(home), "TMPDIR": str(home), "CDPATH": "."}
    r = subprocess.run(
        [
            "bash",
            f"{ROOT.name}/scripts/install.sh",
            "--target",
            "claude",
            "--scope",
            "project",
            "--path",
            str(project),
        ],
        cwd=ROOT.parent,
        env=env,
        capture_output=True,
        text=True,
    )
    assert r.returncode == 0, r.stderr
    assert (project / ".claude/agents/code-reviewer.md").is_file()


@pytest.mark.parametrize(
    "args", [["--scope", "global project"], ["--target", "claude cursor"], ["--target", ""]]
)
def test_bug10_multi_word_values_are_rejected(args, home):
    r = run(args, home)
    assert r.returncode != 0


# --------------------------------------------------------------------------- other contracts
def test_keep_existing_cannot_hide_files_from_check(home):
    r = run(["--target", "claude", "--check", "--keep-existing"], home)
    assert r.returncode != 0


def test_non_skill_destination_fails_in_dry_run_too(home):
    d = home / ".claude" / "skills" / "conducting-a-gate"
    d.mkdir(parents=True)
    (d / "notes.txt").write_text("not a skill")
    r = run(["--target", "claude", "--dry-run"], home)
    assert r.returncode != 0
    assert "not a skill" in r.stderr


def test_code_reviewer_does_not_get_task_on_claude(home, project):
    run(["--target", "claude", "--scope", "project", "--path", str(project)], home)
    tools = frontmatter_of(project / ".claude/agents/code-reviewer.md")["tools"]
    assert "Task" not in tools
    orch = frontmatter_of(project / ".claude/agents/delivery-orchestrator.md")["tools"]
    assert "Task" in orch


def test_docs_target_and_custom_docs_home(home, project, tmp_path):
    r = run(["--target", "docs", "--scope", "project", "--path", str(project)], home)
    assert r.returncode == 0, r.stderr
    assert (project / ".agents-factory/process/playbooks/greenfield.md").is_file()
    custom = tmp_path / "af"
    r = run(["--target", "claude"], home, env={"AGENTS_FACTORY_HOME": str(custom)})
    assert r.returncode == 0, r.stderr
    assert (custom / "process/agent-roster.md").is_file()
    agent = (home / ".claude/agents/code-reviewer.md").read_text()
    assert str(custom) in agent and "~/.agents-factory" not in agent


def test_generated_agents_tell_where_the_docs_are(home):
    run(["--target", "claude"], home)
    agent = (home / ".claude/agents/architecture-guardian.md").read_text()
    assert "~/.agents-factory" in agent
    assert (home / ".agents-factory/process/agent-invocation-contract.md").is_file()
