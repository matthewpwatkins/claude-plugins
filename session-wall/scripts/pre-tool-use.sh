#!/usr/bin/env bash
# PreToolUse hook for Edit | Write | NotebookEdit | Bash.
#
# - Sweeps stale bulletins from the wall (idempotent, cheap).
# - For Edit/Write/NotebookEdit: lazy-creates a bulletin for this session if
#   missing, and refreshes its heartbeat.
# - For Bash: same, but only when the command matches a destructive pattern.
#
# Never blocks the tool call. Failures are silenced so we never break a session.

set -uo pipefail

# shellcheck source=lib.sh
source "$(dirname "$0")/lib.sh"

main() {
  local payload
  payload=$(cat)

  local session_id cwd tool_name
  session_id=$(hook_field "$payload" "session_id")
  cwd=$(hook_field "$payload" "cwd")
  tool_name=$(hook_field "$payload" "tool_name")

  [[ -z "$session_id" ]] && return 0
  [[ -z "$cwd" ]] && cwd="$PWD"

  local wall_dir
  wall_dir="$(wall_dir_for "$cwd")"

  sweep_stale_in "$wall_dir"

  case "$tool_name" in
    Edit|Write|NotebookEdit)
      create_bulletin_if_missing "$wall_dir" "$session_id" "$cwd" "first file modification"
      heartbeat "$(bulletin_path "$wall_dir" "$session_id")"
      ;;
    Bash)
      local cmd
      cmd=$(printf '%s' "$payload" | jq -r '.tool_input.command // ""')
      if [[ -n "$cmd" ]] && is_destructive_bash "$cmd"; then
        create_bulletin_if_missing "$wall_dir" "$session_id" "$cwd" "destructive bash command"
        heartbeat "$(bulletin_path "$wall_dir" "$session_id")"
      elif [[ -f "$(bulletin_path "$wall_dir" "$session_id")" ]]; then
        # Already have a bulletin — keep it warm on any Bash use.
        heartbeat "$(bulletin_path "$wall_dir" "$session_id")"
      fi
      ;;
  esac

  return 0
}

main 2>/dev/null || true
exit 0
