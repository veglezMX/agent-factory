"""The slash commands exist, are well formed, and are documented."""

from conftest import ROOT, commands

EXPECTED = {"run-delivery", "run-advisory", "run-status", "new-agent"}
KNOWN_TOOLS = {
    "Task",
    "Read",
    "Write",
    "Edit",
    "Grep",
    "Glob",
    "Bash",
    "TodoWrite",
    "AskUserQuestion",
    "WebFetch",
    "WebSearch",
}


def test_expected_commands_exist():
    assert set(commands()) == EXPECTED


def test_frontmatter():
    for name, meta in commands().items():
        assert set(meta) == {"description", "argument-hint", "allowed-tools"}, name
        tools = {t.strip() for t in str(meta["allowed-tools"]).split(",")}
        assert tools <= KNOWN_TOOLS, f"{name}: unknown tools {tools - KNOWN_TOOLS}"


def test_read_only_commands_cannot_write():
    tools = {t.strip() for t in str(commands()["run-status"]["allowed-tools"]).split(",")}
    assert not tools & {"Write", "Edit", "Task"}


def test_each_command_is_in_the_readme():
    readme = (ROOT / "README.md").read_text(encoding="utf-8")
    for name in commands():
        assert f"/{name}" in readme, f"README does not mention /{name}"
