#!/usr/bin/env bash
# Stop hook: remove this session's bulletin from the wall. Best-effort.

set -uo pipefail

# shellcheck source=lib.sh
source "$(dirname "$0")/lib.sh"

main() {
  local payload
  payload=$(cat)

  local session_id cwd
  session_id=$(hook_field "$payload" "session_id")
  cwd=$(hook_field "$payload" "cwd")
  [[ -z "$session_id" ]] && return 0
  [[ -z "$cwd" ]] && cwd="$PWD"

  local wall_dir file
  wall_dir="$(wall_dir_for "$cwd")"
  file="$(bulletin_path "$wall_dir" "$session_id")"

  rm -f "$file" 2>/dev/null || true

  # Also opportunistically sweep stale bulletins — keeps the wall tidy.
  sweep_stale_in "$wall_dir"
  return 0
}

main 2>/dev/null || true
exit 0
