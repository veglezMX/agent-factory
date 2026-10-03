# Task runner for agents-factory contributors. Every recipe is a thin wrapper over a
# command CI runs; nothing here is required to edit prose (CI runs the gates for you).
# Install: https://just.systems — or run the underlying commands directly.

set shell := ["bash", "-euo", "pipefail", "-c"]

# List recipes.
default:
    @just --list

# Everything CI runs, in CI's order. Run this before every push.
check: lint derived versions typecheck test

# Regenerate every derived directory from .github/ (run after editing .github/).
regen:
    scripts/install.sh --target repo

# Fail if a derived directory is stale.
derived:
    scripts/install.sh --target repo --check

# Bump-on-change gate (R1 skill versions, R2 changelog). Pass a base ref to compare.
versions base="origin/dev":
    uv run python tools/check_versions.py --base "{{base}}"

# The invariant suite.
test *args:
    uv run pytest {{args}}

# Lint Python tooling and the installer.
lint:
    uv run ruff check tools tests
    uv run ruff format --check tools tests
    uvx --from shellcheck-py shellcheck -S warning scripts/install.sh
    uvx --from actionlint-py actionlint .github/workflows/*.yml

# Auto-fix formatting.
fmt:
    uv run ruff check --fix tools tests
    uv run ruff format tools tests

# Static types for tools/ and tests/.
typecheck:
    uv run pyright

# Start a release: bump plugin.json, rotate CHANGELOG, regenerate, run every gate.
release-prep version:
    uv run python tools/release.py prep "{{version}}"
    just check

# Assert tag, plugin.json, and CHANGELOG agree (CI runs this on tag pushes).
release-verify tag="":
    uv run python tools/release.py verify {{ if tag != "" { "--tag " + tag } else { "" } }}

# Print the release notes for a version (the CHANGELOG section).
release-notes version:
    uv run python tools/release.py notes "{{version}}"
