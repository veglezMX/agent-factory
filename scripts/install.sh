#!/usr/bin/env bash
#
# install.sh — install/convert the agents-factory roster + skills for a target platform.
#
# Source of truth: .github/agents/*.agent.md (GitHub Copilot / VS Code format).
# This script DERIVES the other platforms' layouts from it; never hand-edit the derived
# folders (.claude/agents, .cursor/rules) — re-run this instead.
#
# Installs GLOBALLY by default (user-level config: ~/.claude, ~/.cursor, ~/.copilot). Pass
# --scope project --path <dir> to install into a specific project instead.
#
# Usage:
#   scripts/install.sh --target claude                            # global  -> ~/.claude
#   scripts/install.sh --target claude --scope project --path DIR # project -> DIR/.claude
#   scripts/install.sh --target cursor                            # global  -> ~/.cursor/rules
#   scripts/install.sh --target copilot                           # global  -> ~/.copilot (agents+skills)
#   scripts/install.sh --target agents                            # global  -> ~/.agents (generic per-agent custom-mode files)
#   scripts/install.sh --target roo                               # global  -> Zoo/Roo custom_modes.yaml (editor globalStorage)
#   scripts/install.sh --target roo --scope project --path DIR    # project -> DIR/.roomodes (native single-file format)
#   scripts/install.sh --target plugin                            # regenerate this repo's plugin dirs
#
# Flags:
#   --target  claude | cursor | copilot | agents | roo | zoo | plugin   (default: claude)
#             ('roo' and 'zoo' are aliases — same .roomodes / custom_modes.yaml format;
#              global installs auto-detect Zoo Code and legacy Roo Code storage)
#   --scope   global | project                     (default: global)
#   --path    DIR   project root (required when --scope project)
#   --dest    DIR   alias for "--scope project --path DIR" (back-compat)
#
set -euo pipefail

TARGET="claude"
SCOPE=""
DEST=""
ROOT="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"

usage() { sed -n '2,24p' "${BASH_SOURCE[0]}" | sed 's/^# \{0,1\}//'; }

while [[ $# -gt 0 ]]; do
  case "$1" in
    --target) TARGET="${2:-}"; shift 2 ;;
    --scope)  SCOPE="${2:-}";  shift 2 ;;
    --path)   DEST="${2:-}";   shift 2 ;;
    --dest)   DEST="${2:-}"; SCOPE="${SCOPE:-project}"; shift 2 ;;
    -h|--help) usage; exit 0 ;;
    *) echo "unknown argument: $1" >&2; usage; exit 1 ;;
  esac
done

# --- Resolve install scope -> DEST base directory ------------------------------
# The conversion functions append the platform subdir (e.g. .claude/agents) to DEST:
#   global  -> DEST=$HOME    => ~/.claude/agents, ~/.cursor/rules
#   project -> DEST=<path>   => <path>/.claude/agents, <path>/.cursor/rules
if [[ "$TARGET" == "plugin" ]]; then
  # The plugin IS this repo (a single-plugin marketplace); its components must live at
  # the repo root next to .claude-plugin/, so scope does not apply.
  [[ "${SCOPE:-}" == "global" ]] && \
    echo "note: --scope is ignored for --target plugin (components live at the repo root)." >&2
  DEST="${DEST:-$ROOT}"
else
  [[ -n "$SCOPE" ]] || { [[ -n "$DEST" ]] && SCOPE="project" || SCOPE="global"; }
  case "$SCOPE" in
    global)  DEST="$HOME" ;;
    project) [[ -n "$DEST" ]] || { echo "error: --scope project requires --path <dir>" >&2; usage; exit 1; } ;;
    *)       echo "unknown scope: $SCOPE (use global | project)" >&2; usage; exit 1 ;;
  esac
fi

AGENTS_SRC="$ROOT/.github/agents"
SKILLS_SRC="$ROOT/.github/skills"
[[ -d "$AGENTS_SRC" ]] || { echo "error: $AGENTS_SRC not found — run from the repo." >&2; exit 1; }

# --- VS Code tool id -> Claude Code tool name(s) ---
map_tool_id() {
  case "$1" in
    read)    echo "Read" ;;
    search)  echo "Grep Glob" ;;
    edit)    echo "Edit Write" ;;
    execute) echo "Bash" ;;
    todo)    echo "TodoWrite" ;;
    agent)   echo "Task" ;;
    web|fetch) echo "WebFetch WebSearch" ;;
    vscode)  echo "" ;;        # editor-specific; no Claude equivalent
    *)       echo "" ;;
  esac
}

# Given a raw "tools:" line, emit a Claude-style "tools: A, B, C" line (deduped, ordered).
claude_tools_line() {
  local line="$1" id mapped t out=() ; declare -A seen=()
  # extract bare ids from the quoted array, e.g. tools: ["read","search","edit"]
  for id in $(grep -oE '"[a-zA-Z]+"' <<<"$line" | tr -d '"'); do
    mapped="$(map_tool_id "$id")"
    for t in $mapped; do
      [[ -n "${seen[$t]:-}" ]] && continue
      seen[$t]=1; out+=("$t")
    done
  done
  if [[ ${#out[@]} -eq 0 ]]; then echo "tools: Read"; return; fi
  local joined; joined="$(printf '%s, ' "${out[@]}")"; joined="${joined%, }"
  echo "tools: $joined"
}

# Extract a frontmatter field value (first match) from a file: field_value <file> <key>
field_value() { grep -m1 "^$2:" "$1" | sed "s/^$2:[[:space:]]*//"; }

install_skills() {
  local skills_dir="$1"
  [[ -d "$SKILLS_SRC" ]] || return 0
  mkdir -p "$skills_dir"
  local s name dst
  for s in "$SKILLS_SRC"/*/; do
    [[ -d "$s" ]] || continue
    name="$(basename "$s")"; dst="$skills_dir/$name"
    if [[ -e "$dst" ]]; then echo "  skill '$name' already present (skipped)"; continue; fi
    cp -R "$s" "$dst"; echo "  skill '$name' -> $dst"
  done
}

# Convert .github/agents/*.agent.md into Claude-format *.md in <out_dir>.
gen_agents() {
  local out_dir="$1"; mkdir -p "$out_dir"
  local count=0 src base dest line
  for src in "$AGENTS_SRC"/*.agent.md; do
    [[ -e "$src" ]] || continue
    base="$(basename "$src" .agent.md)"
    [[ "$base" == "test" ]] && continue          # skip the editor scaffold
    dest="$out_dir/$base.md"
    : > "$dest"
    while IFS= read -r line || [[ -n "$line" ]]; do
      if [[ "$line" == tools:* ]]; then
        claude_tools_line "$line" >> "$dest"
      elif [[ "$line" == argument-hint:* ]]; then
        :                                        # Claude subagents have no argument-hint
      else
        printf '%s\n' "$line" >> "$dest"
      fi
    done < "$src"
    count=$((count+1))
  done
  echo "  $count agents -> $out_dir/"
}

convert_claude() {
  local cmd dest
  gen_agents "$DEST/.claude/agents"
  install_skills "$DEST/.claude/skills"
  if [[ -d "$ROOT/.claude/commands" ]]; then
    mkdir -p "$DEST/.claude/commands"
    for cmd in "$ROOT/.claude/commands"/*.md; do
      [[ -e "$cmd" ]] || continue
      dest="$DEST/.claude/commands/$(basename "$cmd")"
      [[ -f "$dest" ]] && continue                  # don't clobber a user's local edits
      cp "$cmd" "$dest"
      echo "  driver -> $dest"
    done
  fi
  echo "Done. Start a delivery run with:  /run-delivery <run-id>   or an advisory review with:  /run-advisory \"<topic>\""
}

# Claude Code marketplace plugin: components live at repo root (agents/ skills/
# commands/) so the .claude-plugin/ manifest can auto-discover them. The two
# manifests (.claude-plugin/plugin.json + marketplace.json) are tracked, not
# generated — this only refreshes the derived component dirs.
convert_plugin() {
  local cmd
  gen_agents "$DEST/agents"
  install_skills "$DEST/skills"
  mkdir -p "$DEST/commands"
  for cmd in "$ROOT/.claude/commands"/*.md; do
    [[ -e "$cmd" ]] || continue
    cp "$cmd" "$DEST/commands/$(basename "$cmd")"
    echo "  driver -> $DEST/commands/$(basename "$cmd")"
  done
  if [[ -f "$DEST/.claude-plugin/plugin.json" ]]; then
    echo "  manifest present -> $DEST/.claude-plugin/plugin.json"
  else
    echo "  WARNING: $DEST/.claude-plugin/plugin.json missing — plugin will not load."
  fi
  echo "Done. Local test:  /plugin marketplace add $DEST"
}

convert_cursor() {
  local out_dir="$DEST/.cursor/rules"; mkdir -p "$out_dir"
  local count=0 src base dest desc
  for src in "$AGENTS_SRC"/*.agent.md; do
    [[ -e "$src" ]] || continue
    base="$(basename "$src" .agent.md)"
    [[ "$base" == "test" ]] && continue
    dest="$out_dir/$base.mdc"
    desc="$(field_value "$src" description)"
    {
      echo "---"
      echo "description: $desc"
      echo "alwaysApply: false"
      echo "---"
      echo
      # body only (everything after the closing frontmatter ---)
      awk 'BEGIN{fm=0} /^---[[:space:]]*$/{fm++; next} fm>=2{print}' "$src"
    } > "$dest"
    count=$((count+1))
  done
  echo "  $count agents -> $out_dir/ (@-mention a rule to use it)"
  echo "Note: Cursor has no native orchestrator — drive the run manually in chat (see PORTABILITY.md)."
}

# GitHub Copilot CLI: the agents are already in the native *.agent.md format, so we COPY
# them (no conversion) into the Copilot config dir. Per GitHub's docs the user-level
# (global) location is the Copilot CLI personal dir ~/.copilot/{agents,skills} (overridable
# with COPILOT_HOME); the project-level location is <path>/.github/{agents,skills}. Skills
# use the SKILL.md folder layout in both cases.
copy_copilot_agents() {
  local out_dir="$1"; mkdir -p "$out_dir"
  local count=0 src base dest
  for src in "$AGENTS_SRC"/*.agent.md; do
    [[ -e "$src" ]] || continue
    base="$(basename "$src" .agent.md)"
    [[ "$base" == "test" ]] && continue          # skip the editor scaffold
    dest="$out_dir/$base.agent.md"
    cp "$src" "$dest"
    count=$((count+1))
  done
  echo "  $count agents -> $out_dir/"
}

convert_copilot() {
  local base
  if [[ "$SCOPE" == "global" ]]; then
    base="${COPILOT_HOME:-$HOME/.copilot}"        # Copilot CLI personal dir: ~/.copilot/{agents,skills}
  else
    base="$DEST/.github"                          # project-level: <path>/.github/{agents,skills}
  fi
  copy_copilot_agents "$base/agents"
  install_skills "$base/skills"
  echo "Done. Start a run by invoking the 'delivery-orchestrator' agent with the packet."
  echo "Note: global installs target the Copilot CLI personal dir (override with COPILOT_HOME)."
  echo "      For a repo's project-level Copilot config, use --scope project --path <dir>."
  echo "See PORTABILITY.md for the agent-to-agent invocation caveat."
}

# --- Generic ".agents" target (Roo Code custom-mode format) --------------------
# Some harnesses load a directory of per-agent files instead of one platform config.
# This emits one YAML file per agent under <dest>/.agents/, each a single Roo Code
# custom-mode object (slug / name / roleDefinition / whenToUse / groups /
# customInstructions). Roo Code itself natively reads a single .roomodes file with a
# customModes: array — see PORTABILITY.md for that caveat.

# VS Code tool id -> Roo Code tool group. Roo groups are coarse: read, edit, browser,
# command, mcp. "search" folds into read; "todo"/"agent"/"vscode" have no group.
map_tool_group() {
  case "$1" in
    read|search) echo "read" ;;
    edit)        echo "edit" ;;
    execute)     echo "command" ;;
    web|fetch)   echo "browser" ;;
    *)           echo "" ;;
  esac
}

# Given a raw "tools:" line, emit a Roo-style "groups: [a, b]" line (deduped, ordered).
roo_groups_line() {
  local line="$1" id mapped g ordered=() ; declare -A seen=()
  for id in $(grep -oE '"[a-zA-Z]+"' <<<"$line" | tr -d '"'); do
    mapped="$(map_tool_group "$id")"
    [[ -n "$mapped" ]] && seen[$mapped]=1
  done
  for g in read edit browser command mcp; do
    [[ -n "${seen[$g]:-}" ]] && ordered+=("$g")
  done
  [[ ${#ordered[@]} -eq 0 ]] && ordered=("read")
  local joined; joined="$(printf '%s, ' "${ordered[@]}")"; joined="${joined%, }"
  echo "groups: [$joined]"
}

# requirements-analyst -> "Requirements Analyst"
title_case() { echo "$1" | sed -e 's/-/ /g' -e 's/\b\(.\)/\u\1/g'; }

# Convert .github/agents/*.agent.md into Roo Code per-agent YAML in <out_dir>.
# Text fields use literal block scalars (|-) so the Markdown bodies need no escaping:
# every non-blank line is indented by 4 spaces; blank lines stay empty. roleDefinition
# is the body's "You are …" persona paragraph (the bodies vary — some open with a
# heading — so we target that line, not just the first paragraph); customInstructions
# is the full body verbatim, so the agent's complete operating manual is preserved.
gen_agents_roo() {
  local out_dir="$1"; mkdir -p "$out_dir"
  local count=0 src base slug name desc dest role
  for src in "$AGENTS_SRC"/*.agent.md; do
    [[ -e "$src" ]] || continue
    base="$(basename "$src" .agent.md)"
    [[ "$base" == "test" ]] && continue          # skip the editor scaffold
    slug="$(field_value "$src" name)"; [[ -n "$slug" ]] || slug="$base"
    name="$(title_case "$slug")"
    desc="$(field_value "$src" description)"
    # persona paragraph: the "You are …" block, up to the next blank line
    role="$(awk 'BEGIN{fm=0;cap=0}
                 /^---[[:space:]]*$/{fm++; next}
                 fm>=2{
                   if(!cap){ if($0 ~ /^You are/) cap=1; else next }
                   if($0 ~ /^[[:space:]]*$/) exit
                   print $0
                 }' "$src")"
    [[ -n "$role" ]] || role="$desc"             # fallback if no "You are" line
    dest="$out_dir/$base.yaml"
    {
      echo "slug: $slug"
      echo "name: $name"
      echo "roleDefinition: |-"
      printf '%s\n' "$role" | sed 's/^./    &/'
      if [[ -n "$desc" ]]; then
        echo "whenToUse: |-"
        printf '    %s\n' "$desc"
      fi
      roo_groups_line "$(grep -m1 '^tools:' "$src" || true)"
      echo "customInstructions: |-"
      # the full body, verbatim, from its first non-blank line
      awk 'BEGIN{fm=0;started=0}
           /^---[[:space:]]*$/{fm++; next}
           fm>=2{
             if(!started){ if($0 ~ /^[[:space:]]*$/) next; started=1 }
             if($0 ~ /^[[:space:]]*$/) print ""; else print "    " $0
           }' "$src"
    } > "$dest"
    count=$((count+1))
  done
  echo "  $count agents -> $out_dir/ (Roo Code custom-mode format)"
}

convert_agents() {
  gen_agents_roo "$DEST/.agents"
  install_skills "$DEST/.agents/skills"
  echo "Done. Point your harness at $DEST/.agents (one custom-mode YAML per agent)."
  echo "Note: Roo Code itself reads a single .roomodes (customModes: array) — use '--target roo'"
  echo "      for that native single-file layout. These per-agent files target generic"
  echo "      .agents-style loaders. See PORTABILITY.md."
}

# --- Native Roo Code target (single .roomodes with a customModes: array) --------
# Unlike the generic "agents" target (a folder of per-agent files), Roo Code itself
# loads ONE file — the project-level .roomodes at the workspace root, or the global
# custom_modes.yaml in its settings dir — holding a top-level customModes: array.
# This target emits that single file directly, so no manual merge step is needed.

# Emit one customModes entry (a YAML block-sequence item) for a source agent file.
# Indentation contract: the "- slug:" item sits at 2 spaces, its keys at 4, and the
# block-scalar bodies at 6 (a block scalar must out-indent its key). roleDefinition
# is the body's "You are …" persona; whenToUse is the description; customInstructions
# is the full body verbatim (its complete operating manual is preserved).
emit_roomode_entry() {
  local src="$1" base slug name desc role
  base="$(basename "$src" .agent.md)"
  slug="$(field_value "$src" name)"; [[ -n "$slug" ]] || slug="$base"
  name="$(title_case "$slug")"
  desc="$(field_value "$src" description)"
  # persona paragraph: the "You are …" block, up to the next blank line
  role="$(awk 'BEGIN{fm=0;cap=0}
               /^---[[:space:]]*$/{fm++; next}
               fm>=2{
                 if(!cap){ if($0 ~ /^You are/) cap=1; else next }
                 if($0 ~ /^[[:space:]]*$/) exit
                 print $0
               }' "$src")"
  [[ -n "$role" ]] || role="$desc"             # fallback if no "You are" line
  echo "  - slug: $slug"
  echo "    name: $name"
  echo "    roleDefinition: |-"
  printf '%s\n' "$role" | sed 's/^./      &/'
  if [[ -n "$desc" ]]; then
    echo "    whenToUse: |-"
    printf '      %s\n' "$desc"
  fi
  # groups inline (a flow sequence is valid YAML even when nested); reuse the posture map
  printf '    %s\n' "$(roo_groups_line "$(grep -m1 '^tools:' "$src" || true)")"
  echo "    customInstructions: |-"
  # the full body, verbatim, from its first non-blank line, indented under the scalar
  awk 'BEGIN{fm=0;started=0}
       /^---[[:space:]]*$/{fm++; next}
       fm>=2{
         if(!started){ if($0 ~ /^[[:space:]]*$/) next; started=1 }
         if($0 ~ /^[[:space:]]*$/) print ""; else print "      " $0
       }' "$src"
}

# Convert .github/agents/*.agent.md into a single native Roo Code .roomodes file.
gen_roomodes() {
  local out_file="$1"; mkdir -p "$(dirname "$out_file")"
  local count=0 src
  echo "customModes:" > "$out_file"
  for src in "$AGENTS_SRC"/*.agent.md; do
    [[ -e "$src" ]] || continue
    [[ "$(basename "$src" .agent.md)" == "test" ]] && continue   # skip the editor scaffold
    emit_roomode_entry "$src" >> "$out_file"
    count=$((count+1))
  done
  echo "  $count agents -> $out_file (native Roo Code customModes: array)"
}

# Candidate dirs that hold the GLOBAL modes file (custom_modes.yaml). Roo Code and
# its active successor Zoo Code (the community fork; Roo was archived in 2026) both
# store global modes inside the editor's VS Code globalStorage for the extension —
# NOT in $HOME. Zoo Code keeps the same format and filenames (.roomodes,
# custom_modes.yaml, the customModes: array); only the extension id differs:
#   zoocodeorganization.zoo-code  (Zoo Code — current)
#   rooveterinaryinc.roo-cline    (Roo Code — legacy)
# The "User" dir location depends on the install: a DESKTOP editor uses an OS config
# root (<root>/<Editor>/User), while a REMOTE/SERVER editor (SSH, WSL, devcontainer,
# Codespaces, code-server) uses ~/.<editor>-server/data/User. We enumerate both,
# crossed with the two extension ids. Override the search with ROO_SETTINGS_DIR=<dir>.
roo_global_settings_dirs() {
  if [[ -n "${ROO_SETTINGS_DIR:-}" ]]; then printf '%s\n' "$ROO_SETTINGS_DIR"; return; fi
  local root e ext userdir
  local exts=("zoocodeorganization.zoo-code" "rooveterinaryinc.roo-cline")
  local userdirs=()

  # Desktop editors: <os-config-root>/<Editor>/User
  local editors=("Code" "Code - Insiders" "VSCodium" "Cursor" "Windsurf")
  case "$(uname -s)" in
    Darwin) root="$HOME/Library/Application Support" ;;
    Linux)  root="${XDG_CONFIG_HOME:-$HOME/.config}" ;;
    *)      root="${APPDATA:-$HOME/.config}" ;;            # Windows (Git Bash / MSYS)
  esac
  for e in "${editors[@]}"; do
    userdirs+=("$root/$e/User")
  done

  # Remote / server editors (VS Code Server over SSH/WSL/devcontainers/Codespaces):
  # ~/.<editor>-server/data/User — plus code-server's own layout.
  for e in .vscode-server .vscode-server-insiders .cursor-server .windsurf-server .vscodium-server; do
    userdirs+=("$HOME/$e/data/User")
  done
  userdirs+=("$HOME/.local/share/code-server/User")

  for userdir in "${userdirs[@]}"; do
    for ext in "${exts[@]}"; do
      printf '%s\n' "$userdir/globalStorage/$ext/settings"
    done
  done
}

# Write the roster into the global custom_modes.yaml for every editor that has Zoo
# Code (or legacy Roo Code) installed — i.e. whose globalStorage dir already exists.
# If none is found, fail loudly with the candidate paths rather than silently
# writing a file the extension will never read.
install_roo_global() {
  local wrote=0 dir ext_dir
  while IFS= read -r dir; do
    ext_dir="$(dirname "$dir")"                            # .../<extension-id>
    # ROO_SETTINGS_DIR is taken verbatim; otherwise require the extension's storage to exist.
    if [[ -n "${ROO_SETTINGS_DIR:-}" || -d "$ext_dir" ]]; then
      gen_roomodes "$dir/custom_modes.yaml"
      wrote=$((wrote+1))
    fi
  done < <(roo_global_settings_dirs)

  if [[ $wrote -eq 0 ]]; then
    {
      echo "error: could not find Zoo Code / Roo Code global storage for any known editor."
      echo "The global modes file is custom_modes.yaml under the editor's globalStorage:"
      roo_global_settings_dirs | sed 's/^/  /'
      echo "Fixes: (1) open Zoo Code in your editor at least once so that dir exists, then re-run;"
      echo "       (2) set ROO_SETTINGS_DIR=<that settings dir> and re-run; or"
      echo "       (3) use --scope project --path <dir> to write a workspace .roomodes instead."
    } >&2
    exit 1
  fi

  install_skills "$HOME/.roo/skills"                        # no native skills runtime; staged for manual use
  echo "Done. Reload your editor window — the modes appear globally in Zoo Code / Roo Code."
  echo "Switch to the 'delivery-orchestrator' mode to start a run."
  echo "Skills have no native Roo runtime — staged under ~/.roo/skills for manual invoke. See PORTABILITY.md."
}

convert_roo() {
  if [[ "$SCOPE" == "global" ]]; then
    install_roo_global
    return
  fi
  gen_roomodes "$DEST/.roomodes"
  install_skills "$DEST/.roo/skills"
  echo "Done. Roo Code reads $DEST/.roomodes natively (top-level customModes: array)."
  echo "Start a run by switching to the 'delivery-orchestrator' mode and pointing it at the packet."
  echo "Skills have no native Roo runtime — installed under $DEST/.roo/skills for manual invoke. See PORTABILITY.md."
}

echo "agents-factory install — target: $TARGET, scope: ${SCOPE:-n/a}, dest: $DEST"
case "$TARGET" in
  claude)  convert_claude ;;
  cursor)  convert_cursor ;;
  copilot) convert_copilot ;;
  agents)  convert_agents ;;
  roo|zoo) convert_roo ;;
  plugin)  convert_plugin ;;
  *) echo "unknown target: $TARGET (use claude | copilot | cursor | agents | roo | zoo | plugin)" >&2; exit 1 ;;
esac
