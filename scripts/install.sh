#!/usr/bin/env bash
#
# install.sh — install/convert the agents-factory roster, skills, and commands
# for a target platform.
#
# Source of truth: .github/{agents,skills,commands}. This script DERIVES every other
# layout from it; never hand-edit a derived folder (.claude/, .cursor/, or the repo-root
# agents/ skills/ commands/) — re-run this instead.
#
# Installs GLOBALLY by default (user-level config: ~/.claude, ~/.cursor, ~/.copilot).
# Pass --scope project --path <dir> to install into a specific project instead.
#
set -euo pipefail

if [[ -z "${BASH_VERSINFO:-}" || "${BASH_VERSINFO[0]}" -lt 3 ]]; then
  echo "error: this script requires bash 3.2 or newer." >&2
  exit 1
fi

TARGET="claude"
SCOPE=""
DEST=""
DRY_RUN=false
KEEP_EXISTING=false
ROOT="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"

VALID_TARGETS="claude cursor copilot agents roo zoo plugin repo"
VALID_SCOPES="global project"

usage() {
  cat <<'EOF'
install.sh — install/convert the agents-factory roster + skills + commands.

Usage:
  scripts/install.sh --target claude                            # global  -> ~/.claude
  scripts/install.sh --target claude --scope project --path DIR # project -> DIR/.claude
  scripts/install.sh --target cursor                            # global  -> ~/.cursor/rules
  scripts/install.sh --target copilot                           # global  -> ~/.copilot (agents+skills)
  scripts/install.sh --target agents                            # global  -> ~/.agents (generic per-agent custom-mode files)
  scripts/install.sh --target roo                               # global  -> Zoo/Roo custom_modes.yaml (editor globalStorage)
  scripts/install.sh --target roo --scope project --path DIR    # project -> DIR/.roomodes (native single-file format)
  scripts/install.sh --target plugin                            # regenerate this repo's plugin dirs
  scripts/install.sh --target repo                              # regenerate EVERY derived dir in this repo
  scripts/install.sh --target repo --dry-run                    # show what would change; write nothing

Flags:
  --target  claude | cursor | copilot | agents | roo | zoo | plugin | repo   (default: claude)
            ('roo' and 'zoo' are aliases — same .roomodes / custom_modes.yaml format;
             global installs auto-detect Zoo Code and legacy Roo Code storage)
  --scope   global | project                                     (default: global)
  --path    DIR    project root (required when --scope project)
  --dest    DIR    alias for "--scope project --path DIR" (back-compat)
  --dry-run        report what would be created/updated; make no changes
  --keep-existing  never overwrite a skill or command already at the destination
  -h, --help       this message

Targets in brief:
  repo     the one to run after editing anything in .github/. Regenerates the plugin
           component dirs, .claude/, and .cursor/ in this repository, in one pass.
  plugin   only the repo-root agents/ skills/ commands/ that .claude-plugin/ discovers.
EOF
}

die() { echo "error: $*" >&2; exit 1; }

in_list() { # in_list <needle> <space-separated haystack>
  case " $2 " in *" $1 "*) return 0 ;; *) return 1 ;; esac
}

need_arg() { # need_arg <flag> <value-or-empty>
  [[ -n "${2:-}" ]] || { echo "error: $1 requires a value" >&2; usage >&2; exit 1; }
}

while [[ $# -gt 0 ]]; do
  case "$1" in
    --target)  need_arg --target "${2:-}"; TARGET="$2"; shift 2 ;;
    --scope)   need_arg --scope  "${2:-}"; SCOPE="$2";  shift 2 ;;
    --path)    need_arg --path   "${2:-}"; DEST="$2";   shift 2 ;;
    --dest)    need_arg --dest   "${2:-}"; DEST="$2"; SCOPE="${SCOPE:-project}"; shift 2 ;;
    --dry-run) DRY_RUN=true; shift ;;
    --keep-existing) KEEP_EXISTING=true; shift ;;
    -h|--help) usage; exit 0 ;;
    *) echo "unknown argument: $1" >&2; usage >&2; exit 1 ;;
  esac
done

in_list "$TARGET" "$VALID_TARGETS" \
  || die "unknown target: $TARGET (use ${VALID_TARGETS// / | })"
[[ -z "$SCOPE" ]] || in_list "$SCOPE" "$VALID_SCOPES" \
  || die "unknown scope: $SCOPE (use ${VALID_SCOPES// / | })"

# --- Resolve install scope -> DEST base directory ------------------------------
# The conversion functions append the platform subdir (e.g. .claude/agents) to DEST:
#   global  -> DEST=$HOME    => ~/.claude/agents, ~/.cursor/rules
#   project -> DEST=<path>   => <path>/.claude/agents, <path>/.cursor/rules
case "$TARGET" in
  plugin|repo)
    # These write into THIS repository: the plugin components must sit at the repo root
    # next to .claude-plugin/, and `repo` regenerates the repo's own derived dirs.
    if [[ -n "$DEST" && "$DEST" != "$ROOT" ]]; then
      die "--target $TARGET always writes to this repository ($ROOT); --path/--dest is not applicable"
    fi
    [[ "${SCOPE:-}" != "global" ]] || echo "note: --scope is ignored for --target $TARGET." >&2
    DEST="$ROOT"; SCOPE="project"
    ;;
  *)
    if [[ -z "$SCOPE" ]]; then
      [[ -n "$DEST" ]] && SCOPE="project" || SCOPE="global"
    fi
    case "$SCOPE" in
      global)
        [[ -z "$DEST" ]] || die "--scope global installs to \$HOME; drop --path/--dest, or pass --scope project"
        DEST="$HOME"
        ;;
      project)
        [[ -n "$DEST" ]] || die "--scope project requires --path <dir>"
        # Resolve to an absolute path so guards that compare against $ROOT are reliable
        # ("--path ." must be recognised as this repository).
        [[ -d "$DEST" ]] || die "--path '$DEST' is not a directory"
        DEST="$(cd "$DEST" && pwd)"
        ;;
    esac
    ;;
esac

AGENTS_SRC="$ROOT/.github/agents"
SKILLS_SRC="$ROOT/.github/skills"
COMMANDS_SRC="$ROOT/.github/commands"
[[ -d "$AGENTS_SRC" ]] || die "$AGENTS_SRC not found — run from the repo."

# --- Change accounting ---------------------------------------------------------
WROTE=0; UNCHANGED=0; SKIPPED=0; WOULD=0; ORPHANS=0; WARNINGS=0

warn() { echo "  WARNING: $*" >&2; WARNINGS=$((WARNINGS+1)); }

# emit <dest> <content> — write only when the content differs; honours --dry-run.
emit() {
  local dest="$1" content="$2"
  if [[ -f "$dest" ]] && [[ "$(cat "$dest")" == "$content" ]]; then
    UNCHANGED=$((UNCHANGED+1)); return 0
  fi
  if $DRY_RUN; then
    [[ -f "$dest" ]] && echo "  would update  $dest" || echo "  would create  $dest"
    WOULD=$((WOULD+1)); return 0
  fi
  mkdir -p "$(dirname "$dest")"
  printf '%s\n' "$content" > "$dest"
  WROTE=$((WROTE+1))
}

# report_orphans <dir> <suffix> — derived files with no corresponding source agent.
report_orphans() {
  local dir="$1" suffix="$2" f base
  [[ -d "$dir" ]] || return 0
  for f in "$dir"/*"$suffix"; do
    [[ -e "$f" ]] || continue
    base="$(basename "$f" "$suffix")"
    if [[ ! -f "$AGENTS_SRC/$base.agent.md" ]]; then
      echo "  ORPHAN: $f has no source in .github/agents (rename or delete it)"
      ORPHANS=$((ORPHANS+1))
    fi
  done
}

# --- VS Code tool id -> Claude Code tool name(s) ---
map_tool_id() {
  case "$1" in
    read)      echo "Read" ;;
    search)    echo "Grep Glob" ;;
    edit)      echo "Edit Write" ;;
    execute)   echo "Bash" ;;
    todo)      echo "TodoWrite" ;;
    agent)     echo "Task" ;;
    web|fetch) echo "WebFetch WebSearch" ;;
    vscode)    echo "" ;;       # editor-specific; no Claude equivalent, dropped on purpose
    *)         return 1 ;;      # unknown id — caller warns
  esac
}

# tool_ids <raw tools: line> — bare ids, quoted or unquoted, in source order.
tool_ids() {
  sed -e 's/^tools:[[:space:]]*//' -e 's/[][",]/ /g' <<<"$1" | tr -s ' ' '\n' | grep -v '^$' || true
}

# Given a raw "tools:" line, emit a Claude-style "tools: A, B, C" line (deduped, ordered).
claude_tools_line() {
  local line="$1" src_label="$2" id mapped t out="" seen=" "
  local ids; ids="$(tool_ids "$line")"
  if [[ -z "$ids" ]]; then
    warn "$src_label: could not parse any tool id from '$line' — defaulting to read-only."
    echo "tools: Read"; return
  fi
  for id in $ids; do
    if ! mapped="$(map_tool_id "$id")"; then
      warn "$src_label: unknown tool id '$id' — dropped (add it to map_tool_id)."
      continue
    fi
    for t in $mapped; do
      case "$seen" in *" $t "*) continue ;; esac
      seen="$seen$t "; out="$out, $t"
    done
  done
  [[ -n "$out" ]] || { echo "tools: Read"; return; }
  echo "tools: ${out#, }"
}

# Extract a frontmatter field value (first match) from a file: field_value <file> <key>
field_value() { grep -m1 "^$2:" "$1" | sed "s/^$2:[[:space:]]*//"; }

# --- Skills and commands (verbatim copies, overwrite by default) ---------------
install_skills() {
  local skills_dir="$1" s name dst
  [[ -d "$SKILLS_SRC" ]] || return 0
  for s in "$SKILLS_SRC"/*/; do
    [[ -d "$s" ]] || continue
    name="$(basename "$s")"; dst="$skills_dir/$name"
    if [[ -e "$dst" ]] && $KEEP_EXISTING; then
      echo "  skill '$name' kept (--keep-existing)"; SKIPPED=$((SKIPPED+1)); continue
    fi
    if [[ -d "$dst" ]] && diff -rq "$s" "$dst" >/dev/null 2>&1; then
      UNCHANGED=$((UNCHANGED+1)); continue
    fi
    if $DRY_RUN; then
      [[ -e "$dst" ]] && echo "  would update  skill '$name' -> $dst" \
                      || echo "  would create  skill '$name' -> $dst"
      WOULD=$((WOULD+1)); continue
    fi
    mkdir -p "$skills_dir"
    if [[ -e "$dst" ]]; then
      # Replace in place. Refuse anything that is not recognisably a skill directory,
      # so a mistyped destination can never take a recursive delete.
      [[ -d "$dst" && -f "$dst/SKILL.md" && "$dst" == "$skills_dir/$name" ]] \
        || die "refusing to replace '$dst' — not a skill directory (no SKILL.md)"
      rm -rf -- "$dst"
    fi
    cp -R "$s" "$dst"; WROTE=$((WROTE+1)); echo "  skill '$name' -> $dst"
  done
}

install_commands() {
  local cmd_dir="$1" c name dst
  [[ -d "$COMMANDS_SRC" ]] || return 0
  for c in "$COMMANDS_SRC"/*.md; do
    [[ -e "$c" ]] || continue
    name="$(basename "$c")"; dst="$cmd_dir/$name"
    if [[ -f "$dst" ]] && $KEEP_EXISTING; then
      echo "  command '$name' kept (--keep-existing)"; SKIPPED=$((SKIPPED+1)); continue
    fi
    emit "$dst" "$(cat "$c")"
  done
}

# --- Agents --------------------------------------------------------------------
# Convert .github/agents/*.agent.md into Claude-format *.md in <out_dir>.
# The tools:/argument-hint: transform is scoped to the YAML frontmatter block, so a body
# line that happens to start with one of those words is passed through untouched.
gen_agents() {
  local out_dir="$1"
  local count=0 src base dest line body fm
  for src in "$AGENTS_SRC"/*.agent.md; do
    [[ -e "$src" ]] || continue
    base="$(basename "$src" .agent.md)"
    dest="$out_dir/$base.md"
    body=""; fm=0
    while IFS= read -r line || [[ -n "$line" ]]; do
      if [[ "$fm" -lt 2 && "$line" == "---" ]]; then
        fm=$((fm+1)); body="$body$line"$'\n'; continue
      fi
      if [[ "$fm" -eq 1 ]]; then
        if [[ "$line" == tools:* ]]; then
          body="$body$(claude_tools_line "$line" "$base")"$'\n'; continue
        elif [[ "$line" == argument-hint:* ]]; then
          continue                                 # Claude subagents have no argument-hint
        fi
      fi
      body="$body$line"$'\n'
    done < "$src"
    emit "$dest" "${body%$'\n'}"
    count=$((count+1))
  done
  echo "  $count agents -> $out_dir/"
  report_orphans "$out_dir" ".md"
}

convert_claude() {
  local cmd dest
  gen_agents "$DEST/.claude/agents"
  install_skills "$DEST/.claude/skills"
  install_commands "$DEST/.claude/commands"
  echo "Done. Start a delivery run with:  /run-delivery <run-id>   or an advisory review with:  /run-advisory \"<topic>\""
}

# Claude Code marketplace plugin: components live at repo root (agents/ skills/
# commands/) so the .claude-plugin/ manifest can auto-discover them. The two manifests
# (.claude-plugin/plugin.json + marketplace.json) are tracked, not generated.
convert_plugin() {
  local cmd
  gen_agents "$DEST/agents"
  install_skills "$DEST/skills"
  install_commands "$DEST/commands"
  if [[ -f "$DEST/.claude-plugin/plugin.json" ]]; then
    echo "  manifest present -> $DEST/.claude-plugin/plugin.json"
  else
    die "$DEST/.claude-plugin/plugin.json missing — the plugin would not load."
  fi
  echo "Done. Local test:  /plugin marketplace add $DEST"
}

convert_cursor() {
  local out_dir="$DEST/.cursor/rules"
  local count=0 src base dest desc content
  for src in "$AGENTS_SRC"/*.agent.md; do
    [[ -e "$src" ]] || continue
    base="$(basename "$src" .agent.md)"
    dest="$out_dir/$base.mdc"
    desc="$(field_value "$src" description)"
    desc="${desc%\"}"; desc="${desc#\"}"
    content="$(
      echo "---"
      # quoted so a description containing ': ' cannot produce invalid YAML
      printf 'description: "%s"\n' "${desc//\"/\\\"}"
      echo "alwaysApply: false"
      echo "---"
      # body only (everything after the closing frontmatter ---)
      awk 'BEGIN{fm=0;started=0}
           /^---[[:space:]]*$/{fm++; next}
           fm>=2{ if(!started){ if($0 ~ /^[[:space:]]*$/) next; started=1; print "" } print }' "$src"
    )"
    emit "$dest" "$content"
    count=$((count+1))
  done
  echo "  $count agents -> $out_dir/ (@-mention a rule to use it)"
  report_orphans "$out_dir" ".mdc"
  echo "Note: Cursor has no native orchestrator — drive the run manually in chat (see PORTABILITY.md)."
}

# GitHub Copilot CLI: the agents are already in the native *.agent.md format, so we COPY
# them (no conversion). Global lives in the Copilot CLI personal dir ~/.copilot/{agents,
# skills} (overridable with COPILOT_HOME); project-level is <path>/.github/{agents,skills}.
copy_copilot_agents() {
  local out_dir="$1"
  local count=0 src base
  for src in "$AGENTS_SRC"/*.agent.md; do
    [[ -e "$src" ]] || continue
    base="$(basename "$src" .agent.md)"
    emit "$out_dir/$base.agent.md" "$(cat "$src")"
    count=$((count+1))
  done
  echo "  $count agents -> $out_dir/"
  report_orphans "$out_dir" ".agent.md"
}

convert_copilot() {
  local base
  if [[ "$SCOPE" == "global" ]]; then
    base="${COPILOT_HOME:-$HOME/.copilot}"
  else
    base="$DEST/.github"
    [[ "$base" != "$ROOT/.github" ]] || die "that would overwrite the source of truth ($ROOT/.github)"
  fi
  copy_copilot_agents "$base/agents"
  install_skills "$base/skills"
  echo "Done. Start a run by invoking the 'delivery-orchestrator' agent with the packet."
  echo "Note: global installs target the Copilot CLI personal dir (override with COPILOT_HOME)."
  echo "See PORTABILITY.md for the agent-to-agent invocation caveat."
}

# --- Generic ".agents" target (Roo Code custom-mode format) --------------------
# One YAML file per agent, each a single Roo Code custom-mode object. Roo Code itself
# natively reads a single .roomodes file with a customModes: array — see PORTABILITY.md.

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

roo_groups_line() {
  local line="$1" id mapped g seen=" " joined=""
  for id in $(tool_ids "$line"); do
    mapped="$(map_tool_group "$id")"
    [[ -n "$mapped" ]] || continue
    case "$seen" in *" $mapped "*) continue ;; esac
    seen="$seen$mapped "
  done
  for g in read edit browser command mcp; do
    case "$seen" in *" $g "*) joined="$joined, $g" ;; esac
  done
  [[ -n "$joined" ]] || joined=", read"
  echo "groups: [${joined#, }]"
}

# requirements-analyst -> "Requirements Analyst"   (awk: portable across GNU and BSD)
title_case() {
  echo "$1" | awk '{ gsub(/-/," "); for(i=1;i<=NF;i++) $i=toupper(substr($i,1,1)) substr($i,2); print }'
}

gen_agents_roo() {
  local out_dir="$1"
  local count=0 src base slug name desc dest role content
  for src in "$AGENTS_SRC"/*.agent.md; do
    [[ -e "$src" ]] || continue
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
    [[ -n "$role" ]] || role="$desc"
    dest="$out_dir/$base.yaml"
    content="$(
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
      awk 'BEGIN{fm=0;started=0}
           /^---[[:space:]]*$/{fm++; next}
           fm>=2{
             if(!started){ if($0 ~ /^[[:space:]]*$/) next; started=1 }
             if($0 ~ /^[[:space:]]*$/) print ""; else print "    " $0
           }' "$src"
    )"
    emit "$dest" "$content"
    count=$((count+1))
  done
  echo "  $count agents -> $out_dir/ (Roo Code custom-mode format)"
  report_orphans "$out_dir" ".yaml"
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

# `repo` regenerates every derived directory tracked in THIS repository, in one pass,
# so a single command after editing .github/ leaves nothing stale.
convert_repo() {
  echo "-- plugin components (agents/ skills/ commands/)"
  convert_plugin
  echo "-- Claude Code (.claude/)"
  convert_claude
  echo "-- Cursor (.cursor/rules/)"
  convert_cursor
}

BANNER="agents-factory install — target: $TARGET, scope: ${SCOPE:-n/a}, dest: $DEST"
$DRY_RUN && BANNER="$BANNER  [dry run — nothing will be written]"
echo "$BANNER"
case "$TARGET" in
  claude)  convert_claude ;;
  cursor)  convert_cursor ;;
  copilot) convert_copilot ;;
  agents)  convert_agents ;;
  roo|zoo) convert_roo ;;
  plugin)  convert_plugin ;;
  repo)    convert_repo ;;
  *) echo "unknown target: $TARGET (use claude | copilot | cursor | agents | roo | zoo | plugin | repo)" >&2; exit 1 ;;
esac

if $DRY_RUN; then
  echo "Summary: $WOULD would change, $UNCHANGED unchanged, $SKIPPED skipped, $ORPHANS orphaned, $WARNINGS warnings."
else
  echo "Summary: $WROTE written, $UNCHANGED unchanged, $SKIPPED skipped, $ORPHANS orphaned, $WARNINGS warnings."
fi
