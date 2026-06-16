#!/usr/bin/env bash
#
# install.sh — install/convert the agents-factory roster + skills for a target platform.
#
# Source of truth: .github/agents/*.agent.md (GitHub Copilot / VS Code format).
# This script DERIVES the other platforms' layouts from it; never hand-edit the derived
# folders (.claude/agents, .cursor/rules) — re-run this instead.
#
# Installs GLOBALLY by default (user-level config: ~/.claude, ~/.cursor, ~/.github). Pass
# --scope project --path <dir> to install into a specific project instead.
#
# Usage:
#   scripts/install.sh --target claude                            # global  -> ~/.claude
#   scripts/install.sh --target claude --scope project --path DIR # project -> DIR/.claude
#   scripts/install.sh --target cursor                            # global  -> ~/.cursor/rules
#   scripts/install.sh --target copilot                           # global  -> ~/.github (agents+skills)
#   scripts/install.sh --target plugin                            # regenerate this repo's plugin dirs
#
# Flags:
#   --target  claude | cursor | copilot | plugin   (default: claude)
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
  gen_agents "$DEST/.claude/agents"
  install_skills "$DEST/.claude/skills"
  if [[ ! -f "$DEST/.claude/commands/run-delivery.md" && -f "$ROOT/.claude/commands/run-delivery.md" ]]; then
    mkdir -p "$DEST/.claude/commands"
    cp "$ROOT/.claude/commands/run-delivery.md" "$DEST/.claude/commands/"
    echo "  driver -> $DEST/.claude/commands/run-delivery.md"
  fi
  echo "Done. Start a run with:  /run-delivery <run-id>"
}

# Claude Code marketplace plugin: components live at repo root (agents/ skills/
# commands/) so the .claude-plugin/ manifest can auto-discover them. The two
# manifests (.claude-plugin/plugin.json + marketplace.json) are tracked, not
# generated — this only refreshes the derived component dirs.
convert_plugin() {
  gen_agents "$DEST/agents"
  install_skills "$DEST/skills"
  mkdir -p "$DEST/commands"
  if [[ -f "$ROOT/.claude/commands/run-delivery.md" ]]; then
    cp "$ROOT/.claude/commands/run-delivery.md" "$DEST/commands/run-delivery.md"
    echo "  driver -> $DEST/commands/run-delivery.md"
  fi
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

# GitHub Copilot / VS Code: the agents are already in the native *.agent.md format, so we
# COPY them (no conversion) into the Copilot config dir. Global install targets the
# editor-agnostic user-level convention ~/.github/{agents,skills}; a project install writes
# <path>/.github/{agents,skills}. Skills reuse the SKILL.md folder layout. VS Code users
# whose profile lives elsewhere can point chat.agentFilesLocations / chat.agentSkillsLocations
# at this folder (absolute path — VS Code does not expand ~).
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
  copy_copilot_agents "$DEST/.github/agents"
  install_skills "$DEST/.github/skills"
  echo "Done. Start a run by invoking the 'delivery-orchestrator' agent with the packet."
  echo "Note (VS Code): if agents/skills aren't auto-detected, add this folder via"
  echo "      chat.agentFilesLocations / chat.agentSkillsLocations (absolute path, no ~)."
  echo "See PORTABILITY.md for the agent-to-agent invocation caveat."
}

echo "agents-factory install — target: $TARGET, scope: ${SCOPE:-n/a}, dest: $DEST"
case "$TARGET" in
  claude)  convert_claude ;;
  cursor)  convert_cursor ;;
  copilot) convert_copilot ;;
  plugin)  convert_plugin ;;
  *) echo "unknown target: $TARGET (use claude | copilot | cursor | plugin)" >&2; exit 1 ;;
esac
