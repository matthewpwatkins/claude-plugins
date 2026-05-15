#!/usr/bin/env bash
# auto-pause: PreToolUse hook. Sleeps the session if budget >= pauseThresholdPct.
# Exit 0 always — exit 2 would block the tool; we want it to proceed after sleep.
set -u

LIB="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)/lib.sh"
source "$LIB"

# Read stdin (we don't currently inspect it, but draining is polite).
input_json="$(cat 2>/dev/null || true)"
: "${input_json:=}"

# Fast-path no-ops.
[ "$(cfg '.enabled')" = "true" ] || exit 0
[ "$(is_armed)" = "1" ]          || exit 0

state_json="$(budget_state 2>/dev/null)" || exit 0   # ccusage missing → silent

pct="$(echo "$state_json" | jq -r '.pct')"
end="$(echo "$state_json" | jq -r '.endTime')"
state="$(classify "$pct")"
buffer="$(cfg '.bufferSeconds')"

case "$state" in
  OK)
    exit 0
    ;;
  WARN)
    jq -nc --arg msg "[auto-pause] Budget at ${pct}% of 5-hour window (warn threshold $(cfg '.warnThresholdPct')%). Reset at ${end}. Consider checkpointing soon; long jobs should use the auto-pause:chunk-and-checkpoint skill." \
      '{systemMessage: $msg}'
    exit 0
    ;;
  PAUSE)
    echo "[auto-pause] Budget ${pct}% >= pause threshold $(cfg '.pauseThresholdPct')%. Sleeping until ${end} + ${buffer}s." >&2
    jq -nc --arg msg "[auto-pause] PAUSING this session until 5-hour window resets at ${end}. The hook is sleeping; your next tool call simply blocked. When you wake up, continue from your last checkpoint." \
      '{systemMessage: $msg}'
    sleep_until "$end" "$buffer" || true
    # Invalidate cache so the next tool sees a fresh window.
    rm -f "$CACHE_FILE" 2>/dev/null || true
    exit 0
    ;;
esac
exit 0
