"""Derived directories are byte-identical to what install.sh would generate now."""

import subprocess

from conftest import INSTALL_SH, ROOT


def test_repo_target_check_passes():
    r = subprocess.run(
        ["bash", str(INSTALL_SH), "--target", "repo", "--check"],
        cwd=ROOT,
        capture_output=True,
        text=True,
    )
    assert r.returncode == 0, (
        "derived dirs are stale — run `scripts/install.sh --target repo`\n" + r.stdout + r.stderr
    )
