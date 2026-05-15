#!/usr/bin/env bash
# auto-pause: statusline renderer. Reads StatusLine stdin JSON; uses the
# native rate_limits.five_hour fields rather than shelling out to ccusage.
set -u

LIB="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)/lib.sh"
source "$LIB"

input="$(cat 2>/dev/null || echo '{}')"
pct="$(echo "$input"   | jq -r '.rate_limits.five_hour.usage_percentage // empty')"
reset="$(echo "$input" | jq -r '.rate_limits.five_hour.reset_time       // empty')"

# Fallback to ccusage if Claude Code didn't supply rate_limits.
if [ -z "$pct" ] || [ "$pct" = "null" ]; then
  state_json="$(budget_state 2>/dev/null || true)"
  if [ -n "$state_json" ]; then
    pct="$(echo "$state_json"   | jq -r '.pct')"
    reset="$(echo "$state_json" | jq -r '.endTime')"
  fi
fi

if [ -z "$pct" ] || [ "$pct" = "null" ]; then
  echo "⏱ —%"
  exit 0
fi

warn="$(cfg '.warnThresholdPct')"
pausep="$(cfg '.pauseThresholdPct')"

# ANSI color
color=""
reset_color="\033[0m"
state="$(awk -v p="$pct" -v w="$warn" -v x="$pausep" 'BEGIN {
  if (p >= x) print "PAUSE";
  else if (p >= w) print "WARN";
  else print "OK";
}')"
case "$state" in
  PAUSE) color="\033[31m" ;;   # red
  WARN)  color="\033[33m" ;;   # yellow
  OK)    color="\033[32m" ;;   # green
esac

show_reset="$(cfg '.statusline.showResetTime')"
if [ "$show_reset" = "true" ] && [ -n "$reset" ] && [ "$reset" != "null" ]; then
  # Render the reset time as local HH:MM.
  reset_hm="$(date -d "$reset" +%H:%M 2>/dev/null || echo "$reset")"
  printf "${color}⏱ %s%% · resets %s${reset_color}\n" "$pct" "$reset_hm"
else
  printf "${color}⏱ %s%%${reset_color}\n" "$pct"
fi
