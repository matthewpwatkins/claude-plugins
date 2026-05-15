#!/usr/bin/env bash
# Shared helpers for session-wall hooks.
# Sourced by session-start.sh, pre-tool-use.sh, stop.sh, sweep-stale.sh.

set -euo pipefail

# Staleness threshold (seconds). Override with SESSION_WALL_STALE_SECONDS
# (useful for tests).
: "${SESSION_WALL_STALE_SECONDS:=1800}"

now_iso() {
  date -u +"%Y-%m-%dT%H:%M:%SZ"
}

# Convert ISO-8601 UTC ("YYYY-MM-DDTHH:MM:SSZ") to epoch seconds.
iso_to_epoch() {
  local iso="$1"
  date -u -d "$iso" +%s 2>/dev/null || echo 0
}

# Wall directory for a given CWD. Pass "" to use $PWD.
wall_dir_for() {
  local cwd="${1:-$PWD}"
  echo "$cwd/.claude/session-wall"
}

# Bulletin path for a session in a given wall dir.
bulletin_path() {
  local wall_dir="$1"
  local session_id="$2"
  echo "$wall_dir/$session_id.json"
}

# Atomic JSON write: takes target path on stdin via $1, JSON content on stdin.
atomic_write() {
  local target="$1"
  local tmp
  tmp="$(mktemp "${target}.XXXXXX")"
  cat > "$tmp"
  mv "$tmp" "$target"
}

# Read session_id and cwd from a hook stdin JSON payload (passed as $1).
hook_field() {
  local payload="$1"
  local field="$2"
  printf '%s' "$payload" | jq -r --arg f "$field" '.[$f] // ""'
}

# True if file's last_heartbeat is older than the staleness threshold.
is_stale() {
  local file="$1"
  local hb
  hb=$(jq -r '.last_heartbeat // ""' "$file" 2>/dev/null || echo "")
  [[ -z "$hb" ]] && return 0
  local hb_epoch now_epoch
  hb_epoch=$(iso_to_epoch "$hb")
  now_epoch=$(date -u +%s)
  (( now_epoch - hb_epoch > SESSION_WALL_STALE_SECONDS ))
}

# Sweep stale bulletins from a wall dir. Best-effort.
sweep_stale_in() {
  local wall_dir="$1"
  [[ -d "$wall_dir" ]] || return 0
  local f
  for f in "$wall_dir"/*.json; do
    [[ -e "$f" ]] || continue
    if is_stale "$f"; then
      rm -f "$f" 2>/dev/null || true
    fi
  done
}

# Update last_heartbeat on an existing bulletin (no-op if missing).
heartbeat() {
  local file="$1"
  [[ -f "$file" ]] || return 0
  local now
  now=$(now_iso)
  jq --arg ts "$now" '.last_heartbeat = $ts' "$file" | atomic_write "$file"
}

# Create a fresh bulletin if one does not exist.
# Args: wall_dir session_id cwd reason
create_bulletin_if_missing() {
  local wall_dir="$1"
  local session_id="$2"
  local cwd="$3"
  local reason="${4:-first modification}"
  local file
  file="$(bulletin_path "$wall_dir" "$session_id")"
  [[ -f "$file" ]] && return 0
  mkdir -p "$wall_dir"
  local now branch
  now=$(now_iso)
  branch=$(git -C "$cwd" rev-parse --abbrev-ref HEAD 2>/dev/null || echo "")
  jq -n \
    --arg sid "$session_id" \
    --arg ts "$now" \
    --arg cwd "$cwd" \
    --arg branch "$branch" \
    --arg reason "$reason" \
    '{
      session_id: $sid,
      started_at: $ts,
      last_heartbeat: $ts,
      cwd: $cwd,
      worktree: $cwd,
      branch: $branch,
      current_activity: $reason,
      paths: [],
      external_resources: [],
      history: [{ts: $ts, msg: ("bulletin created — " + $reason)}]
    }' | atomic_write "$file"
}

# Default destructive-Bash regex. Override via SESSION_WALL_DESTRUCTIVE_REGEX.
: "${SESSION_WALL_DESTRUCTIVE_REGEX:=git[[:space:]]+push|git[[:space:]]+reset[[:space:]]+--hard|git[[:space:]]+clean|rm[[:space:]]+-rf|terraform[[:space:]]+apply|cdk[[:space:]]+deploy|(^|/)(truncate|wipe|purge|reset-)[a-zA-Z0-9_.-]*}"

is_destructive_bash() {
  local cmd="$1"
  [[ "$cmd" =~ $SESSION_WALL_DESTRUCTIVE_REGEX ]]
}
