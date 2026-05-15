#!/usr/bin/env bash
# auto-pause: standalone CLI. Prints one line: STATE PCT RESET_ISO.
# Used by the orchestrate-subagents skill and the /auto-pause:status command.
# Exit 0 always (so callers can pipe through grep without -e weirdness).
set -u
LIB="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)/lib.sh"
source "$LIB"

state_json="$(budget_state 2>/dev/null)" || {
  echo "UNKNOWN 0 -"
  exit 0
}
pct="$(echo "$state_json"   | jq -r '.pct')"
end="$(echo "$state_json"   | jq -r '.endTime')"
state="$(classify "$pct")"
printf "%s %s %s\n" "$state" "$pct" "$end"
