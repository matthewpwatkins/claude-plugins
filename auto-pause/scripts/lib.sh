#!/usr/bin/env bash
# auto-pause: shared library for budget checking.
# Sourced by pre-tool-use.sh, session-start.sh, budget-check.sh, statusline.sh.

set -u

PLUGIN_ROOT="${CLAUDE_PLUGIN_ROOT:-$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)}"
CONFIG_DIR="${HOME}/.claude/auto-pause"
USER_CONFIG="${CONFIG_DIR}/config.json"
DEFAULT_CONFIG="${PLUGIN_ROOT}/defaults/config.json"
SESSION_MARKER_DIR="${CONFIG_DIR}/sessions"
CACHE_FILE="/tmp/auto-pause-cache-${UID}.json"

mkdir -p "$CONFIG_DIR" "$SESSION_MARKER_DIR" 2>/dev/null || true

# Echo merged config JSON (defaults <- user overrides).
load_config() {
  local defaults user
  defaults="$(cat "$DEFAULT_CONFIG")"
  if [ -f "$USER_CONFIG" ]; then
    user="$(cat "$USER_CONFIG")"
    jq -s '.[0] * .[1]' <(echo "$defaults") <(echo "$user")
  else
    echo "$defaults"
  fi
}

# Echo a single config field (jq path).
cfg() {
  local path="$1"
  load_config | jq -r "$path"
}

# Resolve the effective arm state. Highest-precedence first.
#   1. AUTO_PAUSE_ARMED env (1/0)
#   2. session marker .armed / .disarmed
#   3. autoArm config field
is_armed() {
  case "${AUTO_PAUSE_ARMED:-}" in
    1|true|TRUE|yes) echo 1; return ;;
    0|false|FALSE|no) echo 0; return ;;
  esac
  local sid="${CLAUDE_SESSION_ID:-default}"
  [ -f "${SESSION_MARKER_DIR}/${sid}.armed" ]    && { echo 1; return; }
  [ -f "${SESSION_MARKER_DIR}/${sid}.disarmed" ] && { echo 0; return; }
  local v
  v="$(cfg '.autoArm')"
  [ "$v" = "true" ] && echo 1 || echo 0
}

# Run ccusage with the configured command preference.
ccusage_call() {
  local cmd
  cmd="$(cfg '.ccusageCommand')"
  case "$cmd" in
    auto)
      if command -v ccusage >/dev/null 2>&1; then
        ccusage "$@"
      elif command -v npx >/dev/null 2>&1; then
        npx -y ccusage "$@" 2>/dev/null
      else
        return 127
      fi
      ;;
    *)
      # Treat as a shell snippet so users can set e.g. "bun x ccusage"
      eval "$cmd \"\$@\""
      ;;
  esac
}

# Fetch active block from ccusage. Echoes JSON:
#   {pct, totalTokens, endTime, remainingMinutes}
# Returns non-zero if ccusage unavailable, no active block, or limit not resolved.
fetch_budget() {
  local limit_arg raw total end pct remaining_minutes
  limit_arg="$(cfg '.tokenLimit')"
  [ -z "$limit_arg" ] && limit_arg="max"
  raw="$(ccusage_call blocks --active --token-limit "$limit_arg" --json 2>/dev/null)" || return 1
  [ -z "$raw" ] && return 1
  total="$(echo "$raw" | jq -r '.blocks[0].totalTokens // empty')"
  end="$(echo   "$raw" | jq -r '.blocks[0].endTime // empty')"
  pct="$(echo   "$raw" | jq -r '.blocks[0].tokenLimitStatus.percentUsed // empty')"
  remaining_minutes="$(echo "$raw" | jq -r '.blocks[0].projection.remainingMinutes // empty')"
  [ -z "$end" ] && return 1
  [ -z "$pct" ] || [ "$pct" = "null" ] && return 1
  jq -n \
    --arg pct "$pct" \
    --arg total "${total:-0}" \
    --arg end "$end" \
    --arg rm "${remaining_minutes:-0}" \
    '{pct: ($pct|tonumber), totalTokens: ($total|tonumber), endTime: $end, remainingMinutes: ($rm|tonumber)}'
}

# Cached wrapper around fetch_budget. Honors cacheSeconds.
budget_state() {
  local ttl now mtime
  ttl="$(cfg '.cacheSeconds')"
  if [ -f "$CACHE_FILE" ]; then
    now="$(date +%s)"
    mtime="$(stat -c %Y "$CACHE_FILE" 2>/dev/null || stat -f %m "$CACHE_FILE")"
    if [ -n "$mtime" ] && [ "$((now - mtime))" -lt "$ttl" ]; then
      cat "$CACHE_FILE"
      return 0
    fi
  fi
  local fresh
  fresh="$(fetch_budget)" || return 1
  echo "$fresh" > "$CACHE_FILE"
  echo "$fresh"
}

# Classify a percentage as OK / WARN / PAUSE based on thresholds.
classify() {
  local pct="$1" warn pause
  warn="$(cfg '.warnThresholdPct')"
  pause="$(cfg '.pauseThresholdPct')"
  awk -v p="$pct" -v w="$warn" -v x="$pause" 'BEGIN {
    if (p >= x) print "PAUSE";
    else if (p >= w) print "WARN";
    else print "OK";
  }'
}

# Sleep until ISO endTime + buffer seconds.
sleep_until() {
  local end="$1" buffer="${2:-60}" now target wait
  now="$(date +%s)"
  target="$(date -d "$end" +%s 2>/dev/null)"
  [ -z "$target" ] && return 1
  wait=$(( target - now + buffer ))
  [ "$wait" -lt 1 ] && wait=1
  sleep "$wait"
}
