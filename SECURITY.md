# Security policy

## Supported versions

Only the latest release (the newest `vX.Y.Z` tag on `main`) receives fixes. While the project
is pre-1.0, fixes ship in the next PATCH release; see [docs/RELEASING.md](docs/RELEASING.md).

## What counts

agents-factory is prompts, process documents, and an installer script, so the most likely
security problems are:

- `scripts/install.sh` writing, overwriting, or deleting outside the destination it was given;
- an agent definition, skill, or command whose instructions could lead an agent to exfiltrate
  data, run destructive commands without approval, or obey instructions embedded in the
  material it reviews (prompt injection);
- a tool posture that grants more than the roster says.

## Reporting

Please **do not open a public issue.** Use GitHub's private vulnerability reporting
(**Security → Report a vulnerability** on the repository), or email the maintainer at the
address in `.claude-plugin/plugin.json`. Include the version, the file or agent involved, and
a reproduction. You can expect an acknowledgement within a week; fixed issues are credited in
the CHANGELOG unless you prefer otherwise.
