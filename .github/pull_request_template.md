<!-- Target `dev` (releases and hotfixes target `main`). One concern per pull request.
     Contributors: CONTRIBUTING.md · AI agents: AGENTS.md · Releases: docs/RELEASING.md -->

## Summary

<!-- What changes and why. Link the issue it resolves, if any. -->

## Type

<!-- One Conventional Commit type: feat | fix | docs | test | refactor | chore | ci.
     Add `!` and describe the impact below if it breaks the public interface
     (roster, contracts, schemas, skill/command names, installer targets or flags). -->

## Checklist

- [ ] Edited sources only (`.github/…`, `process/`, `templates/`, `scripts/`), then ran `scripts/install.sh --target repo`
- [ ] `CHANGELOG.md` entry under `[Unreleased]` (required for distributed content)
- [ ] Raised `version:` of every changed skill
- [ ] Updated counts and cross-references this change moves (README, roster, manifests, matrix)
- [ ] `just check` passes locally
- [ ] `plugin.json` version untouched (it moves only on a release branch)

## Verification

<!-- How you know it works: commands run and their result, installs tried, tests added. -->

## Notes for reviewers

<!-- Judgement calls the tests cannot make: boundaries, wording, anything over-claimed.
     For agent-authored PRs, name the harness that produced it. -->
