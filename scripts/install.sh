#!/usr/bin/env bash
#
# install.sh — install/convert the agents-factory roster + skills for a target platform.
#
# Source of truth: .github/agents/*.agent.md (GitHub Copilot / VS Code format).
# This script DERIVES the other platforms' layouts from it; never hand-edit the derived
# folders (.claude/agents, .cursor/rules) — re-run this instead.
#
# Usage:
#   scripts/install.sh --target claude        # generate .claude/agents/*.md + ensure .claude/skills/
#   scripts/install.sh --target cursor        # generate .cursor/rules/*.mdc
#   scripts/install.sh --target copilot       # print guidance (agents already native)
#   scripts/install.sh --target claude --dest /path/to/your/project
#
set -euo pipefail

TARGET="claude"
ROOT="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
DEST="$ROOT"

usage() { sed -n '2,16p' "${BASH_SOURCE[0]}" | sed 's/^# \{0,1\}//'; }

while [[ $# -gt 0 ]]; do
  case "$1" in
    --target) TARGET="${2:-}"; shift 2 ;;
    --dest)   DEST="${2:-}";   shift 2 ;;
    -h|--help) usage; exit 0 ;;
    *) echo "unknown argument: $1" >&2; usage; exit 1 ;;
  esac
done

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

install_skills_claude() {
  [[ -d "$SKILLS_SRC" ]] || return 0
  mkdir -p "$DEST/.claude/skills"
  local s name dst
  for s in "$SKILLS_SRC"/*/; do
    [[ -d "$s" ]] || continue
    name="$(basename "$s")"; dst="$DEST/.claude/skills/$name"
    if [[ -e "$dst" ]]; then echo "  skill '$name' already present (skipped)"; continue; fi
    cp -R "$s" "$dst"; echo "  skill '$name' -> $dst"
  done
}

convert_claude() {
  local out_dir="$DEST/.claude/agents"; mkdir -p "$out_dir"
  local count=0 src base name dest line
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
  install_skills_claude
  if [[ ! -f "$DEST/.claude/commands/run-delivery.md" && -f "$ROOT/.claude/commands/run-delivery.md" ]]; then
    mkdir -p "$DEST/.claude/commands"
    cp "$ROOT/.claude/commands/run-delivery.md" "$DEST/.claude/commands/"
    echo "  driver -> $DEST/.claude/commands/run-delivery.md"
  fi
  echo "Done. Start a run with:  /run-delivery <run-id>"
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

print_copilot() {
  cat <<'EOF'
GitHub Copilot / VS Code: the agents are already native at .github/agents/*.agent.md.
  1. Copy the .github/ folder into your repo (verify the agents path your VS Code/Copilot
     version expects; only the location may differ).
  2. Skills: convert .github/skills/creating-stakeholder-packet/SKILL.md to a
     .github/prompts/*.prompt.md, or follow it manually before the first run.
  3. Start a run by invoking the `delivery-orchestrator` agent with the packet.
See PORTABILITY.md for the agent-to-agent invocation caveat.
EOF
}

echo "agents-factory install — target: $TARGET, dest: $DEST"
case "$TARGET" in
  claude)  convert_claude ;;
  cursor)  convert_cursor ;;
  copilot) print_copilot ;;
  *) echo "unknown target: $TARGET (use claude | copilot | cursor)" >&2; exit 1 ;;
esac
